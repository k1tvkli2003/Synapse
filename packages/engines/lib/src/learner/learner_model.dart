import 'dart:math' as math;

import 'package:synapse_core/synapse_core.dart';

/// A per-concept prediction from the learner model (prompt 49).
class ConceptPrediction {
  const ConceptPrediction({
    required this.conceptId,
    required this.pKnown,
    required this.retention,
    required this.willForgetInDays,
    required this.recommendedDifficulty,
    required this.reason,
  });

  /// Probability the learner currently *knows* the concept (BKT).
  final double pKnown;

  /// Probability they'd recall it *right now* (Ebbinghaus-style decay).
  final double retention;

  /// Days until predicted retention drops below the recall threshold.
  final int willForgetInDays;

  /// 1..5 difficulty to target the zone of proximal development.
  final int recommendedDifficulty;

  /// Human-readable, explainable justification (prompt 49 §5).
  final String reason;
  final ConceptId conceptId;

  bool get atRisk => retention < 0.6;
}

/// A pure-Dart predictive learner model (prompt 49). Turns [ConceptMastery] from
/// a score into knowledge tracing + a forgetting forecast + a shared difficulty
/// policy used by Study Plan, Copilot and Insights. Fully explainable and
/// resettable; sane cold-start defaults.
class LearnerModel {
  const LearnerModel({
    this.pLearn = 0.18,
    this.pSlip = 0.10,
    this.pGuess = 0.20,
    this.pInit = 0.25,
    this.recallThreshold = 0.6,
  });

  /// BKT transition/emission parameters.
  final double pLearn;
  final double pSlip;
  final double pGuess;
  final double pInit;
  final double recallThreshold;

  /// Bayesian Knowledge Tracing posterior update for one observation.
  double _bktUpdate(double prior, bool correct) {
    final pObs = correct
        ? prior * (1 - pSlip) + (1 - prior) * pGuess
        : prior * pSlip + (1 - prior) * (1 - pGuess);
    if (pObs <= 0) return prior;
    final posterior = correct
        ? prior * (1 - pSlip) / pObs
        : prior * pSlip / pObs;
    // Apply learning transition.
    return (posterior + (1 - posterior) * pLearn).clamp(0.0, 1.0);
  }

  /// Estimate pKnown by replaying the EMA-derived hit rate through BKT. We don't
  /// store the full event history, so we reconstruct from attempts/correct +
  /// the current mastery EMA — a faithful, deterministic approximation.
  double pKnown(ConceptMastery m) {
    if (m.attempts == 0) return pInit;
    var p = pInit;
    final correctCount = m.correct;
    final wrongCount = m.attempts - m.correct;
    // Interleave outcomes for a stable estimate, recent EMA weighted last.
    final seq = <bool>[
      for (var i = 0; i < math.min(correctCount, 20); i++) true,
      for (var i = 0; i < math.min(wrongCount, 20); i++) false,
    ]..shuffleDeterministic(m.conceptId.hashCode);
    for (final ok in seq) {
      p = _bktUpdate(p, ok);
    }
    // Blend with the live EMA so recent trend matters.
    return (0.6 * p + 0.4 * m.mastery).clamp(0.0, 1.0);
  }

  /// Memory strength → retention now. Strength grows with successful reps and
  /// pKnown; retention decays exponentially with days since last study.
  double retentionNow(ConceptMastery m, {DateTime? now}) {
    final n = now ?? DateTime.now();
    if (m.lastStudied == null || m.attempts == 0) return pInit;
    final days = n.difference(m.lastStudied!).inHours / 24.0;
    final strength = 0.6 + 2.4 * pKnown(m) + 0.25 * math.min(m.correct, 8);
    final stability = math.max(strength, 0.4); // half-life-ish in days
    return math.exp(-days / stability).clamp(0.0, 1.0);
  }

  int willForgetInDays(ConceptMastery m, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final r = retentionNow(m, now: n);
    if (r <= recallThreshold) return 0;
    // Solve exp(-d/stability) = threshold from the current point.
    final strength = 0.6 + 2.4 * pKnown(m) + 0.25 * math.min(m.correct, 8);
    final stability = math.max(strength, 0.4);
    final daysSince = m.lastStudied == null ? 0 : n.difference(m.lastStudied!).inHours / 24.0;
    final totalDays = -stability * math.log(recallThreshold);
    return math.max(0, (totalDays - daysSince).round());
  }

  /// One difficulty policy for every module (prompt 49 §3): target the edge of
  /// competence — too-easy if mastered, too-hard if unknown.
  int nextDifficulty(ConceptMastery m) {
    final p = pKnown(m);
    if (p < 0.2) return 1;
    if (p < 0.4) return 2;
    if (p < 0.6) return 3;
    if (p < 0.8) return 4;
    return 5;
  }

  ConceptPrediction predict(ConceptMastery m, {DateTime? now}) {
    final p = pKnown(m);
    final r = retentionNow(m, now: now);
    final forget = willForgetInDays(m, now: now);
    final diff = nextDifficulty(m);
    final reason = switch ((p, r)) {
      _ when m.attempts == 0 => 'New concept — starting at an easy level',
      _ when r < 0.4 => 'Retention dropping fast — review now',
      _ when r < recallThreshold => 'Likely to forget soon — scheduled for review',
      _ when p > 0.85 => 'Strong — offering a stretch difficulty',
      _ => 'Building mastery — keeping it in rotation',
    };
    return ConceptPrediction(
      conceptId: m.conceptId,
      pKnown: p,
      retention: r,
      willForgetInDays: forget,
      recommendedDifficulty: diff,
      reason: reason,
    );
  }

  /// The concepts most worth studying now: low retention first, then low pKnown.
  List<ConceptPrediction> prioritize(Iterable<ConceptMastery> masteries, {DateTime? now, int limit = 20}) {
    final preds = masteries.map((m) => predict(m, now: now)).toList()
      ..sort((a, b) {
        final byRisk = a.retention.compareTo(b.retention);
        if (byRisk != 0) return byRisk;
        return a.pKnown.compareTo(b.pKnown);
      });
    return preds.take(limit).toList();
  }
}

extension<T> on List<T> {
  /// Deterministic shuffle so predictions are stable across runs (no RNG state).
  void shuffleDeterministic(int seed) {
    final rng = math.Random(seed);
    for (var i = length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final tmp = this[i];
      this[i] = this[j];
      this[j] = tmp;
    }
  }
}

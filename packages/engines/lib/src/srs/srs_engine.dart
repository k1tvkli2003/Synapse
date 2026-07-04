import 'package:synapse_core/synapse_core.dart';

/// The shared spaced-repetition scheduler (prompt 22). An SM-2 variant used by
/// Terms, Cards and saved Mnemonics so they mix into one Daily Review.
class SrsEngine {
  const SrsEngine._();

  static const double minEase = 1.3;

  /// Apply a [grade] to [card] and return the rescheduled card.
  static SrsCard grade(SrsCard card, ReviewGrade grade, {DateTime? now}) {
    final ts = now ?? DateTime.now();
    var ease = card.ease;
    var interval = card.intervalDays;
    var box = card.box;
    var lapses = card.lapses;
    final reps = card.reps + 1;

    switch (grade) {
      case ReviewGrade.again:
        ease = (ease - 0.20).clamp(minEase, 3.0);
        interval = 0; // relearn today
        box = 0;
        lapses += 1;
      case ReviewGrade.hard:
        ease = (ease - 0.15).clamp(minEase, 3.0);
        interval = interval <= 1 ? 1 : (interval * 1.2).round();
        box = box; // unchanged
      case ReviewGrade.good:
        if (card.reps == 0) {
          interval = 1;
        } else if (card.intervalDays <= 1) {
          interval = 4;
        } else {
          interval = (card.intervalDays * ease).round();
        }
        box += 1;
      case ReviewGrade.easy:
        ease = (ease + 0.15).clamp(minEase, 3.0);
        interval = card.reps == 0 ? 2 : (card.intervalDays * ease * 1.3).round().clamp(1, 365);
        box += 1;
    }

    final due = grade == ReviewGrade.again
        ? ts.add(const Duration(minutes: 10))
        : DateTime(ts.year, ts.month, ts.day).add(Duration(days: interval));

    return card.copyWith(
      ease: ease,
      intervalDays: interval,
      box: box,
      lapses: lapses,
      reps: reps,
      dueAt: due,
    );
  }

  /// The due queue across all origins, oldest-due first (prompt 22 Daily Review).
  static List<SrsCard> dueQueue(Iterable<SrsCard> cards, {DateTime? now, int? limit}) {
    final ts = now ?? DateTime.now();
    final due = cards.where((c) => c.isDue(ts)).toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    if (limit != null && due.length > limit) return due.sublist(0, limit);
    return due;
  }

  static int dueCount(Iterable<SrsCard> cards, {DateTime? now}) =>
      cards.where((c) => c.isDue(now)).length;

  /// Forgetting forecast: estimate retention probability of [card] at [now]
  /// (prompt 49 — simple exponential decay over the interval).
  static double retention(SrsCard card, {DateTime? now}) {
    if (card.intervalDays <= 0) return 1.0;
    final ts = now ?? DateTime.now();
    final elapsedDays = ts.difference(card.dueAt.subtract(Duration(days: card.intervalDays))).inHours / 24.0;
    final stability = card.intervalDays * card.ease;
    if (stability <= 0) return 0.0;
    final r = _expNeg(elapsedDays / stability);
    return r.clamp(0.0, 1.0);
  }

  static double _expNeg(double x) {
    // e^-x without importing dart:math at call sites kept simple.
    var term = 1.0;
    var sum = 1.0;
    for (var n = 1; n < 12; n++) {
      term *= -x / n;
      sum += term;
    }
    return sum < 0 ? 0 : sum;
  }
}

import 'package:equatable/equatable.dart';

import 'ids.dart';
import 'module_key.dart';

/// One mastery score per concept, aggregated from **every** module (prompt 33).
/// Studying a concept in Terms, reading it on an ECG, or facing it in Arena all
/// move the same number. Mastery is an exponential moving average of outcomes in
/// `[0, 1]`, which decays naturally toward correct/incorrect evidence.
class ConceptMastery extends Equatable {
  const ConceptMastery({
    required this.conceptId,
    this.mastery = 0.0,
    this.attempts = 0,
    this.correct = 0,
    this.lastStudied,
    this.perModule = const {},
  });

  final ConceptId conceptId;

  /// 0 (unknown) … 1 (mastered).
  final double mastery;
  final int attempts;
  final int correct;
  final DateTime? lastStudied;

  /// Attempt counts per module, so Insights can show *where* a concept is being
  /// practiced (and where it is being neglected).
  final Map<ModuleKey, int> perModule;

  bool get isWeak => attempts >= 2 && mastery < 0.5;
  bool get isMastered => mastery >= 0.85 && attempts >= 4;

  /// Fold a new outcome into the score. [weight] lets harder evidence (e.g. a
  /// full case) move the needle more than a single flashcard.
  ConceptMastery applyOutcome({
    required bool wasCorrect,
    required ModuleKey source,
    DateTime? at,
    double weight = 0.30,
  }) {
    final target = wasCorrect ? 1.0 : 0.0;
    final next = (mastery + (target - mastery) * weight).clamp(0.0, 1.0);
    final updatedPerModule = Map<ModuleKey, int>.from(perModule)
      ..update(source, (v) => v + 1, ifAbsent: () => 1);
    return ConceptMastery(
      conceptId: conceptId,
      mastery: next,
      attempts: attempts + 1,
      correct: correct + (wasCorrect ? 1 : 0),
      lastStudied: at ?? DateTime.now(),
      perModule: updatedPerModule,
    );
  }

  Map<String, dynamic> toJson() => {
        'conceptId': conceptId,
        'mastery': mastery,
        'attempts': attempts,
        'correct': correct,
        'lastStudied': lastStudied?.toIso8601String(),
        'perModule': perModule.map((k, v) => MapEntry(k.name, v)),
      };

  factory ConceptMastery.fromJson(Map<String, dynamic> j) => ConceptMastery(
        conceptId: j['conceptId'] as String,
        mastery: (j['mastery'] as num?)?.toDouble() ?? 0.0,
        attempts: j['attempts'] as int? ?? 0,
        correct: j['correct'] as int? ?? 0,
        lastStudied: DateTime.tryParse(j['lastStudied']?.toString() ?? ''),
        perModule: (j['perModule'] as Map?)?.map(
              (k, v) => MapEntry(
                ModuleKey.tryParse(k.toString()) ?? ModuleKey.terms,
                (v as num).toInt(),
              ),
            ) ??
            const {},
      );

  @override
  List<Object?> get props => [conceptId, mastery, attempts, correct, lastStudied];
}

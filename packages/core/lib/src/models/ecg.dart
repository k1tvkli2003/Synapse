import 'package:equatable/equatable.dart';

import 'ids.dart';

/// An ECG drill case: a tracing tagged with its diagnosis concept and answer
/// options (prompt 04 §5 / 14). Tracings render from generated parameters via a
/// CustomPainter so the module works fully offline with no image assets.
class EcgCase extends Equatable {
  const EcgCase({
    required this.id,
    required this.title,
    required this.diagnosis,
    required this.options,
    required this.correctIndex,
    this.conceptId,
    this.difficulty = 2,
    this.rateBpm = 75,
    this.rhythm = EcgRhythm.sinus,
    this.teaching,
    this.findings = const [],
  });

  final EcgCaseId id;
  final String title;

  /// The correct diagnosis label (also the option at [correctIndex]).
  final String diagnosis;
  final List<String> options;
  final int correctIndex;
  final ConceptId? conceptId;
  final int difficulty;
  final int rateBpm;
  final EcgRhythm rhythm;

  /// Short teaching point shown after answering.
  final String? teaching;

  /// Hallmark findings (e.g. "Peaked T waves", "Wide QRS").
  final List<String> findings;

  bool isCorrect(int index) => index == correctIndex;

  @override
  List<Object?> get props => [id, title, diagnosis, options, correctIndex];
}

/// Drives the generative tracing painter (and a future slider mode, prompt 14).
enum EcgRhythm {
  sinus,
  tachycardia,
  bradycardia,
  afib,
  flutter,
  vtach,
  vfib,
  stemi,
  hyperkalemia,
  heartBlock,
  asystole,
}

class EcgGenParams extends Equatable {
  const EcgGenParams({
    this.rateBpm = 75,
    this.rhythm = EcgRhythm.sinus,
    this.potassium = 4.0,
    this.stElevation = 0.0,
    this.qrsWidthMs = 90,
  });

  final int rateBpm;
  final EcgRhythm rhythm;
  final double potassium;
  final double stElevation;
  final int qrsWidthMs;

  EcgGenParams copyWith({
    int? rateBpm,
    EcgRhythm? rhythm,
    double? potassium,
    double? stElevation,
    int? qrsWidthMs,
  }) {
    return EcgGenParams(
      rateBpm: rateBpm ?? this.rateBpm,
      rhythm: rhythm ?? this.rhythm,
      potassium: potassium ?? this.potassium,
      stElevation: stElevation ?? this.stElevation,
      qrsWidthMs: qrsWidthMs ?? this.qrsWidthMs,
    );
  }

  @override
  List<Object?> get props => [rateBpm, rhythm, potassium, stElevation, qrsWidthMs];
}

class EcgAttempt extends Equatable {
  const EcgAttempt({
    required this.caseId,
    required this.chosenIndex,
    required this.correct,
    this.at,
  });

  final EcgCaseId caseId;
  final int chosenIndex;
  final bool correct;
  final DateTime? at;

  @override
  List<Object?> get props => [caseId, chosenIndex, correct];
}

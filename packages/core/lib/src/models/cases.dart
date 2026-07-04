import 'package:equatable/equatable.dart';

import 'ids.dart';
import 'module_key.dart';

/// A stage in a Virtual Patient encounter. Each stage is powered by a different
/// module (ECG, Labs, Sounds, Algorithms, OR) so a case is *impossible* to
/// complete with one module alone (prompt 32 / 34). On completion it distributes
/// mastery to every concept it touched.
class CaseStage extends Equatable {
  const CaseStage({
    required this.module,
    required this.title,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    this.conceptIds = const [],
    this.rationale,
    this.payload = const {},
  });

  final ModuleKey module;
  final String title;
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final List<ConceptId> conceptIds;
  final String? rationale;

  /// Module-specific render hints, e.g. {'rhythm': 'stemi'} for an ECG stage or
  /// {'panel': 'bmp'} for a Labs stage.
  final Map<String, String> payload;

  bool isCorrect(int i) => i == correctIndex;

  @override
  List<Object?> get props => [module, title, prompt, options, correctIndex];
}

class VirtualPatientCase extends Equatable {
  const VirtualPatientCase({
    required this.id,
    required this.title,
    required this.presentation,
    required this.stages,
    this.demographics,
    this.difficulty = 3,
    this.conceptIds = const [],
    this.finalDiagnosis,
  });

  final CaseId id;
  final String title;

  /// The opening vignette ("a 64-year-old presents with…").
  final String presentation;
  final String? demographics;
  final int difficulty;
  final List<CaseStage> stages;
  final List<ConceptId> conceptIds;
  final String? finalDiagnosis;

  int get stageCount => stages.length;

  @override
  List<Object?> get props => [id, title, stages];
}

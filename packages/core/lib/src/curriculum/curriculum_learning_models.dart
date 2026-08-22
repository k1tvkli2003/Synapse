import 'package:equatable/equatable.dart';

import '../models/ids.dart';
import '../serialization/stable_enum_codec.dart';
import 'curriculum_models.dart';

enum CurriculumSessionType {
  learn,
  recall,
  repair,
  apply,
  challenge,
  checkpoint,
  teach,
  transfer,
}

enum CognitiveLevel {
  recall,
  explain,
  connect,
  diagnose,
  decide,
  defend,
  teach,
  transfer,
}

enum SessionArcStep {
  orient,
  retrieveOrPredict,
  explainOrModel,
  guidedConstruction,
  discriminate,
  apply,
  calibrate,
  repair,
  recallCommit,
  debrief,
}

enum CompletionEvidenceType {
  response,
  explanation,
  discrimination,
  application,
  confidenceCalibration,
  teachBack,
  transfer,
}

enum InteractionStepRole {
  orientation,
  instruction,
  guidedPractice,
  retrieval,
  assessment,
  repair,
  reflection,
  debrief,
}

enum InteractionFamily {
  orientation,
  retrieval,
  explanation,
  construction,
  discrimination,
  application,
  confidence,
  reflection,
}

enum InteractionKind {
  orientCard,
  predict,
  singleBestAnswer,
  multiSelect,
  cloze,
  shortAnswer,
  conceptMatch,
  sequenceOrder,
  causalChainBuild,
  compareContrast,
  imageLabel,
  imageHotspot,
  ecgTraceInterpretation,
  labTrendInterpretation,
  audioDiscrimination,
  clinicalVignette,
  branchingDecision,
  teachBack,
  confidenceRating,
  evidencePeek,
  recapRetrieval,
}

enum ResponseKind {
  none,
  singleChoice,
  multipleChoice,
  orderedIds,
  matchedIds,
  freeText,
  numeric,
  rubric,
}

enum FreeTextNormalization {
  none,
  unicodeCasefold,
  medicalTermAliases,
  reviewerRubric,
}

enum MasteryDimension {
  recall,
  discrimination,
  explain,
  connect,
  application,
  reasoning,
  procedure,
  confidenceCalibration,
  recencyStability,
  transfer,
}

enum ScientificMirroring {
  notDirectional,
  mirrorNavigationOnly,
  neverMirrorScientificContent,
}

final _sessionTypeCodec = StableEnumCodec<CurriculumSessionType>({
  'learn': CurriculumSessionType.learn,
  'recall': CurriculumSessionType.recall,
  'repair': CurriculumSessionType.repair,
  'apply': CurriculumSessionType.apply,
  'challenge': CurriculumSessionType.challenge,
  'checkpoint': CurriculumSessionType.checkpoint,
  'teach': CurriculumSessionType.teach,
  'transfer': CurriculumSessionType.transfer,
});

final _cognitiveCodec = StableEnumCodec<CognitiveLevel>({
  'recall': CognitiveLevel.recall,
  'explain': CognitiveLevel.explain,
  'connect': CognitiveLevel.connect,
  'diagnose': CognitiveLevel.diagnose,
  'decide': CognitiveLevel.decide,
  'defend': CognitiveLevel.defend,
  'teach': CognitiveLevel.teach,
  'transfer': CognitiveLevel.transfer,
});

final _arcCodec = StableEnumCodec<SessionArcStep>({
  'orient': SessionArcStep.orient,
  'retrieve_or_predict': SessionArcStep.retrieveOrPredict,
  'explain_or_model': SessionArcStep.explainOrModel,
  'guided_construction': SessionArcStep.guidedConstruction,
  'discriminate': SessionArcStep.discriminate,
  'apply': SessionArcStep.apply,
  'calibrate': SessionArcStep.calibrate,
  'repair': SessionArcStep.repair,
  'recall_commit': SessionArcStep.recallCommit,
  'debrief': SessionArcStep.debrief,
});

final _completionCodec = StableEnumCodec<CompletionEvidenceType>({
  'response': CompletionEvidenceType.response,
  'explanation': CompletionEvidenceType.explanation,
  'discrimination': CompletionEvidenceType.discrimination,
  'application': CompletionEvidenceType.application,
  'confidence_calibration': CompletionEvidenceType.confidenceCalibration,
  'teach_back': CompletionEvidenceType.teachBack,
  'transfer': CompletionEvidenceType.transfer,
});

final _stepRoleCodec = StableEnumCodec<InteractionStepRole>({
  'orientation': InteractionStepRole.orientation,
  'instruction': InteractionStepRole.instruction,
  'guided_practice': InteractionStepRole.guidedPractice,
  'retrieval': InteractionStepRole.retrieval,
  'assessment': InteractionStepRole.assessment,
  'repair': InteractionStepRole.repair,
  'reflection': InteractionStepRole.reflection,
  'debrief': InteractionStepRole.debrief,
});

final _familyCodec = StableEnumCodec<InteractionFamily>({
  'orientation': InteractionFamily.orientation,
  'retrieval': InteractionFamily.retrieval,
  'explanation': InteractionFamily.explanation,
  'construction': InteractionFamily.construction,
  'discrimination': InteractionFamily.discrimination,
  'application': InteractionFamily.application,
  'confidence': InteractionFamily.confidence,
  'reflection': InteractionFamily.reflection,
});

final _kindCodec = StableEnumCodec<InteractionKind>({
  'orient_card': InteractionKind.orientCard,
  'predict': InteractionKind.predict,
  'single_best_answer': InteractionKind.singleBestAnswer,
  'multi_select': InteractionKind.multiSelect,
  'cloze': InteractionKind.cloze,
  'short_answer': InteractionKind.shortAnswer,
  'concept_match': InteractionKind.conceptMatch,
  'sequence_order': InteractionKind.sequenceOrder,
  'causal_chain_build': InteractionKind.causalChainBuild,
  'compare_contrast': InteractionKind.compareContrast,
  'image_label': InteractionKind.imageLabel,
  'image_hotspot': InteractionKind.imageHotspot,
  'ecg_trace_interpretation': InteractionKind.ecgTraceInterpretation,
  'lab_trend_interpretation': InteractionKind.labTrendInterpretation,
  'audio_discrimination': InteractionKind.audioDiscrimination,
  'clinical_vignette': InteractionKind.clinicalVignette,
  'branching_decision': InteractionKind.branchingDecision,
  'teach_back': InteractionKind.teachBack,
  'confidence_rating': InteractionKind.confidenceRating,
  'evidence_peek': InteractionKind.evidencePeek,
  'recap_retrieval': InteractionKind.recapRetrieval,
});

final _responseCodec = StableEnumCodec<ResponseKind>({
  'none': ResponseKind.none,
  'single_choice': ResponseKind.singleChoice,
  'multiple_choice': ResponseKind.multipleChoice,
  'ordered_ids': ResponseKind.orderedIds,
  'matched_ids': ResponseKind.matchedIds,
  'free_text': ResponseKind.freeText,
  'numeric': ResponseKind.numeric,
  'rubric': ResponseKind.rubric,
});

final _normalizationCodec = StableEnumCodec<FreeTextNormalization>({
  'none': FreeTextNormalization.none,
  'unicode_casefold': FreeTextNormalization.unicodeCasefold,
  'medical_term_aliases': FreeTextNormalization.medicalTermAliases,
  'reviewer_rubric': FreeTextNormalization.reviewerRubric,
});

final _masteryCodec = StableEnumCodec<MasteryDimension>({
  'recall': MasteryDimension.recall,
  'discrimination': MasteryDimension.discrimination,
  'explain': MasteryDimension.explain,
  'connect': MasteryDimension.connect,
  'application': MasteryDimension.application,
  'reasoning': MasteryDimension.reasoning,
  'procedure': MasteryDimension.procedure,
  'confidence_calibration': MasteryDimension.confidenceCalibration,
  'recency_stability': MasteryDimension.recencyStability,
  'transfer': MasteryDimension.transfer,
});

final _mirroringCodec = StableEnumCodec<ScientificMirroring>({
  'not_directional': ScientificMirroring.notDirectional,
  'mirror_navigation_only': ScientificMirroring.mirrorNavigationOnly,
  'never_mirror_scientific_content':
      ScientificMirroring.neverMirrorScientificContent,
});

final _idPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:/-]*$');

String _id(String value, String field) {
  if (value != value.trim() || !_idPattern.hasMatch(value)) {
    throw ArgumentError.value(value, field, 'Invalid stable ID.');
  }
  return value;
}

List<String> _idList(
  Iterable<String> values,
  String field, {
  bool nonEmpty = false,
}) {
  final list = values.map((value) => _id(value, field)).toList(growable: false);
  if (nonEmpty && list.isEmpty) {
    throw ArgumentError.value(list, field, 'Must not be empty.');
  }
  if (list.toSet().length != list.length) {
    throw ArgumentError.value(list, field, 'Duplicate IDs are not allowed.');
  }
  return List.unmodifiable(list);
}

List<String> _strings(Object? value, String field) {
  if (value is! List || value.any((item) => item is! String)) {
    throw SerializationException(
      code: SerializationIssueCode.invalidField,
      message: '$field must be an array of strings.',
      source: value,
    );
  }
  return value.cast<String>();
}

List<T> _enums<T extends Enum>(
  Object? value,
  String field,
  StableEnumCodec<T> codec,
) {
  if (value is! List) {
    throw SerializationException(
      code: SerializationIssueCode.invalidField,
      message: '$field must be an array.',
      source: value,
    );
  }
  return value.map(codec.decode).toList(growable: false);
}

final class CurriculumMicroLesson extends Equatable {
  CurriculumMicroLesson({
    required this.id,
    required this.hierarchyNodeId,
    required this.unitId,
    required this.conceptClusterId,
    required this.ordinal,
    required this.titleUnitId,
    required this.estimatedSeconds,
    required this.splitRationale,
    required Iterable<String> objectiveUnitIds,
    required Iterable<String> sourceAtomIds,
    required Iterable<String> conceptIds,
    required Iterable<String> sessionIds,
    Iterable<String> claimIds = const [],
    Iterable<String> prerequisiteMicroLessonIds = const [],
  }) : objectiveUnitIds = _idList(
         objectiveUnitIds,
         'objectiveUnitIds',
         nonEmpty: true,
       ),
       sourceAtomIds = _idList(sourceAtomIds, 'sourceAtomIds', nonEmpty: true),
       claimIds = _idList(claimIds, 'claimIds'),
       conceptIds = _idList(conceptIds, 'conceptIds', nonEmpty: true),
       sessionIds = _idList(sessionIds, 'sessionIds', nonEmpty: true),
       prerequisiteMicroLessonIds = _idList(
         prerequisiteMicroLessonIds,
         'prerequisiteMicroLessonIds',
       ) {
    _id(id, 'id');
    _id(hierarchyNodeId, 'hierarchyNodeId');
    _id(unitId, 'unitId');
    _id(conceptClusterId, 'conceptClusterId');
    _id(titleUnitId, 'titleUnitId');
    if (ordinal < 1) throw ArgumentError.value(ordinal, 'ordinal');
    if (splitRationale.trim().isEmpty) {
      throw ArgumentError.value(splitRationale, 'splitRationale');
    }
    if (prerequisiteMicroLessonIds.contains(id)) {
      throw ArgumentError('A micro-lesson cannot require itself.');
    }
  }

  final CurriculumMicroLessonId id;
  final CurriculumNodeId hierarchyNodeId;
  final CurriculumNodeId unitId;
  final CurriculumNodeId conceptClusterId;
  final int ordinal;
  final CurriculumLocalizationUnitId titleUnitId;
  final List<CurriculumLocalizationUnitId> objectiveUnitIds;
  final List<SourceAtomId> sourceAtomIds;
  final List<String> claimIds;
  final List<String> conceptIds;
  final List<CurriculumSessionId> sessionIds;
  final List<CurriculumMicroLessonId> prerequisiteMicroLessonIds;
  final LocaleDuration estimatedSeconds;
  final String splitRationale;

  Map<String, dynamic> toJson() => {
    'id': id,
    'hierarchyNodeId': hierarchyNodeId,
    'unitId': unitId,
    'conceptClusterId': conceptClusterId,
    'ordinal': ordinal,
    'titleUnitId': titleUnitId,
    'objectiveUnitIds': objectiveUnitIds,
    'sourceAtomIds': sourceAtomIds,
    'claimIds': claimIds,
    'conceptIds': conceptIds,
    'sessionIds': sessionIds,
    'prerequisiteMicroLessonIds': prerequisiteMicroLessonIds,
    'estimatedSeconds': estimatedSeconds.toJson(),
    'splitRationale': splitRationale,
  };

  factory CurriculumMicroLesson.fromJson(Map<String, dynamic> json) =>
      CurriculumMicroLesson(
        id: json['id'] as String,
        hierarchyNodeId: json['hierarchyNodeId'] as String,
        unitId: json['unitId'] as String,
        conceptClusterId: json['conceptClusterId'] as String,
        ordinal: json['ordinal'] as int,
        titleUnitId: json['titleUnitId'] as String,
        objectiveUnitIds: _strings(
          json['objectiveUnitIds'],
          'objectiveUnitIds',
        ),
        sourceAtomIds: _strings(json['sourceAtomIds'], 'sourceAtomIds'),
        claimIds: _strings(json['claimIds'], 'claimIds'),
        conceptIds: _strings(json['conceptIds'], 'conceptIds'),
        sessionIds: _strings(json['sessionIds'], 'sessionIds'),
        prerequisiteMicroLessonIds: _strings(
          json['prerequisiteMicroLessonIds'],
          'prerequisiteMicroLessonIds',
        ),
        estimatedSeconds: LocaleDuration.fromJson(
          Map<String, dynamic>.from(json['estimatedSeconds'] as Map),
        ),
        splitRationale: json['splitRationale'] as String,
      );

  @override
  List<Object?> get props => [
    id,
    hierarchyNodeId,
    unitId,
    conceptClusterId,
    ordinal,
    titleUnitId,
    objectiveUnitIds,
    sourceAtomIds,
    claimIds,
    conceptIds,
    sessionIds,
    prerequisiteMicroLessonIds,
    estimatedSeconds,
    splitRationale,
  ];
}

final class SessionDiversity extends Equatable {
  SessionDiversity({
    required this.interactionFamilyCount,
    required this.activeStepRatio,
    required this.maxConsecutivePassive,
    required this.maxConsecutiveSameTemplate,
  }) {
    if (interactionFamilyCount < 1) {
      throw ArgumentError.value(
        interactionFamilyCount,
        'interactionFamilyCount',
      );
    }
    if (activeStepRatio < 0 || activeStepRatio > 1) {
      throw ArgumentError.value(activeStepRatio, 'activeStepRatio');
    }
    if (maxConsecutivePassive < 0) {
      throw ArgumentError.value(maxConsecutivePassive, 'maxConsecutivePassive');
    }
    if (maxConsecutiveSameTemplate < 0) {
      throw ArgumentError.value(
        maxConsecutiveSameTemplate,
        'maxConsecutiveSameTemplate',
      );
    }
  }

  final int interactionFamilyCount;
  final double activeStepRatio;
  final int maxConsecutivePassive;
  final int maxConsecutiveSameTemplate;

  Map<String, dynamic> toJson() => {
    'interactionFamilyCount': interactionFamilyCount,
    'activeStepRatio': activeStepRatio,
    'maxConsecutivePassive': maxConsecutivePassive,
    'maxConsecutiveSameTemplate': maxConsecutiveSameTemplate,
  };

  factory SessionDiversity.fromJson(Map<String, dynamic> json) =>
      SessionDiversity(
        interactionFamilyCount: json['interactionFamilyCount'] as int,
        activeStepRatio: (json['activeStepRatio'] as num).toDouble(),
        maxConsecutivePassive: json['maxConsecutivePassive'] as int,
        maxConsecutiveSameTemplate: json['maxConsecutiveSameTemplate'] as int,
      );

  @override
  List<Object?> get props => [
    interactionFamilyCount,
    activeStepRatio,
    maxConsecutivePassive,
    maxConsecutiveSameTemplate,
  ];
}

final class CurriculumSession extends Equatable {
  CurriculumSession({
    required this.id,
    required this.microLessonId,
    required this.ordinal,
    required this.sessionType,
    required this.titleUnitId,
    required this.estimatedSeconds,
    required this.diversity,
    required Iterable<String> objectiveUnitIds,
    required Iterable<CognitiveLevel> cognitiveTargets,
    required Iterable<String> conceptIds,
    required Iterable<String> sourceAtomIds,
    required Iterable<String> interactionIds,
    required Iterable<SessionArcStep> arc,
    required Iterable<CompletionEvidenceType> completionEvidence,
    Iterable<String> claimIds = const [],
  }) : objectiveUnitIds = _idList(
         objectiveUnitIds,
         'objectiveUnitIds',
         nonEmpty: true,
       ),
       cognitiveTargets = List.unmodifiable(cognitiveTargets),
       conceptIds = _idList(conceptIds, 'conceptIds', nonEmpty: true),
       sourceAtomIds = _idList(sourceAtomIds, 'sourceAtomIds', nonEmpty: true),
       claimIds = _idList(claimIds, 'claimIds'),
       interactionIds = _idList(
         interactionIds,
         'interactionIds',
         nonEmpty: true,
       ),
       arc = List.unmodifiable(arc),
       completionEvidence = List.unmodifiable(completionEvidence) {
    _id(id, 'id');
    _id(microLessonId, 'microLessonId');
    _id(titleUnitId, 'titleUnitId');
    if (ordinal < 1) throw ArgumentError.value(ordinal, 'ordinal');
    if (this.cognitiveTargets.isEmpty ||
        this.cognitiveTargets.toSet().length != this.cognitiveTargets.length) {
      throw ArgumentError.value(this.cognitiveTargets, 'cognitiveTargets');
    }
    if (this.interactionIds.length > 12) {
      throw ArgumentError.value(
        this.interactionIds.length,
        'interactionIds',
        'Maximum is 12.',
      );
    }
    if (estimatedSeconds.enSeconds > 480 || estimatedSeconds.faSeconds > 480) {
      throw ArgumentError(
        'A session cannot exceed eight minutes in either locale.',
      );
    }
    if (this.arc.length < 3) throw ArgumentError.value(this.arc, 'arc');
    if (this.completionEvidence.isEmpty ||
        this.completionEvidence.toSet().length !=
            this.completionEvidence.length) {
      throw ArgumentError.value(this.completionEvidence, 'completionEvidence');
    }
  }

  final CurriculumSessionId id;
  final CurriculumMicroLessonId microLessonId;
  final int ordinal;
  final CurriculumSessionType sessionType;
  final CurriculumLocalizationUnitId titleUnitId;
  final List<CurriculumLocalizationUnitId> objectiveUnitIds;
  final List<CognitiveLevel> cognitiveTargets;
  final List<String> conceptIds;
  final List<SourceAtomId> sourceAtomIds;
  final List<String> claimIds;
  final List<CurriculumInteractionId> interactionIds;
  final LocaleDuration estimatedSeconds;
  final List<SessionArcStep> arc;
  final SessionDiversity diversity;
  final List<CompletionEvidenceType> completionEvidence;

  Map<String, dynamic> toJson() => {
    'id': id,
    'microLessonId': microLessonId,
    'ordinal': ordinal,
    'sessionType': _sessionTypeCodec.encode(sessionType),
    'titleUnitId': titleUnitId,
    'objectiveUnitIds': objectiveUnitIds,
    'cognitiveTargets': cognitiveTargets.map(_cognitiveCodec.encode).toList(),
    'conceptIds': conceptIds,
    'sourceAtomIds': sourceAtomIds,
    'claimIds': claimIds,
    'interactionIds': interactionIds,
    'estimatedSeconds': estimatedSeconds.toJson(),
    'arc': arc.map(_arcCodec.encode).toList(),
    'diversity': diversity.toJson(),
    'completionEvidence': completionEvidence
        .map(_completionCodec.encode)
        .toList(),
  };

  factory CurriculumSession.fromJson(Map<String, dynamic> json) =>
      CurriculumSession(
        id: json['id'] as String,
        microLessonId: json['microLessonId'] as String,
        ordinal: json['ordinal'] as int,
        sessionType: _sessionTypeCodec.decode(json['sessionType']),
        titleUnitId: json['titleUnitId'] as String,
        objectiveUnitIds: _strings(
          json['objectiveUnitIds'],
          'objectiveUnitIds',
        ),
        cognitiveTargets: _enums(
          json['cognitiveTargets'],
          'cognitiveTargets',
          _cognitiveCodec,
        ),
        conceptIds: _strings(json['conceptIds'], 'conceptIds'),
        sourceAtomIds: _strings(json['sourceAtomIds'], 'sourceAtomIds'),
        claimIds: _strings(json['claimIds'], 'claimIds'),
        interactionIds: _strings(json['interactionIds'], 'interactionIds'),
        estimatedSeconds: LocaleDuration.fromJson(
          Map<String, dynamic>.from(json['estimatedSeconds'] as Map),
        ),
        arc: _enums(json['arc'], 'arc', _arcCodec),
        diversity: SessionDiversity.fromJson(
          Map<String, dynamic>.from(json['diversity'] as Map),
        ),
        completionEvidence: _enums(
          json['completionEvidence'],
          'completionEvidence',
          _completionCodec,
        ),
      );

  @override
  List<Object?> get props => [
    id,
    microLessonId,
    ordinal,
    sessionType,
    titleUnitId,
    objectiveUnitIds,
    cognitiveTargets,
    conceptIds,
    sourceAtomIds,
    claimIds,
    interactionIds,
    estimatedSeconds,
    arc,
    diversity,
    completionEvidence,
  ];
}

final class InteractionOption extends Equatable {
  InteractionOption({
    required this.id,
    required this.labelUnitId,
    required this.isCorrect,
    Iterable<String> claimIds = const [],
    this.misconceptionId,
    this.whyWrongUnitId,
  }) : claimIds = _idList(claimIds, 'claimIds') {
    _id(id, 'id');
    _id(labelUnitId, 'labelUnitId');
    if (misconceptionId != null) _id(misconceptionId!, 'misconceptionId');
    if (whyWrongUnitId != null) _id(whyWrongUnitId!, 'whyWrongUnitId');
    if (!isCorrect && whyWrongUnitId == null) {
      throw ArgumentError(
        'Every distractor requires a why-wrong localization unit.',
      );
    }
  }

  final String id;
  final CurriculumLocalizationUnitId labelUnitId;
  final bool isCorrect;
  final List<String> claimIds;
  final String? misconceptionId;
  final CurriculumLocalizationUnitId? whyWrongUnitId;

  Map<String, dynamic> toJson() => {
    'id': id,
    'labelUnitId': labelUnitId,
    'isCorrect': isCorrect,
    'claimIds': claimIds,
    'misconceptionId': misconceptionId,
    'whyWrongUnitId': whyWrongUnitId,
  };

  factory InteractionOption.fromJson(Map<String, dynamic> json) =>
      InteractionOption(
        id: json['id'] as String,
        labelUnitId: json['labelUnitId'] as String,
        isCorrect: json['isCorrect'] as bool,
        claimIds: _strings(json['claimIds'], 'claimIds'),
        misconceptionId: json['misconceptionId'] as String?,
        whyWrongUnitId: json['whyWrongUnitId'] as String?,
      );

  @override
  List<Object?> get props => [
    id,
    labelUnitId,
    isCorrect,
    claimIds,
    misconceptionId,
    whyWrongUnitId,
  ];
}

final class ResponseSpec extends Equatable {
  ResponseSpec({
    required this.kind,
    required this.minimumSelections,
    required this.maximumSelections,
    required this.freeTextNormalization,
    Iterable<String> optionIds = const [],
    this.unitTokenId,
    this.tolerance,
  }) : optionIds = _idList(optionIds, 'optionIds') {
    if (minimumSelections < 0 || maximumSelections < minimumSelections) {
      throw ArgumentError('Invalid response selection bounds.');
    }
    if (maximumSelections > this.optionIds.length &&
        this.optionIds.isNotEmpty) {
      throw ArgumentError('maximumSelections exceeds option count.');
    }
    if (kind == ResponseKind.none &&
        (this.optionIds.isNotEmpty ||
            minimumSelections != 0 ||
            maximumSelections != 0)) {
      throw ArgumentError('A no-response step cannot declare choices.');
    }
    if (kind == ResponseKind.singleChoice &&
        (this.optionIds.isEmpty ||
            minimumSelections != 1 ||
            maximumSelections != 1)) {
      throw ArgumentError('Single choice requires exactly one selection.');
    }
    if (kind == ResponseKind.multipleChoice &&
        (this.optionIds.length < 2 || minimumSelections < 1)) {
      throw ArgumentError(
        'Multiple choice requires at least two options and one selection.',
      );
    }
    if (unitTokenId != null) _id(unitTokenId!, 'unitTokenId');
    if (tolerance != null && tolerance! < 0) {
      throw ArgumentError.value(tolerance, 'tolerance');
    }
  }

  final ResponseKind kind;
  final List<String> optionIds;
  final int minimumSelections;
  final int maximumSelections;
  final FreeTextNormalization freeTextNormalization;
  final String? unitTokenId;
  final double? tolerance;

  Map<String, dynamic> toJson() => {
    'kind': _responseCodec.encode(kind),
    'optionIds': optionIds,
    'minimumSelections': minimumSelections,
    'maximumSelections': maximumSelections,
    'freeTextNormalization': _normalizationCodec.encode(freeTextNormalization),
    'unitTokenId': unitTokenId,
    'tolerance': tolerance,
  };

  factory ResponseSpec.fromJson(Map<String, dynamic> json) => ResponseSpec(
    kind: _responseCodec.decode(json['kind']),
    optionIds: _strings(json['optionIds'], 'optionIds'),
    minimumSelections: json['minimumSelections'] as int,
    maximumSelections: json['maximumSelections'] as int,
    freeTextNormalization: _normalizationCodec.decode(
      json['freeTextNormalization'],
    ),
    unitTokenId: json['unitTokenId'] as String?,
    tolerance: (json['tolerance'] as num?)?.toDouble(),
  );

  @override
  List<Object?> get props => [
    kind,
    optionIds,
    minimumSelections,
    maximumSelections,
    freeTextNormalization,
    unitTokenId,
    tolerance,
  ];
}

final class EvaluationSpec extends Equatable {
  EvaluationSpec({
    required Iterable<Object> answerKey,
    required this.scoringVersion,
    required this.diagnosticOnly,
    Iterable<String> rubricUnitIds = const [],
    Iterable<MasteryDimension> masteryDimensions = const [],
    Map<String, String> misconceptionMap = const {},
  }) : answerKey = List.unmodifiable(answerKey),
       rubricUnitIds = _idList(rubricUnitIds, 'rubricUnitIds'),
       masteryDimensions = List.unmodifiable(masteryDimensions),
       misconceptionMap = Map.unmodifiable(misconceptionMap) {
    if (this.answerKey.any(
      (value) => value is! String && value is! num && value is! bool,
    )) {
      throw ArgumentError(
        'Answer keys may contain only string, number, or bool values.',
      );
    }
    if (scoringVersion.trim().isEmpty) {
      throw ArgumentError.value(scoringVersion, 'scoringVersion');
    }
    if (this.masteryDimensions.toSet().length !=
        this.masteryDimensions.length) {
      throw ArgumentError.value(this.masteryDimensions, 'masteryDimensions');
    }
    for (final entry in this.misconceptionMap.entries) {
      _id(entry.key, 'misconceptionMap key');
      _id(entry.value, 'misconceptionMap value');
    }
  }

  final List<Object> answerKey;
  final List<CurriculumLocalizationUnitId> rubricUnitIds;
  final String scoringVersion;
  final List<MasteryDimension> masteryDimensions;
  final bool diagnosticOnly;
  final Map<String, String> misconceptionMap;

  Map<String, dynamic> toJson() => {
    'answerKey': answerKey,
    'rubricUnitIds': rubricUnitIds,
    'scoringVersion': scoringVersion,
    'masteryDimensions': masteryDimensions.map(_masteryCodec.encode).toList(),
    'diagnosticOnly': diagnosticOnly,
    'misconceptionMap': misconceptionMap,
  };

  factory EvaluationSpec.fromJson(Map<String, dynamic> json) => EvaluationSpec(
    answerKey: (json['answerKey'] as List).cast<Object>(),
    rubricUnitIds: _strings(json['rubricUnitIds'], 'rubricUnitIds'),
    scoringVersion: json['scoringVersion'] as String,
    masteryDimensions: _enums(
      json['masteryDimensions'],
      'masteryDimensions',
      _masteryCodec,
    ),
    diagnosticOnly: json['diagnosticOnly'] as bool,
    misconceptionMap: Map<String, String>.from(json['misconceptionMap'] as Map),
  );

  @override
  List<Object?> get props => [
    answerKey,
    rubricUnitIds,
    scoringVersion,
    masteryDimensions,
    diagnosticOnly,
    misconceptionMap,
  ];
}

final class FeedbackSpec extends Equatable {
  FeedbackSpec({
    required this.flashUnitId,
    required this.repairUnitId,
    required this.deepUnitId,
    required this.whyCorrectUnitId,
    Map<String, String> whyWrongByOptionId = const {},
  }) : whyWrongByOptionId = Map.unmodifiable(whyWrongByOptionId) {
    _id(flashUnitId, 'flashUnitId');
    _id(repairUnitId, 'repairUnitId');
    _id(deepUnitId, 'deepUnitId');
    _id(whyCorrectUnitId, 'whyCorrectUnitId');
    for (final entry in this.whyWrongByOptionId.entries) {
      _id(entry.key, 'whyWrongByOptionId key');
      _id(entry.value, 'whyWrongByOptionId value');
    }
  }

  final CurriculumLocalizationUnitId flashUnitId;
  final CurriculumLocalizationUnitId repairUnitId;
  final CurriculumLocalizationUnitId deepUnitId;
  final CurriculumLocalizationUnitId whyCorrectUnitId;
  final Map<String, CurriculumLocalizationUnitId> whyWrongByOptionId;

  Map<String, dynamic> toJson() => {
    'flashUnitId': flashUnitId,
    'repairUnitId': repairUnitId,
    'deepUnitId': deepUnitId,
    'whyCorrectUnitId': whyCorrectUnitId,
    'whyWrongByOptionId': whyWrongByOptionId,
  };

  factory FeedbackSpec.fromJson(Map<String, dynamic> json) => FeedbackSpec(
    flashUnitId: json['flashUnitId'] as String,
    repairUnitId: json['repairUnitId'] as String,
    deepUnitId: json['deepUnitId'] as String,
    whyCorrectUnitId: json['whyCorrectUnitId'] as String,
    whyWrongByOptionId: Map<String, String>.from(
      json['whyWrongByOptionId'] as Map,
    ),
  );

  @override
  List<Object?> get props => [
    flashUnitId,
    repairUnitId,
    deepUnitId,
    whyCorrectUnitId,
    whyWrongByOptionId,
  ];
}

final class InteractionAccessibility extends Equatable {
  InteractionAccessibility({
    required this.scientificMirroring,
    this.alternativeInteractionId,
    this.keyboardOperable = true,
    this.screenReaderEquivalent = true,
    this.colorIndependent = true,
    this.timedResponseRequired = false,
  }) {
    if (!keyboardOperable || !screenReaderEquivalent || !colorIndependent) {
      throw ArgumentError(
        'Every interaction requires keyboard, screen-reader, and color-independent parity.',
      );
    }
    if (timedResponseRequired) {
      throw ArgumentError(
        'Timed responses are not allowed in the learning contract.',
      );
    }
    if (alternativeInteractionId != null) {
      _id(alternativeInteractionId!, 'alternativeInteractionId');
    }
  }

  final bool keyboardOperable;
  final bool screenReaderEquivalent;
  final bool colorIndependent;
  final bool timedResponseRequired;
  final ScientificMirroring scientificMirroring;
  final CurriculumInteractionId? alternativeInteractionId;

  Map<String, dynamic> toJson() => {
    'keyboardOperable': keyboardOperable,
    'screenReaderEquivalent': screenReaderEquivalent,
    'colorIndependent': colorIndependent,
    'timedResponseRequired': timedResponseRequired,
    'scientificMirroring': _mirroringCodec.encode(scientificMirroring),
    'alternativeInteractionId': alternativeInteractionId,
  };

  factory InteractionAccessibility.fromJson(Map<String, dynamic> json) =>
      InteractionAccessibility(
        keyboardOperable: json['keyboardOperable'] as bool,
        screenReaderEquivalent: json['screenReaderEquivalent'] as bool,
        colorIndependent: json['colorIndependent'] as bool,
        timedResponseRequired: json['timedResponseRequired'] as bool,
        scientificMirroring: _mirroringCodec.decode(
          json['scientificMirroring'],
        ),
        alternativeInteractionId: json['alternativeInteractionId'] as String?,
      );

  @override
  List<Object?> get props => [
    keyboardOperable,
    screenReaderEquivalent,
    colorIndependent,
    timedResponseRequired,
    scientificMirroring,
    alternativeInteractionId,
  ];
}

final class InteractionStimulus extends Equatable {
  InteractionStimulus({
    Iterable<String> localizationUnitIds = const [],
    Iterable<String> mediaAssetIds = const [],
  }) : localizationUnitIds = _idList(
         localizationUnitIds,
         'localizationUnitIds',
       ),
       mediaAssetIds = _idList(mediaAssetIds, 'mediaAssetIds');

  final List<CurriculumLocalizationUnitId> localizationUnitIds;
  final List<String> mediaAssetIds;

  Map<String, dynamic> toJson() => {
    'localizationUnitIds': localizationUnitIds,
    'mediaAssetIds': mediaAssetIds,
  };

  factory InteractionStimulus.fromJson(Map<String, dynamic> json) =>
      InteractionStimulus(
        localizationUnitIds: _strings(
          json['localizationUnitIds'],
          'localizationUnitIds',
        ),
        mediaAssetIds: _strings(json['mediaAssetIds'], 'mediaAssetIds'),
      );

  @override
  List<Object?> get props => [localizationUnitIds, mediaAssetIds];
}

final class CurriculumInteraction extends Equatable {
  CurriculumInteraction({
    required this.id,
    required this.sessionId,
    required this.ordinal,
    required this.stepRole,
    required this.family,
    required this.kind,
    required this.cognitiveLevel,
    required this.promptUnitId,
    required this.stimulus,
    required this.responseSpec,
    required this.evaluationSpec,
    required this.feedbackSpec,
    required this.estimatedSeconds,
    required this.accessibility,
    required Iterable<String> sourceAtomIds,
    required Iterable<String> conceptIds,
    Iterable<InteractionOption> options = const [],
    Iterable<String> claimIds = const [],
    this.instructionUnitId,
  }) : options = List.unmodifiable(options),
       sourceAtomIds = _idList(sourceAtomIds, 'sourceAtomIds', nonEmpty: true),
       claimIds = _idList(claimIds, 'claimIds'),
       conceptIds = _idList(conceptIds, 'conceptIds', nonEmpty: true) {
    _id(id, 'id');
    _id(sessionId, 'sessionId');
    _id(promptUnitId, 'promptUnitId');
    if (instructionUnitId != null) _id(instructionUnitId!, 'instructionUnitId');
    if (ordinal < 1) throw ArgumentError.value(ordinal, 'ordinal');
    if (this.options.map((option) => option.id).toSet().length !=
        this.options.length) {
      throw ArgumentError('Interaction option IDs must be unique.');
    }
    if (responseSpec.optionIds
        .toSet()
        .difference(this.options.map((option) => option.id).toSet())
        .isNotEmpty) {
      throw ArgumentError(
        'responseSpec references options not owned by this interaction.',
      );
    }
    if (kind == InteractionKind.singleBestAnswer &&
        this.options.where((option) => option.isCorrect).length != 1) {
      throw ArgumentError(
        'A single-best-answer interaction requires exactly one correct option.',
      );
    }
    final incorrectIds = this.options
        .where((option) => !option.isCorrect)
        .map((option) => option.id)
        .toSet();
    if (!feedbackSpec.whyWrongByOptionId.keys.toSet().containsAll(
      incorrectIds,
    )) {
      throw ArgumentError('Feedback must explain every distractor.');
    }
  }

  final CurriculumInteractionId id;
  final CurriculumSessionId sessionId;
  final int ordinal;
  final InteractionStepRole stepRole;
  final InteractionFamily family;
  final InteractionKind kind;
  final CognitiveLevel cognitiveLevel;
  final CurriculumLocalizationUnitId promptUnitId;
  final CurriculumLocalizationUnitId? instructionUnitId;
  final InteractionStimulus stimulus;
  final List<InteractionOption> options;
  final ResponseSpec responseSpec;
  final EvaluationSpec evaluationSpec;
  final FeedbackSpec feedbackSpec;
  final List<SourceAtomId> sourceAtomIds;
  final List<String> claimIds;
  final List<String> conceptIds;
  final LocaleDuration estimatedSeconds;
  final InteractionAccessibility accessibility;

  bool get isPassive => responseSpec.kind == ResponseKind.none;

  Map<String, dynamic> toJson() => {
    'id': id,
    'sessionId': sessionId,
    'ordinal': ordinal,
    'stepRole': _stepRoleCodec.encode(stepRole),
    'family': _familyCodec.encode(family),
    'kind': _kindCodec.encode(kind),
    'cognitiveLevel': _cognitiveCodec.encode(cognitiveLevel),
    'promptUnitId': promptUnitId,
    'instructionUnitId': instructionUnitId,
    'stimulus': stimulus.toJson(),
    'options': options.map((option) => option.toJson()).toList(),
    'responseSpec': responseSpec.toJson(),
    'evaluationSpec': evaluationSpec.toJson(),
    'feedbackSpec': feedbackSpec.toJson(),
    'sourceAtomIds': sourceAtomIds,
    'claimIds': claimIds,
    'conceptIds': conceptIds,
    'estimatedSeconds': estimatedSeconds.toJson(),
    'accessibility': accessibility.toJson(),
  };

  factory CurriculumInteraction.fromJson(Map<String, dynamic> json) =>
      CurriculumInteraction(
        id: json['id'] as String,
        sessionId: json['sessionId'] as String,
        ordinal: json['ordinal'] as int,
        stepRole: _stepRoleCodec.decode(json['stepRole']),
        family: _familyCodec.decode(json['family']),
        kind: _kindCodec.decode(json['kind']),
        cognitiveLevel: _cognitiveCodec.decode(json['cognitiveLevel']),
        promptUnitId: json['promptUnitId'] as String,
        instructionUnitId: json['instructionUnitId'] as String?,
        stimulus: InteractionStimulus.fromJson(
          Map<String, dynamic>.from(json['stimulus'] as Map),
        ),
        options: (json['options'] as List)
            .map(
              (value) => InteractionOption.fromJson(
                Map<String, dynamic>.from(value as Map),
              ),
            )
            .toList(growable: false),
        responseSpec: ResponseSpec.fromJson(
          Map<String, dynamic>.from(json['responseSpec'] as Map),
        ),
        evaluationSpec: EvaluationSpec.fromJson(
          Map<String, dynamic>.from(json['evaluationSpec'] as Map),
        ),
        feedbackSpec: FeedbackSpec.fromJson(
          Map<String, dynamic>.from(json['feedbackSpec'] as Map),
        ),
        sourceAtomIds: _strings(json['sourceAtomIds'], 'sourceAtomIds'),
        claimIds: _strings(json['claimIds'], 'claimIds'),
        conceptIds: _strings(json['conceptIds'], 'conceptIds'),
        estimatedSeconds: LocaleDuration.fromJson(
          Map<String, dynamic>.from(json['estimatedSeconds'] as Map),
        ),
        accessibility: InteractionAccessibility.fromJson(
          Map<String, dynamic>.from(json['accessibility'] as Map),
        ),
      );

  @override
  List<Object?> get props => [
    id,
    sessionId,
    ordinal,
    stepRole,
    family,
    kind,
    cognitiveLevel,
    promptUnitId,
    instructionUnitId,
    stimulus,
    options,
    responseSpec,
    evaluationSpec,
    feedbackSpec,
    sourceAtomIds,
    claimIds,
    conceptIds,
    estimatedSeconds,
    accessibility,
  ];
}

/// Verifies that a session's declared metrics match the actual playback queue.
final class CurriculumSessionBundle {
  CurriculumSessionBundle({
    required this.session,
    required Iterable<CurriculumInteraction> interactions,
  }) : interactions = List.unmodifiable(interactions) {
    _validate();
  }

  final CurriculumSession session;
  final List<CurriculumInteraction> interactions;

  void _validate() {
    if (interactions.length != session.interactionIds.length) {
      throw StateError(
        'Session interaction count does not match its declared queue.',
      );
    }
    for (var index = 0; index < interactions.length; index++) {
      final interaction = interactions[index];
      if (interaction.id != session.interactionIds[index] ||
          interaction.ordinal != index + 1) {
        throw StateError(
          'Interaction order does not match the session manifest.',
        );
      }
      if (interaction.sessionId != session.id) {
        throw StateError('${interaction.id} belongs to another session.');
      }
    }

    final familyCount = interactions
        .map((interaction) => interaction.family)
        .toSet()
        .length;
    final activeCount = interactions
        .where((interaction) => !interaction.isPassive)
        .length;
    final activeRatio = interactions.isEmpty
        ? 0.0
        : activeCount / interactions.length;
    if (familyCount != session.diversity.interactionFamilyCount ||
        (activeRatio - session.diversity.activeStepRatio).abs() > 0.000001) {
      throw StateError(
        'Declared session diversity does not match the playback queue.',
      );
    }

    var passiveRun = 0;
    var sameTemplateRun = 0;
    InteractionKind? previousKind;
    for (final interaction in interactions) {
      passiveRun = interaction.isPassive ? passiveRun + 1 : 0;
      sameTemplateRun = interaction.kind == previousKind
          ? sameTemplateRun + 1
          : 1;
      previousKind = interaction.kind;
      if (passiveRun > session.diversity.maxConsecutivePassive) {
        throw StateError('Session exceeds its passive-step limit.');
      }
      if (sameTemplateRun > session.diversity.maxConsecutiveSameTemplate) {
        throw StateError('Session exceeds its same-template limit.');
      }
    }
  }
}

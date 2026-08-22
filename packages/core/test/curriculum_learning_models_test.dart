import 'package:synapse_core/synapse_core.dart';
import 'package:test/test.dart';

void main() {
  group('micro-lesson and session contracts', () {
    test('round-trip fine-grained playback metadata', () {
      final microLesson = _microLesson();
      final session = _session();

      expect(CurriculumMicroLesson.fromJson(microLesson.toJson()), microLesson);
      expect(CurriculumSession.fromJson(session.toJson()), session);
      expect(session.estimatedSeconds.forLocale(ContentLocale.fa), 360);
    });

    test('enforces short sessions and bounded queues', () {
      expect(
        () => _session(
          interactionIds: List.generate(
            13,
            (index) => 'interaction.${index + 1}',
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () =>
            _session(duration: LocaleDuration(enSeconds: 481, faSeconds: 300)),
        throwsArgumentError,
      );
    });
  });

  group('interaction playback contracts', () {
    test(
      'round-trip options, response, scoring, feedback, and accessibility',
      () {
        final interaction = _choiceInteraction(ordinal: 2);
        final restored = CurriculumInteraction.fromJson(interaction.toJson());

        expect(restored, interaction);
        expect(
          restored.options
              .singleWhere((option) => !option.isCorrect)
              .whyWrongUnitId,
          isNotNull,
        );
        expect(restored.accessibility.timedResponseRequired, isFalse);
        expect(restored.isPassive, isFalse);
      },
    );

    test('requires a why-wrong explanation for every distractor', () {
      expect(
        () => InteractionOption(
          id: 'option.bad',
          labelUnitId: 'l10n.option.bad',
          isCorrect: false,
        ),
        throwsArgumentError,
      );
    });

    test('rejects inaccessible or timed interaction contracts', () {
      expect(
        () => InteractionAccessibility(
          scientificMirroring: ScientificMirroring.notDirectional,
          screenReaderEquivalent: false,
        ),
        throwsArgumentError,
      );
      expect(
        () => InteractionAccessibility(
          scientificMirroring: ScientificMirroring.notDirectional,
          timedResponseRequired: true,
        ),
        throwsArgumentError,
      );
    });

    test('rejects invalid selection bounds and unknown options', () {
      expect(
        () => ResponseSpec(
          kind: ResponseKind.singleChoice,
          optionIds: const ['option.a', 'option.b'],
          minimumSelections: 0,
          maximumSelections: 1,
          freeTextNormalization: FreeTextNormalization.none,
        ),
        throwsArgumentError,
      );
      expect(
        () => _choiceInteraction(
          responseSpec: ResponseSpec(
            kind: ResponseKind.singleChoice,
            optionIds: const ['option.missing'],
            minimumSelections: 1,
            maximumSelections: 1,
            freeTextNormalization: FreeTextNormalization.none,
          ),
        ),
        throwsArgumentError,
      );
    });
  });

  group('session bundle integrity', () {
    test('proves queue order, ownership, and declared diversity', () {
      final interactions = _interactions();
      final session = _session(
        interactionIds: interactions
            .map((interaction) => interaction.id)
            .toList(),
      );

      final bundle = CurriculumSessionBundle(
        session: session,
        interactions: interactions,
      );

      expect(bundle.interactions.length, 5);
    });

    test('fails stale diversity receipts and reordered queues', () {
      final interactions = _interactions();
      final staleSession = _session(
        interactionIds: interactions
            .map((interaction) => interaction.id)
            .toList(),
        diversity: SessionDiversity(
          interactionFamilyCount: 4,
          activeStepRatio: 0.8,
          maxConsecutivePassive: 1,
          maxConsecutiveSameTemplate: 1,
        ),
      );
      expect(
        () => CurriculumSessionBundle(
          session: staleSession,
          interactions: interactions,
        ),
        throwsStateError,
      );

      final validSession = _session(
        interactionIds: interactions
            .map((interaction) => interaction.id)
            .toList(),
      );
      expect(
        () => CurriculumSessionBundle(
          session: validSession,
          interactions: interactions.reversed,
        ),
        throwsStateError,
      );
    });
  });
}

CurriculumMicroLesson _microLesson() => CurriculumMicroLesson(
  id: 'micro-lesson.cardiology.001',
  hierarchyNodeId: 'node.micro-lesson.cardiology.001',
  unitId: 'node.unit.cardiology.001',
  conceptClusterId: 'node.cluster.cardiology.001',
  ordinal: 1,
  titleUnitId: 'l10n.micro-lesson.cardiology.001.title',
  objectiveUnitIds: const ['l10n.objective.cardiology.001'],
  sourceAtomIds: const ['source.atom.cardiology.001'],
  claimIds: const ['claim.cardiology.001'],
  conceptIds: const ['concept.cardiology.001'],
  sessionIds: const ['session.cardiology.001'],
  estimatedSeconds: LocaleDuration(enSeconds: 300, faSeconds: 360),
  splitRationale:
      'One mechanism and one discrimination task fit a short round.',
);

CurriculumSession _session({
  List<String>? interactionIds,
  LocaleDuration? duration,
  SessionDiversity? diversity,
}) => CurriculumSession(
  id: 'session.cardiology.001',
  microLessonId: 'micro-lesson.cardiology.001',
  ordinal: 1,
  sessionType: CurriculumSessionType.learn,
  titleUnitId: 'l10n.session.cardiology.001.title',
  objectiveUnitIds: const ['l10n.objective.cardiology.001'],
  cognitiveTargets: const [CognitiveLevel.recall, CognitiveLevel.explain],
  conceptIds: const ['concept.cardiology.001'],
  sourceAtomIds: const ['source.atom.cardiology.001'],
  claimIds: const ['claim.cardiology.001'],
  interactionIds: interactionIds ?? const ['interaction.1'],
  estimatedSeconds: duration ?? LocaleDuration(enSeconds: 300, faSeconds: 360),
  arc: const [
    SessionArcStep.orient,
    SessionArcStep.retrieveOrPredict,
    SessionArcStep.debrief,
  ],
  diversity:
      diversity ??
      SessionDiversity(
        interactionFamilyCount: 5,
        activeStepRatio: 0.8,
        maxConsecutivePassive: 1,
        maxConsecutiveSameTemplate: 1,
      ),
  completionEvidence: const [
    CompletionEvidenceType.response,
    CompletionEvidenceType.explanation,
  ],
);

List<CurriculumInteraction> _interactions() => [
  _passiveInteraction(ordinal: 1),
  _choiceInteraction(ordinal: 2),
  _freeTextInteraction(
    ordinal: 3,
    kind: InteractionKind.cloze,
    family: InteractionFamily.retrieval,
  ),
  _freeTextInteraction(
    ordinal: 4,
    kind: InteractionKind.shortAnswer,
    family: InteractionFamily.explanation,
  ),
  _freeTextInteraction(
    ordinal: 5,
    kind: InteractionKind.confidenceRating,
    family: InteractionFamily.confidence,
  ),
];

CurriculumInteraction _passiveInteraction({required int ordinal}) =>
    CurriculumInteraction(
      id: 'interaction.$ordinal',
      sessionId: 'session.cardiology.001',
      ordinal: ordinal,
      stepRole: InteractionStepRole.orientation,
      family: InteractionFamily.orientation,
      kind: InteractionKind.orientCard,
      cognitiveLevel: CognitiveLevel.recall,
      promptUnitId: 'l10n.interaction.$ordinal.prompt',
      stimulus: InteractionStimulus(
        localizationUnitIds: ['l10n.interaction.$ordinal.stimulus'],
      ),
      responseSpec: ResponseSpec(
        kind: ResponseKind.none,
        minimumSelections: 0,
        maximumSelections: 0,
        freeTextNormalization: FreeTextNormalization.none,
      ),
      evaluationSpec: EvaluationSpec(
        answerKey: const [],
        scoringVersion: 'synapse-scoring-v1',
        diagnosticOnly: true,
      ),
      feedbackSpec: _feedback(),
      sourceAtomIds: const ['source.atom.cardiology.001'],
      conceptIds: const ['concept.cardiology.001'],
      estimatedSeconds: LocaleDuration(enSeconds: 30, faSeconds: 35),
      accessibility: InteractionAccessibility(
        scientificMirroring: ScientificMirroring.notDirectional,
      ),
    );

CurriculumInteraction _choiceInteraction({
  int ordinal = 2,
  ResponseSpec? responseSpec,
}) {
  final options = [
    InteractionOption(
      id: 'option.$ordinal.correct',
      labelUnitId: 'l10n.option.$ordinal.correct',
      isCorrect: true,
      claimIds: const ['claim.cardiology.001'],
    ),
    InteractionOption(
      id: 'option.$ordinal.distractor',
      labelUnitId: 'l10n.option.$ordinal.distractor',
      isCorrect: false,
      misconceptionId: 'misconception.cardiology.001',
      whyWrongUnitId: 'l10n.option.$ordinal.distractor.why-wrong',
    ),
  ];
  return CurriculumInteraction(
    id: 'interaction.$ordinal',
    sessionId: 'session.cardiology.001',
    ordinal: ordinal,
    stepRole: InteractionStepRole.assessment,
    family: InteractionFamily.discrimination,
    kind: InteractionKind.singleBestAnswer,
    cognitiveLevel: CognitiveLevel.diagnose,
    promptUnitId: 'l10n.interaction.$ordinal.prompt',
    stimulus: InteractionStimulus(),
    options: options,
    responseSpec:
        responseSpec ??
        ResponseSpec(
          kind: ResponseKind.singleChoice,
          optionIds: options.map((option) => option.id),
          minimumSelections: 1,
          maximumSelections: 1,
          freeTextNormalization: FreeTextNormalization.none,
        ),
    evaluationSpec: EvaluationSpec(
      answerKey: [options.first.id],
      scoringVersion: 'synapse-scoring-v1',
      masteryDimensions: const [MasteryDimension.discrimination],
      diagnosticOnly: false,
      misconceptionMap: {options.last.id: 'misconception.cardiology.001'},
    ),
    feedbackSpec: _feedback(distractorId: options.last.id),
    sourceAtomIds: const ['source.atom.cardiology.001'],
    claimIds: const ['claim.cardiology.001'],
    conceptIds: const ['concept.cardiology.001'],
    estimatedSeconds: LocaleDuration(enSeconds: 45, faSeconds: 50),
    accessibility: InteractionAccessibility(
      scientificMirroring: ScientificMirroring.notDirectional,
    ),
  );
}

CurriculumInteraction _freeTextInteraction({
  required int ordinal,
  required InteractionKind kind,
  required InteractionFamily family,
}) => CurriculumInteraction(
  id: 'interaction.$ordinal',
  sessionId: 'session.cardiology.001',
  ordinal: ordinal,
  stepRole: InteractionStepRole.retrieval,
  family: family,
  kind: kind,
  cognitiveLevel: CognitiveLevel.explain,
  promptUnitId: 'l10n.interaction.$ordinal.prompt',
  stimulus: InteractionStimulus(),
  responseSpec: ResponseSpec(
    kind: ResponseKind.freeText,
    minimumSelections: 0,
    maximumSelections: 0,
    freeTextNormalization: FreeTextNormalization.medicalTermAliases,
  ),
  evaluationSpec: EvaluationSpec(
    answerKey: const [],
    rubricUnitIds: ['l10n.interaction.$ordinal.rubric'],
    scoringVersion: 'synapse-scoring-v1',
    masteryDimensions: const [MasteryDimension.explain],
    diagnosticOnly: false,
  ),
  feedbackSpec: _feedback(),
  sourceAtomIds: const ['source.atom.cardiology.001'],
  claimIds: const ['claim.cardiology.001'],
  conceptIds: const ['concept.cardiology.001'],
  estimatedSeconds: LocaleDuration(enSeconds: 45, faSeconds: 55),
  accessibility: InteractionAccessibility(
    scientificMirroring: ScientificMirroring.notDirectional,
  ),
);

FeedbackSpec _feedback({String? distractorId}) => FeedbackSpec(
  flashUnitId: 'l10n.feedback.flash',
  repairUnitId: 'l10n.feedback.repair',
  deepUnitId: 'l10n.feedback.deep',
  whyCorrectUnitId: 'l10n.feedback.why-correct',
  whyWrongByOptionId: {?distractorId: 'l10n.feedback.$distractorId.why-wrong'},
);

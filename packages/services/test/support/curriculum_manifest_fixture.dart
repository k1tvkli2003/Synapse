import 'package:synapse_core/synapse_core.dart';

CurriculumManifest buildScaffoldManifest({
  String releaseId = 'release.internal.001',
  String version = '2026.07.17+1',
  String titleSuffix = 'A',
}) {
  final source = _source();
  final nodes = _nodes();
  return CurriculumManifest(
    source: source,
    release: _release(
      source,
      releaseId: releaseId,
      version: version,
      channel: CurriculumReleaseChannel.internal,
      state: ContentLifecycleState.validated,
    ),
    nodes: nodes,
    localizationUnits: [
      for (final node in nodes)
        _localization(
          node.titleUnitId,
          ContentSemanticRole.title,
          '$titleSuffix ${node.kind.name}',
        ),
    ],
  );
}

CurriculumManifest buildPublishedManifest({
  required String releaseId,
  required String version,
  String? parentReleaseId,
  String titleSuffix = 'A',
  CurriculumReleaseChannel channel = CurriculumReleaseChannel.stable,
}) {
  final source = _source();
  final nodes = _nodes();
  final microNode = nodes.last;
  final unitNode = nodes[2];
  final clusterNode = nodes[3];
  const microLessonId = 'micro-lesson.cardiology.001';
  const sessionId = 'session.cardiology.001';
  const interactionId = 'interaction.cardiology.001';
  const objectiveId = 'l10n.objective.cardiology.001';
  const sessionTitleId = 'l10n.session.cardiology.001.title';
  const promptId = 'l10n.interaction.cardiology.001.prompt';
  const correctOptionId = 'option.cardiology.correct';
  const wrongOptionId = 'option.cardiology.wrong';
  const correctLabelId = 'l10n.option.cardiology.correct';
  const wrongLabelId = 'l10n.option.cardiology.wrong';
  const flashId = 'l10n.feedback.cardiology.flash';
  const repairId = 'l10n.feedback.cardiology.repair';
  const deepId = 'l10n.feedback.cardiology.deep';
  const whyCorrectId = 'l10n.feedback.cardiology.why-correct';
  const whyWrongId = 'l10n.feedback.cardiology.why-wrong';
  const studyDocumentId = 'study.document.cardiology.001';
  const studyTitleId = 'l10n.study.cardiology.001.title';
  const keyIdeaBlockId = 'study.block.cardiology.001.key-idea';
  const keyIdeaHeadingId = 'l10n.study.cardiology.001.key-idea.heading';
  const keyIdeaBodyId = 'l10n.study.cardiology.001.key-idea.body';
  const mechanismBlockId = 'study.block.cardiology.001.mechanism';
  const mechanismHeadingId = 'l10n.study.cardiology.001.mechanism.heading';
  const mechanismStepOneId = 'l10n.study.cardiology.001.mechanism.step-1';
  const mechanismStepTwoId = 'l10n.study.cardiology.001.mechanism.step-2';
  const recapBlockId = 'study.block.cardiology.001.recap';
  const recapHeadingId = 'l10n.study.cardiology.001.recap.heading';
  const recapBodyId = 'l10n.study.cardiology.001.recap.body';

  final interaction = CurriculumInteraction(
    id: interactionId,
    sessionId: sessionId,
    ordinal: 1,
    stepRole: InteractionStepRole.assessment,
    family: InteractionFamily.discrimination,
    kind: InteractionKind.singleBestAnswer,
    cognitiveLevel: CognitiveLevel.diagnose,
    promptUnitId: promptId,
    stimulus: InteractionStimulus(),
    options: [
      InteractionOption(
        id: correctOptionId,
        labelUnitId: correctLabelId,
        isCorrect: true,
      ),
      InteractionOption(
        id: wrongOptionId,
        labelUnitId: wrongLabelId,
        isCorrect: false,
        misconceptionId: 'misconception.cardiology.001',
        whyWrongUnitId: whyWrongId,
      ),
    ],
    responseSpec: ResponseSpec(
      kind: ResponseKind.singleChoice,
      optionIds: const [correctOptionId, wrongOptionId],
      minimumSelections: 1,
      maximumSelections: 1,
      freeTextNormalization: FreeTextNormalization.none,
    ),
    evaluationSpec: EvaluationSpec(
      answerKey: const [correctOptionId],
      scoringVersion: 'synapse-scoring-v1',
      masteryDimensions: const [MasteryDimension.discrimination],
      diagnosticOnly: false,
      misconceptionMap: const {wrongOptionId: 'misconception.cardiology.001'},
    ),
    feedbackSpec: FeedbackSpec(
      flashUnitId: flashId,
      repairUnitId: repairId,
      deepUnitId: deepId,
      whyCorrectUnitId: whyCorrectId,
      whyWrongByOptionId: const {wrongOptionId: whyWrongId},
    ),
    sourceAtomIds: const ['source.atom.cardiology.001'],
    claimIds: const ['claim.cardiology.001'],
    conceptIds: const ['concept.cardiology.001'],
    estimatedSeconds: LocaleDuration(enSeconds: 45, faSeconds: 55),
    accessibility: InteractionAccessibility(
      scientificMirroring: ScientificMirroring.notDirectional,
    ),
  );
  final session = CurriculumSession(
    id: sessionId,
    microLessonId: microLessonId,
    ordinal: 1,
    sessionType: CurriculumSessionType.learn,
    titleUnitId: sessionTitleId,
    objectiveUnitIds: const [objectiveId],
    cognitiveTargets: const [CognitiveLevel.diagnose],
    conceptIds: const ['concept.cardiology.001'],
    sourceAtomIds: const ['source.atom.cardiology.001'],
    claimIds: const ['claim.cardiology.001'],
    interactionIds: const [interactionId],
    estimatedSeconds: LocaleDuration(enSeconds: 180, faSeconds: 210),
    arc: const [
      SessionArcStep.orient,
      SessionArcStep.retrieveOrPredict,
      SessionArcStep.debrief,
    ],
    diversity: SessionDiversity(
      interactionFamilyCount: 1,
      activeStepRatio: 1,
      maxConsecutivePassive: 0,
      maxConsecutiveSameTemplate: 1,
    ),
    completionEvidence: const [CompletionEvidenceType.response],
  );
  final microLesson = CurriculumMicroLesson(
    id: microLessonId,
    hierarchyNodeId: microNode.id,
    unitId: unitNode.id,
    conceptClusterId: clusterNode.id,
    ordinal: 1,
    titleUnitId: microNode.titleUnitId,
    objectiveUnitIds: const [objectiveId],
    sourceAtomIds: const ['source.atom.cardiology.001'],
    claimIds: const ['claim.cardiology.001'],
    conceptIds: const ['concept.cardiology.001'],
    sessionIds: const [sessionId],
    estimatedSeconds: LocaleDuration(enSeconds: 180, faSeconds: 210),
    splitRationale: 'One bounded mechanism and one discrimination task.',
  );
  final studyDocument = CurriculumStudyDocument(
    id: studyDocumentId,
    microLessonNodeId: microNode.id,
    ordinal: 1,
    kind: CurriculumStudyDocumentKind.primaryLesson,
    titleUnitId: studyTitleId,
    estimatedSeconds: LocaleDuration(enSeconds: 300, faSeconds: 340),
    blockIds: const [keyIdeaBlockId, mechanismBlockId, recapBlockId],
    sourceAtomIds: const ['source.atom.cardiology.001'],
    claimIds: const ['claim.cardiology.001'],
    conceptIds: const ['concept.cardiology.001'],
  );
  final studyBlocks = <CurriculumStudyBlock>[
    CurriculumStudyBlock(
      id: keyIdeaBlockId,
      documentId: studyDocumentId,
      ordinal: 1,
      kind: CurriculumStudyBlockKind.keyIdea,
      headingUnitId: keyIdeaHeadingId,
      contentUnitIds: const [keyIdeaBodyId],
      sourceAtomIds: const ['source.atom.cardiology.001'],
      claimIds: const ['claim.cardiology.001'],
      conceptIds: const ['concept.cardiology.001'],
      revealPolicy: CurriculumStudyRevealPolicy.always,
    ),
    CurriculumStudyBlock(
      id: mechanismBlockId,
      documentId: studyDocumentId,
      ordinal: 2,
      kind: CurriculumStudyBlockKind.mechanismChain,
      headingUnitId: mechanismHeadingId,
      contentUnitIds: const [mechanismStepOneId, mechanismStepTwoId],
      sourceAtomIds: const ['source.atom.cardiology.001'],
      claimIds: const ['claim.cardiology.001'],
      conceptIds: const ['concept.cardiology.001'],
      revealPolicy: CurriculumStudyRevealPolicy.always,
    ),
    CurriculumStudyBlock(
      id: recapBlockId,
      documentId: studyDocumentId,
      ordinal: 3,
      kind: CurriculumStudyBlockKind.recap,
      headingUnitId: recapHeadingId,
      contentUnitIds: const [recapBodyId],
      sourceAtomIds: const ['source.atom.cardiology.001'],
      claimIds: const ['claim.cardiology.001'],
      conceptIds: const ['concept.cardiology.001'],
      revealPolicy: CurriculumStudyRevealPolicy.afterSessionCompletion,
      revealedAfterSessionId: sessionId,
    ),
  ];

  final localizations = <CurriculumLocalizationUnit>[
    for (final node in nodes)
      _localization(
        node.titleUnitId,
        ContentSemanticRole.title,
        '$titleSuffix ${node.kind.name}',
      ),
    _localization(
      objectiveId,
      ContentSemanticRole.objective,
      '$titleSuffix objective',
    ),
    _localization(
      sessionTitleId,
      ContentSemanticRole.title,
      '$titleSuffix session',
    ),
    _localization(promptId, ContentSemanticRole.prompt, '$titleSuffix prompt'),
    _localization(
      correctLabelId,
      ContentSemanticRole.option,
      '$titleSuffix correct',
    ),
    _localization(
      wrongLabelId,
      ContentSemanticRole.option,
      '$titleSuffix wrong',
    ),
    _localization(
      flashId,
      ContentSemanticRole.feedbackFlash,
      '$titleSuffix flash',
    ),
    _localization(
      repairId,
      ContentSemanticRole.feedbackRepair,
      '$titleSuffix repair',
    ),
    _localization(
      deepId,
      ContentSemanticRole.feedbackDeep,
      '$titleSuffix deep',
    ),
    _localization(
      whyCorrectId,
      ContentSemanticRole.whyCorrect,
      '$titleSuffix why correct',
    ),
    _localization(
      whyWrongId,
      ContentSemanticRole.whyWrong,
      '$titleSuffix why wrong',
    ),
    _localization(
      studyTitleId,
      ContentSemanticRole.title,
      '$titleSuffix deep study',
    ),
    _localization(
      keyIdeaHeadingId,
      ContentSemanticRole.title,
      '$titleSuffix key idea',
    ),
    _localization(
      keyIdeaBodyId,
      ContentSemanticRole.explanation,
      '$titleSuffix bounded study idea',
    ),
    _localization(
      mechanismHeadingId,
      ContentSemanticRole.title,
      '$titleSuffix mechanism',
    ),
    _localization(
      mechanismStepOneId,
      ContentSemanticRole.explanation,
      '$titleSuffix mechanism step one',
    ),
    _localization(
      mechanismStepTwoId,
      ContentSemanticRole.explanation,
      '$titleSuffix mechanism step two',
    ),
    _localization(
      recapHeadingId,
      ContentSemanticRole.title,
      '$titleSuffix recap',
    ),
    _localization(
      recapBodyId,
      ContentSemanticRole.recap,
      '$titleSuffix gated recap',
    ),
  ];

  return CurriculumManifest(
    source: source,
    release: _release(
      source,
      releaseId: releaseId,
      version: version,
      parentReleaseId: parentReleaseId,
      channel: channel,
      state: ContentLifecycleState.published,
    ),
    nodes: nodes,
    localizationUnits: localizations,
    microLessons: [microLesson],
    sessions: [session],
    interactions: [interaction],
    studyDocuments: [studyDocument],
    studyBlocks: studyBlocks,
  );
}

/// A minimal, independently valid fragment used to exercise the immutable
/// chapter-shard registry. Each fragment repeats only the shared course root
/// needed for local validation, then contributes one unique Chapter.
CurriculumManifest buildScaffoldChapterShardManifest({
  required String releaseId,
  required String version,
  required int chapterOrdinal,
  String titleSuffix = 'Chapter',
}) {
  final source = _source();
  final ordinal = chapterOrdinal.toString().padLeft(3, '0');
  final course = CurriculumNode.fromSourceKey(
    sourceKey: 'harrison-sim/course/06',
    kind: CurriculumNodeKind.course,
    ordinal: 6,
    identityState: CurriculumIdentityState.approved,
    titleUnitId: 'l10n.course.06.title',
    sourceContainerKeys: const ['harrison-sim/course/06'],
  );
  final chapter = CurriculumNode.fromSourceKey(
    sourceKey: 'harrison-sim/course/06/chapter/$ordinal',
    parentId: course.id,
    kind: CurriculumNodeKind.chapter,
    ordinal: chapterOrdinal,
    identityState: CurriculumIdentityState.approved,
    titleUnitId: 'l10n.chapter.$ordinal.title',
    sourceContainerKeys: ['harrison-sim/course/06/chapter/$ordinal'],
  );
  return CurriculumManifest(
    source: source,
    release: _release(
      source,
      releaseId: releaseId,
      version: version,
      channel: CurriculumReleaseChannel.internal,
      state: ContentLifecycleState.validated,
    ),
    nodes: [course, chapter],
    localizationUnits: [
      _localization(course.titleUnitId, ContentSemanticRole.title, 'Course 06'),
      _localization(
        chapter.titleUnitId,
        ContentSemanticRole.title,
        '$titleSuffix $ordinal',
      ),
    ],
  );
}

CurriculumSource _source() => CurriculumSource(
  id: 'source.harrison-sim',
  sourceKey: 'harrison-sim',
  classification: 'user-provided-simulated-medical-reference',
  sourceTreeSha256: 'a' * 64,
  scanManifestId: 'scan.harrison-sim.full.v1',
  priorityCourseSourceKey: 'harrison-sim/course/06',
);

CurriculumRelease _release(
  CurriculumSource source, {
  required String releaseId,
  required String version,
  required CurriculumReleaseChannel channel,
  required ContentLifecycleState state,
  String? parentReleaseId,
}) => CurriculumRelease(
  id: releaseId,
  sourceId: source.id,
  version: version,
  parentReleaseId: parentReleaseId,
  channel: channel,
  contractVersion: 1,
  authoringProtocolVersion: 'synapse-microlearning-v1',
  sourceTreeSha256: source.sourceTreeSha256,
  contentState: state,
  createdAt: DateTime.utc(2026, 7, 17, 12),
);

List<CurriculumNode> _nodes() {
  final course = CurriculumNode.fromSourceKey(
    sourceKey: 'harrison-sim/course/06',
    kind: CurriculumNodeKind.course,
    ordinal: 6,
    identityState: CurriculumIdentityState.approved,
    titleUnitId: 'l10n.course.06.title',
    sourceContainerKeys: const ['harrison-sim/course/06'],
  );
  final chapter = CurriculumNode.fromSourceKey(
    sourceKey: 'harrison-sim/course/06/chapter/001',
    parentId: course.id,
    kind: CurriculumNodeKind.chapter,
    ordinal: 1,
    identityState: CurriculumIdentityState.approved,
    titleUnitId: 'l10n.chapter.001.title',
    sourceContainerKeys: const ['harrison-sim/course/06/chapter/001'],
  );
  final unit = CurriculumNode.fromSourceKey(
    sourceKey: 'harrison-sim/course/06/chapter/001/unit/001',
    parentId: chapter.id,
    kind: CurriculumNodeKind.unit,
    ordinal: 1,
    identityState: CurriculumIdentityState.approved,
    titleUnitId: 'l10n.unit.001.title',
  );
  final cluster = CurriculumNode.fromSourceKey(
    sourceKey:
        'harrison-sim/course/06/chapter/001/unit/001/concept-cluster/001',
    parentId: unit.id,
    kind: CurriculumNodeKind.conceptCluster,
    ordinal: 1,
    identityState: CurriculumIdentityState.approved,
    titleUnitId: 'l10n.cluster.001.title',
    conceptIds: const ['concept.cardiology.001'],
  );
  final microLesson = CurriculumNode.fromSourceKey(
    sourceKey:
        'harrison-sim/course/06/chapter/001/unit/001/concept-cluster/001/micro-lesson/001',
    parentId: cluster.id,
    kind: CurriculumNodeKind.microLesson,
    ordinal: 1,
    identityState: CurriculumIdentityState.approved,
    titleUnitId: 'l10n.micro-lesson.001.title',
    conceptIds: const ['concept.cardiology.001'],
  );
  return [course, chapter, unit, cluster, microLesson];
}

CurriculumLocalizationUnit _localization(
  String id,
  ContentSemanticRole role,
  String suffix,
) => CurriculumLocalizationUnit(
  id: id,
  semanticRole: role,
  semanticSkeletonSha256: 'b' * 64,
  sourceAtomIds: const ['source.atom.cardiology.001'],
  claimIds: const ['claim.cardiology.001'],
  conceptIds: const ['concept.cardiology.001'],
  en: LocalizedVariant.authored(
    locale: ContentLocale.en,
    text: 'English $suffix',
    status: LocalizedVariantStatus.approved,
    authorId: 'author.en.001',
    reviewerId: 'reviewer.en.001',
    reviewedAt: DateTime.utc(2026, 7, 17, 13),
  ),
  fa: LocalizedVariant.authored(
    locale: ContentLocale.fa,
    text: 'فارسی $suffix',
    status: LocalizedVariantStatus.approved,
    authorId: 'author.fa.001',
    reviewerId: 'reviewer.fa.001',
    reviewedAt: DateTime.utc(2026, 7, 17, 13),
  ),
  pairState: LocalizationPairState.publishable,
);

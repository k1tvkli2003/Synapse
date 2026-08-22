import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_services/synapse_services.dart';

/// A deliberately non-medical, synthetic package for Academy tests and local
/// implementation previews.
///
/// It proves the app renders only package-bound labels and feedback without
/// placing reference-derived teaching content in application code. Production
/// entrypoints never import this dev-only fixture.
CurriculumCatalogSnapshot buildAcademyTestCatalog() {
  const sourceKey = 'synapse-test/course/001';
  const microLessonId = 'micro-lesson.preview.001';
  const sessionId = 'session.preview.001';
  const interactionId = 'interaction.preview.001';
  const objectiveId = 'l10n.preview.objective';
  const sessionTitleId = 'l10n.preview.session.title';
  const promptId = 'l10n.preview.prompt';
  const optionOneId = 'option.preview.one';
  const optionTwoId = 'option.preview.two';
  const optionOneLabelId = 'l10n.preview.option.one';
  const optionTwoLabelId = 'l10n.preview.option.two';
  const flashId = 'l10n.preview.feedback.flash';
  const repairId = 'l10n.preview.feedback.repair';
  const deepId = 'l10n.preview.feedback.deep';
  const whyCorrectId = 'l10n.preview.feedback.correct';
  const whyWrongId = 'l10n.preview.feedback.wrong';
  const studyDocumentId = 'study.document.preview.001';
  const studyTitleId = 'l10n.preview.study.title';
  const keyIdeaBlockId = 'study.block.preview.key-idea';
  const keyIdeaHeadingId = 'l10n.preview.study.key-idea.heading';
  const keyIdeaBodyId = 'l10n.preview.study.key-idea.body';
  const mechanismBlockId = 'study.block.preview.mechanism';
  const mechanismHeadingId = 'l10n.preview.study.mechanism.heading';
  const mechanismOneId = 'l10n.preview.study.mechanism.one';
  const mechanismTwoId = 'l10n.preview.study.mechanism.two';
  const mechanismThreeId = 'l10n.preview.study.mechanism.three';
  const comparisonBlockId = 'study.block.preview.comparison';
  const comparisonHeadingId = 'l10n.preview.study.comparison.heading';
  const comparisonHeaderAId = 'l10n.preview.study.comparison.header-a';
  const comparisonHeaderBId = 'l10n.preview.study.comparison.header-b';
  const comparisonHeaderCId = 'l10n.preview.study.comparison.header-c';
  const comparisonRowId = 'l10n.preview.study.comparison.row';
  const comparisonCellAId = 'l10n.preview.study.comparison.cell-a';
  const comparisonCellBId = 'l10n.preview.study.comparison.cell-b';
  const pearlBlockId = 'study.block.preview.pearl';
  const pearlHeadingId = 'l10n.preview.study.pearl.heading';
  const pearlBodyId = 'l10n.preview.study.pearl.body';
  const recapBlockId = 'study.block.preview.recap';
  const recapHeadingId = 'l10n.preview.study.recap.heading';
  const recapBodyId = 'l10n.preview.study.recap.body';

  final course = CurriculumNode.fromSourceKey(
    sourceKey: sourceKey,
    kind: CurriculumNodeKind.course,
    ordinal: 1,
    identityState: CurriculumIdentityState.approved,
    titleUnitId: 'l10n.preview.course',
  );
  final chapter = CurriculumNode.fromSourceKey(
    sourceKey: '$sourceKey/chapter/001',
    parentId: course.id,
    kind: CurriculumNodeKind.chapter,
    ordinal: 1,
    identityState: CurriculumIdentityState.approved,
    titleUnitId: 'l10n.preview.chapter',
  );
  final unit = CurriculumNode.fromSourceKey(
    sourceKey: '$sourceKey/chapter/001/unit/001',
    parentId: chapter.id,
    kind: CurriculumNodeKind.unit,
    ordinal: 1,
    identityState: CurriculumIdentityState.approved,
    titleUnitId: 'l10n.preview.unit',
  );
  final cluster = CurriculumNode.fromSourceKey(
    sourceKey: '$sourceKey/chapter/001/unit/001/concept-cluster/001',
    parentId: unit.id,
    kind: CurriculumNodeKind.conceptCluster,
    ordinal: 1,
    identityState: CurriculumIdentityState.approved,
    titleUnitId: 'l10n.preview.cluster',
    conceptIds: const ['concept.preview.001'],
  );
  final microNode = CurriculumNode.fromSourceKey(
    sourceKey:
        '$sourceKey/chapter/001/unit/001/concept-cluster/001/micro-lesson/001',
    parentId: cluster.id,
    kind: CurriculumNodeKind.microLesson,
    ordinal: 1,
    identityState: CurriculumIdentityState.approved,
    titleUnitId: 'l10n.preview.micro',
    conceptIds: const ['concept.preview.001'],
  );
  final nodes = [course, chapter, unit, cluster, microNode];

  final interaction = CurriculumInteraction(
    id: interactionId,
    sessionId: sessionId,
    ordinal: 1,
    stepRole: InteractionStepRole.assessment,
    family: InteractionFamily.discrimination,
    kind: InteractionKind.singleBestAnswer,
    cognitiveLevel: CognitiveLevel.explain,
    promptUnitId: promptId,
    stimulus: InteractionStimulus(),
    options: [
      InteractionOption(
        id: optionOneId,
        labelUnitId: optionOneLabelId,
        isCorrect: true,
      ),
      InteractionOption(
        id: optionTwoId,
        labelUnitId: optionTwoLabelId,
        isCorrect: false,
        misconceptionId: 'misconception.preview.001',
        whyWrongUnitId: whyWrongId,
      ),
    ],
    responseSpec: ResponseSpec(
      kind: ResponseKind.singleChoice,
      optionIds: const [optionOneId, optionTwoId],
      minimumSelections: 1,
      maximumSelections: 1,
      freeTextNormalization: FreeTextNormalization.none,
    ),
    evaluationSpec: EvaluationSpec(
      answerKey: const [optionOneId],
      scoringVersion: 'synapse-test-scoring-v1',
      masteryDimensions: const [MasteryDimension.discrimination],
      diagnosticOnly: false,
      misconceptionMap: const {optionTwoId: 'misconception.preview.001'},
    ),
    feedbackSpec: FeedbackSpec(
      flashUnitId: flashId,
      repairUnitId: repairId,
      deepUnitId: deepId,
      whyCorrectUnitId: whyCorrectId,
      whyWrongByOptionId: const {optionTwoId: whyWrongId},
    ),
    sourceAtomIds: const ['source.atom.preview.001'],
    claimIds: const ['claim.preview.001'],
    conceptIds: const ['concept.preview.001'],
    estimatedSeconds: LocaleDuration(enSeconds: 30, faSeconds: 35),
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
    cognitiveTargets: const [CognitiveLevel.explain],
    conceptIds: const ['concept.preview.001'],
    sourceAtomIds: const ['source.atom.preview.001'],
    claimIds: const ['claim.preview.001'],
    interactionIds: const [interactionId],
    estimatedSeconds: LocaleDuration(enSeconds: 90, faSeconds: 100),
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
    unitId: unit.id,
    conceptClusterId: cluster.id,
    ordinal: 1,
    titleUnitId: microNode.titleUnitId,
    objectiveUnitIds: const [objectiveId],
    sourceAtomIds: const ['source.atom.preview.001'],
    claimIds: const ['claim.preview.001'],
    conceptIds: const ['concept.preview.001'],
    sessionIds: const [sessionId],
    estimatedSeconds: LocaleDuration(enSeconds: 90, faSeconds: 100),
    splitRationale: 'Synthetic bounded interaction for a UI test.',
  );
  final studyDocument = CurriculumStudyDocument(
    id: studyDocumentId,
    microLessonNodeId: microNode.id,
    ordinal: 1,
    kind: CurriculumStudyDocumentKind.primaryLesson,
    titleUnitId: studyTitleId,
    estimatedSeconds: LocaleDuration(enSeconds: 390, faSeconds: 430),
    blockIds: const [
      keyIdeaBlockId,
      mechanismBlockId,
      comparisonBlockId,
      pearlBlockId,
      recapBlockId,
    ],
    sourceAtomIds: const ['source.atom.preview.001'],
    claimIds: const ['claim.preview.001'],
    conceptIds: const ['concept.preview.001'],
  );
  final studyBlocks = <CurriculumStudyBlock>[
    CurriculumStudyBlock(
      id: keyIdeaBlockId,
      documentId: studyDocumentId,
      ordinal: 1,
      kind: CurriculumStudyBlockKind.keyIdea,
      headingUnitId: keyIdeaHeadingId,
      contentUnitIds: const [keyIdeaBodyId],
      sourceAtomIds: const ['source.atom.preview.001'],
      claimIds: const ['claim.preview.001'],
      conceptIds: const ['concept.preview.001'],
      revealPolicy: CurriculumStudyRevealPolicy.always,
    ),
    CurriculumStudyBlock(
      id: mechanismBlockId,
      documentId: studyDocumentId,
      ordinal: 2,
      kind: CurriculumStudyBlockKind.mechanismChain,
      headingUnitId: mechanismHeadingId,
      contentUnitIds: const [mechanismOneId, mechanismTwoId, mechanismThreeId],
      sourceAtomIds: const ['source.atom.preview.001'],
      claimIds: const ['claim.preview.001'],
      conceptIds: const ['concept.preview.001'],
      revealPolicy: CurriculumStudyRevealPolicy.always,
    ),
    CurriculumStudyBlock(
      id: comparisonBlockId,
      documentId: studyDocumentId,
      ordinal: 3,
      kind: CurriculumStudyBlockKind.comparisonTable,
      headingUnitId: comparisonHeadingId,
      tableRows: const [
        [comparisonHeaderAId, comparisonHeaderBId, comparisonHeaderCId],
        [comparisonRowId, comparisonCellAId, comparisonCellBId],
      ],
      sourceAtomIds: const ['source.atom.preview.001'],
      claimIds: const ['claim.preview.001'],
      conceptIds: const ['concept.preview.001'],
      revealPolicy: CurriculumStudyRevealPolicy.always,
    ),
    CurriculumStudyBlock(
      id: pearlBlockId,
      documentId: studyDocumentId,
      ordinal: 4,
      kind: CurriculumStudyBlockKind.clinicalPearl,
      headingUnitId: pearlHeadingId,
      contentUnitIds: const [pearlBodyId],
      sourceAtomIds: const ['source.atom.preview.001'],
      claimIds: const ['claim.preview.001'],
      conceptIds: const ['concept.preview.001'],
      revealPolicy: CurriculumStudyRevealPolicy.always,
    ),
    CurriculumStudyBlock(
      id: recapBlockId,
      documentId: studyDocumentId,
      ordinal: 5,
      kind: CurriculumStudyBlockKind.recap,
      headingUnitId: recapHeadingId,
      contentUnitIds: const [recapBodyId],
      sourceAtomIds: const ['source.atom.preview.001'],
      claimIds: const ['claim.preview.001'],
      conceptIds: const ['concept.preview.001'],
      revealPolicy: CurriculumStudyRevealPolicy.afterSessionCompletion,
      revealedAfterSessionId: sessionId,
    ),
  ];

  final manifest = CurriculumManifest(
    source: CurriculumSource(
      id: 'source.synapse-test',
      sourceKey: 'synapse-test',
      classification: 'synthetic-test-only',
      sourceTreeSha256: 'a' * 64,
      scanManifestId: 'scan.synapse-test.001',
      priorityCourseSourceKey: sourceKey,
    ),
    release: CurriculumRelease(
      id: 'release.synapse-test.001',
      sourceId: 'source.synapse-test',
      version: '0.0.1-test',
      channel: CurriculumReleaseChannel.stable,
      contractVersion: 1,
      authoringProtocolVersion: 'synapse-test-v1',
      sourceTreeSha256: 'a' * 64,
      contentState: ContentLifecycleState.published,
      createdAt: DateTime.utc(2026, 7, 17),
    ),
    nodes: nodes,
    localizationUnits: [
      for (final node in nodes)
        _localized(node.titleUnitId, ContentSemanticRole.title, node.kind.name),
      _localized(objectiveId, ContentSemanticRole.objective, 'objective'),
      _localized(sessionTitleId, ContentSemanticRole.title, 'practice session'),
      _localized(promptId, ContentSemanticRole.prompt, 'synthetic prompt'),
      _localized(optionOneLabelId, ContentSemanticRole.option, 'first option'),
      _localized(optionTwoLabelId, ContentSemanticRole.option, 'second option'),
      _localized(flashId, ContentSemanticRole.feedbackFlash, 'feedback flash'),
      _localized(repairId, ContentSemanticRole.feedbackRepair, 'repair note'),
      _localized(deepId, ContentSemanticRole.feedbackDeep, 'deep note'),
      _localized(
        whyCorrectId,
        ContentSemanticRole.whyCorrect,
        'correct rationale',
      ),
      _localized(whyWrongId, ContentSemanticRole.whyWrong, 'repair rationale'),
      _localized(studyTitleId, ContentSemanticRole.title, 'deep study title'),
      _localized(
        keyIdeaHeadingId,
        ContentSemanticRole.title,
        'key idea heading',
      ),
      _localized(
        keyIdeaBodyId,
        ContentSemanticRole.explanation,
        'key idea body',
      ),
      _localized(
        mechanismHeadingId,
        ContentSemanticRole.title,
        'mechanism heading',
      ),
      _localized(
        mechanismOneId,
        ContentSemanticRole.explanation,
        'mechanism step one',
      ),
      _localized(
        mechanismTwoId,
        ContentSemanticRole.explanation,
        'mechanism step two',
      ),
      _localized(
        mechanismThreeId,
        ContentSemanticRole.explanation,
        'mechanism step three',
      ),
      _localized(
        comparisonHeadingId,
        ContentSemanticRole.title,
        'comparison heading',
      ),
      _localized(
        comparisonHeaderAId,
        ContentSemanticRole.caption,
        'comparison dimension',
      ),
      _localized(
        comparisonHeaderBId,
        ContentSemanticRole.caption,
        'comparison route one',
      ),
      _localized(
        comparisonHeaderCId,
        ContentSemanticRole.caption,
        'comparison route two',
      ),
      _localized(
        comparisonRowId,
        ContentSemanticRole.caption,
        'comparison signal',
      ),
      _localized(
        comparisonCellAId,
        ContentSemanticRole.explanation,
        'comparison direct value',
      ),
      _localized(
        comparisonCellBId,
        ContentSemanticRole.explanation,
        'comparison layered value',
      ),
      _localized(pearlHeadingId, ContentSemanticRole.title, 'pearl heading'),
      _localized(pearlBodyId, ContentSemanticRole.explanation, 'pearl body'),
      _localized(recapHeadingId, ContentSemanticRole.title, 'recap heading'),
      _localized(recapBodyId, ContentSemanticRole.recap, 'recap body'),
    ],
    microLessons: [microLesson],
    sessions: [session],
    interactions: [interaction],
    studyDocuments: [studyDocument],
    studyBlocks: studyBlocks,
  );
  return CurriculumCatalogSnapshot.fromManifest(manifest);
}

CurriculumLocalizationUnit _localized(
  String id,
  ContentSemanticRole role,
  String text,
) => CurriculumLocalizationUnit(
  id: id,
  semanticRole: role,
  semanticSkeletonSha256: 'b' * 64,
  sourceAtomIds: const ['source.atom.preview.001'],
  claimIds: const ['claim.preview.001'],
  conceptIds: const ['concept.preview.001'],
  en: LocalizedVariant.authored(
    locale: ContentLocale.en,
    text: _englishSyntheticText(text),
    status: LocalizedVariantStatus.approved,
    authorId: 'author.en.preview',
    reviewerId: 'reviewer.en.preview',
    reviewedAt: DateTime.utc(2026, 7, 17),
  ),
  fa: LocalizedVariant.authored(
    locale: ContentLocale.fa,
    text: _persianSyntheticText(text),
    status: LocalizedVariantStatus.approved,
    authorId: 'author.fa.preview',
    reviewerId: 'reviewer.fa.preview',
    reviewedAt: DateTime.utc(2026, 7, 17),
  ),
  pairState: LocalizationPairState.publishable,
);

String _englishSyntheticText(String text) => switch (text) {
  'deep study title' => 'A Small System, Explained',
  'key idea heading' => 'The one idea to carry',
  'key idea body' =>
    'A stable result appears when every step receives a clear input and leaves a checkable output.',
  'mechanism heading' => 'Follow the signal',
  'mechanism step one' => 'Name the synthetic input.',
  'mechanism step two' => 'Trace the intermediate relationship.',
  'mechanism step three' => 'Confirm the observable output.',
  'comparison heading' => 'Compare two routes',
  'comparison dimension' => 'Dimension',
  'comparison route one' => 'Direct route',
  'comparison route two' => 'Layered route',
  'comparison signal' => 'Synthetic signal',
  'comparison direct value' => 'One transition',
  'comparison layered value' => 'Several transitions',
  'pearl heading' => 'Study cue',
  'pearl body' =>
    'See the whole pattern first; attach details only after the shape is clear.',
  'recap heading' => 'After-session recap',
  'recap body' =>
    'This recap appears only after the linked session is complete.',
  _ => 'Preview $text',
};

String _persianSyntheticText(String text) => switch (text) {
  'course' => 'دوره آزمایشی',
  'chapter' => 'فصل آزمایشی',
  'unit' => 'واحد آزمایشی',
  'conceptCluster' => 'خوشه مفهومی آزمایشی',
  'microLesson' => 'میکرودرس آزمایشی',
  'objective' => 'هدف یادگیری آزمایشی',
  'practice session' => 'جلسه تمرین آزمایشی',
  'synthetic prompt' => 'پرسش آزمایشی',
  'first option' => 'گزینه اول آزمایشی',
  'second option' => 'گزینه دوم آزمایشی',
  'feedback flash' => 'بازخورد کوتاه آزمایشی',
  'repair note' => 'نکته اصلاحی آزمایشی',
  'deep note' => 'توضیح تکمیلی آزمایشی',
  'correct rationale' => 'دلیل پاسخ درست آزمایشی',
  'repair rationale' => 'دلیل اصلاح پاسخ آزمایشی',
  'deep study title' => 'مطالعه عمیق آزمایشی',
  'key idea heading' => 'ایده کلیدی',
  'key idea body' => 'این بلوک، یک ایده کوتاه و قابل مرور را نمایش می‌دهد.',
  'mechanism heading' => 'زنجیره مفهومی',
  'mechanism step one' => 'ورودی آزمایشی را مشخص کن.',
  'mechanism step two' => 'رابطه میانی را دنبال کن.',
  'mechanism step three' => 'به خروجی قابل بررسی برس.',
  'comparison heading' => 'مقایسه دو مسیر',
  'comparison dimension' => 'بُعد',
  'comparison route one' => 'مسیر مستقیم',
  'comparison route two' => 'مسیر لایه‌ای',
  'comparison signal' => 'سیگنال آزمایشی',
  'comparison direct value' => 'یک مرحله',
  'comparison layered value' => 'چند مرحله',
  'pearl heading' => 'نکته کاربردی',
  'pearl body' => 'ابتدا الگو را ببین، سپس جزئیات را به آن متصل کن.',
  'recap heading' => 'مرور پس از جلسه',
  'recap body' => 'این مرور فقط پس از تکمیل جلسه آشکار می‌شود.',
  _ => throw ArgumentError.value(text, 'text', 'Unknown synthetic label'),
};

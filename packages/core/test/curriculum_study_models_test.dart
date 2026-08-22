import 'package:synapse_core/synapse_core.dart';
import 'package:test/test.dart';

void main() {
  group('Deep Study document contract', () {
    test('round-trips a bounded primary Micro-lesson document', () {
      final document = _document();

      expect(CurriculumStudyDocument.fromJson(document.toJson()), document);
      expect(document.blockIds, hasLength(2));
      expect(document.estimatedSeconds.forLocale(ContentLocale.fa), 410);
    });

    test('rejects unbounded documents and duplicate block ownership slots', () {
      expect(
        () =>
            _document(duration: LocaleDuration(enSeconds: 721, faSeconds: 410)),
        throwsArgumentError,
      );
      expect(
        () => _document(blockIds: const ['study.block.1', 'study.block.1']),
        throwsArgumentError,
      );
    });
  });

  group('Deep Study semantic block contract', () {
    test('round-trips prose and rectangular comparison shapes', () {
      final prose = _block();
      final table = _block(
        id: 'study.block.2',
        ordinal: 2,
        kind: CurriculumStudyBlockKind.comparisonTable,
        contentUnitIds: const [],
        tableRows: const [
          ['l10n.table.header.1', 'l10n.table.header.2'],
          ['l10n.table.row.1', 'l10n.table.cell.1'],
        ],
      );

      expect(CurriculumStudyBlock.fromJson(prose.toJson()), prose);
      expect(CurriculumStudyBlock.fromJson(table.toJson()), table);
      expect(table.localizationUnitIds, hasLength(5));
    });

    test('enforces semantic shape bounds and rectangular tables', () {
      expect(
        () => _block(
          kind: CurriculumStudyBlockKind.mechanismChain,
          contentUnitIds: const ['l10n.study.body.1'],
        ),
        throwsArgumentError,
      );
      expect(
        () => _block(
          kind: CurriculumStudyBlockKind.comparisonTable,
          contentUnitIds: const [],
          tableRows: const [
            ['l10n.table.header.1', 'l10n.table.header.2'],
            ['l10n.table.row.1'],
          ],
        ),
        throwsArgumentError,
      );
    });

    test('requires a Session gate only for delayed reveal policies', () {
      expect(
        () =>
            _block(revealPolicy: CurriculumStudyRevealPolicy.afterFirstAttempt),
        throwsArgumentError,
      );
      expect(
        () => _block(revealedAfterSessionId: 'session.1'),
        throwsArgumentError,
      );

      final gated = _block(
        revealPolicy: CurriculumStudyRevealPolicy.afterSessionCompletion,
        revealedAfterSessionId: 'session.1',
      );
      expect(gated.isAlwaysVisible, isFalse);
    });

    test('reveals only from exact, meaningful release-bound progress', () {
      final attemptGate = _block(
        revealPolicy: CurriculumStudyRevealPolicy.afterFirstAttempt,
        revealedAfterSessionId: 'session.1',
      );
      final completionGate = _block(
        revealPolicy: CurriculumStudyRevealPolicy.afterSessionCompletion,
        revealedAfterSessionId: 'session.1',
      );
      final selectedOnly = _progress(revision: 2, selectedOptionId: 'option.1');
      final attempted = _progress(
        revision: 3,
        choiceResponses: {
          'interaction.1': CurriculumChoiceResponse(
            id: 'response.1',
            interactionId: 'interaction.1',
            selectedOptionId: 'option.1',
            isCorrect: true,
            answeredAt: DateTime.utc(2026, 7, 18, 12, 1),
          ),
        },
      );
      final completed = _progress(
        phase: CurriculumSessionProgressPhase.completed,
        revision: 4,
        completedAt: DateTime.utc(2026, 7, 18, 12, 2),
        completionReceiptId: 'completion.1',
      );

      bool revealed(
        CurriculumStudyBlock block,
        CurriculumSessionProgress progress, {
        String releaseId = 'release.1',
        String nodeId = 'node.micro-lesson.1',
      }) => block.isRevealedBy(
        progress: progress,
        releaseId: releaseId,
        microLessonNodeId: nodeId,
      );

      expect(revealed(attemptGate, selectedOnly), isFalse);
      expect(revealed(attemptGate, attempted), isTrue);
      expect(revealed(completionGate, attempted), isFalse);
      expect(revealed(completionGate, completed), isTrue);
      expect(
        revealed(attemptGate, attempted, releaseId: 'release.other'),
        isFalse,
      );
      expect(revealed(attemptGate, attempted, nodeId: 'node.other'), isFalse);
      expect(
        attemptGate.isRevealedBy(
          progress: null,
          releaseId: 'release.1',
          microLessonNodeId: 'node.micro-lesson.1',
        ),
        isFalse,
      );
    });
  });
}

CurriculumStudyDocument _document({
  Iterable<String> blockIds = const ['study.block.1', 'study.block.2'],
  LocaleDuration? duration,
}) => CurriculumStudyDocument(
  id: 'study.document.1',
  microLessonNodeId: 'node.micro-lesson.1',
  ordinal: 1,
  kind: CurriculumStudyDocumentKind.primaryLesson,
  titleUnitId: 'l10n.study.title.1',
  estimatedSeconds: duration ?? LocaleDuration(enSeconds: 360, faSeconds: 410),
  blockIds: blockIds,
  sourceAtomIds: const ['source.atom.1'],
  claimIds: const ['claim.1'],
  conceptIds: const ['concept.1'],
);

CurriculumStudyBlock _block({
  String id = 'study.block.1',
  int ordinal = 1,
  CurriculumStudyBlockKind kind = CurriculumStudyBlockKind.prose,
  Iterable<String> contentUnitIds = const ['l10n.study.body.1'],
  Iterable<Iterable<String>> tableRows = const [],
  CurriculumStudyRevealPolicy revealPolicy = CurriculumStudyRevealPolicy.always,
  String? revealedAfterSessionId,
}) => CurriculumStudyBlock(
  id: id,
  documentId: 'study.document.1',
  ordinal: ordinal,
  kind: kind,
  headingUnitId: 'l10n.study.heading.1',
  contentUnitIds: contentUnitIds,
  tableRows: tableRows,
  sourceAtomIds: const ['source.atom.1'],
  claimIds: const ['claim.1'],
  conceptIds: const ['concept.1'],
  revealPolicy: revealPolicy,
  revealedAfterSessionId: revealedAfterSessionId,
);

CurriculumSessionProgress _progress({
  CurriculumSessionProgressPhase phase =
      CurriculumSessionProgressPhase.inProgress,
  int interactionIndex = 0,
  int revision = 1,
  String? selectedOptionId,
  Map<String, CurriculumChoiceResponse> choiceResponses = const {},
  DateTime? completedAt,
  String? completionReceiptId,
}) => CurriculumSessionProgress(
  key: CurriculumSessionProgressKey(
    releaseId: 'release.1',
    microLessonNodeId: 'node.micro-lesson.1',
    sessionId: 'session.1',
  ),
  phase: phase,
  interactionIndex: interactionIndex,
  revision: revision,
  startedAt: DateTime.utc(2026, 7, 18, 12),
  updatedAt: DateTime.utc(2026, 7, 18, 12, 2),
  selectedOptionId: selectedOptionId,
  choiceResponses: choiceResponses,
  completedAt: completedAt,
  completionReceiptId: completionReceiptId,
);

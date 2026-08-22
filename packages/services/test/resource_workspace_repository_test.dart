import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_foundation/synapse_foundation.dart';
import 'package:synapse_services/synapse_services.dart';
import 'package:test/test.dart';

const _documentDigest =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _selectionDigest =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

void main() {
  late MemoryKeyValueStore store;
  late MutableClock clock;
  late LocalResourceWorkspaceRepository repository;

  setUp(() {
    store = MemoryKeyValueStore();
    clock = MutableClock(DateTime.utc(2026, 7, 22, 14));
    repository = _repository(store, clock, const [
      'annotation.001',
      'annotation.002',
      'annotation.003',
    ]);
  });

  test(
    'persists content-addressed metadata and paged anchor across restart',
    () async {
      final document = _document();
      final anchor = _textAnchor();

      await repository.registerDocument(document);
      await repository.registerAnchor(anchor);
      final restarted = _repository(store, clock, const ['unused.001']);

      expect(await restarted.readDocument(document.id), document);
      expect(await restarted.findDocumentByDigest(_documentDigest), document);
      expect(await restarted.listDocuments(), [document]);
      expect(await restarted.readAnchor(anchor.stableId), anchor);
      expect(await restarted.auditIntegrity(), isEmpty);
      final wire = store.snapshot[LocalResourceWorkspaceRepository.stateKey]
          .toString();
      expect(wire, isNot(contains('base64')));
      expect(wire, isNot(contains(r'C:\Users')));
    },
  );

  test(
    'creates typed comments and highlights under one resource authority',
    () async {
      await repository.registerDocument(_document());
      final anchor = _textAnchor();
      final comment = await repository.addComment(
        anchor: anchor,
        locale: ContentLocale.en,
        body: 'Compare this mechanism with the preceding Block.',
        color: ResourceArtifactColor.cyan,
        tagIds: const ['tag.compare'],
      );
      final highlight = await repository.addHighlight(
        anchor: anchor,
        color: ResourceArtifactColor.gold,
      );

      expect(comment.kind, ResourceAnnotationKind.comment);
      expect(highlight.kind, ResourceAnnotationKind.highlight);
      expect(await repository.listAnnotationsForResource(anchor.resource), [
        highlight,
        comment,
      ]);
      expect(
        (await repository.listAnchorsForResource(anchor.resource)).single,
        anchor,
      );
    },
  );

  test(
    'annotation lifecycle is compare-and-set and keeps delete tombstone',
    () async {
      final anchor = _blockAnchor();
      final annotation = await repository.addHighlight(
        anchor: anchor,
        color: ResourceArtifactColor.green,
      );
      clock.advance(const Duration(minutes: 1));
      final resolved = await repository.setAnnotationState(
        annotationId: annotation.id,
        state: ResourceAnnotationState.resolved,
        expectedRevision: annotation.revision,
      );
      expect(resolved.revision, 2);
      expect(
        await repository.setAnnotationState(
          annotationId: annotation.id,
          state: ResourceAnnotationState.resolved,
          expectedRevision: 999,
        ),
        resolved,
      );
      await expectLater(
        repository.setAnnotationState(
          annotationId: annotation.id,
          state: ResourceAnnotationState.deleted,
          expectedRevision: 1,
        ),
        throwsA(
          isA<ResourceWorkspaceException>().having(
            (error) => error.code,
            'code',
            'stale_resource_annotation_revision',
          ),
        ),
      );
      final deleted = await repository.setAnnotationState(
        annotationId: annotation.id,
        state: ResourceAnnotationState.deleted,
        expectedRevision: resolved.revision,
      );
      expect(
        await repository.listAnnotationsForResource(anchor.resource),
        isEmpty,
      );
      expect(
        await repository.listAnnotationsForResource(
          anchor.resource,
          includeDeleted: true,
        ),
        [deleted],
      );
    },
  );

  test(
    'bookmark toggle has deterministic identity and stale-write safety',
    () async {
      final anchor = _blockAnchor();
      final saved = await repository.setBookmarked(
        anchor: anchor,
        isBookmarked: true,
        color: ResourceArtifactColor.gold,
        label: 'Return before the next session',
      );
      expect(await repository.readBookmark(anchor.stableId), saved);
      expect(
        await repository.setBookmarked(
          anchor: anchor,
          isBookmarked: true,
          color: ResourceArtifactColor.gold,
          label: 'Return before the next session',
          expectedRevision: 999,
        ),
        saved,
      );
      await expectLater(
        repository.setBookmarked(
          anchor: anchor,
          isBookmarked: false,
          color: ResourceArtifactColor.gold,
          expectedRevision: saved.revision + 1,
        ),
        throwsA(isA<ResourceWorkspaceException>()),
      );
      final removed = await repository.setBookmarked(
        anchor: anchor,
        isBookmarked: false,
        color: ResourceArtifactColor.gold,
        expectedRevision: saved.revision,
      );
      expect(removed.isDeleted, isTrue);
      expect(await repository.readBookmark(anchor.stableId), isNull);
      expect(
        await repository.readBookmark(anchor.stableId, includeDeleted: true),
        removed,
      );
    },
  );

  test(
    'rejects paged artifacts until document metadata is registered',
    () async {
      final anchor = _textAnchor();
      await expectLater(
        repository.registerAnchor(anchor),
        throwsA(
          isA<ResourceWorkspaceException>().having(
            (error) => error.code,
            'code',
            'resource_anchor_document_missing',
          ),
        ),
      );
      expect(
        store.snapshot.containsKey(LocalResourceWorkspaceRepository.stateKey),
        isFalse,
      );
    },
  );

  test(
    'refreshes Block fallback ordinal without changing semantic anchor ID',
    () async {
      final first = _blockAnchor(blockOrdinal: 2);
      final reordered = _blockAnchor(blockOrdinal: 8);
      expect(first.stableId, reordered.stableId);

      await repository.registerAnchor(first);
      await repository.registerAnchor(reordered);

      final stored = await repository.readAnchor(first.stableId);
      expect(stored, reordered);
      expect((stored! as CurriculumBlockResourceAnchor).blockOrdinal, 8);
    },
  );

  test(
    'detects integrity drift without echoing private annotation text',
    () async {
      await repository.addComment(
        anchor: _blockAnchor(),
        locale: ContentLocale.en,
        body: 'private learner sentence',
        color: ResourceArtifactColor.violet,
      );
      final raw = Map<String, Object?>.from(
        store.snapshot[LocalResourceWorkspaceRepository.stateKey]! as Map,
      );
      raw['integrity'] = {
        ...Map<String, Object?>.from(raw['integrity']! as Map),
        'annotationCount': 99,
      };
      await store.write(LocalResourceWorkspaceRepository.stateKey, raw);

      final issues = await repository.auditIntegrity();
      expect(issues.single.code, 'corrupt_resource_workspace_registry');
      expect(
        issues.single.message,
        isNot(contains('private learner sentence')),
      );
    },
  );

  test('persists bounded freehand ink without platform path data', () async {
    final document = await repository.registerDocument(_document());
    final anchor = DocumentRegionResourceAnchor(
      resource: document.reference,
      pageNumber: 3,
      region: NormalizedResourceRegion(
        leftMillionths: 0,
        topMillionths: 0,
        widthMillionths: NormalizedResourceRegion.scale,
        heightMillionths: NormalizedResourceRegion.scale,
      ),
    );
    final ink = await repository.addInk(
      anchor: anchor,
      strokes: [
        ResourceInkStroke(
          id: 'stroke.001',
          points: [
            ResourceInkPoint(
              xMillionths: 100000,
              yMillionths: 200000,
              pressurePermille: 700,
            ),
            ResourceInkPoint(
              xMillionths: 400000,
              yMillionths: 600000,
              pressurePermille: 700,
            ),
          ],
          widthMillionths: 4500,
          opacityPermille: 850,
        ),
      ],
      color: ResourceArtifactColor.cyan,
    );
    final restarted = _repository(store, clock, const ['unused.ink']);

    expect(await restarted.listAnnotationsForResource(document.reference), [
      ink,
    ]);
    expect(
      await restarted.readAnchor(anchor.stableId),
      isA<DocumentRegionResourceAnchor>(),
    );
    final wire = store.snapshot[LocalResourceWorkspaceRepository.stateKey]
        .toString();
    expect(wire, contains('pressurePermille: 700'));
    expect(wire, isNot(contains(r'C:\Users')));
  });

  test(
    'links one document to a lesson context with a durable tombstone',
    () async {
      final document = await repository.registerDocument(_document());
      final context = ResourceReference.curriculumNode(
        sourceId: 'source.harrison-sim',
        nodeId: 'node.micro.001',
      );
      final linked = await repository.setCrossReference(
        from: context,
        to: document.reference,
        kind: ResourceCrossReferenceKind.supportingDocument,
        isLinked: true,
      );
      expect(
        await repository.listCrossReferencesFrom(
          context,
          kind: ResourceCrossReferenceKind.supportingDocument,
        ),
        [linked],
      );

      final removed = await repository.setCrossReference(
        from: context,
        to: document.reference,
        kind: ResourceCrossReferenceKind.supportingDocument,
        isLinked: false,
        expectedRevision: linked.revision,
      );
      expect(removed.isDeleted, isTrue);
      expect(await repository.listCrossReferencesFrom(context), isEmpty);
      expect(
        await repository.readCrossReference(linked.id, includeDeleted: true),
        removed,
      );
    },
  );
}

LocalResourceWorkspaceRepository _repository(
  MemoryKeyValueStore store,
  MutableClock clock,
  Iterable<String> ids,
) => LocalResourceWorkspaceRepository(
  store: store,
  clock: clock,
  idSource: SequenceIdSource(ids),
);

ResourceDocument _document() => ResourceDocument(
  id: 'document.001',
  displayName: 'Cardiology reference.pdf',
  mediaType: 'application/pdf',
  contentSha256: _documentDigest,
  byteLength: 4096,
  pageCount: 12,
  origin: ResourceDocumentOrigin.userImport,
  createdAt: DateTime.utc(2026, 7, 22, 14),
);

DocumentTextRangeResourceAnchor _textAnchor() =>
    DocumentTextRangeResourceAnchor(
      resource: ResourceReference.document('document.001'),
      pageNumber: 3,
      startOffset: 20,
      endOffset: 48,
      selectedTextSha256: _selectionDigest,
    );

CurriculumBlockResourceAnchor _blockAnchor({int blockOrdinal = 2}) =>
    CurriculumBlockResourceAnchor(
      resource: ResourceReference.curriculumStudyDocument(
        sourceId: 'source.harrison-sim',
        documentId: 'study.document.001',
      ),
      blockId: 'study.block.002',
      blockOrdinal: blockOrdinal,
      localizationUnitId: 'l10n.study.body.002',
    );

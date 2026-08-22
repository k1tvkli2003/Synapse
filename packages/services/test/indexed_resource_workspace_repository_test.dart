import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_foundation/synapse_foundation.dart';
import 'package:synapse_services/synapse_services.dart';
import 'package:test/test.dart';

const _documentDigest =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _selectionDigest =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

void main() {
  late LearnerDataPlaneDatabase database;
  late _MemoryKeyProvider keys;
  late EncryptedIndexedLearnerRecordStore records;
  late MutableClock clock;

  setUp(() {
    database = LearnerDataPlaneDatabase(NativeDatabase.memory());
    keys = _MemoryKeyProvider(_key(29));
    records = EncryptedIndexedLearnerRecordStore(
      database: database,
      keys: keys,
    );
    clock = MutableClock(DateTime.utc(2026, 7, 22, 14));
  });

  tearDown(() => database.close());

  test(
    'restores one resource graph with exact scoped indexes after restart',
    () async {
      final repository = _repository(records, clock, const ['annotation.001']);
      final document = await repository.registerDocument(_document());
      final anchor = _textAnchor();
      final comment = await repository.addComment(
        anchor: anchor,
        locale: ContentLocale.fa,
        body: 'این نکته خصوصی فقط برای مرور خود کاربر است.',
        color: ResourceArtifactColor.cyan,
        tagIds: const ['tag.private-review'],
      );
      final bookmark = await repository.setBookmarked(
        anchor: anchor,
        isBookmarked: true,
        color: ResourceArtifactColor.gold,
        label: 'Return after the calm round',
      );
      final lesson = ResourceReference.curriculumNode(
        sourceId: 'source.harrison-sim',
        nodeId: 'node.cardiology.001',
      );
      final crossReference = await repository.setCrossReference(
        from: lesson,
        to: document.reference,
        kind: ResourceCrossReferenceKind.supportingDocument,
        isLinked: true,
      );

      final restarted = _repository(records, clock, const ['unused.001']);
      expect(await restarted.readDocument(document.id), document);
      expect(await restarted.findDocumentByDigest(_documentDigest), document);
      expect(await restarted.readAnchor(anchor.stableId), anchor);
      expect(await restarted.listAnnotationsForResource(document.reference), [
        comment,
      ]);
      expect(await restarted.listBookmarksForResource(document.reference), [
        bookmark,
      ]);
      expect(await restarted.listCrossReferencesFrom(lesson), [crossReference]);
      expect(
        await restarted.listAnnotationsForResource(
          ResourceReference.document('document.unrelated'),
        ),
        isEmpty,
      );
      expect(await restarted.auditIntegrity(), isEmpty);
    },
  );

  test(
    'keeps private workspace identities and payload out of SQLite',
    () async {
      final repository = _repository(records, clock, const [
        'annotation.private.001',
      ]);
      await repository.registerDocument(_document());
      await repository.addComment(
        anchor: _textAnchor(),
        locale: ContentLocale.en,
        body: 'Private differential: never expose this sentence.',
        color: ResourceArtifactColor.violet,
        tagIds: const ['tag.secret'],
      );

      final rows = await database
          .select(database.encryptedLearnerRecords)
          .get();
      final serialized = rows.join('\n');
      expect(serialized, isNot(contains('document.001')));
      expect(serialized, isNot(contains('annotation.private.001')));
      expect(serialized, isNot(contains('Private differential')));
      expect(serialized, isNot(contains('tag.secret')));
      expect(serialized, isNot(contains(r'C:\Users')));
      expect(serialized, isNot(contains('base64')));
      expect(rows.every((row) => row.recordIdHash.length == 64), isTrue);
      expect(rows.every((row) => row.scopeHash.length == 64), isTrue);
    },
  );

  test(
    'rejects digest length drift without committing the conflicting document',
    () async {
      final repository = _repository(records, clock, const ['unused.001']);
      await repository.registerDocument(_document());

      await expectLater(
        repository.registerDocument(
          ResourceDocument(
            id: 'document.conflict',
            displayName: 'Conflicting length.pdf',
            mediaType: 'application/pdf',
            contentSha256: _documentDigest,
            byteLength: 8192,
            pageCount: 12,
            origin: ResourceDocumentOrigin.userImport,
            createdAt: clock.nowUtc(),
          ),
        ),
        throwsA(
          isA<ResourceWorkspaceException>().having(
            (error) => error.code,
            'code',
            'resource_document_digest_length_drift',
          ),
        ),
      );
      expect(await repository.readDocument('document.conflict'), isNull);
      expect(await repository.listDocuments(), hasLength(1));
    },
  );

  test(
    'anchor and annotation remain atomic when generated identity collides',
    () async {
      final existing = ResourceAnnotation(
        id: 'annotation.collision',
        anchorId: _blockAnchor().stableId,
        kind: ResourceAnnotationKind.comment,
        color: ResourceArtifactColor.cyan,
        locale: ContentLocale.en,
        body: 'Existing encrypted annotation',
        state: ResourceAnnotationState.active,
        revision: 1,
        createdAt: clock.nowUtc(),
        updatedAt: clock.nowUtc(),
        stateChangedAt: clock.nowUtc(),
      );
      await records.put(
        PrivateLearnerRecordDraft(
          namespace: IndexedResourceWorkspaceRepository.annotationNamespace,
          recordId: existing.id,
          scopeId: _blockAnchor().resource.stableId,
          kind: 'comment',
          updatedAt: existing.updatedAt,
          payload: existing.toJson(),
        ),
        expectedRevision: null,
      );
      final repository = _repository(records, clock, const [
        'annotation.collision',
      ]);
      final newAnchor = CurriculumBlockResourceAnchor(
        resource: ResourceReference.curriculumStudyDocument(
          sourceId: 'source.harrison-sim',
          documentId: 'study.document.atomic',
        ),
        blockId: 'study.block.atomic',
        blockOrdinal: 4,
        localizationUnitId: 'l10n.study.atomic',
      );

      await expectLater(
        repository.addComment(
          anchor: newAnchor,
          locale: ContentLocale.en,
          body: 'Must never be partially committed',
          color: ResourceArtifactColor.green,
        ),
        throwsA(
          isA<ResourceWorkspaceException>().having(
            (error) => error.code,
            'code',
            'resource_annotation_identity_collision',
          ),
        ),
      );
      expect(await repository.readAnchor(newAnchor.stableId), isNull);
    },
  );

  test(
    'persists CAS lifecycles and tombstones without losing auditability',
    () async {
      final repository = _repository(records, clock, const ['annotation.001']);
      final annotation = await repository.addHighlight(
        anchor: _blockAnchor(),
        color: ResourceArtifactColor.green,
      );
      clock.advance(const Duration(minutes: 1));
      final resolved = await repository.setAnnotationState(
        annotationId: annotation.id,
        state: ResourceAnnotationState.resolved,
        expectedRevision: annotation.revision,
      );
      await expectLater(
        repository.setAnnotationState(
          annotationId: annotation.id,
          state: ResourceAnnotationState.deleted,
          expectedRevision: annotation.revision,
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
        await repository.listAnnotationsForResource(_blockAnchor().resource),
        isEmpty,
      );
      expect(
        await repository.listAnnotationsForResource(
          _blockAnchor().resource,
          includeDeleted: true,
        ),
        [deleted],
      );
      expect(await repository.auditIntegrity(), isEmpty);
    },
  );

  test('integrity audit reports a privacy-safe orphan annotation', () async {
    final orphan = ResourceAnnotation(
      id: 'annotation.orphan.private',
      anchorId: 'anchor.missing.private',
      kind: ResourceAnnotationKind.comment,
      color: ResourceArtifactColor.gold,
      locale: ContentLocale.en,
      body: 'This private content must not enter an integrity message.',
      state: ResourceAnnotationState.active,
      revision: 1,
      createdAt: clock.nowUtc(),
      updatedAt: clock.nowUtc(),
      stateChangedAt: clock.nowUtc(),
    );
    await records.put(
      PrivateLearnerRecordDraft(
        namespace: IndexedResourceWorkspaceRepository.annotationNamespace,
        recordId: orphan.id,
        scopeId: 'resource.private.orphan',
        kind: 'comment',
        updatedAt: orphan.updatedAt,
        payload: orphan.toJson(),
      ),
      expectedRevision: null,
    );
    final repository = _repository(records, clock, const ['unused.001']);

    final issues = await repository.auditIntegrity();
    expect(issues, hasLength(1));
    expect(issues.single.code, 'resource_annotation_anchor_missing');
    expect(issues.single.message, isNot(contains(orphan.body!)));
    expect(issues.single.recordId, isNull);
  });

  test(
    'resource projections do not truncate after 500 private artifacts',
    () async {
      final repository = _repository(records, clock, const ['unused.001']);
      final anchor = await repository.registerAnchor(_blockAnchor());
      final mutations = List.generate(503, (index) {
        final timestamp = clock.nowUtc().add(Duration(microseconds: index));
        final annotation = ResourceAnnotation(
          id: 'annotation.bulk.${index.toString().padLeft(3, '0')}',
          anchorId: anchor.stableId,
          kind: ResourceAnnotationKind.comment,
          color: ResourceArtifactColor.cyan,
          locale: ContentLocale.en,
          body: 'Private bulk note $index',
          state: ResourceAnnotationState.active,
          revision: 1,
          createdAt: timestamp,
          updatedAt: timestamp,
          stateChangedAt: timestamp,
        );
        return PrivateLearnerRecordMutation(
          draft: PrivateLearnerRecordDraft(
            namespace: IndexedResourceWorkspaceRepository.annotationNamespace,
            recordId: annotation.id,
            scopeId: anchor.resource.stableId,
            kind: 'comment',
            updatedAt: timestamp,
            payload: annotation.toJson(),
          ),
          expectedRevision: null,
        );
      });
      await records.putBatch(mutations.take(500));
      await records.putBatch(mutations.skip(500));

      final annotations = await repository.listAnnotationsForResource(
        anchor.resource,
      );
      expect(annotations, hasLength(503));
      expect(annotations.map((value) => value.id).toSet(), hasLength(503));
      expect(annotations.first.id, 'annotation.bulk.502');
      expect(annotations.last.id, 'annotation.bulk.000');
    },
  );
}

IndexedResourceWorkspaceRepository _repository(
  EncryptedIndexedLearnerRecordStore records,
  MutableClock clock,
  Iterable<String> ids,
) => IndexedResourceWorkspaceRepository(
  records: records,
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

CurriculumBlockResourceAnchor _blockAnchor() => CurriculumBlockResourceAnchor(
  resource: ResourceReference.curriculumStudyDocument(
    sourceId: 'source.harrison-sim',
    documentId: 'study.document.001',
  ),
  blockId: 'study.block.002',
  blockOrdinal: 2,
  localizationUnitId: 'l10n.study.body.002',
);

LearnerDataKey _key(int seed) => LearnerDataKey(
  version: 1,
  bytes: Uint8List.fromList(
    List<int>.generate(32, (index) => (seed + index * 17) & 0xff),
  ),
);

final class _MemoryKeyProvider implements LearnerDataKeyProvider {
  _MemoryKeyProvider(this.key);

  LearnerDataKey key;

  @override
  Future<LearnerDataKey> currentKey() async => key;

  @override
  Future<LearnerDataKey?> readKey(int version) async =>
      version == key.version ? key : null;
}

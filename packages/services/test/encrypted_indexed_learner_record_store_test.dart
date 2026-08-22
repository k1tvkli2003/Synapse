import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:synapse_services/synapse_services.dart';
import 'package:test/test.dart';

void main() {
  late LearnerDataPlaneDatabase database;
  late _MemoryKeyProvider keys;
  late EncryptedIndexedLearnerRecordStore store;

  setUp(() {
    database = LearnerDataPlaneDatabase(NativeDatabase.memory());
    keys = _MemoryKeyProvider(_key(7));
    store = EncryptedIndexedLearnerRecordStore(database: database, keys: keys);
  });

  tearDown(() => database.close());

  test(
    'encrypts clear identifiers and payload while preserving indexes',
    () async {
      final first = await store.put(
        _draft(
          id: 'annotation.private.001',
          scope: 'document.private.heart',
          updatedAt: DateTime.utc(2026, 7, 22, 19),
          body: 'Private synthesis alpha',
        ),
        expectedRevision: null,
      );
      await store.put(
        _draft(
          id: 'annotation.private.002',
          scope: 'document.private.other',
          updatedAt: DateTime.utc(2026, 7, 22, 20),
          body: 'Private synthesis beta',
        ),
        expectedRevision: null,
      );

      expect(first.revision, 1);
      final restored = await store.read(
        namespace: 'resource.annotation',
        recordId: first.recordId,
      );
      expect(restored?.payload['body'], 'Private synthesis alpha');
      final scoped = await store.query(
        const PrivateLearnerRecordQuery(
          namespace: 'resource.annotation',
          scopeId: 'document.private.heart',
          kind: 'comment',
        ),
      );
      expect(scoped.map((value) => value.recordId), ['annotation.private.001']);

      final rows = await database
          .select(database.encryptedLearnerRecords)
          .get();
      final serializedRows = rows.join('\n');
      expect(serializedRows, isNot(contains('annotation.private.001')));
      expect(serializedRows, isNot(contains('document.private.heart')));
      expect(serializedRows, isNot(contains('Private synthesis alpha')));
      expect(rows.first.recordIdHash, hasLength(64));
      expect(rows.first.scopeHash, hasLength(64));
      expect(rows.first.nonce, hasLength(12));
      expect(rows.first.authenticationMac, hasLength(16));

      final indexes = await database
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' ORDER BY name",
          )
          .get();
      expect(
        indexes.map((row) => row.read<String>('name')),
        containsAll([
          'encrypted_learner_records_kind_idx',
          'encrypted_learner_records_scope_idx',
        ]),
      );
    },
  );

  test('supports restart, exact retry, CAS updates, and tombstones', () async {
    final initialDraft = _draft(
      id: 'bookmark.page.001',
      scope: 'document.private.heart',
      updatedAt: DateTime.utc(2026, 7, 22, 19),
      body: 'Page 12',
    );
    final first = await store.put(initialDraft, expectedRevision: null);
    final retry = await store.put(
      PrivateLearnerRecordDraft(
        namespace: initialDraft.namespace,
        recordId: initialDraft.recordId,
        scopeId: initialDraft.scopeId,
        kind: initialDraft.kind,
        updatedAt: DateTime.utc(2026, 7, 22, 23),
        payload: initialDraft.payload,
      ),
      expectedRevision: 999,
    );
    expect(retry.revision, first.revision);
    expect(retry.updatedAt, first.updatedAt);

    await expectLater(
      store.put(
        _draft(
          id: initialDraft.recordId,
          scope: initialDraft.scopeId,
          updatedAt: DateTime.utc(2026, 7, 22, 20),
          body: 'Changed body',
        ),
        expectedRevision: 9,
      ),
      throwsA(
        isA<LearnerDataPlaneException>().having(
          (error) => error.code,
          'code',
          'stale_learner_record_revision',
        ),
      ),
    );

    final changed = await store.put(
      _draft(
        id: initialDraft.recordId,
        scope: initialDraft.scopeId,
        updatedAt: DateTime.utc(2026, 7, 22, 20),
        body: 'Changed body',
      ),
      expectedRevision: 1,
    );
    final deleted = await store.put(
      PrivateLearnerRecordDraft(
        namespace: changed.namespace,
        recordId: changed.recordId,
        scopeId: changed.scopeId,
        kind: changed.kind,
        updatedAt: DateTime.utc(2026, 7, 22, 21),
        payload: changed.payload,
        tombstone: true,
      ),
      expectedRevision: 2,
    );
    expect(deleted.revision, 3);
    expect(
      await store.query(
        const PrivateLearnerRecordQuery(
          namespace: 'resource.annotation',
          scopeId: 'document.private.heart',
        ),
      ),
      isEmpty,
    );
    expect(
      await store.query(
        const PrivateLearnerRecordQuery(
          namespace: 'resource.annotation',
          scopeId: 'document.private.heart',
          includeTombstones: true,
        ),
      ),
      hasLength(1),
    );

    final restarted = EncryptedIndexedLearnerRecordStore(
      database: database,
      keys: keys,
    );
    expect(
      (await restarted.read(
        namespace: deleted.namespace,
        recordId: deleted.recordId,
      ))?.revision,
      3,
    );
  });

  test(
    'authenticated read and audit detect same-size ciphertext tampering',
    () async {
      final saved = await store.put(
        _draft(
          id: 'ink.stroke.001',
          scope: 'document.private.heart',
          updatedAt: DateTime.utc(2026, 7, 22, 19),
          body: 'Synthetic ink payload',
        ),
        expectedRevision: null,
      );
      final row = await database
          .select(database.encryptedLearnerRecords)
          .getSingle();
      final tampered = Uint8List.fromList(row.cipherText);
      tampered[tampered.length ~/ 2] ^= 0x01;
      await database
          .update(database.encryptedLearnerRecords)
          .replace(row.copyWith(cipherText: tampered));

      await expectLater(
        store.read(namespace: saved.namespace, recordId: saved.recordId),
        throwsA(
          isA<LearnerDataPlaneException>()
              .having(
                (error) => error.code,
                'code',
                'encrypted_learner_record_invalid',
              )
              .having(
                (error) => error.toString(),
                'privacy-safe error',
                isNot(contains(saved.recordId)),
              ),
        ),
      );
      final issues = await store.auditIntegrity();
      expect(issues, hasLength(1));
      expect(issues.single.namespace, 'resource.annotation');
      expect(issues.single.recordIdHash, hasLength(64));
      expect(issues.single.message, isNot(contains(saved.recordId)));
    },
  );

  test(
    'multi-record batches are atomic when one CAS precondition fails',
    () async {
      final existing = await store.put(
        _draft(
          id: 'anchor.001',
          scope: 'document.private.heart',
          updatedAt: DateTime.utc(2026, 7, 22, 19),
          body: 'Existing anchor',
        ),
        expectedRevision: null,
      );
      final newArtifact = _draft(
        id: 'annotation.batch.001',
        scope: 'document.private.heart',
        updatedAt: DateTime.utc(2026, 7, 22, 20),
        body: 'Atomic annotation',
      );
      final changedExisting = _draft(
        id: existing.recordId,
        scope: existing.scopeId,
        updatedAt: DateTime.utc(2026, 7, 22, 20),
        body: 'Changed anchor',
      );

      await expectLater(
        store.putBatch([
          PrivateLearnerRecordMutation(
            draft: newArtifact,
            expectedRevision: null,
          ),
          PrivateLearnerRecordMutation(
            draft: changedExisting,
            expectedRevision: 99,
          ),
        ]),
        throwsA(
          isA<LearnerDataPlaneException>().having(
            (error) => error.code,
            'code',
            'stale_learner_record_revision',
          ),
        ),
      );
      expect(
        await store.read(
          namespace: newArtifact.namespace,
          recordId: newArtifact.recordId,
        ),
        isNull,
      );

      final committed = await store.putBatch([
        PrivateLearnerRecordMutation(
          draft: newArtifact,
          expectedRevision: null,
        ),
        PrivateLearnerRecordMutation(
          draft: changedExisting,
          expectedRevision: 1,
        ),
      ]);
      expect(committed.map((value) => value.revision), [1, 2]);
    },
  );

  test(
    'exports decrypted namespace records and physically deletes only it',
    () async {
      await store.put(
        _draft(
          id: 'note.001',
          scope: 'lesson.001',
          updatedAt: DateTime.utc(2026, 7, 22, 19),
          body: 'First private note',
        ),
        expectedRevision: null,
      );
      await store.put(
        _draft(
          id: 'note.002',
          scope: 'lesson.002',
          updatedAt: DateTime.utc(2026, 7, 22, 20),
          body: 'Second private note',
        ),
        expectedRevision: null,
      );
      await store.put(
        PrivateLearnerRecordDraft(
          namespace: 'resource.reading-position',
          recordId: 'position.001',
          scopeId: 'document.private.heart',
          kind: 'page-position',
          updatedAt: DateTime.utc(2026, 7, 22, 21),
          payload: const {'page': 12},
        ),
        expectedRevision: null,
      );

      final exported = await store.exportNamespace('resource.annotation');
      expect(exported.map((value) => value.recordId), ['note.001', 'note.002']);
      expect(await store.deleteNamespace('resource.annotation'), 2);
      expect(await store.exportNamespace('resource.annotation'), isEmpty);
      expect(
        await store.exportNamespace('resource.reading-position'),
        hasLength(1),
      );
    },
  );

  test(
    'keyset pages return every tied record once beyond the 500 cap',
    () async {
      final timestamp = DateTime.utc(2026, 7, 22, 23);
      final drafts = List.generate(
        503,
        (index) => PrivateLearnerRecordMutation(
          draft: _draft(
            id: 'annotation.page.${index.toString().padLeft(3, '0')}',
            scope: 'document.private.paged',
            updatedAt: timestamp,
            body: 'Paged private body $index',
          ),
          expectedRevision: null,
        ),
      );
      await store.putBatch(drafts.take(500));
      await store.putBatch(drafts.skip(500));

      final values = <PrivateLearnerRecord>[];
      final cursors = <String>{};
      String? cursor;
      do {
        final page = await store.queryPage(
          PrivateLearnerRecordQuery(
            namespace: 'resource.annotation',
            scopeId: 'document.private.paged',
            limit: 137,
            cursor: cursor,
          ),
        );
        values.addAll(page.records);
        cursor = page.nextCursor;
        if (cursor != null) expect(cursors.add(cursor), isTrue);
      } while (cursor != null);

      expect(values, hasLength(503));
      expect(values.map((value) => value.recordId).toSet(), hasLength(503));
      await expectLater(
        store.queryPage(
          const PrivateLearnerRecordQuery(
            namespace: 'resource.annotation',
            cursor: 'not-a-valid-private-cursor',
          ),
        ),
        throwsA(
          isA<LearnerDataPlaneException>().having(
            (error) => error.code,
            'code',
            'invalid_learner_record_query_cursor',
          ),
        ),
      );
    },
  );
}

PrivateLearnerRecordDraft _draft({
  required String id,
  required String scope,
  required DateTime updatedAt,
  required String body,
}) => PrivateLearnerRecordDraft(
  namespace: 'resource.annotation',
  recordId: id,
  scopeId: scope,
  kind: 'comment',
  updatedAt: updatedAt,
  payload: {
    'body': body,
    'tags': const ['review'],
  },
);

LearnerDataKey _key(int seed) => LearnerDataKey(
  version: 1,
  bytes: List<int>.generate(32, (index) => (seed + index * 17) & 0xff),
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

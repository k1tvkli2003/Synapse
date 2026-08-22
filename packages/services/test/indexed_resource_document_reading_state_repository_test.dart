import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_foundation/synapse_foundation.dart';
import 'package:synapse_services/synapse_services.dart';
import 'package:test/test.dart';

const _digest =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

void main() {
  late LearnerDataPlaneDatabase database;
  late _MemoryKeyProvider keys;
  late EncryptedIndexedLearnerRecordStore records;
  late MutableClock clock;
  late ResourceDocument document;

  setUp(() {
    database = LearnerDataPlaneDatabase(NativeDatabase.memory());
    keys = _MemoryKeyProvider(_key(41));
    records = EncryptedIndexedLearnerRecordStore(
      database: database,
      keys: keys,
    );
    clock = MutableClock(DateTime.utc(2026, 7, 22, 12));
    document = ResourceDocument(
      id: 'document.private.pdf.001',
      displayName: 'Private cardiology reference.pdf',
      mediaType: 'application/pdf',
      contentSha256: _digest,
      byteLength: 4096,
      pageCount: 120,
      origin: ResourceDocumentOrigin.userImport,
      createdAt: clock.nowUtc(),
    );
  });

  tearDown(() => database.close());

  test('restores an encrypted reward-neutral position after restart', () async {
    final first = _repository(records, clock);
    final saved = await first.savePosition(
      document: document,
      pageNumber: 34,
      pagePositionMillionths: 250000,
      expectedRevision: null,
    );
    final restarted = _repository(records, clock);

    expect(await restarted.read(document.id), saved);
    expect(await restarted.listRecent(), [saved]);
    final rows = await database.select(database.encryptedLearnerRecords).get();
    final serialized = rows.join('\n');
    expect(serialized, isNot(contains(document.id)));
    expect(serialized, isNot(contains(document.contentSha256)));
    expect(serialized, isNot(contains('pageNumber')));
    expect(serialized.toLowerCase(), isNot(contains('mastery')));
    expect(serialized.toLowerCase(), isNot(contains('xp')));
  });

  test('enforces domain CAS while preserving idempotent saves', () async {
    final repository = _repository(records, clock);
    final first = await repository.savePosition(
      document: document,
      pageNumber: 4,
      pagePositionMillionths: 0,
      expectedRevision: null,
    );
    final same = await repository.savePosition(
      document: document,
      pageNumber: 4,
      pagePositionMillionths: 0,
      expectedRevision: 999,
    );
    expect(same, first);

    clock.advance(const Duration(minutes: 1));
    final second = await repository.savePosition(
      document: document,
      pageNumber: 5,
      pagePositionMillionths: 500000,
      expectedRevision: first.revision,
    );
    expect(second.revision, 2);
    await expectLater(
      repository.savePosition(
        document: document,
        pageNumber: 6,
        pagePositionMillionths: 0,
        expectedRevision: first.revision,
      ),
      throwsA(
        isA<ResourceDocumentReadingStateException>().having(
          (error) => error.code,
          'code',
          'stale_document_reading_position_revision',
        ),
      ),
    );
  });

  test(
    'clear writes a tombstone and a later save cannot be stale-resurrected',
    () async {
      final repository = _repository(records, clock);
      final saved = await repository.savePosition(
        document: document,
        pageNumber: 8,
        pagePositionMillionths: 0,
        expectedRevision: null,
      );
      expect(
        await repository.clear(
          documentId: document.id,
          expectedRevision: saved.revision,
        ),
        isTrue,
      );
      expect(await repository.read(document.id), isNull);
      expect(await repository.listRecent(), isEmpty);
      final raw = await records.read(
        namespace: IndexedResourceDocumentReadingStateRepository.namespace,
        recordId: saved.id,
      );
      expect(raw?.tombstone, isTrue);
      expect(raw?.revision, 2);
      await expectLater(
        repository.savePosition(
          document: document,
          pageNumber: 9,
          pagePositionMillionths: 0,
          expectedRevision: saved.revision,
        ),
        throwsA(isA<ResourceDocumentReadingStateException>()),
      );

      clock.advance(const Duration(minutes: 1));
      final restored = await repository.savePosition(
        document: document,
        pageNumber: 9,
        pagePositionMillionths: 0,
        expectedRevision: null,
      );
      expect(restored.revision, 1);
      expect(
        (await records.read(
          namespace: raw!.namespace,
          recordId: raw.recordId,
        ))?.revision,
        3,
      );
    },
  );

  test(
    'audit reports malformed records without echoing private payload',
    () async {
      await records.put(
        PrivateLearnerRecordDraft(
          namespace: IndexedResourceDocumentReadingStateRepository.namespace,
          recordId: 'reading-position.malformed.private',
          scopeId: document.id,
          kind: IndexedResourceDocumentReadingStateRepository.kind,
          updatedAt: clock.nowUtc(),
          payload: const {'privateBody': 'Never leak this learner text'},
        ),
        expectedRevision: null,
      );
      final issues = await _repository(records, clock).auditIntegrity();
      expect(issues, hasLength(1));
      expect(issues.single.code, 'corrupt_indexed_document_reading_state');
      expect(issues.single.message, isNot(contains('Never leak')));
    },
  );
}

IndexedResourceDocumentReadingStateRepository _repository(
  EncryptedIndexedLearnerRecordStore records,
  MutableClock clock,
) => IndexedResourceDocumentReadingStateRepository(
  records: records,
  clock: clock,
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

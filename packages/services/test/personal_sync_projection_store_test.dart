import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_services/synapse_services.dart';
import 'package:test/test.dart';

void main() {
  late LearnerDataPlaneDatabase database;
  late EncryptedIndexedLearnerRecordStore records;
  late PersonalSyncEnvelopeCipher cipher;
  late PersonalSyncProjectionStore projections;

  setUp(() {
    database = LearnerDataPlaneDatabase(NativeDatabase.memory());
    records = EncryptedIndexedLearnerRecordStore(
      database: database,
      keys: _LearnerKeys(),
    );
    cipher = PersonalSyncEnvelopeCipher(keys: _WorkspaceKeys());
    projections = PersonalSyncProjectionStore(records: records);
  });

  tearDown(() => database.close());

  test(
    'append-only events are exactly-once and reject substituted IDs',
    () async {
      final first = await _event(
        cipher,
        id: 'evt_attempt_001',
        idempotencyKey: 'idem_attempt_001',
        entityId: 'attempt.respiratory.001',
        kind: PersonalSyncEventKind.attempt,
        mergePolicy: PersonalSyncMergePolicy.appendOnly,
        payload: const {'score': 8, 'interactionCount': 10},
      );
      await projections.apply(first);
      await projections.apply(first);

      expect(
        await records.query(
          const PrivateLearnerRecordQuery(
            namespace: PersonalSyncProjectionStore.ledgerNamespace,
            limit: 20,
          ),
        ),
        hasLength(1),
      );

      final substituted = await _event(
        cipher,
        id: 'evt_attempt_001',
        idempotencyKey: 'idem_attempt_001',
        entityId: 'attempt.respiratory.001',
        kind: PersonalSyncEventKind.attempt,
        mergePolicy: PersonalSyncMergePolicy.appendOnly,
        payload: const {'score': 9, 'interactionCount': 10},
      );
      await expectLater(
        projections.apply(substituted),
        throwsA(
          isA<PersonalSyncProjectionException>().having(
            (error) => error.code,
            'code',
            'sync_append_event_conflict',
          ),
        ),
      );
    },
  );

  test(
    'monotonic progress keeps maxima even with skewed device clocks',
    () async {
      final laterClock = await _event(
        cipher,
        id: 'evt_progress_android',
        idempotencyKey: 'idem_progress_android',
        entityId: 'progress.kidney.001',
        kind: PersonalSyncEventKind.progress,
        mergePolicy: PersonalSyncMergePolicy.monotonicMaximum,
        logicalRevision: 1,
        deviceId: 'dev_android',
        createdAt: DateTime.utc(2026, 7, 27, 13),
        payload: const {
          'completedInteractions': 7,
          'mastery': {'correct': 4, 'speed': 2},
        },
      );
      final skewedClock = await _event(
        cipher,
        id: 'evt_progress_windows',
        idempotencyKey: 'idem_progress_windows',
        entityId: 'progress.kidney.001',
        kind: PersonalSyncEventKind.progress,
        mergePolicy: PersonalSyncMergePolicy.monotonicMaximum,
        logicalRevision: 2,
        deviceId: 'dev_windows',
        createdAt: DateTime.utc(2026, 7, 27, 12),
        payload: const {
          'completedInteractions': 5,
          'mastery': {'correct': 9, 'speed': 1},
        },
      );

      await projections.apply(laterClock);
      await projections.apply(skewedClock);

      final snapshot = await projections.readProjection(
        stream: 'academy.progress',
        entityId: 'progress.kidney.001',
      );
      expect(snapshot, isNotNull);
      expect(snapshot!.logicalRevision, 2);
      expect(snapshot.payload['completedInteractions'], 7);
      expect(snapshot.payload['mastery'], {'correct': 9, 'speed': 2});
    },
  );

  test('tombstone wins over a delayed higher-revision resurrection', () async {
    final created = await _event(
      cipher,
      id: 'evt_note_create',
      idempotencyKey: 'idem_note_create',
      entityId: 'note.oncology.001',
      kind: PersonalSyncEventKind.note,
      mergePolicy: PersonalSyncMergePolicy.tombstoneWins,
      logicalRevision: 1,
      payload: const {'body': 'Follow the leukocyte pattern.'},
    );
    final deleted = await _event(
      cipher,
      id: 'evt_note_delete',
      idempotencyKey: 'idem_note_delete',
      entityId: 'note.oncology.001',
      kind: PersonalSyncEventKind.note,
      mergePolicy: PersonalSyncMergePolicy.tombstoneWins,
      logicalRevision: 2,
      tombstone: true,
      payload: const {'reason': 'user-delete'},
    );
    final delayedUpdate = await _event(
      cipher,
      id: 'evt_note_delayed',
      idempotencyKey: 'idem_note_delayed',
      entityId: 'note.oncology.001',
      kind: PersonalSyncEventKind.note,
      mergePolicy: PersonalSyncMergePolicy.tombstoneWins,
      logicalRevision: 99,
      payload: const {'body': 'This must not resurrect the deleted note.'},
    );

    await projections.apply(created);
    await projections.apply(deleted);
    await projections.apply(delayedUpdate);

    final snapshot = await projections.readProjection(
      stream: 'academy.note',
      entityId: 'note.oncology.001',
    );
    expect(snapshot, isNotNull);
    expect(snapshot!.tombstone, isTrue);
    expect(snapshot.eventId, 'evt_note_delete');
  });
}

Future<DecryptedPersonalSyncEvent> _event(
  PersonalSyncEnvelopeCipher cipher, {
  required String id,
  required String idempotencyKey,
  required String entityId,
  required PersonalSyncEventKind kind,
  required PersonalSyncMergePolicy mergePolicy,
  required Map<String, Object?> payload,
  int logicalRevision = 1,
  String deviceId = 'dev_windows',
  DateTime? createdAt,
  bool tombstone = false,
}) async {
  final encrypted = await cipher.encrypt(
    PersonalSyncClearEvent(
      id: id,
      workspaceId: 'wrk_personal',
      deviceId: deviceId,
      stream: 'academy.${kind.name}',
      entityId: entityId,
      kind: kind,
      mergePolicy: mergePolicy,
      logicalRevision: logicalRevision,
      idempotencyKey: idempotencyKey,
      clientCreatedAt: createdAt ?? DateTime.utc(2026, 7, 27, 10),
      payload: payload,
      tombstone: tombstone,
    ),
  );
  return cipher.decrypt(encrypted);
}

final class _LearnerKeys implements LearnerDataKeyProvider {
  final _key = LearnerDataKey(
    version: 1,
    bytes: Uint8List.fromList(
      List<int>.generate(32, (index) => (index * 17 + 5) & 0xff),
    ),
  );

  @override
  Future<LearnerDataKey> currentKey() async => _key;

  @override
  Future<LearnerDataKey?> readKey(int version) async =>
      version == _key.version ? _key : null;
}

final class _WorkspaceKeys implements WorkspaceSyncKeyProvider {
  final _key = WorkspaceSyncKey(
    version: 1,
    bytes: Uint8List.fromList(
      List<int>.generate(32, (index) => (index * 19 + 7) & 0xff),
    ),
  );

  @override
  Future<WorkspaceSyncKey> currentKey() async => _key;

  @override
  Future<WorkspaceSyncKey?> readKey(int version) async =>
      version == _key.version ? _key : null;
}

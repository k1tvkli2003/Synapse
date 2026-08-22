import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_foundation/synapse_foundation.dart';
import 'package:synapse_services/synapse_services.dart';
import 'package:test/test.dart';

void main() {
  late LearnerDataPlaneDatabase database;
  late EncryptedIndexedLearnerRecordStore records;
  late PersonalSyncOutboxRepository outbox;
  late PersonalSyncEnvelopeCipher cipher;
  late LocalCurriculumSessionProgressRepository progress;
  late PersonalSyncCurriculumReconciler reconciler;

  setUp(() {
    database = LearnerDataPlaneDatabase(NativeDatabase.memory());
    records = EncryptedIndexedLearnerRecordStore(
      database: database,
      keys: _LearnerKeys(),
    );
    outbox = PersonalSyncOutboxRepository(
      records: records,
      clock: _FixedClock(DateTime.utc(2026, 7, 27, 12)),
    );
    cipher = PersonalSyncEnvelopeCipher(keys: _WorkspaceKeys());
    progress = LocalCurriculumSessionProgressRepository(
      store: MemoryKeyValueStore(),
      clock: _FixedClock(DateTime.utc(2026, 7, 27, 12)),
      idSource: SequenceIdSource(const ['unused.001']),
    );
    reconciler = PersonalSyncCurriculumReconciler(
      projections: PersonalSyncProjectionStore(records: records),
      records: records,
      progress: progress,
    );
  });

  tearDown(() => database.close());

  test(
    'hydrates a completed Session from reordered encrypted events and replays exactly once',
    () async {
      final journal = PersonalSyncCurriculumJournal(
        currentContext: () async => _context(),
        cipher: cipher,
        outbox: outbox,
      );
      final source = _completedProgress();
      await journal.recordCheckpoint(source);
      final pending = await outbox.pending(limit: 10);
      final decrypted = await Future.wait(pending.map(cipher.decrypt));
      final attempt = decrypted.singleWhere(
        (event) => event.envelope.kind == PersonalSyncEventKind.attempt,
      );
      final history = decrypted.singleWhere(
        (event) => event.envelope.kind == PersonalSyncEventKind.studyHistory,
      );
      final checkpoint = decrypted.singleWhere(
        (event) => event.envelope.kind == PersonalSyncEventKind.progress,
      );

      // A remote page may arrive in any valid transport order. Progress first
      // creates a safe minimal resume checkpoint; later ledger events enrich
      // it without changing its completion receipt or fabricating rewards.
      await reconciler.apply(checkpoint);
      await reconciler.apply(history);
      await reconciler.apply(attempt);

      final hydrated = await progress.read(source.key);
      expect(hydrated, isNotNull);
      expect(hydrated!.isCompleted, isTrue);
      expect(hydrated.interactionIndex, 3);
      expect(hydrated.completionReceiptId, 'completion_001');
      expect(hydrated.responseFor('interaction_001')?.id, 'response_001');
      expect(
        hydrated.responseFor('interaction_001')?.selectedOptionId,
        'option_001',
      );

      await reconciler.apply(attempt);
      await reconciler.apply(history);
      await reconciler.apply(checkpoint);
      expect(await progress.read(source.key), hydrated);
      expect(
        await records.query(
          const PrivateLearnerRecordQuery(
            namespace: PersonalSyncProjectionStore.ledgerNamespace,
            limit: 10,
          ),
        ),
        hasLength(2),
      );
    },
  );

  test(
    'rejects an attempt that is missing its stable response receipt',
    () async {
      final event = await cipher.encrypt(
        PersonalSyncClearEvent(
          id: 'evt_invalid_attempt',
          workspaceId: 'wrk_personal',
          deviceId: 'dev_windows',
          stream: 'academy.attempt',
          entityId: 'attempt:response_001',
          kind: PersonalSyncEventKind.attempt,
          mergePolicy: PersonalSyncMergePolicy.appendOnly,
          logicalRevision: 1,
          idempotencyKey: 'idem_invalid_attempt',
          clientCreatedAt: DateTime.utc(2026, 7, 27, 12),
          payload: {
            'releaseId': 'rel_001',
            'microLessonNodeId': 'node_001',
            'sessionId': 'session_001',
            'interactionId': 'interaction_001',
            'selectedOptionId': 'option_001',
            'isCorrect': true,
            'answeredAt': DateTime.utc(2026, 7, 27, 12).toIso8601String(),
          },
        ),
      );

      await expectLater(
        reconciler.apply(await cipher.decrypt(event)),
        throwsA(
          isA<PersonalSyncCurriculumReconcilerException>().having(
            (error) => error.code,
            'code',
            'invalid_academy_sync_field',
          ),
        ),
      );
    },
  );
}

CurriculumSessionProgress _completedProgress() {
  final startedAt = DateTime.utc(2026, 7, 27, 10);
  return CurriculumSessionProgress(
    key: CurriculumSessionProgressKey(
      releaseId: 'rel_001',
      microLessonNodeId: 'node_001',
      sessionId: 'session_001',
    ),
    phase: CurriculumSessionProgressPhase.completed,
    interactionIndex: 3,
    revision: 5,
    startedAt: startedAt,
    updatedAt: startedAt.add(const Duration(minutes: 8)),
    choiceResponses: {
      'interaction_001': CurriculumChoiceResponse(
        id: 'response_001',
        interactionId: 'interaction_001',
        selectedOptionId: 'option_001',
        isCorrect: true,
        answeredAt: startedAt.add(const Duration(minutes: 3)),
      ),
    },
    completedAt: startedAt.add(const Duration(minutes: 8)),
    completionReceiptId: 'completion_001',
  );
}

PersonalSyncDeviceContext _context() {
  final key = base64Url
      .encode(Uint8List.fromList(List<int>.filled(32, 8)))
      .replaceAll('=', '');
  final workspace = PersonalWorkspace(
    id: 'wrk_personal',
    keyVersion: 1,
    recoveryGeneration: 1,
    createdAt: DateTime.utc(2026, 7, 27),
  );
  return PersonalSyncDeviceContext(
    workspace: workspace,
    device: TrustedDevice(
      id: 'dev_windows',
      workspaceId: workspace.id,
      label: 'Windows',
      platform: PersonalDevicePlatform.windows,
      role: DeviceTrustRole.root,
      signingPublicKey: key,
      encryptionPublicKey: key,
      createdAt: workspace.createdAt,
      lastSeenAt: workspace.createdAt,
    ),
  );
}

final class _FixedClock implements Clock {
  const _FixedClock(this.value);

  final DateTime value;

  @override
  DateTime nowUtc() => value;
}

final class _LearnerKeys implements LearnerDataKeyProvider {
  final _key = LearnerDataKey(
    version: 1,
    bytes: Uint8List.fromList(
      List<int>.generate(32, (index) => (index * 13 + 5) & 0xff),
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
      List<int>.generate(32, (index) => (index * 29 + 7) & 0xff),
    ),
  );

  @override
  Future<WorkspaceSyncKey> currentKey() async => _key;

  @override
  Future<WorkspaceSyncKey?> readKey(int version) async =>
      version == _key.version ? _key : null;
}

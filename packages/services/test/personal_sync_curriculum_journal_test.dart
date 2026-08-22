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
  });

  tearDown(() => database.close());

  test('checkpoint journal is local-only while unpaired', () async {
    final journal = PersonalSyncCurriculumJournal(
      currentContext: () async => null,
      cipher: cipher,
      outbox: outbox,
    );

    expect(await journal.recordCheckpoint(_inProgress()), isNull);
    expect(await outbox.pending(), isEmpty);
  });

  test(
    'journals opaque attempts, history and monotonic progress exactly once',
    () async {
      final journal = PersonalSyncCurriculumJournal(
        currentContext: () async => _context('dev_windows'),
        cipher: cipher,
        outbox: outbox,
      );
      final progress = _completed();

      final first = await journal.recordCheckpoint(progress);
      final second = await journal.recordCheckpoint(progress);
      final pending = await outbox.pending(limit: 20);

      expect(first, isNotNull);
      expect(second!.progressEventId, first!.progressEventId);
      expect(first.attemptEventCount, 1);
      expect(first.historyEventCount, 1);
      expect(pending, hasLength(3));

      final clear = await Future.wait(pending.map(cipher.decrypt));
      final progressEvent = clear.singleWhere(
        (event) => event.envelope.kind == PersonalSyncEventKind.progress,
      );
      expect(progressEvent.payload['interactionIndex'], 3);
      expect(progressEvent.payload.containsKey('selectedOptionId'), isFalse);
      expect(progressEvent.payload.containsKey('choiceResponses'), isFalse);
      expect(
        progressEvent.envelope.mergePolicy,
        PersonalSyncMergePolicy.monotonicMaximum,
      );
      expect(
        clear.where(
          (event) => event.envelope.kind == PersonalSyncEventKind.attempt,
        ),
        hasLength(1),
      );
      final attemptEvent = clear.singleWhere(
        (event) => event.envelope.kind == PersonalSyncEventKind.attempt,
      );
      expect(attemptEvent.payload['responseId'], 'response_001');
      expect(
        clear.where(
          (event) => event.envelope.kind == PersonalSyncEventKind.studyHistory,
        ),
        hasLength(1),
      );
    },
  );

  test(
    'concurrent devices use distinct progress idempotency identities',
    () async {
      final progress = _inProgress();
      final windows = PersonalSyncCurriculumJournal(
        currentContext: () async => _context('dev_windows'),
        cipher: cipher,
        outbox: outbox,
      );
      final android = PersonalSyncCurriculumJournal(
        currentContext: () async => _context('dev_android'),
        cipher: cipher,
        outbox: outbox,
      );

      final a = await windows.recordCheckpoint(progress);
      final b = await android.recordCheckpoint(progress);

      expect(a, isNotNull);
      expect(b, isNotNull);
      expect(a!.progressEventId, isNot(b!.progressEventId));
      expect(await outbox.pending(), hasLength(2));
    },
  );
}

CurriculumSessionProgress _inProgress() {
  final at = DateTime.utc(2026, 7, 27, 10);
  return CurriculumSessionProgress(
    key: CurriculumSessionProgressKey(
      releaseId: 'rel_001',
      microLessonNodeId: 'node_001',
      sessionId: 'session_001',
    ),
    phase: CurriculumSessionProgressPhase.inProgress,
    interactionIndex: 1,
    revision: 2,
    startedAt: at,
    updatedAt: at.add(const Duration(minutes: 2)),
    selectedOptionId: 'option_002',
  );
}

CurriculumSessionProgress _completed() {
  final at = DateTime.utc(2026, 7, 27, 10);
  final key = CurriculumSessionProgressKey(
    releaseId: 'rel_001',
    microLessonNodeId: 'node_001',
    sessionId: 'session_001',
  );
  return CurriculumSessionProgress(
    key: key,
    phase: CurriculumSessionProgressPhase.completed,
    interactionIndex: 3,
    revision: 5,
    startedAt: at,
    updatedAt: at.add(const Duration(minutes: 8)),
    choiceResponses: {
      'interaction_001': CurriculumChoiceResponse(
        id: 'response_001',
        interactionId: 'interaction_001',
        selectedOptionId: 'option_001',
        isCorrect: true,
        answeredAt: at.add(const Duration(minutes: 3)),
      ),
    },
    completedAt: at.add(const Duration(minutes: 8)),
    completionReceiptId: 'completion_001',
  );
}

PersonalSyncDeviceContext _context(String deviceId) {
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
      id: deviceId,
      workspaceId: workspace.id,
      label: deviceId,
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

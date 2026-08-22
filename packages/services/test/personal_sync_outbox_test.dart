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
  late _MemoryWorkspaceKeys workspaceKeys;
  late PersonalSyncEnvelopeCipher cipher;

  setUp(() {
    database = LearnerDataPlaneDatabase(NativeDatabase.memory());
    records = EncryptedIndexedLearnerRecordStore(
      database: database,
      keys: _MemoryLearnerKeys(),
    );
    outbox = PersonalSyncOutboxRepository(
      records: records,
      clock: _FixedClock(DateTime.utc(2026, 7, 26, 12)),
    );
    workspaceKeys = _MemoryWorkspaceKeys();
    cipher = PersonalSyncEnvelopeCipher(keys: workspaceKeys);
  });

  tearDown(() => database.close());

  test('duplicate push and pull remain idempotent', () async {
    final event = await cipher.encrypt(
      PersonalSyncClearEvent(
        id: 'evt_001',
        workspaceId: 'wrk_001',
        deviceId: 'dev_windows',
        stream: 'academy.progress',
        entityId: 'progress.micro.001',
        kind: PersonalSyncEventKind.progress,
        mergePolicy: PersonalSyncMergePolicy.monotonicMaximum,
        logicalRevision: 3,
        idempotencyKey: 'idem_001',
        clientCreatedAt: DateTime.utc(2026, 7, 26, 11),
        payload: const {'completedInteractions': 7},
      ),
    );
    await outbox.enqueue(event);
    await outbox.enqueue(event);
    expect(await outbox.pending(), hasLength(1));

    final remote = EncryptedSyncEvent.fromJson({
      ...event.toJson(),
      'serverSequence': 1,
    });
    final gateway = _MemoryGateway(remote);
    final projections = _ProjectionCollector();
    final coordinator = PersonalSyncCoordinator(
      gateway: gateway,
      outbox: outbox,
      cipher: cipher,
      projections: projections,
    );

    final first = await coordinator.syncOnce(
      accessToken: 'token',
      workspaceId: 'wrk_001',
    );
    final second = await coordinator.syncOnce(
      accessToken: 'token',
      workspaceId: 'wrk_001',
    );

    expect(first.pushed, 1);
    expect(first.pulled, 1);
    expect(second.pushed, 0);
    expect(second.pulled, 0);
    expect(projections.events, hasLength(1));
    expect((await outbox.readCheckpoint('wrk_001'))?.serverSequence, 1);
  });

  test(
    'drains every durable outbox page before pulling remote deltas',
    () async {
      for (var index = 1; index <= 3; index += 1) {
        final event = await cipher.encrypt(
          PersonalSyncClearEvent(
            id: 'evt_batch_00$index',
            workspaceId: 'wrk_001',
            deviceId: 'dev_windows',
            stream: 'academy.progress',
            entityId: 'progress.batch.$index',
            kind: PersonalSyncEventKind.progress,
            mergePolicy: PersonalSyncMergePolicy.monotonicMaximum,
            logicalRevision: index,
            idempotencyKey: 'idem_batch_00$index',
            clientCreatedAt: DateTime.utc(2026, 7, 26, 11, index),
            payload: {'completedInteractions': index},
          ),
        );
        await outbox.enqueue(event);
      }
      final gateway = _MemoryGateway(null);
      final coordinator = PersonalSyncCoordinator(
        gateway: gateway,
        outbox: outbox,
        cipher: cipher,
        projections: _ProjectionCollector(),
      );

      final result = await coordinator.syncOnce(
        accessToken: 'token',
        workspaceId: 'wrk_001',
        batchSize: 1,
      );

      expect(result.pushed, 3);
      expect(gateway.pushBatches, hasLength(3));
      expect(gateway.pushBatches.every((batch) => batch.length == 1), isTrue);
      expect(await outbox.pending(), isEmpty);
    },
  );
}

final class _FixedClock implements Clock {
  const _FixedClock(this.value);

  final DateTime value;

  @override
  DateTime nowUtc() => value;
}

final class _MemoryLearnerKeys implements LearnerDataKeyProvider {
  final key = LearnerDataKey(
    version: 1,
    bytes: List<int>.generate(32, (index) => (index * 9 + 3) & 0xff),
  );

  @override
  Future<LearnerDataKey> currentKey() async => key;

  @override
  Future<LearnerDataKey?> readKey(int version) async =>
      version == key.version ? key : null;
}

final class _MemoryWorkspaceKeys implements WorkspaceSyncKeyProvider {
  final key = WorkspaceSyncKey(
    version: 1,
    bytes: List<int>.generate(32, (index) => (index * 11 + 5) & 0xff),
  );

  @override
  Future<WorkspaceSyncKey> currentKey() async => key;

  @override
  Future<WorkspaceSyncKey?> readKey(int version) async =>
      version == key.version ? key : null;
}

final class _ProjectionCollector implements PersonalSyncProjectionApplier {
  final events = <DecryptedPersonalSyncEvent>[];

  @override
  Future<void> apply(DecryptedPersonalSyncEvent event) async {
    events.add(event);
  }
}

final class _MemoryGateway implements PersonalSyncGateway {
  _MemoryGateway(this.remote);

  final EncryptedSyncEvent? remote;
  final pushBatches = <List<EncryptedSyncEvent>>[];

  @override
  Future<List<EncryptedSyncEvent>> pushEvents({
    required String accessToken,
    required Iterable<EncryptedSyncEvent> events,
  }) async {
    final batch = events.toList(growable: false);
    pushBatches.add(batch);
    return List.unmodifiable(batch);
  }

  @override
  Future<SyncPullPage> pullEvents({
    required String accessToken,
    required int afterSequence,
    int limit = 200,
  }) async {
    final current = remote;
    if (current == null || afterSequence >= 1) {
      return SyncPullPage(events: const [], nextSequence: afterSequence);
    }
    return SyncPullPage(events: [current], nextSequence: 1);
  }

  @override
  Future<PairingSession> approvePairingSession({
    required String accessToken,
    required PairingSessionId sessionId,
    required String pairingCode,
    required String candidateEncryptionPublicKey,
    required String sealedWorkspaceKey,
  }) => throw UnimplementedError();

  @override
  Future<({TrustedDevice device, PersonalWorkspace workspace})> bootstrap({
    required String bootstrapToken,
    required String recoveryVerifierSha256,
    required TrustedDevice device,
  }) => throw UnimplementedError();

  @override
  Future<PairingSession> createPairingSession({
    required TrustedDevice candidate,
  }) => throw UnimplementedError();

  @override
  Future<Uint8List> downloadPackage({
    required String accessToken,
    required ContentPackageId packageId,
  }) => throw UnimplementedError();

  @override
  Future<DeviceTokenResponse> exchangeDeviceToken({
    required TrustedDeviceId deviceId,
    required String nonce,
    required DateTime timestamp,
    required String signature,
    PairingSessionId? pairingSessionId,
    String? pairingCode,
  }) => throw UnimplementedError();

  @override
  Future<ContentManifest?> fetchManifest({
    required String accessToken,
    String? ifNoneMatch,
  }) => throw UnimplementedError();

  @override
  Future<List<TrustedDevice>> listDevices(String accessToken) =>
      throw UnimplementedError();

  @override
  Future<void> revokeDevice({
    required String accessToken,
    required TrustedDeviceId deviceId,
  }) => throw UnimplementedError();

  @override
  Future<({TrustedDevice device, PersonalWorkspace workspace})> rotateRecovery({
    required PersonalWorkspaceId workspaceId,
    required int expectedGeneration,
    required String recoveryVerifierSha256,
    required String newRecoveryVerifierSha256,
    required TrustedDevice newRootDevice,
  }) => throw UnimplementedError();
}

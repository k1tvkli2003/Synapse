import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synapse_app/data/personal_sync/personal_device_sync_service.dart';
import 'package:synapse_app/data/personal_sync/personal_sync_dispatcher.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_foundation/synapse_foundation.dart';
import 'package:synapse_services/synapse_services.dart';

void main() {
  late LearnerDataPlaneDatabase database;
  late EncryptedIndexedLearnerRecordStore records;
  late PersonalSyncOutboxRepository outbox;
  late PersonalSyncEnvelopeCipher cipher;
  late _Gateway gateway;
  late PersonalSyncCoordinator coordinator;

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
    gateway = _Gateway();
    coordinator = PersonalSyncCoordinator(
      gateway: gateway,
      outbox: outbox,
      cipher: cipher,
      projections: _ProjectionCollector(),
    );
  });

  tearDown(() => database.close());

  test(
    'defers safely while offline without requesting a device token',
    () async {
      var tokenRequests = 0;
      final states = <PersonalSyncDispatchState>[];
      final dispatcher = PersonalSyncDispatcher(
        readRuntime: () async => _runtime(),
        ensureAccessToken: () async {
          tokenRequests += 1;
          return 'token_test';
        },
        markSuccessfulSync: (_) async {},
        coordinator: coordinator,
        isOnline: () => false,
        onState: states.add,
      );

      final receipt = await dispatcher.requestSync();

      expect(receipt.kind, PersonalSyncDispatchReceiptKind.deferred);
      expect(receipt.errorCode, 'offline');
      expect(tokenRequests, 0);
      expect(states.last.phase, PersonalSyncDispatchPhase.offline);
      dispatcher.dispose();
    },
  );

  test(
    'drains queued encrypted events and records a successful transport receipt',
    () async {
      await _enqueueProgress(outbox, cipher);
      var tokenRequests = 0;
      DateTime? markedAt;
      final states = <PersonalSyncDispatchState>[];
      final dispatcher = PersonalSyncDispatcher(
        readRuntime: () async => _runtime(),
        ensureAccessToken: () async {
          tokenRequests += 1;
          return 'token_test';
        },
        markSuccessfulSync: (at) async => markedAt = at,
        coordinator: coordinator,
        isOnline: () => true,
        onState: states.add,
        now: () => DateTime.utc(2026, 7, 27, 12, 30),
      );

      final receipt = await dispatcher.requestSync();

      expect(receipt.kind, PersonalSyncDispatchReceiptKind.completed);
      expect(receipt.result?.pushed, 1);
      expect(tokenRequests, 1);
      expect(gateway.pushCalls, 1);
      expect(markedAt, DateTime.utc(2026, 7, 27, 12, 30));
      expect(await outbox.pending(), isEmpty);
      expect(states.last.phase, PersonalSyncDispatchPhase.idle);
      dispatcher.dispose();
    },
  );

  test(
    'retries a transient gateway failure without dropping the durable outbox',
    () async {
      await _enqueueProgress(outbox, cipher);
      gateway.remainingPushFailures = 1;
      var successReceipts = 0;
      final states = <PersonalSyncDispatchState>[];
      final dispatcher = PersonalSyncDispatcher(
        readRuntime: () async => _runtime(),
        ensureAccessToken: () async => 'token_test',
        markSuccessfulSync: (_) async => successReceipts += 1,
        coordinator: coordinator,
        isOnline: () => true,
        onState: states.add,
        baseRetryDelay: const Duration(milliseconds: 4),
        maxRetryDelay: const Duration(milliseconds: 20),
      );
      addTearDown(dispatcher.dispose);

      final first = await dispatcher.requestSync();
      expect(first.kind, PersonalSyncDispatchReceiptKind.retryScheduled);
      expect(await outbox.pending(), hasLength(1));

      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(gateway.pushCalls, greaterThanOrEqualTo(2));
      expect(successReceipts, 1);
      expect(await outbox.pending(), isEmpty);
      expect(
        states.any(
          (state) => state.phase == PersonalSyncDispatchPhase.retryScheduled,
        ),
        isTrue,
      );
      expect(states.last.phase, PersonalSyncDispatchPhase.idle);
    },
  );
}

Future<void> _enqueueProgress(
  PersonalSyncOutboxRepository outbox,
  PersonalSyncEnvelopeCipher cipher,
) async {
  final event = await cipher.encrypt(
    PersonalSyncClearEvent(
      id: 'evt_dispatch_001',
      workspaceId: 'wrk_personal',
      deviceId: 'dev_windows',
      stream: 'academy.progress',
      entityId: 'session:rel_001|node_001|session_001',
      kind: PersonalSyncEventKind.progress,
      mergePolicy: PersonalSyncMergePolicy.monotonicMaximum,
      logicalRevision: 1,
      idempotencyKey: 'idem_dispatch_001',
      clientCreatedAt: DateTime.utc(2026, 7, 27, 12),
      payload: const {
        'releaseId': 'rel_001',
        'microLessonNodeId': 'node_001',
        'sessionId': 'session_001',
        'interactionIndex': 0,
        'choiceResponseCount': 0,
        'completed': false,
        'startedAt': '2026-07-27T12:00:00.000Z',
        'completedAt': null,
        'completionReceiptId': null,
      },
    ),
  );
  await outbox.enqueue(event);
}

PersonalSyncRuntime _runtime() {
  final key = base64Url
      .encode(Uint8List.fromList(List<int>.filled(32, 9)))
      .replaceAll('=', '');
  final createdAt = DateTime.utc(2026, 7, 27);
  final workspace = PersonalWorkspace(
    id: 'wrk_personal',
    keyVersion: 1,
    recoveryGeneration: 1,
    createdAt: createdAt,
  );
  return PersonalSyncRuntime(
    workspace: workspace,
    device: TrustedDevice(
      id: 'dev_windows',
      workspaceId: workspace.id,
      label: 'Windows',
      platform: PersonalDevicePlatform.windows,
      role: DeviceTrustRole.root,
      signingPublicKey: key,
      encryptionPublicKey: key,
      createdAt: createdAt,
      lastSeenAt: createdAt,
    ),
    recoveryKitExported: true,
  );
}

final class _Gateway implements PersonalSyncGateway {
  var pushCalls = 0;
  var remainingPushFailures = 0;

  @override
  Future<List<EncryptedSyncEvent>> pushEvents({
    required String accessToken,
    required Iterable<EncryptedSyncEvent> events,
  }) async {
    pushCalls += 1;
    if (remainingPushFailures > 0) {
      remainingPushFailures -= 1;
      throw const PersonalSyncApiException(
        code: 'gateway_transient',
        message: 'Temporary gateway failure.',
        statusCode: 503,
      );
    }
    return events.toList(growable: false);
  }

  @override
  Future<SyncPullPage> pullEvents({
    required String accessToken,
    required int afterSequence,
    int limit = 200,
  }) async => SyncPullPage(events: const [], nextSequence: afterSequence);

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

final class _ProjectionCollector implements PersonalSyncProjectionApplier {
  @override
  Future<void> apply(DecryptedPersonalSyncEvent event) async {}
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
      List<int>.generate(32, (index) => (index * 7 + 3) & 0xff),
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
      List<int>.generate(32, (index) => (index * 11 + 5) & 0xff),
    ),
  );

  @override
  Future<WorkspaceSyncKey> currentKey() async => _key;

  @override
  Future<WorkspaceSyncKey?> readKey(int version) async =>
      version == _key.version ? _key : null;
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:synapse_app/data/learner_data/secure_learner_data_key_provider.dart';
import 'package:synapse_app/data/personal_sync/personal_device_identity.dart';
import 'package:synapse_app/data/personal_sync/personal_device_sync_service.dart';
import 'package:synapse_app/data/personal_sync/personal_workspace_key_store.dart';
import 'package:synapse_app/data/personal_sync/recovery_kit.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_services/synapse_services.dart';

void main() {
  test(
    'Windows bootstrap persists a device-bound runtime and encrypted kit',
    () async {
      final now = DateTime.utc(2026, 7, 27, 10);
      final gateway = _PairingGateway(now);
      final secure = _MemorySecureStringStore();
      final service = _service(
        gateway: gateway,
        secure: secure,
        platform: PersonalDevicePlatform.windows,
        now: now,
      );
      final draft = await RecoveryKitCodec(
        randomBytes: _fixedBytes,
        now: () => now,
      ).prepare(passphrase: 'bootstrap recovery passphrase, long enough');

      final bootstrap = await service.bootstrapWindowsRoot(
        deviceLabel: 'Main Windows',
        bootstrapToken: 'private-one-time-bootstrap-token',
        recoveryDraft: draft,
      );

      expect(bootstrap.runtime.workspace.id, 'wrk_personal');
      expect(bootstrap.runtime.device.role, DeviceTrustRole.root);
      expect(bootstrap.runtime.accessToken, isNotNull);
      expect(bootstrap.runtime.recoveryKitExported, isFalse);
      expect(gateway.bootstrapRecoveryVerifier, draft.recoveryVerifierSha256);
      expect(
        bootstrap.recoveryKit.serialize(),
        isNot(contains('Main Windows')),
      );
      expect(await service.restoreRuntime(), isNotNull);
      expect(
        await service.pendingRecoveryKit(),
        bootstrap.recoveryKit.serialize(),
      );

      await service.markRecoveryKitExported();
      expect((await service.restoreRuntime())!.recoveryKitExported, isTrue);
      expect(await service.pendingRecoveryKit(), isNull);
    },
  );

  test('two devices pair through a bound expiring invitation', () async {
    final now = DateTime.utc(2026, 7, 27, 10);
    final gateway = _PairingGateway(now);
    final rootSecure = _MemorySecureStringStore();
    final root = _service(
      gateway: gateway,
      secure: rootSecure,
      platform: PersonalDevicePlatform.windows,
      now: now,
    );
    final recoveryDraft = await RecoveryKitCodec(
      randomBytes: _fixedBytes,
      now: () => now,
    ).prepare(passphrase: 'pairing root recovery passphrase');
    final rootBootstrap = await root.bootstrapWindowsRoot(
      deviceLabel: 'Root Windows',
      bootstrapToken: 'private-one-time-bootstrap-token',
      recoveryDraft: recoveryDraft,
    );

    final candidateSecure = _MemorySecureStringStore();
    final candidate = _service(
      gateway: gateway,
      secure: candidateSecure,
      platform: PersonalDevicePlatform.android,
      now: now,
    );
    final invitation = await candidate.startCandidatePairing(
      deviceLabel: 'Personal Android',
    );
    final scanned = PersonalPairingInvitation.decode(invitation.encode());

    await root.approvePairingInvitation(scanned);
    final candidateRuntime = await candidate.completeCandidatePairing();
    final candidateKeys = SecureWorkspaceSyncKeyProvider(
      secureStore: candidateSecure,
    );
    final rootKeys = SecureWorkspaceSyncKeyProvider(secureStore: rootSecure);

    expect(candidateRuntime.workspace.id, rootBootstrap.runtime.workspace.id);
    expect(candidateRuntime.device.role, DeviceTrustRole.trusted);
    expect(
      (await candidateKeys.currentKey()).bytes,
      (await rootKeys.currentKey()).bytes,
    );
    expect(await candidate.ensureAccessToken(), candidateRuntime.accessToken);
    expect(
      await PersonalSyncRuntimeStore(
        secureStore: candidateSecure,
      ).readPendingPairing(),
      isNull,
    );
  });

  test(
    'expired QR pairing is rejected before a workspace key is sealed',
    () async {
      final now = DateTime.utc(2026, 7, 27, 10);
      final gateway = _PairingGateway(now);
      final rootSecure = _MemorySecureStringStore();
      final root = _service(
        gateway: gateway,
        secure: rootSecure,
        platform: PersonalDevicePlatform.windows,
        now: now,
      );
      final recoveryDraft = await RecoveryKitCodec(
        randomBytes: _fixedBytes,
        now: () => now,
      ).prepare(passphrase: 'expired QR recovery passphrase');
      await root.bootstrapWindowsRoot(
        deviceLabel: 'Root Windows',
        bootstrapToken: 'private-one-time-bootstrap-token',
        recoveryDraft: recoveryDraft,
      );
      final expired = PersonalPairingInvitation(
        sessionId: 'pair_expired',
        pairingCode: '123-456',
        candidateDeviceId: 'dev_expired',
        candidateEncryptionPublicKey: _base64Url(List<int>.filled(32, 7)),
        expiresAt: now.subtract(const Duration(seconds: 1)),
      );

      await expectLater(
        root.approvePairingInvitation(expired),
        throwsA(
          isA<PersonalDeviceSyncException>().having(
            (error) => error.code,
            'code',
            'pairing_invitation_expired',
          ),
        ),
      );
      expect(gateway.approvalAttempts, 0);
    },
  );

  test(
    'a rejected root bootstrap always consumes passphrase-derived material',
    () async {
      final now = DateTime.utc(2026, 7, 27, 10);
      final draft = await RecoveryKitCodec(
        randomBytes: _fixedBytes,
        now: () => now,
      ).prepare(passphrase: 'non-Windows recovery passphrase');
      final service = _service(
        gateway: _PairingGateway(now),
        secure: _MemorySecureStringStore(),
        platform: PersonalDevicePlatform.android,
        now: now,
      );

      await expectLater(
        service.bootstrapWindowsRoot(
          deviceLabel: 'Personal Android',
          bootstrapToken: 'private-one-time-bootstrap-token',
          recoveryDraft: draft,
        ),
        throwsA(
          isA<PersonalDeviceSyncException>().having(
            (error) => error.code,
            'code',
            'root_bootstrap_requires_windows',
          ),
        ),
      );
      await expectLater(
        draft.seal(
          workspace: PersonalWorkspace(
            id: 'wrk_unused',
            keyVersion: 1,
            recoveryGeneration: 1,
            createdAt: now,
          ),
          keys: [WorkspaceSyncKey(version: 1, bytes: List<int>.filled(32, 3))],
        ),
        throwsA(isA<RecoveryKitException>()),
      );
    },
  );
}

PersonalDeviceSyncService _service({
  required _PairingGateway gateway,
  required _MemorySecureStringStore secure,
  required PersonalDevicePlatform platform,
  required DateTime now,
}) => PersonalDeviceSyncService(
  gateway: gateway,
  identities: PersonalDeviceIdentityStore(
    secureStore: secure,
    platform: platform,
    randomBytes: _fixedBytes,
    now: () => now,
  ),
  workspaceKeys: SecureWorkspaceSyncKeyProvider(
    secureStore: secure,
    randomBytes: _fixedBytes,
  ),
  runtimeStore: PersonalSyncRuntimeStore(secureStore: secure),
  platform: platform,
  randomBytes: _fixedBytes,
  now: () => now,
);

List<int> _fixedBytes(int length) =>
    List<int>.generate(length, (index) => (index * 23 + 17) & 0xff);

String _base64Url(List<int> value) =>
    base64Url.encode(value).replaceAll('=', '');

final class _PairingGateway implements PersonalSyncGateway {
  _PairingGateway(this.now);

  final DateTime now;
  PersonalWorkspace? _workspace;
  TrustedDevice? _root;
  PairingSession? _session;
  int _tokenCounter = 0;
  int approvalAttempts = 0;
  String? bootstrapRecoveryVerifier;

  @override
  Future<({PersonalWorkspace workspace, TrustedDevice device})> bootstrap({
    required String bootstrapToken,
    required String recoveryVerifierSha256,
    required TrustedDevice device,
  }) async {
    if (_workspace != null ||
        bootstrapToken != 'private-one-time-bootstrap-token') {
      throw const PersonalSyncApiException(
        code: 'bootstrap_rejected',
        message: 'Bootstrap rejected.',
      );
    }
    bootstrapRecoveryVerifier = recoveryVerifierSha256;
    final workspace = PersonalWorkspace(
      id: 'wrk_personal',
      keyVersion: 1,
      recoveryGeneration: 1,
      createdAt: now,
    );
    final root = TrustedDevice(
      id: device.id,
      workspaceId: workspace.id,
      label: device.label,
      platform: device.platform,
      role: DeviceTrustRole.root,
      signingPublicKey: device.signingPublicKey,
      encryptionPublicKey: device.encryptionPublicKey,
      createdAt: now,
      lastSeenAt: now,
    );
    _workspace = workspace;
    _root = root;
    return (workspace: workspace, device: root);
  }

  @override
  Future<PairingSession> createPairingSession({
    required TrustedDevice candidate,
  }) async {
    final session = PairingSession(
      id: 'pair_personal',
      pairingCode: '123-456',
      candidateDeviceId: candidate.id,
      candidateLabel: candidate.label,
      candidatePlatform: candidate.platform,
      candidateSigningPublicKey: candidate.signingPublicKey,
      candidateEncryptionPublicKey: candidate.encryptionPublicKey,
      state: PairingSessionState.pending,
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 3)),
    );
    _session = session;
    return session;
  }

  @override
  Future<PairingSession> approvePairingSession({
    required String accessToken,
    required PairingSessionId sessionId,
    required String pairingCode,
    required String candidateEncryptionPublicKey,
    required String sealedWorkspaceKey,
  }) async {
    approvalAttempts += 1;
    final session = _session;
    final workspace = _workspace;
    if (session == null ||
        workspace == null ||
        session.id != sessionId ||
        session.pairingCode != pairingCode ||
        session.candidateEncryptionPublicKey != candidateEncryptionPublicKey ||
        sealedWorkspaceKey.length < 40) {
      throw const PersonalSyncApiException(
        code: 'pairing_rejected',
        message: 'Pairing rejected.',
        statusCode: 403,
      );
    }
    final approved = PairingSession(
      id: session.id,
      pairingCode: session.pairingCode,
      workspaceId: workspace.id,
      candidateDeviceId: session.candidateDeviceId,
      candidateLabel: session.candidateLabel,
      candidatePlatform: session.candidatePlatform,
      candidateSigningPublicKey: session.candidateSigningPublicKey,
      candidateEncryptionPublicKey: session.candidateEncryptionPublicKey,
      state: PairingSessionState.approved,
      createdAt: session.createdAt,
      expiresAt: session.expiresAt,
      approvedAt: now,
      sealedWorkspaceKey: sealedWorkspaceKey,
    );
    _session = approved;
    return approved;
  }

  @override
  Future<DeviceTokenResponse> exchangeDeviceToken({
    required TrustedDeviceId deviceId,
    required String nonce,
    required DateTime timestamp,
    required String signature,
    PairingSessionId? pairingSessionId,
    String? pairingCode,
  }) async {
    final workspace = _workspace!;
    final root = _root!;
    if (pairingSessionId == null) {
      if (deviceId != root.id) {
        throw const PersonalSyncApiException(
          code: 'unknown_device',
          message: 'Unknown device.',
          statusCode: 403,
        );
      }
      return _token(workspace: workspace, device: root);
    }
    final session = _session;
    if (session == null ||
        session.id != pairingSessionId ||
        session.pairingCode != pairingCode ||
        session.state != PairingSessionState.approved ||
        session.candidateDeviceId != deviceId ||
        session.sealedWorkspaceKey == null) {
      throw const PersonalSyncApiException(
        code: 'pairing_rejected',
        message: 'Pairing rejected.',
        statusCode: 403,
      );
    }
    final device = TrustedDevice(
      id: session.candidateDeviceId,
      workspaceId: workspace.id,
      label: session.candidateLabel,
      platform: session.candidatePlatform,
      role: DeviceTrustRole.trusted,
      signingPublicKey: session.candidateSigningPublicKey,
      encryptionPublicKey: session.candidateEncryptionPublicKey,
      createdAt: now,
      lastSeenAt: now,
    );
    _session = PairingSession(
      id: session.id,
      pairingCode: session.pairingCode,
      workspaceId: session.workspaceId,
      candidateDeviceId: session.candidateDeviceId,
      candidateLabel: session.candidateLabel,
      candidatePlatform: session.candidatePlatform,
      candidateSigningPublicKey: session.candidateSigningPublicKey,
      candidateEncryptionPublicKey: session.candidateEncryptionPublicKey,
      state: PairingSessionState.consumed,
      createdAt: session.createdAt,
      expiresAt: session.expiresAt,
      approvedAt: session.approvedAt,
      sealedWorkspaceKey: session.sealedWorkspaceKey,
    );
    return _token(
      workspace: workspace,
      device: device,
      sealedWorkspaceKey: session.sealedWorkspaceKey,
    );
  }

  DeviceTokenResponse _token({
    required PersonalWorkspace workspace,
    required TrustedDevice device,
    String? sealedWorkspaceKey,
  }) => DeviceTokenResponse(
    accessToken: 'token_${(++_tokenCounter).toString().padLeft(24, '0')}',
    expiresAt: now.add(const Duration(minutes: 15)),
    workspace: workspace,
    device: device,
    sealedWorkspaceKey: sealedWorkspaceKey,
  );

  @override
  Future<List<TrustedDevice>> listDevices(String accessToken) =>
      throw UnimplementedError();

  @override
  Future<void> revokeDevice({
    required String accessToken,
    required TrustedDeviceId deviceId,
  }) => throw UnimplementedError();

  @override
  Future<({PersonalWorkspace workspace, TrustedDevice device})> rotateRecovery({
    required PersonalWorkspaceId workspaceId,
    required int expectedGeneration,
    required String recoveryVerifierSha256,
    required String newRecoveryVerifierSha256,
    required TrustedDevice newRootDevice,
  }) => throw UnimplementedError();

  @override
  Future<List<EncryptedSyncEvent>> pushEvents({
    required String accessToken,
    required Iterable<EncryptedSyncEvent> events,
  }) => throw UnimplementedError();

  @override
  Future<SyncPullPage> pullEvents({
    required String accessToken,
    required int afterSequence,
    int limit = 200,
  }) => throw UnimplementedError();

  @override
  Future<ContentManifest?> fetchManifest({
    required String accessToken,
    String? ifNoneMatch,
  }) => throw UnimplementedError();

  @override
  Future<Uint8List> downloadPackage({
    required String accessToken,
    required ContentPackageId packageId,
  }) => throw UnimplementedError();
}

final class _MemorySecureStringStore implements SecureStringStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

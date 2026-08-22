import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_services/synapse_services.dart';

import '../learner_data/secure_learner_data_key_provider.dart';
import 'personal_device_identity.dart';
import 'personal_workspace_key_store.dart';
import 'recovery_kit.dart';

/// Securely persisted, non-content runtime information for one paired device.
/// Workspace keys, device private keys, and recovery secrets live in separate
/// secure-storage records or in an exported Recovery Kit, never in this state.
final class PersonalSyncRuntime {
  PersonalSyncRuntime({
    required this.workspace,
    required this.device,
    this.accessToken,
    DateTime? accessTokenExpiresAt,
    this.recoveryKitExported = false,
    DateTime? lastSuccessfulSyncAt,
  }) : accessTokenExpiresAt = accessTokenExpiresAt?.toUtc(),
       lastSuccessfulSyncAt = lastSuccessfulSyncAt?.toUtc() {
    if (workspace.id != device.workspaceId) {
      throw const PersonalDeviceSyncException(
        'runtime_workspace_mismatch',
        'The stored device does not belong to the stored workspace.',
      );
    }
    if ((accessToken == null) != (accessTokenExpiresAt == null)) {
      throw const PersonalDeviceSyncException(
        'runtime_token_mismatch',
        'The stored device token is incomplete.',
      );
    }
    if (accessToken != null && !_tokenPattern.hasMatch(accessToken!)) {
      throw const PersonalDeviceSyncException(
        'runtime_token_invalid',
        'The stored device token is invalid.',
      );
    }
  }

  final PersonalWorkspace workspace;
  final TrustedDevice device;
  final String? accessToken;
  final DateTime? accessTokenExpiresAt;
  final bool recoveryKitExported;
  final DateTime? lastSuccessfulSyncAt;

  bool hasUsableTokenAt(
    DateTime now, {
    Duration leeway = const Duration(seconds: 45),
  }) {
    final expiry = accessTokenExpiresAt;
    return accessToken != null &&
        expiry != null &&
        expiry.isAfter(now.toUtc().add(leeway));
  }

  PersonalSyncRuntime copyWith({
    PersonalWorkspace? workspace,
    TrustedDevice? device,
    String? accessToken,
    DateTime? accessTokenExpiresAt,
    bool? recoveryKitExported,
    DateTime? lastSuccessfulSyncAt,
    bool clearToken = false,
  }) => PersonalSyncRuntime(
    workspace: workspace ?? this.workspace,
    device: device ?? this.device,
    accessToken: clearToken ? null : (accessToken ?? this.accessToken),
    accessTokenExpiresAt: clearToken
        ? null
        : (accessTokenExpiresAt ?? this.accessTokenExpiresAt),
    recoveryKitExported: recoveryKitExported ?? this.recoveryKitExported,
    lastSuccessfulSyncAt: lastSuccessfulSyncAt ?? this.lastSuccessfulSyncAt,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'workspace': workspace.toJson(),
    'device': device.toJson(),
    'accessToken': accessToken,
    'accessTokenExpiresAt': accessTokenExpiresAt?.toIso8601String(),
    'recoveryKitExported': recoveryKitExported,
    'lastSuccessfulSyncAt': lastSuccessfulSyncAt?.toIso8601String(),
  };

  factory PersonalSyncRuntime.fromJson(Map<String, Object?> value) {
    if (value['schemaVersion'] != 1) {
      throw const FormatException();
    }
    return PersonalSyncRuntime(
      workspace: PersonalWorkspace.fromJson(_map(value['workspace'])),
      device: TrustedDevice.fromJson(_map(value['device'])),
      accessToken: value['accessToken'] as String?,
      accessTokenExpiresAt: _dateOrNull(value['accessTokenExpiresAt']),
      recoveryKitExported: value['recoveryKitExported'] as bool? ?? false,
      lastSuccessfulSyncAt: _dateOrNull(value['lastSuccessfulSyncAt']),
    );
  }
}

/// Candidate state is separate from a paired runtime so an unapproved phone or
/// browser can never be mistaken for a trusted device after a restart.
final class PersonalPendingPairing {
  PersonalPendingPairing({required this.session}) {
    if (session.pairingCode == null || session.pairingCode!.isEmpty) {
      throw const PersonalDeviceSyncException(
        'pending_pairing_missing_proof',
        'The pending pairing session has no short-lived proof.',
      );
    }
  }

  final PairingSession session;

  bool isExpiredAt(DateTime now) => session.isExpiredAt(now);

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'session': session.toJson(),
  };

  factory PersonalPendingPairing.fromJson(Map<String, Object?> value) {
    if (value['schemaVersion'] != 1) throw const FormatException();
    return PersonalPendingPairing(
      session: PairingSession.fromJson(_map(value['session'])),
    );
  }
}

/// Compact, expiring payload rendered as a QR code by the UI. It has no
/// gateway URL or credentials: the approving device keeps using its own
/// configured private gateway and verifies the included key against it.
final class PersonalPairingInvitation {
  const PersonalPairingInvitation({
    required this.sessionId,
    required this.pairingCode,
    required this.candidateDeviceId,
    required this.candidateEncryptionPublicKey,
    required this.expiresAt,
  });

  static const _prefix = 'synapse-pair-v1:';

  final PairingSessionId sessionId;
  final String pairingCode;
  final TrustedDeviceId candidateDeviceId;
  final String candidateEncryptionPublicKey;
  final DateTime expiresAt;

  bool isExpiredAt(DateTime now) => !now.toUtc().isBefore(expiresAt.toUtc());

  String encode() =>
      _prefix +
      base64Url
          .encode(
            utf8.encode(
              jsonEncode({
                'schemaVersion': 1,
                'sessionId': sessionId,
                'pairingCode': pairingCode,
                'candidateDeviceId': candidateDeviceId,
                'candidateEncryptionPublicKey': candidateEncryptionPublicKey,
                'expiresAt': expiresAt.toUtc().toIso8601String(),
              }),
            ),
          )
          .replaceAll('=', '');

  factory PersonalPairingInvitation.fromSession(PairingSession session) {
    final code = session.pairingCode;
    if (code == null) {
      throw const PersonalDeviceSyncException(
        'pairing_invitation_missing_code',
        'The candidate pairing session has no short-lived code.',
      );
    }
    return PersonalPairingInvitation(
      sessionId: session.id,
      pairingCode: code,
      candidateDeviceId: session.candidateDeviceId,
      candidateEncryptionPublicKey: session.candidateEncryptionPublicKey,
      expiresAt: session.expiresAt,
    );
  }

  factory PersonalPairingInvitation.decode(String value) {
    try {
      if (!value.startsWith(_prefix)) throw const FormatException();
      final raw = value.substring(_prefix.length);
      final decoded = jsonDecode(utf8.decode(_base64UrlDecode(raw)));
      if (decoded is! Map || decoded['schemaVersion'] != 1) {
        throw const FormatException();
      }
      final invitation = PersonalPairingInvitation(
        sessionId: decoded['sessionId'] as String,
        pairingCode: decoded['pairingCode'] as String,
        candidateDeviceId: decoded['candidateDeviceId'] as String,
        candidateEncryptionPublicKey:
            decoded['candidateEncryptionPublicKey'] as String,
        expiresAt: DateTime.parse(decoded['expiresAt'] as String).toUtc(),
      );
      if (!_pairingCodePattern.hasMatch(invitation.pairingCode) ||
          !_identifierPattern.hasMatch(invitation.sessionId) ||
          !_identifierPattern.hasMatch(invitation.candidateDeviceId) ||
          _base64UrlDecode(invitation.candidateEncryptionPublicKey).length !=
              32) {
        throw const FormatException();
      }
      return invitation;
    } on PersonalDeviceSyncException {
      rethrow;
    } on Object catch (error) {
      throw PersonalDeviceSyncException(
        'invalid_pairing_invitation',
        'The pairing QR payload is invalid or unsupported.',
        error,
      );
    }
  }
}

final class PersonalSyncRuntimeStore {
  factory PersonalSyncRuntimeStore({
    required SecureStringStore secureStore,
    Duration operationTimeout = const Duration(seconds: 5),
  }) {
    if (operationTimeout <= Duration.zero) {
      throw ArgumentError.value(operationTimeout, 'operationTimeout');
    }
    return PersonalSyncRuntimeStore._(secureStore, operationTimeout);
  }

  PersonalSyncRuntimeStore._(this._secureStore, this._operationTimeout);

  static const runtimeStorageKey = 'synapse.personal_sync.runtime.v1';
  static const pendingPairingStorageKey =
      'synapse.personal_sync.pending_pairing.v1';
  static const pendingRecoveryKitStorageKey =
      'synapse.personal_sync.pending_recovery_kit.v1';

  final SecureStringStore _secureStore;
  final Duration _operationTimeout;

  Future<PersonalSyncRuntime?> readRuntime() => _read(
    key: runtimeStorageKey,
    decode: (value) => PersonalSyncRuntime.fromJson(value),
    corruptCode: 'corrupt_personal_sync_runtime',
  );

  Future<void> writeRuntime(PersonalSyncRuntime runtime) =>
      _write(runtimeStorageKey, runtime.toJson());

  Future<void> clearRuntime() => _delete(runtimeStorageKey);

  Future<PersonalPendingPairing?> readPendingPairing() => _read(
    key: pendingPairingStorageKey,
    decode: (value) => PersonalPendingPairing.fromJson(value),
    corruptCode: 'corrupt_personal_pending_pairing',
  );

  Future<void> writePendingPairing(PersonalPendingPairing pending) =>
      _write(pendingPairingStorageKey, pending.toJson());

  Future<void> clearPendingPairing() => _delete(pendingPairingStorageKey);

  Future<String?> readPendingRecoveryKit() async {
    try {
      return await _secureStore
          .read(pendingRecoveryKitStorageKey)
          .timeout(_operationTimeout);
    } on TimeoutException catch (error) {
      throw PersonalDeviceSyncException(
        'personal_sync_storage_timeout',
        'Secure personal-sync storage did not respond in time.',
        error,
      );
    }
  }

  Future<void> writePendingRecoveryKit(String serialized) async {
    if (serialized.length < 80 || serialized.length > 8 * 1024 * 1024) {
      throw const PersonalDeviceSyncException(
        'invalid_pending_recovery_kit',
        'The encrypted recovery kit is invalid.',
      );
    }
    try {
      await _secureStore
          .write(pendingRecoveryKitStorageKey, serialized)
          .timeout(_operationTimeout);
    } on TimeoutException catch (error) {
      throw PersonalDeviceSyncException(
        'personal_sync_storage_timeout',
        'Secure personal-sync storage did not persist the update.',
        error,
      );
    }
  }

  Future<void> clearPendingRecoveryKit() =>
      _delete(pendingRecoveryKitStorageKey);

  Future<T?> _read<T>({
    required String key,
    required T Function(Map<String, Object?> value) decode,
    required String corruptCode,
  }) async {
    try {
      final raw = await _secureStore.read(key).timeout(_operationTimeout);
      if (raw == null) return null;
      return decode(_map(jsonDecode(raw)));
    } on TimeoutException catch (error) {
      throw PersonalDeviceSyncException(
        'personal_sync_storage_timeout',
        'Secure personal-sync storage did not respond in time.',
        error,
      );
    } on PersonalDeviceSyncException {
      rethrow;
    } on Object catch (error) {
      throw PersonalDeviceSyncException(
        corruptCode,
        'Secure personal-sync state is invalid.',
        error,
      );
    }
  }

  Future<void> _write(String key, Map<String, Object?> value) async {
    try {
      await _secureStore
          .write(key, jsonEncode(value))
          .timeout(_operationTimeout);
    } on TimeoutException catch (error) {
      throw PersonalDeviceSyncException(
        'personal_sync_storage_timeout',
        'Secure personal-sync storage did not persist the update.',
        error,
      );
    }
  }

  Future<void> _delete(String key) async {
    try {
      await _secureStore.delete(key).timeout(_operationTimeout);
    } on TimeoutException catch (error) {
      throw PersonalDeviceSyncException(
        'personal_sync_storage_timeout',
        'Secure personal-sync storage did not clear the update.',
        error,
      );
    }
  }
}

/// Client-side protocol implementation for root bootstrap and two-device QR
/// pairing. It deliberately has no Flutter/Riverpod dependency so every state
/// transition can be verified with a gateway test double.
final class PersonalDeviceSyncService {
  factory PersonalDeviceSyncService({
    required PersonalSyncGateway gateway,
    required PersonalDeviceIdentityStore identities,
    required SecureWorkspaceSyncKeyProvider workspaceKeys,
    required PersonalSyncRuntimeStore runtimeStore,
    required PersonalDevicePlatform platform,
    WorkspaceKeySealer? keySealer,
    List<int> Function(int length)? randomBytes,
    DateTime Function()? now,
  }) => PersonalDeviceSyncService._(
    gateway,
    identities,
    workspaceKeys,
    runtimeStore,
    platform,
    keySealer ?? WorkspaceKeySealer(),
    randomBytes ?? _secureRandomBytes,
    now ?? (() => DateTime.now().toUtc()),
  );

  PersonalDeviceSyncService._(
    this._gateway,
    this._identities,
    this._workspaceKeys,
    this._runtimeStore,
    this._platform,
    this._keySealer,
    this._randomBytes,
    this._now,
  );

  final PersonalSyncGateway _gateway;
  final PersonalDeviceIdentityStore _identities;
  final SecureWorkspaceSyncKeyProvider _workspaceKeys;
  final PersonalSyncRuntimeStore _runtimeStore;
  final PersonalDevicePlatform _platform;
  final WorkspaceKeySealer _keySealer;
  final List<int> Function(int length) _randomBytes;
  final DateTime Function() _now;

  Future<PersonalSyncRuntime?> restoreRuntime() => _runtimeStore.readRuntime();

  Future<PersonalPendingPairing?> pendingPairing() =>
      _runtimeStore.readPendingPairing();

  Future<PersonalRootBootstrap> bootstrapWindowsRoot({
    required String deviceLabel,
    required String bootstrapToken,
    required RecoveryKitDraft recoveryDraft,
  }) async {
    try {
      if (_platform != PersonalDevicePlatform.windows) {
        throw const PersonalDeviceSyncException(
          'root_bootstrap_requires_windows',
          'Initial personal workspace setup must start on Windows.',
        );
      }
      if (await _runtimeStore.readRuntime() != null) {
        throw const PersonalDeviceSyncException(
          'workspace_already_paired',
          'This device already belongs to a personal workspace.',
        );
      }
      final identity = await _identities.loadOrCreate(label: deviceLabel);
      final response = await _gateway.bootstrap(
        bootstrapToken: bootstrapToken,
        recoveryVerifierSha256: recoveryDraft.recoveryVerifierSha256,
        device: identity.trustedDevice(
          workspaceId: 'pending',
          role: DeviceTrustRole.root,
          registeredAt: _now(),
        ),
      );
      _assertDeviceResponse(identity, response.workspace, response.device);
      final activeKey = await _workspaceKeys.createInitialKey();
      if (activeKey.version != response.workspace.keyVersion) {
        throw const PersonalDeviceSyncException(
          'workspace_key_version_mismatch',
          'The local workspace-key version does not match the new workspace.',
        );
      }
      var runtime = PersonalSyncRuntime(
        workspace: response.workspace,
        device: response.device,
      );
      await _runtimeStore.writeRuntime(runtime);
      final recoveryKit = await recoveryDraft.seal(
        workspace: response.workspace,
        keys: await _workspaceKeys.snapshotForRecovery(),
      );
      await _runtimeStore.writePendingRecoveryKit(recoveryKit.serialize());
      runtime = await _refreshDeviceToken(runtime, identity);
      await _runtimeStore.writeRuntime(runtime);
      return PersonalRootBootstrap(runtime: runtime, recoveryKit: recoveryKit);
    } finally {
      // [seal] consumes the draft as well; dispose is deliberately idempotent
      // so every failed bootstrap path clears passphrase-derived material.
      recoveryDraft.dispose();
    }
  }

  Future<void> markRecoveryKitExported() async {
    final runtime = await _requireRuntime();
    await _runtimeStore.writeRuntime(
      runtime.copyWith(recoveryKitExported: true),
    );
    await _runtimeStore.clearPendingRecoveryKit();
  }

  Future<String?> pendingRecoveryKit() =>
      _runtimeStore.readPendingRecoveryKit();

  Future<PersonalPairingInvitation> startCandidatePairing({
    required String deviceLabel,
  }) async {
    if (await _runtimeStore.readRuntime() != null) {
      throw const PersonalDeviceSyncException(
        'workspace_already_paired',
        'This device already belongs to a personal workspace.',
      );
    }
    final identity = await _identities.loadOrCreate(label: deviceLabel);
    final session = await _gateway.createPairingSession(
      candidate: identity.trustedDevice(
        workspaceId: 'pending',
        role: DeviceTrustRole.trusted,
        registeredAt: _now(),
      ),
    );
    if (session.isExpiredAt(_now())) {
      throw const PersonalDeviceSyncException(
        'pairing_session_expired',
        'The new pairing session expired before it could be shown.',
      );
    }
    await _runtimeStore.writePendingPairing(
      PersonalPendingPairing(session: session),
    );
    return PersonalPairingInvitation.fromSession(session);
  }

  Future<void> approvePairingInvitation(
    PersonalPairingInvitation invitation,
  ) async {
    if (invitation.isExpiredAt(_now())) {
      throw const PersonalDeviceSyncException(
        'pairing_invitation_expired',
        'This pairing invitation has expired. Generate a new QR code.',
      );
    }
    final runtime = await _requireRuntime();
    final token = await ensureAccessToken();
    final activeKey = await _workspaceKeys.currentKey();
    if (activeKey.version != runtime.workspace.keyVersion) {
      throw const PersonalDeviceSyncException(
        'workspace_key_version_mismatch',
        'The active workspace key does not match the paired workspace.',
      );
    }
    final sealedKey = await _keySealer.seal(
      workspaceKey: activeKey,
      recipientEncryptionPublicKey: invitation.candidateEncryptionPublicKey,
    );
    final approved = await _gateway.approvePairingSession(
      accessToken: token,
      sessionId: invitation.sessionId,
      pairingCode: invitation.pairingCode,
      candidateEncryptionPublicKey: invitation.candidateEncryptionPublicKey,
      sealedWorkspaceKey: sealedKey,
    );
    if (approved.state != PairingSessionState.approved ||
        approved.workspaceId != runtime.workspace.id ||
        approved.candidateDeviceId != invitation.candidateDeviceId ||
        approved.candidateEncryptionPublicKey !=
            invitation.candidateEncryptionPublicKey) {
      throw const PersonalDeviceSyncException(
        'pairing_approval_mismatch',
        'The gateway did not confirm the scanned pairing invitation.',
      );
    }
  }

  Future<PersonalSyncRuntime> completeCandidatePairing() async {
    final pending = await _runtimeStore.readPendingPairing();
    if (pending == null) {
      throw const PersonalDeviceSyncException(
        'pending_pairing_missing',
        'There is no pairing request waiting on this device.',
      );
    }
    if (pending.isExpiredAt(_now())) {
      await _runtimeStore.clearPendingPairing();
      throw const PersonalDeviceSyncException(
        'pairing_session_expired',
        'This pairing request has expired. Generate a new QR code.',
      );
    }
    final session = pending.session;
    final identity = await _identities.loadOrCreate(
      label: session.candidateLabel,
    );
    if (identity.id != session.candidateDeviceId) {
      throw const PersonalDeviceSyncException(
        'pairing_identity_mismatch',
        'This device identity no longer matches the pending pairing request.',
      );
    }
    final timestamp = _now();
    final nonce = _nonce();
    final token = await _gateway.exchangeDeviceToken(
      deviceId: identity.id,
      nonce: nonce,
      timestamp: timestamp,
      signature: await identity.signDeviceTokenChallenge(
        nonce: nonce,
        timestamp: timestamp,
      ),
      pairingSessionId: session.id,
      pairingCode: session.pairingCode,
    );
    final workspace = token.workspace;
    final device = token.device;
    final sealedKey = token.sealedWorkspaceKey;
    if (workspace == null || device == null || sealedKey == null) {
      throw const PersonalDeviceSyncException(
        'pairing_response_incomplete',
        'The pairing gateway response is incomplete.',
      );
    }
    _assertDeviceResponse(identity, workspace, device);
    final key = await _keySealer.unseal(
      sealedWorkspaceKey: sealedKey,
      recipient: identity,
    );
    if (key.version != workspace.keyVersion) {
      throw const PersonalDeviceSyncException(
        'pairing_workspace_key_mismatch',
        'The paired workspace key does not match the workspace version.',
      );
    }
    await _workspaceKeys.install(key);
    final runtime = PersonalSyncRuntime(
      workspace: workspace,
      device: device,
      accessToken: token.accessToken,
      accessTokenExpiresAt: token.expiresAt,
    );
    await _runtimeStore.writeRuntime(runtime);
    await _runtimeStore.clearPendingPairing();
    return runtime;
  }

  Future<String> ensureAccessToken() async {
    final runtime = await _requireRuntime();
    if (runtime.hasUsableTokenAt(_now())) return runtime.accessToken!;
    final identity = await _identities.loadOrCreate(
      label: runtime.device.label,
    );
    _assertDeviceResponse(identity, runtime.workspace, runtime.device);
    final refreshed = await _refreshDeviceToken(runtime, identity);
    await _runtimeStore.writeRuntime(refreshed);
    return refreshed.accessToken!;
  }

  /// Stores a privacy-safe transport receipt only after a complete encrypted
  /// push/pull run. It contains no payload, sequence, or learning content and
  /// lets the Settings surface distinguish a paired device from one that has
  /// successfully reconnected at least once.
  Future<void> markSuccessfulSync(DateTime completedAt) async {
    final at = completedAt.toUtc();
    if (at.microsecondsSinceEpoch <= 0) {
      throw ArgumentError.value(completedAt, 'completedAt');
    }
    final runtime = await _requireRuntime();
    final prior = runtime.lastSuccessfulSyncAt;
    await _runtimeStore.writeRuntime(
      runtime.copyWith(
        lastSuccessfulSyncAt: prior == null || at.isAfter(prior) ? at : prior,
      ),
    );
  }

  Future<PersonalSyncRuntime> _refreshDeviceToken(
    PersonalSyncRuntime runtime,
    PersonalDeviceIdentity identity,
  ) async {
    final nonce = _nonce();
    final timestamp = _now();
    final response = await _gateway.exchangeDeviceToken(
      deviceId: identity.id,
      nonce: nonce,
      timestamp: timestamp,
      signature: await identity.signDeviceTokenChallenge(
        nonce: nonce,
        timestamp: timestamp,
      ),
    );
    final workspace = response.workspace;
    final device = response.device;
    if (workspace == null || device == null) {
      throw const PersonalDeviceSyncException(
        'device_token_response_incomplete',
        'The device-token response is incomplete.',
      );
    }
    _assertDeviceResponse(identity, workspace, device);
    if (workspace.id != runtime.workspace.id ||
        workspace.keyVersion != runtime.workspace.keyVersion) {
      throw const PersonalDeviceSyncException(
        'workspace_state_changed',
        'The remote workspace changed and requires recovery before sync.',
      );
    }
    return runtime.copyWith(
      workspace: workspace,
      device: device,
      accessToken: response.accessToken,
      accessTokenExpiresAt: response.expiresAt,
    );
  }

  Future<PersonalSyncRuntime> _requireRuntime() async {
    final runtime = await _runtimeStore.readRuntime();
    if (runtime == null) {
      throw const PersonalDeviceSyncException(
        'personal_workspace_unpaired',
        'This device has not been paired with a personal workspace.',
      );
    }
    return runtime;
  }

  void _assertDeviceResponse(
    PersonalDeviceIdentity identity,
    PersonalWorkspace workspace,
    TrustedDevice device,
  ) {
    if (device.id != identity.id ||
        device.workspaceId != workspace.id ||
        device.signingPublicKey != identity.signingPublicKey ||
        device.encryptionPublicKey != identity.encryptionPublicKey ||
        !device.isActive) {
      throw const PersonalDeviceSyncException(
        'device_identity_response_mismatch',
        'The gateway returned a device identity that does not match this device.',
      );
    }
  }

  String _nonce() {
    return base64Url.encode(_randomBytes(32)).replaceAll('=', '');
  }

  static List<int> _secureRandomBytes(int length) {
    final random = SecretKeyData.random(length: length);
    try {
      return Uint8List.fromList(random.bytes);
    } finally {
      random.destroy();
    }
  }
}

final class PersonalRootBootstrap {
  const PersonalRootBootstrap({
    required this.runtime,
    required this.recoveryKit,
  });

  final PersonalSyncRuntime runtime;
  final EncryptedRecoveryKit recoveryKit;
}

final class PersonalDeviceSyncException implements Exception {
  const PersonalDeviceSyncException(this.code, this.message, [this.cause]);

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'PersonalDeviceSyncException($code): $message';
}

final _tokenPattern = RegExp(r'^[A-Za-z0-9_-]{20,200}$');
final _pairingCodePattern = RegExp(r'^[0-9]{3}-[0-9]{3}$');
final _identifierPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,159}$');

Map<String, Object?> _map(Object? value) {
  if (value is! Map) throw const FormatException();
  return Map<String, Object?>.from(value);
}

DateTime? _dateOrNull(Object? value) {
  if (value == null) return null;
  if (value is! String) throw const FormatException();
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw const FormatException();
  return parsed.toUtc();
}

List<int> _base64UrlDecode(String value) {
  final padded = value.padRight((value.length + 3) ~/ 4 * 4, '=');
  return base64Url.decode(padded);
}

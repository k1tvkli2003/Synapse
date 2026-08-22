import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_services/synapse_services.dart';

import '../learner_data/secure_learner_data_key_provider.dart';

/// Secure device identity for personal pairing. On Web, [FlutterSecureStringStore]
/// is backed by flutter_secure_storage's WebCrypto implementation; clearing
/// browser storage deliberately makes the browser a new, untrusted device.
final class PersonalDeviceIdentityStore {
  PersonalDeviceIdentityStore({
    required SecureStringStore secureStore,
    required PersonalDevicePlatform platform,
    List<int> Function(int length)? randomBytes,
    DateTime Function()? now,
    Duration operationTimeout = const Duration(seconds: 5),
  }) : this._(
         secureStore: secureStore,
         platform: platform,
         randomBytes: randomBytes ?? _secureRandomBytes,
         now: now ?? (() => DateTime.now().toUtc()),
         operationTimeout: operationTimeout,
       );

  PersonalDeviceIdentityStore._({
    required this._secureStore,
    required this._platform,
    required this._randomBytes,
    required this._now,
    required this._operationTimeout,
  });

  static const storageKey = 'synapse.personal_sync.device_identity.v1';

  final SecureStringStore _secureStore;
  final PersonalDevicePlatform _platform;
  final List<int> Function(int length) _randomBytes;
  final DateTime Function() _now;
  final Duration _operationTimeout;
  Future<PersonalDeviceIdentity>? _pending;

  Future<PersonalDeviceIdentity> loadOrCreate({required String label}) {
    final current = _pending;
    if (current != null) return current;
    final pending = _loadOrCreate(label: label);
    _pending = pending;
    return _resetAfterFailure(pending);
  }

  Future<PersonalDeviceIdentity> _loadOrCreate({required String label}) async {
    final encoded = await _read();
    if (encoded != null) return PersonalDeviceIdentity._decode(encoded);
    if (label.trim().isEmpty || label.trim().length > 80) {
      throw const PersonalDeviceIdentityException(
        'invalid_device_label',
        'A device label must contain between 1 and 80 characters.',
      );
    }

    final signingAlgorithm = Ed25519();
    final encryptionAlgorithm = X25519();
    final signingPair = await signingAlgorithm.newKeyPair();
    final encryptionPair = await encryptionAlgorithm.newKeyPair();
    final signingPrivate = Uint8List.fromList(
      await signingPair.extractPrivateKeyBytes(),
    );
    final signingPublic = await signingPair.extractPublicKey();
    final encryptionPrivate = Uint8List.fromList(
      await encryptionPair.extractPrivateKeyBytes(),
    );
    final encryptionPublic = await encryptionPair.extractPublicKey();
    signingPair.destroy();
    encryptionPair.destroy();

    final identity = PersonalDeviceIdentity._(
      id: 'dev_${_base64Url(_randomBytes(18))}',
      label: label.trim(),
      platform: _platform,
      createdAt: _now(),
      signingPrivateKey: signingPrivate,
      signingPublicKey: Uint8List.fromList(signingPublic.bytes),
      encryptionPrivateKey: encryptionPrivate,
      encryptionPublicKey: Uint8List.fromList(encryptionPublic.bytes),
    );
    await _write(identity._encode());
    return identity;
  }

  Future<PersonalDeviceIdentity> _resetAfterFailure(
    Future<PersonalDeviceIdentity> pending,
  ) async {
    try {
      return await pending;
    } on Object catch (error, stackTrace) {
      if (identical(_pending, pending)) _pending = null;
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<String?> _read() async {
    try {
      return await _secureStore.read(storageKey).timeout(_operationTimeout);
    } on TimeoutException catch (error) {
      throw PersonalDeviceIdentityException(
        'device_identity_read_timeout',
        'Secure device identity storage did not respond in time.',
        error,
      );
    }
  }

  Future<void> _write(String value) async {
    try {
      await _secureStore.write(storageKey, value).timeout(_operationTimeout);
    } on TimeoutException catch (error) {
      throw PersonalDeviceIdentityException(
        'device_identity_write_timeout',
        'Secure device identity storage did not persist the key material.',
        error,
      );
    }
  }

  static List<int> _secureRandomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }
}

final class PersonalDeviceIdentity {
  PersonalDeviceIdentity._({
    required this.id,
    required this.label,
    required this.platform,
    required DateTime createdAt,
    required this._signingPrivateKey,
    required this._signingPublicKey,
    required this._encryptionPrivateKey,
    required this._encryptionPublicKey,
  }) : createdAt = createdAt.toUtc() {
    _validateId(id);
    if (label.isEmpty || label.length > 80) {
      throw const PersonalDeviceIdentityException(
        'invalid_device_label',
        'Stored device label is invalid.',
      );
    }
    if (_signingPrivateKey.length != 32 ||
        _signingPublicKey.length != 32 ||
        _encryptionPrivateKey.length != 32 ||
        _encryptionPublicKey.length != 32) {
      throw const PersonalDeviceIdentityException(
        'invalid_device_key_material',
        'Stored device key material has an invalid length.',
      );
    }
  }

  static const _schemaVersion = 1;

  final TrustedDeviceId id;
  final String label;
  final PersonalDevicePlatform platform;
  final DateTime createdAt;
  final Uint8List _signingPrivateKey;
  final Uint8List _signingPublicKey;
  final Uint8List _encryptionPrivateKey;
  final Uint8List _encryptionPublicKey;

  String get signingPublicKey => _base64Url(_signingPublicKey);
  String get encryptionPublicKey => _base64Url(_encryptionPublicKey);

  TrustedDevice trustedDevice({
    required PersonalWorkspaceId workspaceId,
    required DeviceTrustRole role,
    DateTime? registeredAt,
  }) {
    final now = (registeredAt ?? DateTime.now()).toUtc();
    return TrustedDevice(
      id: id,
      workspaceId: workspaceId,
      label: label,
      platform: platform,
      role: role,
      signingPublicKey: signingPublicKey,
      encryptionPublicKey: encryptionPublicKey,
      createdAt: now,
      lastSeenAt: now,
    );
  }

  Future<String> signDeviceTokenChallenge({
    required String nonce,
    required DateTime timestamp,
  }) async {
    final keyPair = SimpleKeyPairData(
      Uint8List.fromList(_signingPrivateKey),
      publicKey: SimplePublicKey(
        Uint8List.fromList(_signingPublicKey),
        type: KeyPairType.ed25519,
      ),
      type: KeyPairType.ed25519,
    );
    try {
      final message =
          'synapse-device-token-v1\n$id\n$nonce\n'
          '${timestamp.toUtc().toIso8601String()}';
      final signature = await Ed25519().sign(
        utf8.encode(message),
        keyPair: keyPair,
      );
      return _base64Url(signature.bytes);
    } finally {
      keyPair.destroy();
    }
  }

  SimpleKeyPairData _encryptionKeyPair() => SimpleKeyPairData(
    Uint8List.fromList(_encryptionPrivateKey),
    publicKey: SimplePublicKey(
      Uint8List.fromList(_encryptionPublicKey),
      type: KeyPairType.x25519,
    ),
    type: KeyPairType.x25519,
  );

  String _encode() => jsonEncode({
    'schemaVersion': _schemaVersion,
    'id': id,
    'label': label,
    'platform': platform.name,
    'createdAt': createdAt.toIso8601String(),
    'signingPrivateKey': _base64Url(_signingPrivateKey),
    'signingPublicKey': _base64Url(_signingPublicKey),
    'encryptionPrivateKey': _base64Url(_encryptionPrivateKey),
    'encryptionPublicKey': _base64Url(_encryptionPublicKey),
  });

  static PersonalDeviceIdentity _decode(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map || decoded['schemaVersion'] != _schemaVersion) {
        throw const FormatException('Unsupported identity schema.');
      }
      return PersonalDeviceIdentity._(
        id: decoded['id'] as String,
        label: decoded['label'] as String,
        platform: PersonalDevicePlatform.values.byName(
          decoded['platform'] as String,
        ),
        createdAt: DateTime.parse(decoded['createdAt'] as String),
        signingPrivateKey: Uint8List.fromList(
          _base64UrlDecode(decoded['signingPrivateKey'] as String),
        ),
        signingPublicKey: Uint8List.fromList(
          _base64UrlDecode(decoded['signingPublicKey'] as String),
        ),
        encryptionPrivateKey: Uint8List.fromList(
          _base64UrlDecode(decoded['encryptionPrivateKey'] as String),
        ),
        encryptionPublicKey: Uint8List.fromList(
          _base64UrlDecode(decoded['encryptionPublicKey'] as String),
        ),
      );
    } on PersonalDeviceIdentityException {
      rethrow;
    } on Object catch (error) {
      throw PersonalDeviceIdentityException(
        'corrupt_device_identity',
        'Secure device identity storage is invalid.',
        error,
      );
    }
  }

  static void _validateId(String value) {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,159}$').hasMatch(value)) {
      throw const PersonalDeviceIdentityException(
        'invalid_device_identifier',
        'Stored device identity is invalid.',
      );
    }
  }
}

final class PersonalDeviceIdentityException implements Exception {
  const PersonalDeviceIdentityException(this.code, this.message, [this.cause]);

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'PersonalDeviceIdentityException($code): $message';
}

String _base64Url(List<int> value) =>
    base64Url.encode(value).replaceAll('=', '');

List<int> _base64UrlDecode(String value) {
  final padded = value.padRight((value.length + 3) ~/ 4 * 4, '=');
  return base64Url.decode(padded);
}

/// Seals the 32-byte workspace E2EE key to a candidate's X25519 public key.
/// The gateway can store this envelope but cannot decrypt it.
final class WorkspaceKeySealer {
  WorkspaceKeySealer({X25519? x25519, AesGcm? cipher, Hkdf? hkdf})
    : _x25519 = x25519 ?? X25519(),
      _cipher = cipher ?? AesGcm.with256bits(),
      _hkdf = hkdf ?? Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  static const _schemaVersion = 1;
  static const _salt = 'synapse.workspace-key.seal.v1';

  final X25519 _x25519;
  final AesGcm _cipher;
  final Hkdf _hkdf;

  Future<String> seal({
    required WorkspaceSyncKey workspaceKey,
    required String recipientEncryptionPublicKey,
  }) async {
    KeyPair? ephemeral;
    try {
      final recipientBytes = _base64UrlDecode(recipientEncryptionPublicKey);
      if (recipientBytes.length != 32) throw const FormatException();
      final recipient = SimplePublicKey(
        recipientBytes,
        type: KeyPairType.x25519,
      );
      final activeEphemeral = await _x25519.newKeyPair();
      ephemeral = activeEphemeral;
      final ephemeralPublic = await activeEphemeral.extractPublicKey();
      final ephemeralBytes = Uint8List.fromList(ephemeralPublic.bytes);
      final shared = await _x25519.sharedSecretKey(
        keyPair: activeEphemeral,
        remotePublicKey: recipient,
      );
      final derived = await _deriveSealingKey(
        shared: shared,
        ephemeralPublicKey: ephemeralBytes,
        recipientPublicKey: recipientBytes,
      );
      final aad = utf8.encode(
        'synapse.workspace-key.seal.v1:${workspaceKey.version}',
      );
      final box = await _cipher.encrypt(
        workspaceKey.bytes,
        secretKey: derived,
        aad: aad,
      );
      return _base64Url(
        utf8.encode(
          jsonEncode({
            'schemaVersion': _schemaVersion,
            'workspaceKeyVersion': workspaceKey.version,
            'ephemeralPublicKey': _base64Url(ephemeralBytes),
            'nonce': _base64Url(box.nonce),
            'cipherText': _base64Url(box.cipherText),
            'authenticationTag': _base64Url(box.mac.bytes),
          }),
        ),
      );
    } on PersonalDeviceIdentityException {
      rethrow;
    } on Object catch (error) {
      throw PersonalDeviceIdentityException(
        'workspace_key_seal_failed',
        'The workspace key could not be sealed for the paired device.',
        error,
      );
    } finally {
      ephemeral?.destroy();
    }
  }

  Future<WorkspaceSyncKey> unseal({
    required String sealedWorkspaceKey,
    required PersonalDeviceIdentity recipient,
  }) async {
    SimpleKeyPairData? recipientPair;
    try {
      final decoded = jsonDecode(
        utf8.decode(_base64UrlDecode(sealedWorkspaceKey)),
      );
      if (decoded is! Map || decoded['schemaVersion'] != _schemaVersion) {
        throw const FormatException();
      }
      final version = decoded['workspaceKeyVersion'];
      if (version is! int || version < 1) throw const FormatException();
      final ephemeralBytes = _base64UrlDecode(
        decoded['ephemeralPublicKey'] as String,
      );
      final nonce = _base64UrlDecode(decoded['nonce'] as String);
      final cipherText = _base64UrlDecode(decoded['cipherText'] as String);
      final tag = _base64UrlDecode(decoded['authenticationTag'] as String);
      if (ephemeralBytes.length != 32 ||
          nonce.length != 12 ||
          tag.length != 16) {
        throw const FormatException();
      }
      recipientPair = recipient._encryptionKeyPair();
      final shared = await _x25519.sharedSecretKey(
        keyPair: recipientPair,
        remotePublicKey: SimplePublicKey(
          ephemeralBytes,
          type: KeyPairType.x25519,
        ),
      );
      final derived = await _deriveSealingKey(
        shared: shared,
        ephemeralPublicKey: ephemeralBytes,
        recipientPublicKey: recipient._encryptionPublicKey,
      );
      final plain = await _cipher.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(tag)),
        secretKey: derived,
        aad: utf8.encode('synapse.workspace-key.seal.v1:$version'),
      );
      return WorkspaceSyncKey(version: version, bytes: plain);
    } on PersonalDeviceIdentityException {
      rethrow;
    } on Object catch (error) {
      throw PersonalDeviceIdentityException(
        'workspace_key_unseal_failed',
        'The paired workspace key envelope could not be authenticated.',
        error,
      );
    } finally {
      recipientPair?.destroy();
    }
  }

  Future<SecretKey> _deriveSealingKey({
    required SecretKey shared,
    required List<int> ephemeralPublicKey,
    required List<int> recipientPublicKey,
  }) => _hkdf.deriveKey(
    secretKey: shared,
    nonce: utf8.encode(_salt),
    info: utf8.encode(
      'ephemeral=${_base64Url(ephemeralPublicKey)};recipient='
      '${_base64Url(recipientPublicKey)}',
    ),
  );
}

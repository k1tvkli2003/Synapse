import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_services/synapse_services.dart';

/// Passphrase-encrypted offline recovery material for the single-owner
/// workspace. The server receives only [RecoveryKitData.recoveryVerifierSha256]
/// during recovery; it never receives the passphrase or the workspace keys.
///
/// PBKDF2 is used intentionally here because its WebCrypto implementation is
/// available on every target Synapse supports. The format is versioned so a
/// future memory-hard KDF can be introduced without weakening existing kits.
final class RecoveryKitCodec {
  RecoveryKitCodec({
    List<int> Function(int length)? randomBytes,
    DateTime Function()? now,
  }) : _randomBytes = randomBytes ?? _secureRandomBytes,
       _now = now ?? (() => DateTime.now().toUtc());

  static const schemaVersion = 1;
  static const kdfAlgorithm = 'pbkdf2-hmac-sha256';
  static const kdfIterations = 600000;
  static const _minimumKdfIterations = 600000;
  static const _maximumKdfIterations = 2000000;
  static const _aad = 'synapse.personal-recovery-kit.v1';

  final List<int> Function(int length) _randomBytes;
  final DateTime Function() _now;
  final AesGcm _cipher = AesGcm.with256bits();

  Future<RecoveryKitDraft> prepare({required String passphrase}) async {
    _validatePassphrase(passphrase);
    final salt = Uint8List.fromList(_randomBytes(32));
    final recoverySecret = Uint8List.fromList(_randomBytes(32));
    final key = await _deriveKey(
      passphrase: passphrase,
      salt: salt,
      iterations: kdfIterations,
    );
    return RecoveryKitDraft._(
      codec: this,
      salt: salt,
      recoverySecret: recoverySecret,
      encryptionKey: key,
      createdAt: _now(),
    );
  }

  Future<RecoveryKitData> open({
    required String serialized,
    required String passphrase,
  }) async {
    _validatePassphrase(passphrase);
    SecretKey? key;
    try {
      final envelope = _decodeEnvelope(serialized);
      key = await _deriveKey(
        passphrase: passphrase,
        salt: envelope.salt,
        iterations: envelope.iterations,
      );
      final clear = await _cipher.decrypt(
        SecretBox(
          envelope.cipherText,
          nonce: envelope.nonce,
          mac: Mac(envelope.authenticationTag),
        ),
        secretKey: key,
        aad: utf8.encode(_aad),
      );
      return _decodePayload(clear);
    } on RecoveryKitException {
      rethrow;
    } on Object catch (error) {
      throw RecoveryKitException(
        'recovery_kit_authentication_failed',
        'The recovery kit could not be unlocked with this passphrase.',
        error,
      );
    } finally {
      key?.destroy();
    }
  }

  Future<SecretKey> _deriveKey({
    required String passphrase,
    required List<int> salt,
    required int iterations,
  }) {
    if (iterations < _minimumKdfIterations ||
        iterations > _maximumKdfIterations) {
      throw const RecoveryKitException(
        'unsupported_recovery_kdf',
        'The recovery kit uses an unsupported key-derivation configuration.',
      );
    }
    return Pbkdf2.hmacSha256(
      iterations: iterations,
      bits: 256,
    ).deriveKeyFromPassword(password: passphrase, nonce: salt);
  }

  _RecoveryEnvelope _decodeEnvelope(String serialized) {
    try {
      final decoded = jsonDecode(serialized);
      if (decoded is! Map || decoded['schemaVersion'] != schemaVersion) {
        throw const FormatException();
      }
      final rawKdf = decoded['kdf'];
      if (rawKdf is! Map || rawKdf['algorithm'] != kdfAlgorithm) {
        throw const FormatException();
      }
      final iterations = rawKdf['iterations'];
      final salt = _decodeBase64Url(rawKdf['salt']);
      final nonce = _decodeBase64Url(decoded['nonce']);
      final cipherText = _decodeBase64Url(decoded['cipherText']);
      final tag = _decodeBase64Url(decoded['authenticationTag']);
      if (iterations is! int ||
          salt.length != 32 ||
          nonce.length != 12 ||
          tag.length != 16 ||
          cipherText.isEmpty) {
        throw const FormatException();
      }
      return _RecoveryEnvelope(
        iterations: iterations,
        salt: salt,
        nonce: nonce,
        cipherText: cipherText,
        authenticationTag: tag,
      );
    } on RecoveryKitException {
      rethrow;
    } on Object catch (error) {
      throw RecoveryKitException(
        'invalid_recovery_kit',
        'The recovery kit file is invalid or unsupported.',
        error,
      );
    }
  }

  RecoveryKitData _decodePayload(List<int> clear) {
    try {
      final decoded = jsonDecode(utf8.decode(clear));
      if (decoded is! Map || decoded['schemaVersion'] != schemaVersion) {
        throw const FormatException();
      }
      final rawKeys = decoded['keys'];
      if (rawKeys is! List || rawKeys.isEmpty || rawKeys.length > 8) {
        throw const FormatException();
      }
      final keys = rawKeys
          .map((value) {
            if (value is! Map ||
                value['version'] is! int ||
                value['keyMaterial'] is! String) {
              throw const FormatException();
            }
            return WorkspaceSyncKey(
              version: value['version'] as int,
              bytes: _decodeBase64Url(value['keyMaterial']),
            );
          })
          .toList(growable: false);
      if (keys.map((key) => key.version).toSet().length != keys.length) {
        throw const FormatException();
      }
      final workspaceId = decoded['workspaceId'];
      final recoveryGeneration = decoded['recoveryGeneration'];
      final createdAt = decoded['createdAt'];
      final recoverySecret = _decodeBase64Url(decoded['recoverySecret']);
      if (workspaceId is! String ||
          !_identifier.hasMatch(workspaceId) ||
          recoveryGeneration is! int ||
          recoveryGeneration < 1 ||
          createdAt is! String ||
          recoverySecret.length != 32) {
        throw const FormatException();
      }
      return RecoveryKitData(
        workspaceId: workspaceId,
        recoveryGeneration: recoveryGeneration,
        keys: keys,
        recoveryVerifierSha256: _sha256(recoverySecret),
        createdAt: DateTime.parse(createdAt),
      );
    } on RecoveryKitException {
      rethrow;
    } on Object catch (error) {
      throw RecoveryKitException(
        'invalid_recovery_kit_payload',
        'The recovery kit payload is invalid or incomplete.',
        error,
      );
    }
  }

  static void _validatePassphrase(String value) {
    if (value.runes.length < 12 || value.runes.length > 256) {
      throw const RecoveryKitException(
        'invalid_recovery_passphrase',
        'Choose a recovery passphrase between 12 and 256 characters.',
      );
    }
  }

  static List<int> _secureRandomBytes(int length) {
    final key = SecretKeyData.random(length: length);
    try {
      return Uint8List.fromList(key.bytes);
    } finally {
      key.destroy();
    }
  }
}

/// Holds short-lived in-memory encryption material only until the initial kit
/// has been sealed. Call [seal] exactly once, or [dispose] when bootstrap is
/// abandoned.
final class RecoveryKitDraft {
  RecoveryKitDraft._({
    required this._codec,
    required this._salt,
    required Uint8List recoverySecret,
    required this._encryptionKey,
    required DateTime createdAt,
  }) : _recoverySecret = recoverySecret,
       createdAt = createdAt.toUtc(),
       recoveryVerifierSha256 = _sha256(recoverySecret);

  final RecoveryKitCodec _codec;
  final Uint8List _salt;
  final Uint8List _recoverySecret;
  SecretKey? _encryptionKey;
  final DateTime createdAt;

  /// This is the only recovery proof sent to the private gateway.
  final String recoveryVerifierSha256;

  Future<EncryptedRecoveryKit> seal({
    required PersonalWorkspace workspace,
    required Iterable<WorkspaceSyncKey> keys,
  }) async {
    final encryptionKey = _encryptionKey;
    if (encryptionKey == null) {
      throw const RecoveryKitException(
        'recovery_draft_consumed',
        'This recovery-kit draft has already been sealed or discarded.',
      );
    }
    _encryptionKey = null;
    try {
      final snapshot =
          keys
              .map(
                (key) =>
                    WorkspaceSyncKey(version: key.version, bytes: key.bytes),
              )
              .toList()
            ..sort((left, right) => left.version.compareTo(right.version));
      if (snapshot.isEmpty ||
          snapshot.length > 8 ||
          snapshot.map((key) => key.version).toSet().length !=
              snapshot.length ||
          !snapshot.any((key) => key.version == workspace.keyVersion)) {
        throw const RecoveryKitException(
          'invalid_recovery_keyring',
          'The recovery kit requires the active workspace key and its retained history.',
        );
      }
      final payload = utf8.encode(
        jsonEncode({
          'schemaVersion': RecoveryKitCodec.schemaVersion,
          'workspaceId': workspace.id,
          'recoveryGeneration': workspace.recoveryGeneration,
          'createdAt': createdAt.toIso8601String(),
          'recoverySecret': _base64Url(_recoverySecret),
          'keys': snapshot
              .map(
                (key) => {
                  'version': key.version,
                  'keyMaterial': _base64Url(key.bytes),
                },
              )
              .toList(growable: false),
        }),
      );
      final box = await _codec._cipher.encrypt(
        payload,
        secretKey: encryptionKey,
        aad: utf8.encode(RecoveryKitCodec._aad),
      );
      return EncryptedRecoveryKit._(
        iterations: RecoveryKitCodec.kdfIterations,
        salt: _salt,
        nonce: box.nonce,
        cipherText: box.cipherText,
        authenticationTag: box.mac.bytes,
      );
    } on RecoveryKitException {
      rethrow;
    } on Object catch (error) {
      throw RecoveryKitException(
        'recovery_kit_seal_failed',
        'The recovery kit could not be sealed.',
        error,
      );
    } finally {
      encryptionKey.destroy();
      _recoverySecret.fillRange(0, _recoverySecret.length, 0);
    }
  }

  void dispose() {
    final encryptionKey = _encryptionKey;
    _encryptionKey = null;
    encryptionKey?.destroy();
    _recoverySecret.fillRange(0, _recoverySecret.length, 0);
  }
}

final class EncryptedRecoveryKit {
  EncryptedRecoveryKit._({
    required this.iterations,
    required List<int> salt,
    required List<int> nonce,
    required List<int> cipherText,
    required List<int> authenticationTag,
  }) : _salt = Uint8List.fromList(salt),
       _nonce = Uint8List.fromList(nonce),
       _cipherText = Uint8List.fromList(cipherText),
       _authenticationTag = Uint8List.fromList(authenticationTag);

  final int iterations;
  final Uint8List _salt;
  final Uint8List _nonce;
  final Uint8List _cipherText;
  final Uint8List _authenticationTag;

  String serialize() => jsonEncode({
    'schemaVersion': RecoveryKitCodec.schemaVersion,
    'kdf': {
      'algorithm': RecoveryKitCodec.kdfAlgorithm,
      'iterations': iterations,
      'salt': _base64Url(_salt),
    },
    'nonce': _base64Url(_nonce),
    'cipherText': _base64Url(_cipherText),
    'authenticationTag': _base64Url(_authenticationTag),
  });
}

final class RecoveryKitData {
  RecoveryKitData({
    required this.workspaceId,
    required this.recoveryGeneration,
    required Iterable<WorkspaceSyncKey> keys,
    required this.recoveryVerifierSha256,
    required DateTime createdAt,
  }) : keys = List.unmodifiable(
         keys
             .map(
               (key) =>
                   WorkspaceSyncKey(version: key.version, bytes: key.bytes),
             )
             .toList(growable: false),
       ),
       createdAt = createdAt.toUtc() {
    if (!_identifier.hasMatch(workspaceId) || recoveryGeneration < 1) {
      throw const RecoveryKitException(
        'invalid_recovery_kit_data',
        'The recovery kit data is invalid.',
      );
    }
    if (this.keys.isEmpty || this.keys.length > 8) {
      throw const RecoveryKitException(
        'invalid_recovery_kit_data',
        'The recovery kit data is invalid.',
      );
    }
  }

  final PersonalWorkspaceId workspaceId;
  final int recoveryGeneration;
  final List<WorkspaceSyncKey> keys;
  final String recoveryVerifierSha256;
  final DateTime createdAt;

  WorkspaceSyncKey get newestKey =>
      keys.reduce((latest, key) => key.version > latest.version ? key : latest);
}

final class RecoveryKitException implements Exception {
  const RecoveryKitException(this.code, this.message, [this.cause]);

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'RecoveryKitException($code): $message';
}

final class _RecoveryEnvelope {
  const _RecoveryEnvelope({
    required this.iterations,
    required this.salt,
    required this.nonce,
    required this.cipherText,
    required this.authenticationTag,
  });

  final int iterations;
  final List<int> salt;
  final List<int> nonce;
  final List<int> cipherText;
  final List<int> authenticationTag;
}

final _identifier = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,159}$');

String _base64Url(List<int> value) =>
    base64Url.encode(value).replaceAll('=', '');

List<int> _decodeBase64Url(Object? value) {
  if (value is! String || value.isEmpty || value.length > 4 * 1024 * 1024) {
    throw const FormatException();
  }
  final padded = value.padRight((value.length + 3) ~/ 4 * 4, '=');
  return base64Url.decode(padded);
}

String _sha256(List<int> value) => hashes.sha256.convert(value).toString();

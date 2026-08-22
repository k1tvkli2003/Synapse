import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:synapse_services/synapse_services.dart';

abstract interface class SecureStringStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

final class FlutterSecureStringStore implements SecureStringStore {
  const FlutterSecureStringStore([
    this._storage = const FlutterSecureStorage(),
  ]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Device-bound key provider for the indexed learner Data Plane.
///
/// Only the 32-byte root key envelope enters platform secure storage. SQLite,
/// SharedPreferences, exports, sync, logs and analytics never receive it.
final class SecureLearnerDataKeyProvider implements LearnerDataKeyProvider {
  factory SecureLearnerDataKeyProvider({
    required SecureStringStore secureStore,
    List<int> Function(int length)? randomBytes,
    Duration operationTimeout = const Duration(seconds: 5),
  }) => SecureLearnerDataKeyProvider._(
    secureStore,
    randomBytes ?? _secureRandomBytes,
    operationTimeout,
  );

  SecureLearnerDataKeyProvider._(
    this._secureStore,
    this._randomBytes,
    this._operationTimeout,
  ) {
    if (_operationTimeout <= Duration.zero) {
      throw ArgumentError.value(
        _operationTimeout,
        'operationTimeout',
        'Secure-storage operation timeout must be positive.',
      );
    }
  }

  static const currentVersion = 1;
  static const _schemaVersion = 1;
  static const storageKey = 'synapse.learner_data_plane.master_key.v1';

  final SecureStringStore _secureStore;
  final List<int> Function(int length) _randomBytes;
  final Duration _operationTimeout;
  Future<LearnerDataKey>? _pendingCurrentKey;

  @override
  Future<LearnerDataKey> currentKey() {
    final pending = _pendingCurrentKey;
    if (pending != null) return pending;
    final started = _loadOrCreateCurrentKey();
    _pendingCurrentKey = started;
    return _resetAfterFailure(started);
  }

  @override
  Future<LearnerDataKey?> readKey(int version) => version == currentVersion
      ? currentKey()
      : Future<LearnerDataKey?>.value();

  Future<LearnerDataKey> _loadOrCreateCurrentKey() async {
    final existing = await _readEnvelope();
    if (existing != null) return _decode(existing);
    final bytes = _randomBytes(32);
    if (bytes.length != 32 || bytes.any((value) => value < 0 || value > 255)) {
      throw const LearnerDataPlaneException(
        'learner_data_key_generation_failed',
        'The platform could not generate a valid learner Data Plane key.',
      );
    }
    final key = LearnerDataKey(version: currentVersion, bytes: bytes);
    final envelope = jsonEncode({
      'schemaVersion': _schemaVersion,
      'keyVersion': currentVersion,
      'keyMaterial': base64Encode(key.bytes),
    });
    await _writeEnvelope(envelope);
    return key;
  }

  Future<LearnerDataKey> _resetAfterFailure(
    Future<LearnerDataKey> pending,
  ) async {
    try {
      return await pending;
    } on Object catch (error, stack) {
      if (identical(_pendingCurrentKey, pending)) _pendingCurrentKey = null;
      Error.throwWithStackTrace(error, stack);
    }
  }

  Future<String?> _readEnvelope() async {
    try {
      return await _secureStore.read(storageKey).timeout(_operationTimeout);
    } on TimeoutException catch (error) {
      throw LearnerDataPlaneException(
        'secure_learner_data_key_read_timeout',
        'Platform secure storage did not return the learner key in time.',
        error,
      );
    }
  }

  Future<void> _writeEnvelope(String envelope) async {
    try {
      await _secureStore.write(storageKey, envelope).timeout(_operationTimeout);
    } on TimeoutException catch (error) {
      throw LearnerDataPlaneException(
        'secure_learner_data_key_write_timeout',
        'Platform secure storage did not persist the learner key in time.',
        error,
      );
    }
  }

  static LearnerDataKey _decode(String envelope) {
    try {
      final decoded = jsonDecode(envelope);
      if (decoded is! Map ||
          decoded['schemaVersion'] != _schemaVersion ||
          decoded['keyVersion'] != currentVersion ||
          decoded['keyMaterial'] is! String) {
        throw const FormatException('Unsupported key envelope.');
      }
      final bytes = base64Decode(decoded['keyMaterial'] as String);
      if (bytes.length != 32) {
        throw const FormatException('Invalid key material length.');
      }
      return LearnerDataKey(version: currentVersion, bytes: bytes);
    } on Object catch (error) {
      throw LearnerDataPlaneException(
        'corrupt_learner_data_key_envelope',
        'The secure learner Data Plane key envelope is invalid.',
        error,
      );
    }
  }

  static List<int> _secureRandomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }
}

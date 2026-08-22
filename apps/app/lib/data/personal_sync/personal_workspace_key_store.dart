import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:synapse_services/synapse_services.dart';

import '../learner_data/secure_learner_data_key_provider.dart';

/// A separate keyring for remotely synchronized personal data. It deliberately
/// does not reuse the local learner-data-plane root key, so a pairing or
/// recovery operation can never rewrite the device-local encryption boundary.
final class SecureWorkspaceSyncKeyProvider implements WorkspaceSyncKeyProvider {
  SecureWorkspaceSyncKeyProvider({
    required SecureStringStore secureStore,
    List<int> Function(int length)? randomBytes,
    Duration operationTimeout = const Duration(seconds: 5),
  }) : this._(
         secureStore: secureStore,
         randomBytes: randomBytes ?? _secureRandomBytes,
         operationTimeout: operationTimeout,
       );

  SecureWorkspaceSyncKeyProvider._({
    required this._secureStore,
    required this._randomBytes,
    required this._operationTimeout,
  });

  static const storageKey = 'synapse.personal_sync.workspace_keyring.v1';
  static const _schemaVersion = 1;
  static const _maximumRetainedVersions = 8;

  final SecureStringStore _secureStore;
  final List<int> Function(int length) _randomBytes;
  final Duration _operationTimeout;

  @override
  Future<WorkspaceSyncKey> currentKey() async {
    final keyring = await _readKeyring();
    final key = keyring.current;
    if (key == null) {
      throw const PersonalWorkspaceKeyException(
        'workspace_key_missing',
        'This device has not yet received a personal workspace key.',
      );
    }
    return key;
  }

  @override
  Future<WorkspaceSyncKey?> readKey(int version) async =>
      (await _readKeyring()).keys[version];

  /// Used only while creating the first Windows root device. A paired device
  /// must call [install] with its sealed key instead of generating a new one.
  Future<WorkspaceSyncKey> createInitialKey() async {
    final existing = await _readKeyring();
    if (existing.current != null) return existing.current!;
    final key = WorkspaceSyncKey(version: 1, bytes: _randomBytes(32));
    await _writeKeyring(_WorkspaceKeyring(currentVersion: 1, keys: {1: key}));
    return key;
  }

  Future<void> install(WorkspaceSyncKey key, {bool makeCurrent = true}) async {
    final existing = await _readKeyring();
    final keys = <int, WorkspaceSyncKey>{...existing.keys, key.version: key};
    if (keys.length > _maximumRetainedVersions) {
      final oldest = keys.keys.toList()..sort();
      while (keys.length > _maximumRetainedVersions) {
        keys.remove(oldest.removeAt(0));
      }
    }
    await _writeKeyring(
      _WorkspaceKeyring(
        currentVersion: makeCurrent ? key.version : existing.currentVersion,
        keys: keys,
      ),
    );
  }

  /// Returns copies of the retained key history for an explicitly requested,
  /// passphrase-encrypted Recovery Kit. This is never used for ordinary sync.
  Future<List<WorkspaceSyncKey>> snapshotForRecovery() async {
    final keyring = await _readKeyring();
    return List.unmodifiable(
      keyring.keys.values
          .map(
            (key) => WorkspaceSyncKey(version: key.version, bytes: key.bytes),
          )
          .toList()
        ..sort((left, right) => left.version.compareTo(right.version)),
    );
  }

  Future<_WorkspaceKeyring> _readKeyring() async {
    try {
      final encoded = await _secureStore
          .read(storageKey)
          .timeout(_operationTimeout);
      if (encoded == null) return const _WorkspaceKeyring.empty();
      final decoded = jsonDecode(encoded);
      if (decoded is! Map || decoded['schemaVersion'] != _schemaVersion) {
        throw const FormatException();
      }
      final currentVersion = decoded['currentVersion'];
      final rawKeys = decoded['keys'];
      if (currentVersion is! int || rawKeys is! Map) {
        throw const FormatException();
      }
      final keys = <int, WorkspaceSyncKey>{};
      for (final entry in rawKeys.entries) {
        final version = int.tryParse(entry.key.toString());
        if (version == null || entry.value is! String) {
          throw const FormatException();
        }
        keys[version] = WorkspaceSyncKey(
          version: version,
          bytes: base64Url.decode(_pad(entry.value as String)),
        );
      }
      final result = _WorkspaceKeyring(
        currentVersion: currentVersion,
        keys: keys,
      );
      if (result.current == null) throw const FormatException();
      return result;
    } on PersonalWorkspaceKeyException {
      rethrow;
    } on TimeoutException catch (error) {
      throw PersonalWorkspaceKeyException(
        'workspace_key_read_timeout',
        'Secure workspace-key storage did not respond in time.',
        error,
      );
    } on Object catch (error) {
      throw PersonalWorkspaceKeyException(
        'corrupt_workspace_keyring',
        'Secure workspace-key storage is invalid.',
        error,
      );
    }
  }

  Future<void> _writeKeyring(_WorkspaceKeyring keyring) async {
    try {
      await _secureStore
          .write(
            storageKey,
            jsonEncode({
              'schemaVersion': _schemaVersion,
              'currentVersion': keyring.currentVersion,
              'keys': {
                for (final entry in keyring.keys.entries)
                  '${entry.key}': base64Url
                      .encode(entry.value.bytes)
                      .replaceAll('=', ''),
              },
            }),
          )
          .timeout(_operationTimeout);
    } on TimeoutException catch (error) {
      throw PersonalWorkspaceKeyException(
        'workspace_key_write_timeout',
        'Secure workspace-key storage did not persist the keyring.',
        error,
      );
    }
  }

  static List<int> _secureRandomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }
}

final class _WorkspaceKeyring {
  const _WorkspaceKeyring({required this.currentVersion, required this.keys});
  const _WorkspaceKeyring.empty() : currentVersion = 0, keys = const {};

  final int currentVersion;
  final Map<int, WorkspaceSyncKey> keys;
  WorkspaceSyncKey? get current => keys[currentVersion];
}

final class PersonalWorkspaceKeyException implements Exception {
  const PersonalWorkspaceKeyException(this.code, this.message, [this.cause]);

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'PersonalWorkspaceKeyException($code): $message';
}

String _pad(String value) => value.padRight((value.length + 3) ~/ 4 * 4, '=');

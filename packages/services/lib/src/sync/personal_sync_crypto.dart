import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';
import 'package:synapse_core/synapse_core.dart';

final class WorkspaceSyncKey {
  WorkspaceSyncKey({required this.version, required List<int> bytes})
    : bytes = Uint8List.fromList(bytes) {
    if (version < 1 || this.bytes.length != 32) {
      throw ArgumentError(
        'Workspace sync keys require a positive version and 32 bytes.',
      );
    }
  }

  final int version;
  final Uint8List bytes;
}

abstract interface class WorkspaceSyncKeyProvider {
  Future<WorkspaceSyncKey> currentKey();

  Future<WorkspaceSyncKey?> readKey(int version);
}

final class PersonalSyncClearEvent {
  const PersonalSyncClearEvent({
    required this.id,
    required this.workspaceId,
    required this.deviceId,
    required this.stream,
    required this.entityId,
    required this.kind,
    required this.mergePolicy,
    required this.logicalRevision,
    required this.idempotencyKey,
    required this.clientCreatedAt,
    required this.payload,
    this.tombstone = false,
  });

  final EncryptedSyncEventId id;
  final PersonalWorkspaceId workspaceId;
  final TrustedDeviceId deviceId;
  final String stream;
  final String entityId;
  final PersonalSyncEventKind kind;
  final PersonalSyncMergePolicy mergePolicy;
  final int logicalRevision;
  final String idempotencyKey;
  final DateTime clientCreatedAt;
  final Map<String, Object?> payload;
  final bool tombstone;
}

final class DecryptedPersonalSyncEvent {
  const DecryptedPersonalSyncEvent({
    required this.envelope,
    required this.entityId,
    required this.payload,
  });

  final EncryptedSyncEvent envelope;
  final String entityId;
  final Map<String, Object?> payload;
}

final class PersonalSyncCryptoException implements Exception {
  const PersonalSyncCryptoException(this.code, this.message, [this.cause]);

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'PersonalSyncCryptoException($code): $message';
}

/// End-to-end encryption boundary for remote personal sync.
///
/// The server receives only authenticated metadata, a keyed entity hash and
/// ciphertext. Clear entity IDs and payloads never cross this boundary.
final class PersonalSyncEnvelopeCipher {
  PersonalSyncEnvelopeCipher({required WorkspaceSyncKeyProvider keys})
    : _keys = keys;

  static const payloadSchemaVersion = 1;
  static const maxClearPayloadBytes = 2 * 1024 * 1024;

  final WorkspaceSyncKeyProvider _keys;
  final AesGcm _cipher = AesGcm.with256bits();

  Future<EncryptedSyncEvent> encrypt(PersonalSyncClearEvent clear) async {
    final key = await _keys.currentKey();
    final entityHash = _entityHash(key, clear.entityId);
    final aad = _associatedData(
      id: clear.id,
      workspaceId: clear.workspaceId,
      deviceId: clear.deviceId,
      stream: clear.stream,
      entityHash: entityHash,
      kind: clear.kind,
      mergePolicy: clear.mergePolicy,
      logicalRevision: clear.logicalRevision,
      keyVersion: key.version,
      idempotencyKey: clear.idempotencyKey,
      clientCreatedAt: clear.clientCreatedAt,
      tombstone: clear.tombstone,
    );
    final clearBytes = utf8.encode(
      CanonicalJson.encode({
        'schemaVersion': payloadSchemaVersion,
        'entityId': clear.entityId,
        'payload': clear.payload,
      }),
    );
    if (clearBytes.length > maxClearPayloadBytes) {
      throw const PersonalSyncCryptoException(
        'sync_payload_too_large',
        'A personal sync event exceeds the encrypted payload limit.',
      );
    }
    final secretBox = await _cipher.encrypt(
      clearBytes,
      secretKey: SecretKey(key.bytes),
      aad: utf8.encode(aad),
    );
    return EncryptedSyncEvent(
      id: clear.id,
      workspaceId: clear.workspaceId,
      deviceId: clear.deviceId,
      stream: clear.stream,
      entityHash: entityHash,
      kind: clear.kind,
      mergePolicy: clear.mergePolicy,
      logicalRevision: clear.logicalRevision,
      keyVersion: key.version,
      idempotencyKey: clear.idempotencyKey,
      clientCreatedAt: clear.clientCreatedAt,
      nonce: base64Url.encode(secretBox.nonce),
      cipherText: base64Url.encode(secretBox.cipherText),
      authenticationTag: base64Url.encode(secretBox.mac.bytes),
      tombstone: clear.tombstone,
    );
  }

  Future<DecryptedPersonalSyncEvent> decrypt(
    EncryptedSyncEvent envelope,
  ) async {
    final key = await _keys.readKey(envelope.keyVersion);
    if (key == null) {
      throw const PersonalSyncCryptoException(
        'sync_key_unavailable',
        'The workspace key version required by this event is unavailable.',
      );
    }
    try {
      final clearBytes = await _cipher.decrypt(
        SecretBox(
          base64Url.decode(envelope.cipherText),
          nonce: base64Url.decode(envelope.nonce),
          mac: Mac(base64Url.decode(envelope.authenticationTag)),
        ),
        secretKey: SecretKey(key.bytes),
        aad: utf8.encode(envelope.canonicalAssociatedData()),
      );
      final decoded = jsonDecode(utf8.decode(clearBytes));
      if (decoded is! Map ||
          decoded['schemaVersion'] != payloadSchemaVersion ||
          decoded['entityId'] is! String ||
          decoded['payload'] is! Map) {
        throw const FormatException('Unsupported sync payload.');
      }
      final entityId = decoded['entityId'] as String;
      if (_entityHash(key, entityId) != envelope.entityHash) {
        throw const FormatException('Entity index verification failed.');
      }
      return DecryptedPersonalSyncEvent(
        envelope: envelope,
        entityId: entityId,
        payload: Map<String, Object?>.from(decoded['payload'] as Map),
      );
    } on PersonalSyncCryptoException {
      rethrow;
    } on Object catch (error) {
      throw PersonalSyncCryptoException(
        'sync_event_authentication_failed',
        'A remote personal sync event failed authenticated decryption.',
        error,
      );
    }
  }

  String _entityHash(WorkspaceSyncKey key, String entityId) {
    final hmac = hashes.Hmac(hashes.sha256, key.bytes);
    return hmac.convert(utf8.encode('entity-id\u0000$entityId')).toString();
  }
}

String _associatedData({
  required String id,
  required String workspaceId,
  required String deviceId,
  required String stream,
  required String entityHash,
  required PersonalSyncEventKind kind,
  required PersonalSyncMergePolicy mergePolicy,
  required int logicalRevision,
  required int keyVersion,
  required String idempotencyKey,
  required DateTime clientCreatedAt,
  required bool tombstone,
}) => CanonicalJson.encode({
  'id': id,
  'workspaceId': workspaceId,
  'deviceId': deviceId,
  'stream': stream,
  'entityHash': entityHash,
  'kind': kind.name,
  'mergePolicy': mergePolicy.name,
  'logicalRevision': logicalRevision,
  'keyVersion': keyVersion,
  'idempotencyKey': idempotencyKey,
  'clientCreatedAt': clientCreatedAt.toUtc().toIso8601String(),
  'tombstone': tombstone,
});

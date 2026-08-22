import 'dart:convert';

import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';
import 'package:synapse_core/synapse_core.dart';

import 'learner_data_plane_database.dart';

/// Device-bound root key used to derive independent payload and index keys.
final class LearnerDataKey {
  LearnerDataKey({required this.version, required List<int> bytes})
    : bytes = Uint8List.fromList(bytes) {
    if (version < 1 || this.bytes.length != 32) {
      throw ArgumentError(
        'Learner Data Plane keys require a positive version and 32 bytes.',
      );
    }
  }

  final int version;
  final Uint8List bytes;
}

/// Key-vault boundary. Production implementations must keep key material out of
/// the database, SharedPreferences, logs, exports and analytics.
abstract interface class LearnerDataKeyProvider {
  Future<LearnerDataKey> currentKey();

  Future<LearnerDataKey?> readKey(int version);
}

final class PrivateLearnerRecordDraft {
  const PrivateLearnerRecordDraft({
    required this.namespace,
    required this.recordId,
    required this.scopeId,
    required this.kind,
    required this.updatedAt,
    required this.payload,
    this.tombstone = false,
  });

  final String namespace;
  final String recordId;
  final String scopeId;
  final String kind;
  final DateTime updatedAt;
  final Map<String, Object?> payload;
  final bool tombstone;
}

final class PrivateLearnerRecordMutation {
  const PrivateLearnerRecordMutation({
    required this.draft,
    required this.expectedRevision,
  });

  final PrivateLearnerRecordDraft draft;
  final int? expectedRevision;
}

final class PrivateLearnerRecord {
  const PrivateLearnerRecord({
    required this.namespace,
    required this.recordId,
    required this.scopeId,
    required this.kind,
    required this.revision,
    required this.updatedAt,
    required this.payload,
    required this.tombstone,
  });

  final String namespace;
  final String recordId;
  final String scopeId;
  final String kind;
  final int revision;
  final DateTime updatedAt;
  final Map<String, Object?> payload;
  final bool tombstone;

  PrivateLearnerRecordDraft toDraft() => PrivateLearnerRecordDraft(
    namespace: namespace,
    recordId: recordId,
    scopeId: scopeId,
    kind: kind,
    updatedAt: updatedAt,
    payload: payload,
    tombstone: tombstone,
  );
}

final class PrivateLearnerRecordQuery {
  const PrivateLearnerRecordQuery({
    required this.namespace,
    this.scopeId,
    this.kind,
    this.includeTombstones = false,
    this.limit = 100,
    this.cursor,
  });

  final String namespace;
  final String? scopeId;
  final String? kind;
  final bool includeTombstones;
  final int limit;
  final String? cursor;
}

final class PrivateLearnerRecordPage {
  const PrivateLearnerRecordPage({
    required this.records,
    required this.nextCursor,
  });

  final List<PrivateLearnerRecord> records;
  final String? nextCursor;
}

final class LearnerDataPlaneIntegrityIssue {
  const LearnerDataPlaneIntegrityIssue({
    required this.code,
    required this.message,
    required this.namespace,
    required this.recordIdHash,
  });

  final String code;
  final String message;
  final String namespace;
  final String recordIdHash;
}

final class LearnerDataPlaneException implements Exception {
  const LearnerDataPlaneException(this.code, this.message, [this.cause]);

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'LearnerDataPlaneException($code): $message';
}

abstract interface class IndexedLearnerRecordStore {
  Future<PrivateLearnerRecord?> read({
    required String namespace,
    required String recordId,
  });

  Future<PrivateLearnerRecord> put(
    PrivateLearnerRecordDraft draft, {
    required int? expectedRevision,
  });

  Future<List<PrivateLearnerRecord>> putBatch(
    Iterable<PrivateLearnerRecordMutation> mutations,
  );

  Future<List<PrivateLearnerRecord>> query(PrivateLearnerRecordQuery query);

  Future<PrivateLearnerRecordPage> queryPage(PrivateLearnerRecordQuery query);

  Future<List<PrivateLearnerRecord>> exportNamespace(String namespace);

  Future<int> deleteNamespace(String namespace);

  Future<List<LearnerDataPlaneIntegrityIssue>> auditIntegrity();
}

/// Record-oriented, queryable learner Data Plane using AES-256-GCM payloads
/// and keyed HMAC-SHA256 identifiers.
///
/// SQLite sees operational namespace/kind/revision/tombstone/timestamp fields,
/// but never sees a cleartext learner record ID, resource scope, note body or
/// artifact payload. Authenticated associated data binds those operational
/// fields to the ciphertext, preventing undetected row metadata substitution.
final class EncryptedIndexedLearnerRecordStore
    implements IndexedLearnerRecordStore {
  factory EncryptedIndexedLearnerRecordStore({
    required LearnerDataPlaneDatabase database,
    required LearnerDataKeyProvider keys,
  }) => EncryptedIndexedLearnerRecordStore._(database, keys);

  EncryptedIndexedLearnerRecordStore._(this._database, this._keys);

  static const encryptedPayloadSchemaVersion = 1;
  static const maxPayloadBytes = 2 * 1024 * 1024;
  static final _tokenPattern = RegExp(r'^[a-z0-9][a-z0-9._-]*$');

  final LearnerDataPlaneDatabase _database;
  final LearnerDataKeyProvider _keys;
  final AesGcm _cipher = AesGcm.with256bits();

  @override
  Future<PrivateLearnerRecord?> read({
    required String namespace,
    required String recordId,
  }) async {
    _validateToken(namespace, field: 'namespace');
    _validateOpaqueId(recordId, field: 'recordId');
    final key = await _currentKey();
    final recordHash = _indexHash(key, 'record-id', recordId);
    final row =
        await (_database.select(_database.encryptedLearnerRecords)..where(
              (table) =>
                  table.namespace.equals(namespace) &
                  table.recordIdHash.equals(recordHash),
            ))
            .getSingleOrNull();
    if (row == null) return null;
    final value = await _decrypt(row);
    if (value.recordId != recordId) {
      throw const LearnerDataPlaneException(
        'learner_record_index_collision',
        'Encrypted learner record identity failed index verification.',
      );
    }
    return value;
  }

  @override
  Future<PrivateLearnerRecord> put(
    PrivateLearnerRecordDraft draft, {
    required int? expectedRevision,
  }) async => (await putBatch([
    PrivateLearnerRecordMutation(
      draft: draft,
      expectedRevision: expectedRevision,
    ),
  ])).single;

  @override
  Future<List<PrivateLearnerRecord>> putBatch(
    Iterable<PrivateLearnerRecordMutation> mutations,
  ) async {
    final batch = List<PrivateLearnerRecordMutation>.unmodifiable(mutations);
    if (batch.isEmpty || batch.length > 500) {
      throw const LearnerDataPlaneException(
        'invalid_learner_record_batch_size',
        'Private learner record batches require between 1 and 500 mutations.',
      );
    }
    for (final mutation in batch) {
      _validateDraft(mutation.draft);
      if (mutation.expectedRevision case final revision? when revision < 1) {
        throw const LearnerDataPlaneException(
          'invalid_expected_learner_record_revision',
          'Expected learner record revision must be positive when present.',
        );
      }
    }
    final key = await _currentKey();
    return _database.transaction(() async {
      final seen = <String>{};
      final planned =
          <({PrivateLearnerRecord value, EncryptedLearnerRecordRow? row})>[];
      for (final mutation in batch) {
        final draft = mutation.draft;
        final recordHash = _indexHash(key, 'record-id', draft.recordId);
        final scopeHash = _indexHash(key, 'scope-id', draft.scopeId);
        if (!seen.add('${draft.namespace}\u0000$recordHash')) {
          throw const LearnerDataPlaneException(
            'duplicate_learner_record_batch_identity',
            'A private learner record batch contains a duplicate identity.',
          );
        }
        final existingRow =
            await (_database.select(_database.encryptedLearnerRecords)..where(
                  (table) =>
                      table.namespace.equals(draft.namespace) &
                      table.recordIdHash.equals(recordHash),
                ))
                .getSingleOrNull();
        final existing = existingRow == null
            ? null
            : await _decrypt(existingRow);
        if (existing != null && existing.recordId != draft.recordId) {
          throw const LearnerDataPlaneException(
            'learner_record_index_collision',
            'Encrypted learner record identity failed index verification.',
          );
        }
        if (existing != null && _sameContent(existing, draft)) {
          planned.add((value: existing, row: null));
          continue;
        }
        if (existing == null && mutation.expectedRevision != null ||
            existing != null &&
                existing.revision != mutation.expectedRevision) {
          throw const LearnerDataPlaneException(
            'stale_learner_record_revision',
            'The private learner record changed after this view opened.',
          );
        }
        final updatedAt = draft.updatedAt.toUtc();
        if (existing != null && updatedAt.isBefore(existing.updatedAt)) {
          throw const LearnerDataPlaneException(
            'non_monotonic_learner_record_time',
            'The private learner record timestamp moved backwards.',
          );
        }
        final value = PrivateLearnerRecord(
          namespace: draft.namespace,
          recordId: draft.recordId,
          scopeId: draft.scopeId,
          kind: draft.kind,
          revision: (existing?.revision ?? 0) + 1,
          updatedAt: updatedAt,
          payload: _jsonCopy(draft.payload),
          tombstone: draft.tombstone,
        );
        planned.add((
          value: value,
          row: await _encrypt(
            value,
            key: key,
            recordIdHash: recordHash,
            scopeHash: scopeHash,
          ),
        ));
      }
      for (final item in planned) {
        if (item.row case final row?) {
          await _database
              .into(_database.encryptedLearnerRecords)
              .insertOnConflictUpdate(row);
        }
      }
      return List.unmodifiable(planned.map((item) => item.value));
    });
  }

  @override
  Future<List<PrivateLearnerRecord>> query(
    PrivateLearnerRecordQuery query,
  ) async => (await queryPage(query)).records;

  @override
  Future<PrivateLearnerRecordPage> queryPage(
    PrivateLearnerRecordQuery query,
  ) async {
    _validateToken(query.namespace, field: 'namespace');
    if (query.scopeId case final scopeId?) {
      _validateOpaqueId(scopeId, field: 'scopeId');
    }
    if (query.kind case final kind?) {
      _validateToken(kind, field: 'kind');
    }
    if (query.limit < 1 || query.limit > 500) {
      throw const LearnerDataPlaneException(
        'invalid_learner_record_query_limit',
        'Private learner record query limit must be between 1 and 500.',
      );
    }
    final cursor = query.cursor == null
        ? null
        : _QueryCursor.decode(query.cursor!);
    final key = await _currentKey();
    final selection = _database.select(_database.encryptedLearnerRecords)
      ..where((table) {
        Expression<bool> predicate = table.namespace.equals(query.namespace);
        if (query.scopeId case final scopeId?) {
          predicate =
              predicate &
              table.scopeHash.equals(_indexHash(key, 'scope-id', scopeId));
        }
        if (query.kind case final kind?) {
          predicate = predicate & table.kind.equals(kind);
        }
        if (!query.includeTombstones) {
          predicate = predicate & table.tombstone.equals(false);
        }
        if (cursor != null) {
          predicate =
              predicate &
              (table.updatedAtMicros.isSmallerThanValue(
                    cursor.updatedAtMicros,
                  ) |
                  (table.updatedAtMicros.equals(cursor.updatedAtMicros) &
                      table.recordIdHash.isSmallerThanValue(
                        cursor.recordIdHash,
                      )));
        }
        return predicate;
      })
      ..orderBy([
        (table) => OrderingTerm.desc(table.updatedAtMicros),
        (table) => OrderingTerm.desc(table.recordIdHash),
      ])
      ..limit(query.limit);
    final rows = await selection.get();
    final records = List<PrivateLearnerRecord>.unmodifiable(
      await Future.wait(rows.map(_decrypt)),
    );
    final nextCursor = rows.length == query.limit
        ? _QueryCursor(
            updatedAtMicros: rows.last.updatedAtMicros,
            recordIdHash: rows.last.recordIdHash,
          ).encode()
        : null;
    return PrivateLearnerRecordPage(records: records, nextCursor: nextCursor);
  }

  @override
  Future<List<PrivateLearnerRecord>> exportNamespace(String namespace) async {
    _validateToken(namespace, field: 'namespace');
    final rows = await (_database.select(
      _database.encryptedLearnerRecords,
    )..where((table) => table.namespace.equals(namespace))).get();
    final values = await Future.wait(rows.map(_decrypt));
    values.sort((left, right) {
      final byTime = left.updatedAt.compareTo(right.updatedAt);
      return byTime != 0 ? byTime : left.recordId.compareTo(right.recordId);
    });
    return List.unmodifiable(values);
  }

  @override
  Future<int> deleteNamespace(String namespace) async {
    _validateToken(namespace, field: 'namespace');
    return _database.transaction(
      () => (_database.delete(
        _database.encryptedLearnerRecords,
      )..where((table) => table.namespace.equals(namespace))).go(),
    );
  }

  @override
  Future<List<LearnerDataPlaneIntegrityIssue>> auditIntegrity() async {
    final rows = await _database
        .select(_database.encryptedLearnerRecords)
        .get();
    final issues = <LearnerDataPlaneIntegrityIssue>[];
    for (final row in rows) {
      try {
        await _decrypt(row);
      } on Object {
        issues.add(
          LearnerDataPlaneIntegrityIssue(
            code: 'encrypted_learner_record_integrity_failure',
            message:
                'An encrypted learner record failed authenticated validation.',
            namespace: row.namespace,
            recordIdHash: row.recordIdHash,
          ),
        );
      }
    }
    return List.unmodifiable(issues);
  }

  Future<EncryptedLearnerRecordRow> _encrypt(
    PrivateLearnerRecord value, {
    required LearnerDataKey key,
    required String recordIdHash,
    required String scopeHash,
  }) async {
    final clearText = Uint8List.fromList(
      utf8.encode(
        CanonicalJson.encode({
          'schemaVersion': encryptedPayloadSchemaVersion,
          'namespace': value.namespace,
          'recordId': value.recordId,
          'scopeId': value.scopeId,
          'kind': value.kind,
          'revision': value.revision,
          'tombstone': value.tombstone,
          'updatedAt': value.updatedAt.toUtc().toIso8601String(),
          'payload': value.payload,
        }),
      ),
    );
    if (clearText.length > maxPayloadBytes) {
      throw const LearnerDataPlaneException(
        'learner_record_payload_too_large',
        'A private learner record exceeds the encrypted payload limit.',
      );
    }
    final updatedAtMicros = value.updatedAt.microsecondsSinceEpoch;
    final aad = _associatedData(
      namespace: value.namespace,
      recordIdHash: recordIdHash,
      scopeHash: scopeHash,
      kind: value.kind,
      keyVersion: key.version,
      revision: value.revision,
      tombstone: value.tombstone,
      updatedAtMicros: updatedAtMicros,
    );
    final secretBox = await _cipher.encrypt(
      clearText,
      secretKey: SecretKey(_derivedKey(key, 'payload-encryption-v1')),
      nonce: _cipher.newNonce(),
      aad: aad,
    );
    return EncryptedLearnerRecordRow(
      namespace: value.namespace,
      recordIdHash: recordIdHash,
      scopeHash: scopeHash,
      kind: value.kind,
      keyVersion: key.version,
      revision: value.revision,
      tombstone: value.tombstone,
      updatedAtMicros: updatedAtMicros,
      nonce: Uint8List.fromList(secretBox.nonce),
      cipherText: Uint8List.fromList(secretBox.cipherText),
      authenticationMac: Uint8List.fromList(secretBox.mac.bytes),
    );
  }

  Future<PrivateLearnerRecord> _decrypt(EncryptedLearnerRecordRow row) async {
    try {
      final key = await _keys.readKey(row.keyVersion);
      if (key == null) {
        throw const LearnerDataPlaneException(
          'learner_data_key_unavailable',
          'The encryption key for a private learner record is unavailable.',
        );
      }
      final clearBytes = await _cipher.decrypt(
        SecretBox(
          row.cipherText,
          nonce: row.nonce,
          mac: Mac(row.authenticationMac),
        ),
        secretKey: SecretKey(_derivedKey(key, 'payload-encryption-v1')),
        aad: _associatedData(
          namespace: row.namespace,
          recordIdHash: row.recordIdHash,
          scopeHash: row.scopeHash,
          kind: row.kind,
          keyVersion: row.keyVersion,
          revision: row.revision,
          tombstone: row.tombstone,
          updatedAtMicros: row.updatedAtMicros,
        ),
      );
      final decoded = jsonDecode(utf8.decode(clearBytes));
      if (decoded is! Map || decoded.keys.any((key) => key is! String)) {
        throw const FormatException('Encrypted payload must decode to JSON.');
      }
      final json = Map<String, Object?>.from(decoded);
      if (json['schemaVersion'] != encryptedPayloadSchemaVersion ||
          json['namespace'] != row.namespace ||
          json['kind'] != row.kind ||
          json['revision'] != row.revision ||
          json['tombstone'] != row.tombstone) {
        throw const FormatException('Encrypted record envelope drift.');
      }
      final recordId = json['recordId'];
      final scopeId = json['scopeId'];
      final updatedAtText = json['updatedAt'];
      final payload = json['payload'];
      if (recordId is! String ||
          scopeId is! String ||
          updatedAtText is! String ||
          payload is! Map ||
          payload.keys.any((key) => key is! String)) {
        throw const FormatException('Encrypted learner record shape drift.');
      }
      final updatedAt = DateTime.parse(updatedAtText).toUtc();
      if (updatedAt.microsecondsSinceEpoch != row.updatedAtMicros ||
          _indexHash(key, 'record-id', recordId) != row.recordIdHash ||
          _indexHash(key, 'scope-id', scopeId) != row.scopeHash) {
        throw const FormatException('Encrypted learner record index drift.');
      }
      return PrivateLearnerRecord(
        namespace: row.namespace,
        recordId: recordId,
        scopeId: scopeId,
        kind: row.kind,
        revision: row.revision,
        updatedAt: updatedAt,
        payload: _jsonCopy(Map<String, Object?>.from(payload)),
        tombstone: row.tombstone,
      );
    } on LearnerDataPlaneException {
      rethrow;
    } on Object catch (error) {
      throw LearnerDataPlaneException(
        'encrypted_learner_record_invalid',
        'A private learner record failed authenticated validation.',
        error,
      );
    }
  }

  Future<LearnerDataKey> _currentKey() async {
    final key = await _keys.currentKey();
    if (key.version < 1 || key.bytes.length != 32) {
      throw const LearnerDataPlaneException(
        'invalid_learner_data_key',
        'The learner Data Plane key is invalid.',
      );
    }
    return key;
  }

  Uint8List _associatedData({
    required String namespace,
    required String recordIdHash,
    required String scopeHash,
    required String kind,
    required int keyVersion,
    required int revision,
    required bool tombstone,
    required int updatedAtMicros,
  }) => Uint8List.fromList(
    utf8.encode(
      CanonicalJson.encode({
        'schemaVersion': encryptedPayloadSchemaVersion,
        'namespace': namespace,
        'recordIdHash': recordIdHash,
        'scopeHash': scopeHash,
        'kind': kind,
        'keyVersion': keyVersion,
        'revision': revision,
        'tombstone': tombstone,
        'updatedAtMicros': updatedAtMicros,
      }),
    ),
  );

  String _indexHash(LearnerDataKey key, String domain, String value) =>
      hashes.Hmac(
        hashes.sha256,
        _derivedKey(key, 'deterministic-index-v1'),
      ).convert(utf8.encode('$domain\u0000$value')).toString();

  Uint8List _derivedKey(LearnerDataKey key, String domain) =>
      Uint8List.fromList(
        hashes.Hmac(
          hashes.sha256,
          key.bytes,
        ).convert(utf8.encode('synapse-learner-data-plane\u0000$domain')).bytes,
      );

  static bool _sameContent(
    PrivateLearnerRecord existing,
    PrivateLearnerRecordDraft draft,
  ) =>
      existing.namespace == draft.namespace &&
      existing.recordId == draft.recordId &&
      existing.scopeId == draft.scopeId &&
      existing.kind == draft.kind &&
      existing.tombstone == draft.tombstone &&
      CanonicalJson.encode(existing.payload) ==
          CanonicalJson.encode(draft.payload);

  static void _validateDraft(PrivateLearnerRecordDraft draft) {
    _validateToken(draft.namespace, field: 'namespace');
    _validateToken(draft.kind, field: 'kind');
    _validateOpaqueId(draft.recordId, field: 'recordId');
    _validateOpaqueId(draft.scopeId, field: 'scopeId');
    if (draft.updatedAt.microsecondsSinceEpoch <= 0) {
      throw const LearnerDataPlaneException(
        'invalid_learner_record_time',
        'Private learner record time must be after the Unix epoch.',
      );
    }
    try {
      final length = utf8.encode(CanonicalJson.encode(draft.payload)).length;
      if (length > maxPayloadBytes) {
        throw const LearnerDataPlaneException(
          'learner_record_payload_too_large',
          'A private learner record exceeds the encrypted payload limit.',
        );
      }
    } on LearnerDataPlaneException {
      rethrow;
    } on Object catch (error) {
      throw LearnerDataPlaneException(
        'invalid_learner_record_payload',
        'Private learner record payload must be canonical JSON.',
        error,
      );
    }
  }

  static void _validateToken(String value, {required String field}) {
    if (value.length > 80 || !_tokenPattern.hasMatch(value)) {
      throw LearnerDataPlaneException(
        'invalid_learner_record_token',
        '$field is not a valid learner Data Plane token.',
      );
    }
  }

  static void _validateOpaqueId(String value, {required String field}) {
    if (value.trim() != value || value.isEmpty || value.length > 512) {
      throw LearnerDataPlaneException(
        'invalid_learner_record_identifier',
        '$field is not a valid learner Data Plane identifier.',
      );
    }
  }
}

Map<String, Object?> _jsonCopy(Map<String, Object?> value) =>
    Map<String, Object?>.unmodifiable(
      Map<String, Object?>.from(jsonDecode(CanonicalJson.encode(value)) as Map),
    );

final class _QueryCursor {
  const _QueryCursor({
    required this.updatedAtMicros,
    required this.recordIdHash,
  });

  final int updatedAtMicros;
  final String recordIdHash;

  String encode() => base64Url
      .encode(
        utf8.encode(
          CanonicalJson.encode({
            'v': 1,
            'updatedAtMicros': updatedAtMicros,
            'recordIdHash': recordIdHash,
          }),
        ),
      )
      .replaceAll('=', '');

  factory _QueryCursor.decode(String value) {
    try {
      if (value.isEmpty || value.length > 256) throw const FormatException();
      final normalized = value.padRight((value.length + 3) ~/ 4 * 4, '=');
      final decoded = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      if (decoded is! Map ||
          decoded['v'] != 1 ||
          decoded['updatedAtMicros'] is! int ||
          decoded['recordIdHash'] is! String) {
        throw const FormatException();
      }
      final updatedAtMicros = decoded['updatedAtMicros'] as int;
      final recordIdHash = decoded['recordIdHash'] as String;
      if (updatedAtMicros <= 0 ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(recordIdHash)) {
        throw const FormatException();
      }
      return _QueryCursor(
        updatedAtMicros: updatedAtMicros,
        recordIdHash: recordIdHash,
      );
    } on Object catch (error) {
      throw LearnerDataPlaneException(
        'invalid_learner_record_query_cursor',
        'Private learner record query cursor is invalid.',
        error,
      );
    }
  }
}

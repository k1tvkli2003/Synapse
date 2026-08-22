import 'package:synapse_core/synapse_core.dart';

import '../data_plane/encrypted_indexed_learner_record_store.dart';
import 'personal_sync_crypto.dart';
import 'personal_sync_outbox.dart';

/// A locally encrypted, deterministic materialization of personal-sync
/// envelopes. It intentionally sits beside the outbox rather than replacing
/// existing local repositories: native Flutter state stays immediately
/// available offline and this store is the merge-safe replica used by sync.
///
/// The server never receives this clear projection. It receives only the
/// encrypted [EncryptedSyncEvent] envelope produced by
/// [PersonalSyncEnvelopeCipher].
final class PersonalSyncProjectionStore
    implements PersonalSyncProjectionApplier {
  PersonalSyncProjectionStore({required this.records});

  /// Each append-only attempt, reward, and study-history event occupies its
  /// own durable record. Replaying the same event ID is a no-op; substituting
  /// a different payload under an existing event ID fails closed.
  static const ledgerNamespace = 'sync.ledger';

  /// Latest materialized values for progress, mastery, notes, bookmarks,
  /// reading positions, and settings. The payload and entity ID remain inside
  /// the local encrypted Data Plane.
  static const projectionNamespace = 'sync.projection';

  static const _schemaVersion = 1;
  static const _maxApplyAttempts = 4;

  final IndexedLearnerRecordStore records;

  @override
  Future<void> apply(DecryptedPersonalSyncEvent event) async {
    _validateEvent(event);
    switch (event.envelope.mergePolicy) {
      case PersonalSyncMergePolicy.appendOnly:
        await _applyAppendOnly(event);
      case PersonalSyncMergePolicy.monotonicMaximum:
      case PersonalSyncMergePolicy.lastWriteWins:
      case PersonalSyncMergePolicy.tombstoneWins:
        await _applyMaterialized(event);
    }
  }

  /// Reads a merge-safe local projection without exposing implementation
  /// record IDs to feature code.
  Future<PersonalSyncProjectionSnapshot?> readProjection({
    required String stream,
    required String entityId,
  }) async {
    _validateStreamAndEntity(stream: stream, entityId: entityId);
    final record = await records.read(
      namespace: projectionNamespace,
      recordId: _projectionRecordId(stream, entityId),
    );
    if (record == null) return null;
    return PersonalSyncProjectionSnapshot._(_snapshot(record));
  }

  Future<void> _applyAppendOnly(DecryptedPersonalSyncEvent event) async {
    final recordId = _ledgerRecordId(event.envelope.id);
    final incoming = _wire(event);
    final existing = await records.read(
      namespace: ledgerNamespace,
      recordId: recordId,
    );
    if (existing != null) {
      final prior = _snapshot(existing);
      if (prior.eventId != event.envelope.id ||
          CanonicalJson.encode(existing.payload) !=
              CanonicalJson.encode(incoming)) {
        throw const PersonalSyncProjectionException(
          'sync_append_event_conflict',
          'An append-only event ID was reused with different content.',
        );
      }
      return;
    }
    await records.put(
      PrivateLearnerRecordDraft(
        namespace: ledgerNamespace,
        recordId: recordId,
        scopeId: event.envelope.workspaceId,
        kind: personalSyncStorageKind(event.envelope.kind),
        updatedAt: _safeUpdatedAt(event.envelope.clientCreatedAt),
        payload: incoming,
      ),
      expectedRevision: null,
    );
  }

  Future<void> _applyMaterialized(DecryptedPersonalSyncEvent event) async {
    final recordId = _projectionRecordId(event.envelope.stream, event.entityId);
    final incoming = _snapshotFromWire(_wire(event));
    for (var attempt = 0; attempt < _maxApplyAttempts; attempt += 1) {
      final existing = await records.read(
        namespace: projectionNamespace,
        recordId: recordId,
      );
      final next = existing == null
          ? incoming
          : _merge(existing: _snapshot(existing), incoming: incoming);
      if (existing != null && _sameSnapshot(_snapshot(existing), next)) {
        return;
      }
      try {
        await records.put(
          PrivateLearnerRecordDraft(
            namespace: projectionNamespace,
            recordId: recordId,
            scopeId: event.envelope.workspaceId,
            kind: personalSyncStorageKind(event.envelope.kind),
            updatedAt: _latestTime(
              existing?.updatedAt,
              event.envelope.clientCreatedAt,
            ),
            payload: next.toWire(),
            tombstone: next.tombstone,
          ),
          expectedRevision: existing?.revision,
        );
        return;
      } on LearnerDataPlaneException catch (error) {
        if (error.code != 'stale_learner_record_revision' ||
            attempt + 1 >= _maxApplyAttempts) {
          rethrow;
        }
      }
    }
    throw const PersonalSyncProjectionException(
      'sync_projection_contention',
      'The local personal-sync projection changed too frequently to merge safely.',
    );
  }

  _ProjectionSnapshot _merge({
    required _ProjectionSnapshot existing,
    required _ProjectionSnapshot incoming,
  }) {
    if (existing.workspaceId != incoming.workspaceId ||
        existing.stream != incoming.stream ||
        existing.entityId != incoming.entityId ||
        existing.mergePolicy != incoming.mergePolicy) {
      throw const PersonalSyncProjectionException(
        'sync_projection_identity_conflict',
        'A synced entity changed its workspace, stream, or merge contract.',
      );
    }
    switch (incoming.mergePolicy) {
      case PersonalSyncMergePolicy.appendOnly:
        throw const PersonalSyncProjectionException(
          'sync_projection_invalid_policy',
          'Append-only events do not have a materialized projection.',
        );
      case PersonalSyncMergePolicy.lastWriteWins:
        return _compareStamps(incoming, existing) >= 0 ? incoming : existing;
      case PersonalSyncMergePolicy.tombstoneWins:
        // A deletion is never silently resurrected by a delayed device. A user
        // who wants the same note/bookmark again creates a fresh entity ID.
        if (existing.tombstone) return existing;
        if (incoming.tombstone) return incoming;
        return _compareStamps(incoming, existing) >= 0 ? incoming : existing;
      case PersonalSyncMergePolicy.monotonicMaximum:
        if (existing.tombstone) return existing;
        if (incoming.tombstone) return incoming;
        final incomingWins = _compareStamps(incoming, existing) >= 0;
        final winner = incomingWins ? incoming : existing;
        final loser = incomingWins ? existing : incoming;
        return winner.copyWith(
          payload: _mergeMonotonic(
            existing.payload,
            incoming.payload,
            preferIncoming: incomingWins,
          ),
          // Preserve the highest logical revision even when the event that
          // contributed the maximum numeric value originated on a skewed clock.
          logicalRevision: winner.logicalRevision > loser.logicalRevision
              ? winner.logicalRevision
              : loser.logicalRevision,
        );
    }
  }

  Map<String, Object?> _wire(DecryptedPersonalSyncEvent event) => {
    'schemaVersion': _schemaVersion,
    'workspaceId': event.envelope.workspaceId,
    'stream': event.envelope.stream,
    'entityId': event.entityId,
    'kind': event.envelope.kind.name,
    'mergePolicy': event.envelope.mergePolicy.name,
    'logicalRevision': event.envelope.logicalRevision,
    'clientCreatedAt': event.envelope.clientCreatedAt.toUtc().toIso8601String(),
    'deviceId': event.envelope.deviceId,
    'eventId': event.envelope.id,
    'tombstone': event.envelope.tombstone,
    'value': event.payload,
  };

  _ProjectionSnapshot _snapshot(PrivateLearnerRecord record) {
    final snapshot = _snapshotFromWire(record.payload);
    if (snapshot.tombstone != record.tombstone) {
      throw const PersonalSyncProjectionException(
        'sync_projection_tombstone_mismatch',
        'A local personal-sync projection failed integrity validation.',
      );
    }
    return snapshot;
  }

  _ProjectionSnapshot _snapshotFromWire(Map<String, Object?> raw) {
    try {
      if (raw['schemaVersion'] != _schemaVersion ||
          raw['workspaceId'] is! String ||
          raw['stream'] is! String ||
          raw['entityId'] is! String ||
          raw['kind'] is! String ||
          raw['mergePolicy'] is! String ||
          raw['logicalRevision'] is! int ||
          raw['clientCreatedAt'] is! String ||
          raw['deviceId'] is! String ||
          raw['eventId'] is! String ||
          raw['tombstone'] is! bool ||
          raw['value'] is! Map) {
        throw const FormatException();
      }
      final stream = raw['stream'] as String;
      final entityId = raw['entityId'] as String;
      _validateStreamAndEntity(stream: stream, entityId: entityId);
      final revision = raw['logicalRevision'] as int;
      if (revision < 1) throw const FormatException();
      final createdAt = DateTime.tryParse(raw['clientCreatedAt'] as String);
      if (createdAt == null) throw const FormatException();
      return _ProjectionSnapshot(
        workspaceId: raw['workspaceId'] as String,
        stream: stream,
        entityId: entityId,
        kind: PersonalSyncEventKind.values.byName(raw['kind'] as String),
        mergePolicy: PersonalSyncMergePolicy.values.byName(
          raw['mergePolicy'] as String,
        ),
        logicalRevision: revision,
        clientCreatedAt: createdAt.toUtc(),
        deviceId: raw['deviceId'] as String,
        eventId: raw['eventId'] as String,
        tombstone: raw['tombstone'] as bool,
        payload: Map<String, Object?>.from(raw['value'] as Map),
      );
    } on PersonalSyncProjectionException {
      rethrow;
    } on Object catch (error) {
      throw PersonalSyncProjectionException(
        'invalid_sync_projection',
        'A local personal-sync projection is invalid or unsupported.',
        error,
      );
    }
  }

  void _validateEvent(DecryptedPersonalSyncEvent event) {
    _validateStreamAndEntity(
      stream: event.envelope.stream,
      entityId: event.entityId,
    );
    if (event.envelope.logicalRevision < 1 ||
        event.envelope.clientCreatedAt.microsecondsSinceEpoch <= 0) {
      throw const PersonalSyncProjectionException(
        'invalid_sync_projection_event',
        'A personal sync event has invalid merge metadata.',
      );
    }
    if (event.envelope.mergePolicy == PersonalSyncMergePolicy.appendOnly &&
        event.envelope.tombstone) {
      throw const PersonalSyncProjectionException(
        'invalid_sync_append_tombstone',
        'Append-only personal sync events cannot be tombstoned.',
      );
    }
  }

  void _validateStreamAndEntity({
    required String stream,
    required String entityId,
  }) {
    if (!RegExp(r'^[a-z0-9][a-z0-9._-]{0,79}$').hasMatch(stream) ||
        entityId.isEmpty ||
        entityId.length > 400 ||
        entityId.trim() != entityId ||
        entityId.contains('\u0000')) {
      throw const PersonalSyncProjectionException(
        'invalid_sync_projection_entity',
        'A personal sync projection has an invalid stream or entity ID.',
      );
    }
  }

  String _ledgerRecordId(String eventId) => 'event::$eventId';

  String _projectionRecordId(String stream, String entityId) =>
      'state::$stream::$entityId';
}

final class PersonalSyncProjectionSnapshot {
  const PersonalSyncProjectionSnapshot._(this._value);

  final _ProjectionSnapshot _value;

  String get workspaceId => _value.workspaceId;
  String get stream => _value.stream;
  String get entityId => _value.entityId;
  PersonalSyncEventKind get kind => _value.kind;
  PersonalSyncMergePolicy get mergePolicy => _value.mergePolicy;
  int get logicalRevision => _value.logicalRevision;
  DateTime get clientCreatedAt => _value.clientCreatedAt;
  String get deviceId => _value.deviceId;
  String get eventId => _value.eventId;
  bool get tombstone => _value.tombstone;
  Map<String, Object?> get payload => Map.unmodifiable(_value.payload);
}

final class PersonalSyncProjectionException implements Exception {
  const PersonalSyncProjectionException(this.code, this.message, [this.cause]);

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'PersonalSyncProjectionException($code): $message';
}

final class _ProjectionSnapshot {
  const _ProjectionSnapshot({
    required this.workspaceId,
    required this.stream,
    required this.entityId,
    required this.kind,
    required this.mergePolicy,
    required this.logicalRevision,
    required this.clientCreatedAt,
    required this.deviceId,
    required this.eventId,
    required this.tombstone,
    required this.payload,
  });

  final String workspaceId;
  final String stream;
  final String entityId;
  final PersonalSyncEventKind kind;
  final PersonalSyncMergePolicy mergePolicy;
  final int logicalRevision;
  final DateTime clientCreatedAt;
  final String deviceId;
  final String eventId;
  final bool tombstone;
  final Map<String, Object?> payload;

  _ProjectionSnapshot copyWith({
    int? logicalRevision,
    Map<String, Object?>? payload,
  }) => _ProjectionSnapshot(
    workspaceId: workspaceId,
    stream: stream,
    entityId: entityId,
    kind: kind,
    mergePolicy: mergePolicy,
    logicalRevision: logicalRevision ?? this.logicalRevision,
    clientCreatedAt: clientCreatedAt,
    deviceId: deviceId,
    eventId: eventId,
    tombstone: tombstone,
    payload: payload ?? this.payload,
  );

  Map<String, Object?> toWire() => {
    'schemaVersion': PersonalSyncProjectionStore._schemaVersion,
    'workspaceId': workspaceId,
    'stream': stream,
    'entityId': entityId,
    'kind': kind.name,
    'mergePolicy': mergePolicy.name,
    'logicalRevision': logicalRevision,
    'clientCreatedAt': clientCreatedAt.toUtc().toIso8601String(),
    'deviceId': deviceId,
    'eventId': eventId,
    'tombstone': tombstone,
    'value': payload,
  };
}

int _compareStamps(_ProjectionSnapshot left, _ProjectionSnapshot right) {
  final revision = left.logicalRevision.compareTo(right.logicalRevision);
  if (revision != 0) return revision;
  final time = left.clientCreatedAt.compareTo(right.clientCreatedAt);
  if (time != 0) return time;
  final device = left.deviceId.compareTo(right.deviceId);
  if (device != 0) return device;
  return left.eventId.compareTo(right.eventId);
}

bool _sameSnapshot(_ProjectionSnapshot left, _ProjectionSnapshot right) =>
    left.workspaceId == right.workspaceId &&
    left.stream == right.stream &&
    left.entityId == right.entityId &&
    left.kind == right.kind &&
    left.mergePolicy == right.mergePolicy &&
    left.logicalRevision == right.logicalRevision &&
    left.clientCreatedAt == right.clientCreatedAt &&
    left.deviceId == right.deviceId &&
    left.eventId == right.eventId &&
    left.tombstone == right.tombstone &&
    CanonicalJson.encode(left.payload) == CanonicalJson.encode(right.payload);

Map<String, Object?> _mergeMonotonic(
  Map<String, Object?> existing,
  Map<String, Object?> incoming, {
  required bool preferIncoming,
}) {
  final keys = <String>{...existing.keys, ...incoming.keys}.toList()..sort();
  return {
    for (final key in keys)
      key: _mergeMonotonicValue(
        existing[key],
        incoming[key],
        preferIncoming: preferIncoming,
      ),
  };
}

Object? _mergeMonotonicValue(
  Object? existing,
  Object? incoming, {
  required bool preferIncoming,
}) {
  if (existing == null) return incoming;
  if (incoming == null) return existing;
  if (existing is num && incoming is num) {
    return incoming.compareTo(existing) > 0 ? incoming : existing;
  }
  if (existing is bool && incoming is bool) return existing || incoming;
  if (existing is Map && incoming is Map) {
    return _mergeMonotonic(
      Map<String, Object?>.from(existing),
      Map<String, Object?>.from(incoming),
      preferIncoming: preferIncoming,
    );
  }
  // Lists and non-monotonic scalar metadata are selected by the deterministic
  // revision/device/event stamp, never by arrival order.
  return preferIncoming ? incoming : existing;
}

DateTime _safeUpdatedAt(DateTime value) {
  final utc = value.toUtc();
  if (utc.microsecondsSinceEpoch <= 0) {
    throw const PersonalSyncProjectionException(
      'invalid_sync_projection_time',
      'A personal sync event timestamp is invalid.',
    );
  }
  return utc;
}

DateTime _latestTime(DateTime? existing, DateTime incoming) {
  final validIncoming = _safeUpdatedAt(incoming);
  if (existing == null || validIncoming.isAfter(existing.toUtc())) {
    return validIncoming;
  }
  return existing.toUtc();
}

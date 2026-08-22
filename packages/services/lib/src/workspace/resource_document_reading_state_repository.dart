import 'dart:async';

import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_foundation/synapse_foundation.dart';

abstract interface class ResourceDocumentReadingStateRepository {
  Future<ResourceDocumentReadingPosition?> read(ResourceDocumentId documentId);

  Future<List<ResourceDocumentReadingPosition>> listRecent();

  Future<ResourceDocumentReadingPosition> savePosition({
    required ResourceDocument document,
    required int pageNumber,
    required int pagePositionMillionths,
    required int? expectedRevision,
  });

  Future<bool> clear({
    required ResourceDocumentId documentId,
    required int expectedRevision,
  });

  Future<List<ResourceDocumentReadingStateIntegrityIssue>> auditIntegrity();
}

final class ResourceDocumentReadingStateException implements Exception {
  const ResourceDocumentReadingStateException(
    this.code,
    this.message, [
    this.cause,
  ]);

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'ResourceDocumentReadingStateException($code): $message';
}

final class ResourceDocumentReadingStateIntegrityIssue {
  const ResourceDocumentReadingStateIntegrityIssue({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;
}

/// One-key rollback boundary for private PDF resume positions.
///
/// Document bytes, copied text, annotations, rewards, and package progress are
/// never stored here. Older builds can ignore this additive key safely.
final class LocalResourceDocumentReadingStateRepository
    implements ResourceDocumentReadingStateRepository {
  LocalResourceDocumentReadingStateRepository({
    required KeyValueStore store,
    required Clock clock,
  }) : this._(store, clock, _queueFor(store));

  LocalResourceDocumentReadingStateRepository._(
    this._store,
    this._clock,
    this._mutationQueue,
  );

  static const stateKey = '__synapse_resource_document_reading_state_v1';
  static const currentSchemaVersion = 1;
  static final Expando<_DocumentReadingMutationQueue> _mutationQueues =
      Expando();

  final KeyValueStore _store;
  final Clock _clock;
  final _DocumentReadingMutationQueue _mutationQueue;

  /// Replaces only the legacy PDF resume key after validating every record.
  /// This is an explicit, quiesced downgrade/export boundary—not dual-write.
  Future<List<ResourceDocumentReadingPosition>> replacePositionsForRollback(
    Iterable<ResourceDocumentReadingPosition> positions,
  ) => _mutate(() async {
    final records =
        <ResourceDocumentReadingPositionId, ResourceDocumentReadingPosition>{};
    for (final position in positions) {
      if (records.containsKey(position.id)) {
        throw const ResourceDocumentReadingStateException(
          'duplicate_document_reading_position',
          'Rollback snapshot contains a duplicate reading-position identity.',
        );
      }
      records[position.id] = position;
    }
    final state = _DocumentReadingState(records: records);
    final validated = _DocumentReadingState.fromJson(state.toJson());
    await _writeState(validated);
    final restored = await _readState();
    if (CanonicalJson.encode(restored.toJson()) !=
        CanonicalJson.encode(validated.toJson())) {
      throw const ResourceDocumentReadingStateException(
        'document_reading_state_rollback_verification_failed',
        'Legacy reading-state rollback failed read-after-write validation.',
      );
    }
    final values = restored.records.values.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    return List.unmodifiable(values);
  });

  @override
  Future<ResourceDocumentReadingPosition?> read(
    ResourceDocumentId documentId,
  ) => _mutate(() async {
    final id = ResourceDocumentReadingPosition.stableIdFor(documentId);
    return (await _readState()).records[id];
  });

  @override
  Future<List<ResourceDocumentReadingPosition>> listRecent() =>
      _mutate(() async {
        final values = (await _readState()).records.values.toList()
          ..sort((left, right) {
            final byTime = right.updatedAt.compareTo(left.updatedAt);
            return byTime != 0 ? byTime : right.id.compareTo(left.id);
          });
        return List.unmodifiable(values);
      });

  @override
  Future<ResourceDocumentReadingPosition> savePosition({
    required ResourceDocument document,
    required int pageNumber,
    required int pagePositionMillionths,
    required int? expectedRevision,
  }) => _mutate(() async {
    if (document.mediaType != 'application/pdf' || document.pageCount == null) {
      throw const ResourceDocumentReadingStateException(
        'document_not_page_addressable',
        'Reading position requires immutable paged PDF metadata.',
      );
    }
    final state = await _readState();
    final id = ResourceDocumentReadingPosition.stableIdFor(document.id);
    final existing = state.records[id];
    if (existing != null &&
        existing.documentContentSha256 != document.contentSha256) {
      throw const ResourceDocumentReadingStateException(
        'document_identity_drift',
        'Document identity no longer matches the saved content digest.',
      );
    }
    if (existing != null &&
        existing.pageNumber == pageNumber &&
        existing.pagePositionMillionths == pagePositionMillionths &&
        existing.pageCountAtSave == document.pageCount) {
      return existing;
    }
    if (existing == null) {
      if (expectedRevision != null) {
        throw const ResourceDocumentReadingStateException(
          'stale_document_reading_position_revision',
          'The document reading position changed after this view opened.',
        );
      }
    } else if (existing.revision != expectedRevision) {
      throw const ResourceDocumentReadingStateException(
        'stale_document_reading_position_revision',
        'The document reading position changed after this view opened.',
      );
    }
    final now = _clock.nowUtc();
    final position = ResourceDocumentReadingPosition(
      id: id,
      documentId: document.id,
      documentContentSha256: document.contentSha256,
      pageNumber: pageNumber,
      pageCountAtSave: document.pageCount!,
      pagePositionMillionths: pagePositionMillionths,
      revision: (existing?.revision ?? 0) + 1,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    state.records[id] = position;
    await _writeState(state);
    return position;
  });

  @override
  Future<bool> clear({
    required ResourceDocumentId documentId,
    required int expectedRevision,
  }) => _mutate(() async {
    final state = await _readState();
    final id = ResourceDocumentReadingPosition.stableIdFor(documentId);
    final existing = state.records[id];
    if (existing == null) return false;
    if (existing.revision != expectedRevision) {
      throw const ResourceDocumentReadingStateException(
        'stale_document_reading_position_revision',
        'The document reading position changed after this view opened.',
      );
    }
    state.records.remove(id);
    await _writeState(state);
    return true;
  });

  @override
  Future<List<ResourceDocumentReadingStateIntegrityIssue>> auditIntegrity() =>
      _mutate(() async {
        try {
          await _readState();
          return const [];
        } on ResourceDocumentReadingStateException catch (error) {
          return [
            ResourceDocumentReadingStateIntegrityIssue(
              code: error.code,
              message: error.message,
            ),
          ];
        }
      });

  Future<_DocumentReadingState> _readState() async {
    final raw = await _store.read(stateKey);
    if (raw == null) return _DocumentReadingState.empty();
    if (raw is! Map || raw.keys.any((key) => key is! String)) {
      throw const ResourceDocumentReadingStateException(
        'corrupt_document_reading_state_registry',
        'Document reading-state registry is not a JSON object.',
      );
    }
    try {
      return _DocumentReadingState.fromJson(Map<String, Object?>.from(raw));
    } on ResourceDocumentReadingStateException {
      rethrow;
    } on Object catch (error) {
      throw ResourceDocumentReadingStateException(
        'corrupt_document_reading_state_registry',
        'Document reading-state registry failed schema validation.',
        error,
      );
    }
  }

  Future<void> _writeState(_DocumentReadingState state) =>
      _store.write(stateKey, state.toJson());

  Future<T> _mutate<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _mutationQueue.tail = _mutationQueue.tail.then((_) async {
      try {
        completer.complete(await action());
      } on Object catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  static _DocumentReadingMutationQueue _queueFor(KeyValueStore store) =>
      _mutationQueues[store] ??= _DocumentReadingMutationQueue();
}

final class _DocumentReadingMutationQueue {
  Future<void> tail = Future.value();
}

final class _DocumentReadingState {
  _DocumentReadingState({
    required Map<
      ResourceDocumentReadingPositionId,
      ResourceDocumentReadingPosition
    >
    records,
  }) : records = Map.of(records);

  factory _DocumentReadingState.empty() =>
      _DocumentReadingState(records: const {});

  final Map<ResourceDocumentReadingPositionId, ResourceDocumentReadingPosition>
  records;

  Map<String, Object?> toJson() => {
    'schemaVersion':
        LocalResourceDocumentReadingStateRepository.currentSchemaVersion,
    'records': records.map(
      (id, position) => MapEntry<String, Object?>(id, position.toJson()),
    ),
    'integrity': {
      'recordCount': records.length,
      'pageNumberTotal': records.values.fold<int>(
        0,
        (total, position) => total + position.pageNumber,
      ),
      'revisionTotal': records.values.fold<int>(
        0,
        (total, position) => total + position.revision,
      ),
    },
  };

  factory _DocumentReadingState.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] !=
        LocalResourceDocumentReadingStateRepository.currentSchemaVersion) {
      throw const ResourceDocumentReadingStateException(
        'unsupported_document_reading_state_schema',
        'Unsupported document reading-state registry schema.',
      );
    }
    final records =
        <ResourceDocumentReadingPositionId, ResourceDocumentReadingPosition>{};
    for (final entry in _jsonObject(json['records'], 'records').entries) {
      final position = ResourceDocumentReadingPosition.fromJson(
        _jsonObject(entry.value, 'records.${entry.key}'),
      );
      if (position.id != entry.key) {
        throw const ResourceDocumentReadingStateException(
          'corrupt_document_reading_state_registry',
          'Document reading-position identity does not match its key.',
        );
      }
      records[entry.key] = position;
    }
    final expected = _DocumentReadingState(records: records).toJson();
    final expectedIntegrity = _jsonObject(expected['integrity'], 'expected');
    final actualIntegrity = _jsonObject(json['integrity'], 'integrity');
    if (CanonicalJson.encode(expectedIntegrity) !=
        CanonicalJson.encode(actualIntegrity)) {
      throw const ResourceDocumentReadingStateException(
        'corrupt_document_reading_state_registry',
        'Document reading-state integrity does not match its records.',
      );
    }
    return _DocumentReadingState(records: records);
  }
}

Map<String, Object?> _jsonObject(Object? value, String field) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw ResourceDocumentReadingStateException(
      'corrupt_document_reading_state_registry',
      '$field must be a JSON object.',
    );
  }
  return Map<String, Object?>.from(value);
}

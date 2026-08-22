import 'dart:async';

import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_foundation/synapse_foundation.dart';

/// Local-first semantic resume state for immutable Deep Study documents.
///
/// This repository stores IDs, ordinals, locale/release provenance, and an
/// approximate position only. It never copies package-authored text, answers,
/// evidence bodies, mastery, rewards, or clinical claims.
abstract interface class CurriculumReadingStateRepository {
  Future<CurriculumReadingPosition?> read(CurriculumReadingPositionKey key);

  Future<List<CurriculumReadingPosition>> listForSource(
    CurriculumSourceId sourceId,
  );

  Future<CurriculumReadingPosition> savePosition({
    required CurriculumReadingPositionKey key,
    required CurriculumReleaseId releaseId,
    required CurriculumStudyBlockId blockId,
    required int blockOrdinal,
    required int documentPositionPermille,
    required ContentLocale locale,
    required int? expectedRevision,
    CurriculumLocalizationUnitId? anchorUnitId,
  });

  Future<bool> clear({
    required CurriculumReadingPositionKey key,
    required int expectedRevision,
  });

  Future<List<CurriculumReadingStateIntegrityIssue>> auditIntegrity();
}

final class CurriculumReadingStateException implements Exception {
  const CurriculumReadingStateException(this.code, this.message, [this.cause]);

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'CurriculumReadingStateException($code): $message';
}

/// Privacy-safe diagnostic evidence. It never includes package or note text.
final class CurriculumReadingStateIntegrityIssue {
  const CurriculumReadingStateIntegrityIssue({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;
}

/// Additive one-key adapter for block-level resume anchors.
///
/// The separate key is a rollback boundary: older Synapse builds ignore it
/// without rewriting or deleting the existing Workspace v1 registry.
final class LocalCurriculumReadingStateRepository
    implements CurriculumReadingStateRepository {
  LocalCurriculumReadingStateRepository({
    required KeyValueStore store,
    required Clock clock,
  }) : this._(store, clock, _queueFor(store));

  LocalCurriculumReadingStateRepository._(
    this._store,
    this._clock,
    this._mutationQueue,
  );

  static const stateKey = '__synapse_curriculum_reading_state_v1';
  static const currentSchemaVersion = 1;
  static final _stableIdPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:/-]*$');
  static final Expando<_ReadingMutationQueue> _mutationQueues = Expando();

  final KeyValueStore _store;
  final Clock _clock;
  final _ReadingMutationQueue _mutationQueue;

  @override
  Future<CurriculumReadingPosition?> read(CurriculumReadingPositionKey key) =>
      _mutate(() async => (await _readState()).records[key.stableId]);

  @override
  Future<List<CurriculumReadingPosition>> listForSource(
    CurriculumSourceId sourceId,
  ) => _mutate(() async {
    _requireStableId(sourceId, 'sourceId');
    final values =
        (await _readState()).records.values
            .where((position) => position.key.sourceId == sourceId)
            .toList()
          ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return List.unmodifiable(values);
  });

  @override
  Future<CurriculumReadingPosition> savePosition({
    required CurriculumReadingPositionKey key,
    required CurriculumReleaseId releaseId,
    required CurriculumStudyBlockId blockId,
    required int blockOrdinal,
    required int documentPositionPermille,
    required ContentLocale locale,
    required int? expectedRevision,
    CurriculumLocalizationUnitId? anchorUnitId,
  }) => _mutate(() async {
    _requireStableId(releaseId, 'releaseId');
    _requireStableId(blockId, 'blockId');
    _requireStableIdIfPresent(anchorUnitId, 'anchorUnitId');
    final state = await _readState();
    final existing = state.records[key.stableId];
    if (existing != null &&
        existing.lastReadReleaseId == releaseId &&
        existing.blockId == blockId &&
        existing.blockOrdinal == blockOrdinal &&
        existing.anchorUnitId == anchorUnitId &&
        existing.documentPositionPermille == documentPositionPermille &&
        existing.lastLocale == locale) {
      return existing;
    }
    if (existing == null) {
      if (expectedRevision != null) {
        throw const CurriculumReadingStateException(
          'stale_reading_position_revision',
          'The reading position changed after this view opened.',
        );
      }
    } else if (existing.revision != expectedRevision) {
      throw const CurriculumReadingStateException(
        'stale_reading_position_revision',
        'The reading position changed after this view opened.',
      );
    }
    final now = _clock.nowUtc();
    final position = CurriculumReadingPosition(
      key: key,
      lastReadReleaseId: releaseId,
      blockId: blockId,
      blockOrdinal: blockOrdinal,
      anchorUnitId: anchorUnitId,
      documentPositionPermille: documentPositionPermille,
      lastLocale: locale,
      revision: (existing?.revision ?? 0) + 1,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    state.records[key.stableId] = position;
    await _writeState(state);
    return position;
  });

  @override
  Future<bool> clear({
    required CurriculumReadingPositionKey key,
    required int expectedRevision,
  }) => _mutate(() async {
    final state = await _readState();
    final existing = state.records[key.stableId];
    if (existing == null) return false;
    if (existing.revision != expectedRevision) {
      throw const CurriculumReadingStateException(
        'stale_reading_position_revision',
        'The reading position changed after this view opened.',
      );
    }
    state.records.remove(key.stableId);
    await _writeState(state);
    return true;
  });

  @override
  Future<List<CurriculumReadingStateIntegrityIssue>> auditIntegrity() =>
      _mutate(() async {
        try {
          await _readState();
          return const [];
        } on CurriculumReadingStateException catch (error) {
          return [
            CurriculumReadingStateIntegrityIssue(
              code: error.code,
              message: error.message,
            ),
          ];
        }
      });

  Future<_ReadingRegistryState> _readState() async {
    final raw = await _store.read(stateKey);
    if (raw == null) return _ReadingRegistryState.empty();
    if (raw is! Map || raw.keys.any((key) => key is! String)) {
      throw const CurriculumReadingStateException(
        'corrupt_reading_state_registry',
        'Reading-state registry is not a JSON object.',
      );
    }
    try {
      return _ReadingRegistryState.fromJson(Map<String, Object?>.from(raw));
    } on CurriculumReadingStateException {
      rethrow;
    } on Object catch (error) {
      throw CurriculumReadingStateException(
        'corrupt_reading_state_registry',
        'Reading-state registry failed schema validation.',
        error,
      );
    }
  }

  Future<void> _writeState(_ReadingRegistryState state) =>
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

  static _ReadingMutationQueue _queueFor(KeyValueStore store) =>
      _mutationQueues[store] ??= _ReadingMutationQueue();

  static void _requireStableId(String value, String field) {
    if (value != value.trim() || !_stableIdPattern.hasMatch(value)) {
      throw ArgumentError.value(value, field, 'Invalid stable ID.');
    }
  }

  static void _requireStableIdIfPresent(String? value, String field) {
    if (value != null) _requireStableId(value, field);
  }
}

final class _ReadingMutationQueue {
  Future<void> tail = Future.value();
}

final class _ReadingRegistryState {
  _ReadingRegistryState({
    required Map<CurriculumReadingPositionId, CurriculumReadingPosition>
    records,
  }) : records = Map.of(records);

  factory _ReadingRegistryState.empty() =>
      _ReadingRegistryState(records: const {});

  final Map<CurriculumReadingPositionId, CurriculumReadingPosition> records;

  Map<String, Object?> toJson() => {
    'schemaVersion': LocalCurriculumReadingStateRepository.currentSchemaVersion,
    'records': records.map(
      (id, position) => MapEntry<String, Object?>(id, position.toJson()),
    ),
    'integrity': {
      'recordCount': records.length,
      'positionPermilleTotal': records.values.fold<int>(
        0,
        (total, position) => total + position.documentPositionPermille,
      ),
    },
  };

  factory _ReadingRegistryState.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] !=
        LocalCurriculumReadingStateRepository.currentSchemaVersion) {
      throw const CurriculumReadingStateException(
        'unsupported_reading_state_schema',
        'Unsupported reading-state registry schema.',
      );
    }
    final recordsJson = _jsonObject(json['records'], 'records');
    final records = <CurriculumReadingPositionId, CurriculumReadingPosition>{};
    for (final entry in recordsJson.entries) {
      final position = CurriculumReadingPosition.fromJson(
        _jsonObject(entry.value, 'records.${entry.key}'),
      );
      if (position.key.stableId != entry.key) {
        throw const CurriculumReadingStateException(
          'corrupt_reading_state_registry',
          'Reading-position identity does not match its registry key.',
        );
      }
      records[entry.key] = position;
    }
    final integrity = _jsonObject(json['integrity'], 'integrity');
    final positionPermilleTotal = records.values.fold<int>(
      0,
      (total, position) => total + position.documentPositionPermille,
    );
    if (integrity['recordCount'] != records.length ||
        integrity['positionPermilleTotal'] != positionPermilleTotal) {
      throw const CurriculumReadingStateException(
        'corrupt_reading_state_registry',
        'Reading-state integrity summary does not match its records.',
      );
    }
    return _ReadingRegistryState(records: records);
  }
}

Map<String, Object?> _jsonObject(Object? value, String field) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw CurriculumReadingStateException(
      'corrupt_reading_state_registry',
      '$field must be a JSON object.',
    );
  }
  return Map<String, Object?>.from(value);
}

import 'dart:async';

import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_foundation/synapse_foundation.dart';

/// Local-first checkpoint store for reviewed curriculum sessions.
///
/// This repository is intentionally not a reward engine, mastery engine, or
/// cloud authority. It writes an atomic, release-bound resume projection and
/// stable choice events. A future outbox can replay those opaque event IDs to
/// the server without allowing a device to mint XP, currency, or competence.
abstract interface class CurriculumSessionProgressRepository {
  Future<CurriculumSessionProgress?> read(CurriculumSessionProgressKey key);

  /// Opens or resumes a release-bound checkpoint without awarding or
  /// completing anything. This is required for passive interactions too.
  Future<CurriculumSessionProgress> open({
    required CurriculumSessionProgressKey key,
    required int interactionIndex,
  });

  Future<List<CurriculumSessionProgress>> incompleteForRelease(
    CurriculumReleaseId releaseId,
  );

  /// Upgrades a supported older registry in place without changing checkpoint
  /// identity, response receipts, or completion receipts.
  Future<CurriculumProgressMigrationReceipt> migrateToCurrentSchema();

  /// Produces a data-preserving snapshot for a supported older reader. This
  /// never mutates the installed registry or weakens the current schema.
  Future<Map<String, Object?>> createRollbackSnapshot({
    required int targetSchemaVersion,
  });

  Future<CurriculumSessionProgress> selectOption({
    required CurriculumSessionProgressKey key,
    required int interactionIndex,
    required String selectedOptionId,
    int? expectedRevision,
  });

  Future<CurriculumSessionProgress> recordChoice({
    required CurriculumSessionProgressKey key,
    required int interactionIndex,
    required CurriculumInteractionId interactionId,
    required String selectedOptionId,
    required bool isCorrect,
    required int expectedRevision,
  });

  Future<CurriculumSessionProgress> advance({
    required CurriculumSessionProgressKey key,
    required int interactionIndex,
    required int nextInteractionIndex,
    required int expectedRevision,
    CurriculumInteractionId? requiresRecordedChoiceForInteractionId,
  });

  Future<CurriculumSessionProgress> complete({
    required CurriculumSessionProgressKey key,
    required int interactionIndex,
    required int expectedRevision,
    CurriculumInteractionId? requiresRecordedChoiceForInteractionId,
  });

  /// Merges a privacy-safe, encrypted personal-sync replica into the local
  /// release-bound checkpoint. The replica cannot carry an in-progress option
  /// selection, rewards, free text, content bodies, or competence claims.
  ///
  /// Choice receipts are unioned by stable response ID, the visible answer for
  /// a conflicting interaction is chosen deterministically, and completion is
  /// monotonic. The encrypted sync ledger retains every competing source event
  /// as the lossless audit fallback; this local checkpoint remains a compact
  /// resume projection rather than a second authority.
  Future<CurriculumSessionProgress> mergeExternalReplica(
    CurriculumSessionProgress replica,
  );

  Future<List<CurriculumProgressIntegrityIssue>> auditIntegrity();
}

/// A privacy-safe diagnostic record. [message] is for logs and support
/// mapping, never for direct learner presentation.
final class CurriculumProgressIntegrityIssue {
  const CurriculumProgressIntegrityIssue({
    required this.code,
    required this.message,
    this.progressId,
  });

  final String code;
  final String message;
  final CurriculumSessionProgressId? progressId;
}

/// Privacy-safe evidence for one local schema check or forward migration.
final class CurriculumProgressMigrationReceipt {
  const CurriculumProgressMigrationReceipt({
    required this.sourceSchemaVersion,
    required this.targetSchemaVersion,
    required this.recordCount,
    required this.migrated,
  });

  final int sourceSchemaVersion;
  final int targetSchemaVersion;
  final int recordCount;
  final bool migrated;
}

/// Versioned one-key persistence adapter. The one-write registry is a clear
/// atomic boundary for [KeyValueStore] implementations such as SharedPrefs;
/// it never clears or repurposes unrelated learner data.
final class LocalCurriculumSessionProgressRepository
    implements CurriculumSessionProgressRepository {
  LocalCurriculumSessionProgressRepository({
    required KeyValueStore store,
    required Clock clock,
    required IdSource idSource,
  }) : this._(store, clock, idSource);

  LocalCurriculumSessionProgressRepository._(
    this._store,
    this._clock,
    this._idSource,
  );

  static const stateKey = '__synapse_curriculum_session_progress_v1';
  static const currentSchemaVersion = 2;
  static const rollbackSchemaVersion = 1;

  final KeyValueStore _store;
  final Clock _clock;
  final IdSource _idSource;
  Future<void> _mutationTail = Future.value();

  @override
  Future<CurriculumSessionProgress?> read(CurriculumSessionProgressKey key) =>
      _mutate(() async => (await _readState()).records[key.stableId]);

  @override
  Future<CurriculumSessionProgress> open({
    required CurriculumSessionProgressKey key,
    required int interactionIndex,
  }) => _mutate(() async {
    _requireIndex(interactionIndex, 'interactionIndex');
    final state = await _readState();
    final existing = state.records[key.stableId];
    if (existing != null) return existing;
    final now = _clock.nowUtc();
    final progress = CurriculumSessionProgress(
      key: key,
      phase: CurriculumSessionProgressPhase.inProgress,
      interactionIndex: interactionIndex,
      revision: 1,
      startedAt: now,
      updatedAt: now,
    );
    state.records[key.stableId] = progress;
    await _writeState(state);
    return progress;
  });

  @override
  Future<List<CurriculumSessionProgress>> incompleteForRelease(
    CurriculumReleaseId releaseId,
  ) => _mutate(() async {
    final state = await _readState();
    final values =
        state.records.values
            .where(
              (progress) =>
                  progress.key.releaseId == releaseId && !progress.isCompleted,
            )
            .toList()
          ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return List.unmodifiable(values);
  });

  @override
  Future<CurriculumProgressMigrationReceipt> migrateToCurrentSchema() =>
      _mutate(() async {
        final decoded = await _readDecodedState();
        final migrated = decoded.requiresMigration;
        if (migrated) await _writeState(decoded.state);
        return CurriculumProgressMigrationReceipt(
          sourceSchemaVersion: decoded.sourceSchemaVersion,
          targetSchemaVersion: currentSchemaVersion,
          recordCount: decoded.state.records.length,
          migrated: migrated,
        );
      });

  @override
  Future<Map<String, Object?>> createRollbackSnapshot({
    required int targetSchemaVersion,
  }) {
    if (targetSchemaVersion != rollbackSchemaVersion) {
      throw CurriculumProgressException(
        'unsupported_progress_rollback_schema',
        'Unsupported learner progress rollback schema: '
            '$targetSchemaVersion.',
      );
    }
    return _mutate(() async {
      final state = await _readState();
      return state.toSchemaV1Json();
    });
  }

  @override
  Future<CurriculumSessionProgress> selectOption({
    required CurriculumSessionProgressKey key,
    required int interactionIndex,
    required String selectedOptionId,
    int? expectedRevision,
  }) => _mutate(() async {
    _requireIndex(interactionIndex, 'interactionIndex');
    _requireId(selectedOptionId, 'selectedOptionId');
    final state = await _readState();
    final current = _currentOrNew(
      state: state,
      key: key,
      interactionIndex: interactionIndex,
      expectedRevision: expectedRevision,
    );
    if (current.selectedOptionId == selectedOptionId) return current;
    final next = CurriculumSessionProgress(
      key: key,
      phase: CurriculumSessionProgressPhase.inProgress,
      interactionIndex: current.interactionIndex,
      revision: current.revision + 1,
      startedAt: current.startedAt,
      updatedAt: _clock.nowUtc(),
      selectedOptionId: selectedOptionId,
      choiceResponses: current.choiceResponses,
    );
    state.records[key.stableId] = next;
    await _writeState(state);
    return next;
  });

  @override
  Future<CurriculumSessionProgress> recordChoice({
    required CurriculumSessionProgressKey key,
    required int interactionIndex,
    required CurriculumInteractionId interactionId,
    required String selectedOptionId,
    required bool isCorrect,
    required int expectedRevision,
  }) => _mutate(() async {
    _requireIndex(interactionIndex, 'interactionIndex');
    _requireId(interactionId, 'interactionId');
    _requireId(selectedOptionId, 'selectedOptionId');
    final state = await _readState();
    final current = _currentOrNew(
      state: state,
      key: key,
      interactionIndex: interactionIndex,
      expectedRevision: expectedRevision,
    );
    if (current.selectedOptionId != selectedOptionId) {
      throw const CurriculumProgressException(
        'selection_mismatch',
        'A recorded choice must match the persisted selected option.',
      );
    }
    final existing = current.responseFor(interactionId);
    if (existing != null) {
      if (existing.selectedOptionId == selectedOptionId &&
          existing.isCorrect == isCorrect) {
        return current;
      }
      throw const CurriculumProgressException(
        'choice_already_recorded',
        'A different choice is already recorded for this interaction.',
      );
    }
    final responses = {...current.choiceResponses};
    responses[interactionId] = CurriculumChoiceResponse(
      id: _idSource.nextId(),
      interactionId: interactionId,
      selectedOptionId: selectedOptionId,
      isCorrect: isCorrect,
      answeredAt: _clock.nowUtc(),
    );
    final next = CurriculumSessionProgress(
      key: key,
      phase: CurriculumSessionProgressPhase.inProgress,
      interactionIndex: current.interactionIndex,
      revision: current.revision + 1,
      startedAt: current.startedAt,
      updatedAt: _clock.nowUtc(),
      selectedOptionId: current.selectedOptionId,
      choiceResponses: responses,
    );
    state.records[key.stableId] = next;
    await _writeState(state);
    return next;
  });

  @override
  Future<CurriculumSessionProgress> advance({
    required CurriculumSessionProgressKey key,
    required int interactionIndex,
    required int nextInteractionIndex,
    required int expectedRevision,
    CurriculumInteractionId? requiresRecordedChoiceForInteractionId,
  }) => _mutate(() async {
    _requireIndex(interactionIndex, 'interactionIndex');
    _requireIndex(nextInteractionIndex, 'nextInteractionIndex');
    _requireIdIfPresent(
      requiresRecordedChoiceForInteractionId,
      'requiresRecordedChoiceForInteractionId',
    );
    if (nextInteractionIndex != interactionIndex + 1) {
      throw const CurriculumProgressException(
        'invalid_progress_advance',
        'A session checkpoint can advance exactly one interaction at a time.',
      );
    }
    final state = await _readState();
    final current = _requireCurrent(
      state: state,
      key: key,
      interactionIndex: interactionIndex,
      expectedRevision: expectedRevision,
    );
    _requireRecordedChoice(current, requiresRecordedChoiceForInteractionId);
    final next = CurriculumSessionProgress(
      key: key,
      phase: CurriculumSessionProgressPhase.inProgress,
      interactionIndex: nextInteractionIndex,
      revision: current.revision + 1,
      startedAt: current.startedAt,
      updatedAt: _clock.nowUtc(),
      choiceResponses: current.choiceResponses,
    );
    state.records[key.stableId] = next;
    await _writeState(state);
    return next;
  });

  @override
  Future<CurriculumSessionProgress> complete({
    required CurriculumSessionProgressKey key,
    required int interactionIndex,
    required int expectedRevision,
    CurriculumInteractionId? requiresRecordedChoiceForInteractionId,
  }) => _mutate(() async {
    _requireIndex(interactionIndex, 'interactionIndex');
    _requireIdIfPresent(
      requiresRecordedChoiceForInteractionId,
      'requiresRecordedChoiceForInteractionId',
    );
    final state = await _readState();
    final stored = state.records[key.stableId];
    if (stored?.isCompleted == true) return stored!;
    final current = _requireCurrent(
      state: state,
      key: key,
      interactionIndex: interactionIndex,
      expectedRevision: expectedRevision,
    );
    _requireRecordedChoice(current, requiresRecordedChoiceForInteractionId);
    final now = _clock.nowUtc();
    final next = CurriculumSessionProgress(
      key: key,
      phase: CurriculumSessionProgressPhase.completed,
      interactionIndex: current.interactionIndex,
      revision: current.revision + 1,
      startedAt: current.startedAt,
      updatedAt: now,
      choiceResponses: current.choiceResponses,
      completedAt: now,
      completionReceiptId: _idSource.nextId(),
    );
    state.records[key.stableId] = next;
    await _writeState(state);
    return next;
  });

  @override
  Future<CurriculumSessionProgress> mergeExternalReplica(
    CurriculumSessionProgress replica,
  ) => _mutate(() async {
    _validateExternalReplica(replica);
    final state = await _readState();
    final current = state.records[replica.key.stableId];
    if (current == null) {
      state.records[replica.key.stableId] = replica;
      await _writeState(state);
      return replica;
    }
    final next = _mergeExternalReplica(current: current, incoming: replica);
    if (next == current) return current;
    state.records[next.key.stableId] = next;
    await _writeState(state);
    return next;
  });

  @override
  Future<List<CurriculumProgressIntegrityIssue>> auditIntegrity() async {
    try {
      await _readDecodedState();
      return const [];
    } on CurriculumProgressException catch (error) {
      return [
        CurriculumProgressIntegrityIssue(
          code: error.code,
          message: error.message,
        ),
      ];
    } on Object {
      return const [
        CurriculumProgressIntegrityIssue(
          code: 'corrupt_progress_registry',
          message: 'Learner progress registry failed validation.',
        ),
      ];
    }
  }

  CurriculumSessionProgress _currentOrNew({
    required _ProgressRegistryState state,
    required CurriculumSessionProgressKey key,
    required int interactionIndex,
    required int? expectedRevision,
  }) {
    final current = state.records[key.stableId];
    if (current == null) {
      if (expectedRevision != null) {
        throw const CurriculumProgressException(
          'progress_checkpoint_missing',
          'The expected learner-progress checkpoint does not exist.',
        );
      }
      final now = _clock.nowUtc();
      return CurriculumSessionProgress(
        key: key,
        phase: CurriculumSessionProgressPhase.inProgress,
        interactionIndex: interactionIndex,
        revision: 1,
        startedAt: now,
        updatedAt: now,
      );
    }
    return _validateCurrent(
      current: current,
      interactionIndex: interactionIndex,
      expectedRevision: expectedRevision,
    );
  }

  CurriculumSessionProgress _requireCurrent({
    required _ProgressRegistryState state,
    required CurriculumSessionProgressKey key,
    required int interactionIndex,
    required int expectedRevision,
  }) {
    final current = state.records[key.stableId];
    if (current == null) {
      throw const CurriculumProgressException(
        'progress_checkpoint_missing',
        'No learner-progress checkpoint exists for this session.',
      );
    }
    return _validateCurrent(
      current: current,
      interactionIndex: interactionIndex,
      expectedRevision: expectedRevision,
    );
  }

  CurriculumSessionProgress _validateCurrent({
    required CurriculumSessionProgress current,
    required int interactionIndex,
    required int? expectedRevision,
  }) {
    if (current.isCompleted) {
      throw const CurriculumProgressException(
        'session_already_completed',
        'Completed learner progress is immutable.',
      );
    }
    if (current.interactionIndex != interactionIndex) {
      throw const CurriculumProgressException(
        'stale_progress_checkpoint',
        'The interaction index no longer matches the stored checkpoint.',
      );
    }
    if (expectedRevision == null || expectedRevision != current.revision) {
      throw const CurriculumProgressException(
        'stale_progress_revision',
        'The learner-progress revision no longer matches the stored checkpoint.',
      );
    }
    return current;
  }

  void _requireRecordedChoice(
    CurriculumSessionProgress progress,
    CurriculumInteractionId? interactionId,
  ) {
    if (interactionId != null && progress.responseFor(interactionId) == null) {
      throw const CurriculumProgressException(
        'required_choice_missing',
        'The required interaction response has not been recorded.',
      );
    }
  }

  static void _validateExternalReplica(CurriculumSessionProgress replica) {
    if (replica.selectedOptionId != null) {
      throw const CurriculumProgressException(
        'invalid_external_progress_replica',
        'A synced progress replica cannot include a pending answer selection.',
      );
    }
  }

  static CurriculumSessionProgress _mergeExternalReplica({
    required CurriculumSessionProgress current,
    required CurriculumSessionProgress incoming,
  }) {
    if (current.key != incoming.key) {
      throw const CurriculumProgressException(
        'external_progress_key_mismatch',
        'A synced progress replica belongs to another learning session.',
      );
    }
    final responses = _mergeResponses(
      current.choiceResponses,
      incoming.choiceResponses,
    );
    final interactionIndex =
        current.interactionIndex > incoming.interactionIndex
        ? current.interactionIndex
        : incoming.interactionIndex;
    final completed = current.isCompleted || incoming.isCompleted;
    final completion = _selectCompletion(current, incoming);
    final startedAt = current.startedAt.isBefore(incoming.startedAt)
        ? current.startedAt
        : incoming.startedAt;
    final updatedAt = current.updatedAt.isAfter(incoming.updatedAt)
        ? current.updatedAt
        : incoming.updatedAt;
    final preservePendingSelection =
        !completed &&
        current.interactionIndex == interactionIndex &&
        incoming.interactionIndex <= current.interactionIndex;
    final unchangedCandidate = CurriculumSessionProgress(
      key: current.key,
      phase: completed
          ? CurriculumSessionProgressPhase.completed
          : CurriculumSessionProgressPhase.inProgress,
      interactionIndex: interactionIndex,
      revision: current.revision,
      startedAt: startedAt,
      updatedAt: updatedAt,
      selectedOptionId: preservePendingSelection
          ? current.selectedOptionId
          : null,
      choiceResponses: responses,
      completedAt: completion?.completedAt,
      completionReceiptId: completion?.completionReceiptId,
    );
    if (_sameProgressProjection(current, unchangedCandidate)) return current;
    return CurriculumSessionProgress(
      key: unchangedCandidate.key,
      phase: unchangedCandidate.phase,
      interactionIndex: unchangedCandidate.interactionIndex,
      revision: _mergedRevision(current, incoming),
      startedAt: unchangedCandidate.startedAt,
      updatedAt: unchangedCandidate.updatedAt,
      selectedOptionId: unchangedCandidate.selectedOptionId,
      choiceResponses: unchangedCandidate.choiceResponses,
      completedAt: unchangedCandidate.completedAt,
      completionReceiptId: unchangedCandidate.completionReceiptId,
    );
  }

  static Map<CurriculumInteractionId, CurriculumChoiceResponse> _mergeResponses(
    Map<CurriculumInteractionId, CurriculumChoiceResponse> current,
    Map<CurriculumInteractionId, CurriculumChoiceResponse> incoming,
  ) {
    final responseOwners = <String, CurriculumInteractionId>{};
    for (final responses in [current, incoming]) {
      for (final entry in responses.entries) {
        final owner = responseOwners[entry.value.id];
        if (owner != null && owner != entry.key) {
          throw const CurriculumProgressException(
            'duplicate_progress_receipt',
            'A synced response receipt belongs to multiple interactions.',
          );
        }
        responseOwners[entry.value.id] = entry.key;
      }
    }
    final merged = <CurriculumInteractionId, CurriculumChoiceResponse>{
      ...current,
    };
    for (final entry in incoming.entries) {
      final existing = merged[entry.key];
      if (existing == null || _compareResponse(entry.value, existing) > 0) {
        merged[entry.key] = entry.value;
      }
    }
    return Map.unmodifiable(merged);
  }

  static int _mergedRevision(
    CurriculumSessionProgress current,
    CurriculumSessionProgress incoming,
  ) {
    final high = current.revision > incoming.revision
        ? current.revision
        : incoming.revision;
    // This is a cross-device logical revision, not a local write counter.
    // Derive it only from replica inputs so two devices converge to the same
    // value regardless of arrival order. Equal-revision divergent replicas
    // gain one deterministic merge generation; otherwise the higher source
    // revision already dominates the merged projection.
    return current.revision == incoming.revision ? high + 1 : high;
  }

  static _CompletionCandidate? _selectCompletion(
    CurriculumSessionProgress current,
    CurriculumSessionProgress incoming,
  ) {
    final candidates = <_CompletionCandidate>[
      if (current.isCompleted)
        _CompletionCandidate(
          completedAt: current.completedAt!,
          completionReceiptId: current.completionReceiptId!,
        ),
      if (incoming.isCompleted)
        _CompletionCandidate(
          completedAt: incoming.completedAt!,
          completionReceiptId: incoming.completionReceiptId!,
        ),
    ];
    if (candidates.isEmpty) return null;
    candidates.sort((left, right) {
      final time = left.completedAt.compareTo(right.completedAt);
      return time != 0
          ? time
          : left.completionReceiptId.compareTo(right.completionReceiptId);
    });
    return candidates.first;
  }

  static int _compareResponse(
    CurriculumChoiceResponse left,
    CurriculumChoiceResponse right,
  ) {
    final answeredAt = left.answeredAt.compareTo(right.answeredAt);
    if (answeredAt != 0) return answeredAt;
    final id = left.id.compareTo(right.id);
    if (id != 0) return id;
    final option = left.selectedOptionId.compareTo(right.selectedOptionId);
    if (option != 0) return option;
    return left.isCorrect == right.isCorrect
        ? 0
        : left.isCorrect
        ? 1
        : -1;
  }

  static bool _sameProgressProjection(
    CurriculumSessionProgress left,
    CurriculumSessionProgress right,
  ) {
    if (left.key != right.key ||
        left.phase != right.phase ||
        left.interactionIndex != right.interactionIndex ||
        left.startedAt != right.startedAt ||
        left.updatedAt != right.updatedAt ||
        left.selectedOptionId != right.selectedOptionId ||
        left.completedAt != right.completedAt ||
        left.completionReceiptId != right.completionReceiptId ||
        left.choiceResponses.length != right.choiceResponses.length) {
      return false;
    }
    for (final entry in left.choiceResponses.entries) {
      if (right.choiceResponses[entry.key] != entry.value) return false;
    }
    return true;
  }

  Future<_ProgressRegistryState> _readState() async {
    final decoded = await _readDecodedState();
    if (decoded.requiresMigration) await _writeState(decoded.state);
    return decoded.state;
  }

  Future<_DecodedProgressRegistry> _readDecodedState() async {
    final raw = await _store.read(stateKey);
    if (raw == null) {
      return _DecodedProgressRegistry(
        state: _ProgressRegistryState.empty(),
        sourceSchemaVersion: currentSchemaVersion,
        persisted: false,
      );
    }
    if (raw is! Map) {
      throw const CurriculumProgressException(
        'corrupt_progress_registry',
        'Learner progress registry is not a JSON object.',
      );
    }
    try {
      return _ProgressRegistryState.decode(Map<String, Object?>.from(raw));
    } on CurriculumProgressException {
      rethrow;
    } on Object catch (error) {
      throw CurriculumProgressException(
        'corrupt_progress_registry',
        'Learner progress registry failed schema validation.',
        error,
      );
    }
  }

  Future<void> _writeState(_ProgressRegistryState state) =>
      _store.write(stateKey, state.toJson());

  Future<T> _mutate<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _mutationTail = _mutationTail.then((_) async {
      try {
        completer.complete(await action());
      } on Object catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  static void _requireIndex(int value, String field) {
    if (value < 0) throw ArgumentError.value(value, field);
  }

  static void _requireId(String value, String field) {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:/-]*$').hasMatch(value)) {
      throw ArgumentError.value(value, field, 'Invalid stable ID.');
    }
  }

  static void _requireIdIfPresent(String? value, String field) {
    if (value != null) _requireId(value, field);
  }
}

final class _CompletionCandidate {
  const _CompletionCandidate({
    required this.completedAt,
    required this.completionReceiptId,
  });

  final DateTime completedAt;
  final String completionReceiptId;
}

final class _ProgressRegistryState {
  _ProgressRegistryState({required this.records});

  factory _ProgressRegistryState.empty() => _ProgressRegistryState(records: {});

  final Map<CurriculumSessionProgressId, CurriculumSessionProgress> records;

  Map<String, Object?> toJson() => {
    'schemaVersion':
        LocalCurriculumSessionProgressRepository.currentSchemaVersion,
    'records': records.map(
      (id, progress) => MapEntry<String, Object?>(id, progress.toJson()),
    ),
    'integrity': _ProgressRegistryIntegrity.fromRecords(records).toJson(),
  };

  Map<String, Object?> toSchemaV1Json() => {
    'schemaVersion':
        LocalCurriculumSessionProgressRepository.rollbackSchemaVersion,
    'records': records.map(
      (id, progress) => MapEntry<String, Object?>(id, progress.toJson()),
    ),
  };

  static _DecodedProgressRegistry decode(Map<String, Object?> json) {
    final schemaVersion = json['schemaVersion'];
    if (schemaVersion !=
            LocalCurriculumSessionProgressRepository.rollbackSchemaVersion &&
        schemaVersion !=
            LocalCurriculumSessionProgressRepository.currentSchemaVersion) {
      throw const CurriculumProgressException(
        'unsupported_progress_schema',
        'Unsupported learner progress registry schema.',
      );
    }
    final state = _ProgressRegistryState(
      records: _decodeRecords(json['records']),
    );
    final actualIntegrity = _ProgressRegistryIntegrity.fromRecords(
      state.records,
    );
    if (schemaVersion ==
        LocalCurriculumSessionProgressRepository.currentSchemaVersion) {
      final storedIntegrity = _ProgressRegistryIntegrity.fromJson(
        json['integrity'],
      );
      if (!storedIntegrity.matches(actualIntegrity)) {
        throw const CurriculumProgressException(
          'corrupt_progress_registry',
          'Learner progress integrity summary does not match its records.',
        );
      }
    }
    return _DecodedProgressRegistry(
      state: state,
      sourceSchemaVersion: schemaVersion as int,
      persisted: true,
    );
  }

  static Map<CurriculumSessionProgressId, CurriculumSessionProgress>
  _decodeRecords(Object? rawRecords) {
    if (rawRecords is! Map) {
      throw const CurriculumProgressException(
        'corrupt_progress_registry',
        'Learner progress records are not a JSON object.',
      );
    }
    final records = <CurriculumSessionProgressId, CurriculumSessionProgress>{};
    for (final entry in rawRecords.entries) {
      if (entry.key is! String || entry.value is! Map) {
        throw const CurriculumProgressException(
          'corrupt_progress_registry',
          'Learner progress record has an invalid key or value.',
        );
      }
      final progress = CurriculumSessionProgress.fromJson(
        Map<String, Object?>.from(entry.value as Map),
      );
      if (progress.key.stableId != entry.key) {
        throw const CurriculumProgressException(
          'corrupt_progress_registry',
          'Learner progress record identity does not match its registry key.',
        );
      }
      records[entry.key] = progress;
    }
    return records;
  }
}

final class _DecodedProgressRegistry {
  const _DecodedProgressRegistry({
    required this.state,
    required this.sourceSchemaVersion,
    required this.persisted,
  });

  final _ProgressRegistryState state;
  final int sourceSchemaVersion;
  final bool persisted;

  bool get requiresMigration =>
      persisted &&
      sourceSchemaVersion !=
          LocalCurriculumSessionProgressRepository.currentSchemaVersion;
}

final class _ProgressRegistryIntegrity {
  const _ProgressRegistryIntegrity({
    required this.recordCount,
    required this.choiceReceiptCount,
    required this.completionReceiptCount,
  });

  factory _ProgressRegistryIntegrity.fromRecords(
    Map<CurriculumSessionProgressId, CurriculumSessionProgress> records,
  ) {
    final receiptIds = <String>{};
    var choiceReceiptCount = 0;
    var completionReceiptCount = 0;
    for (final progress in records.values) {
      for (final response in progress.choiceResponses.values) {
        if (!receiptIds.add(response.id)) {
          throw const CurriculumProgressException(
            'duplicate_progress_receipt',
            'Learner progress response receipts must be globally unique.',
          );
        }
        choiceReceiptCount += 1;
      }
      final completionReceiptId = progress.completionReceiptId;
      if (completionReceiptId != null) {
        if (!receiptIds.add(completionReceiptId)) {
          throw const CurriculumProgressException(
            'duplicate_progress_receipt',
            'Learner progress completion receipts must be globally unique.',
          );
        }
        completionReceiptCount += 1;
      }
    }
    return _ProgressRegistryIntegrity(
      recordCount: records.length,
      choiceReceiptCount: choiceReceiptCount,
      completionReceiptCount: completionReceiptCount,
    );
  }

  factory _ProgressRegistryIntegrity.fromJson(Object? value) {
    if (value is! Map) {
      throw const CurriculumProgressException(
        'corrupt_progress_registry',
        'Learner progress integrity summary is not a JSON object.',
      );
    }
    final json = Map<String, Object?>.from(value);
    final recordCount = json['recordCount'];
    final choiceReceiptCount = json['choiceReceiptCount'];
    final completionReceiptCount = json['completionReceiptCount'];
    if (recordCount is! int ||
        recordCount < 0 ||
        choiceReceiptCount is! int ||
        choiceReceiptCount < 0 ||
        completionReceiptCount is! int ||
        completionReceiptCount < 0) {
      throw const CurriculumProgressException(
        'corrupt_progress_registry',
        'Learner progress integrity summary has invalid counts.',
      );
    }
    return _ProgressRegistryIntegrity(
      recordCount: recordCount,
      choiceReceiptCount: choiceReceiptCount,
      completionReceiptCount: completionReceiptCount,
    );
  }

  final int recordCount;
  final int choiceReceiptCount;
  final int completionReceiptCount;

  Map<String, Object?> toJson() => {
    'recordCount': recordCount,
    'choiceReceiptCount': choiceReceiptCount,
    'completionReceiptCount': completionReceiptCount,
  };

  bool matches(_ProgressRegistryIntegrity other) =>
      recordCount == other.recordCount &&
      choiceReceiptCount == other.choiceReceiptCount &&
      completionReceiptCount == other.completionReceiptCount;
}

import 'dart:async';

import 'package:synapse_core/synapse_core.dart';

import '../curriculum/curriculum_session_progress_repository.dart';
import '../data_plane/encrypted_indexed_learner_record_store.dart';
import 'personal_sync_crypto.dart';
import 'personal_sync_outbox.dart';
import 'personal_sync_projection_store.dart';

/// Called after an encrypted Academy replica has changed the local resume
/// projection. Flutter uses this only to invalidate read models; it never
/// performs network I/O from the callback.
typedef PersonalSyncCurriculumReconciled =
    FutureOr<void> Function(CurriculumSessionProgress progress);

/// Applies encrypted personal-sync envelopes into two deliberately separate
/// local forms:
///
/// 1. [PersonalSyncProjectionStore] retains the lossless encrypted ledger and
///    merge-safe generic projections.
/// 2. This reconciler builds a compact release-bound Academy checkpoint that
///    the existing Session Player can resume immediately.
///
/// Only opaque choice outcomes and structured progress cross this boundary.
/// Pending selection, free-text teach-back, rewards, mastery claims, package
/// bodies, and evidence text are excluded by schema and validated again here.
final class PersonalSyncCurriculumReconciler
    implements PersonalSyncProjectionApplier {
  PersonalSyncCurriculumReconciler({
    required this.projections,
    required this.records,
    required this.progress,
    this.onReconciled,
  });

  static const replicaNamespace = 'sync.academy.replica';
  static const _replicaKind = 'academy-replica';
  static const _schemaVersion = 1;
  static const _maxWriteAttempts = 4;

  final PersonalSyncProjectionStore projections;
  final IndexedLearnerRecordStore records;
  final CurriculumSessionProgressRepository progress;
  final PersonalSyncCurriculumReconciled? onReconciled;

  @override
  Future<void> apply(DecryptedPersonalSyncEvent event) async {
    // Preserve the generic, lossless/event-sourced source before deriving a
    // compact UI checkpoint. If the domain payload is malformed, the caller
    // deliberately does not advance its pull receipt and retries safely.
    await projections.apply(event);
    final mutation = _AcademyReplicaMutation.tryParse(event);
    if (mutation == null) return;

    final replica = await _applyReplicaMutation(mutation);
    final projection = await projections.readProjection(
      stream: 'academy.progress',
      entityId: _progressEntityId(mutation.key),
    );
    if (projection == null || projection.tombstone) return;

    final checkpoint = _buildCheckpoint(
      workspaceId: event.envelope.workspaceId,
      state: replica,
      projection: projection,
    );
    final reconciled = await progress.mergeExternalReplica(checkpoint);
    await onReconciled?.call(reconciled);
  }

  Future<_AcademyReplicaState> _applyReplicaMutation(
    _AcademyReplicaMutation mutation,
  ) async {
    final recordId = _replicaRecordId(mutation.key);
    for (var attempt = 0; attempt < _maxWriteAttempts; attempt += 1) {
      final existing = await records.read(
        namespace: replicaNamespace,
        recordId: recordId,
      );
      final current = existing == null
          ? _AcademyReplicaState.empty(
              workspaceId: mutation.workspaceId,
              key: mutation.key,
              at: mutation.observedAt,
            )
          : _AcademyReplicaState.fromJson(existing.payload);
      final next = current.apply(mutation);
      if (next == current) return current;
      try {
        await records.put(
          PrivateLearnerRecordDraft(
            namespace: replicaNamespace,
            recordId: recordId,
            scopeId: mutation.workspaceId,
            kind: _replicaKind,
            updatedAt: next.latestAt,
            payload: next.toJson(),
          ),
          expectedRevision: existing?.revision,
        );
        return next;
      } on LearnerDataPlaneException catch (error) {
        if (error.code != 'stale_learner_record_revision' ||
            attempt + 1 >= _maxWriteAttempts) {
          rethrow;
        }
      }
    }
    throw const PersonalSyncCurriculumReconcilerException(
      'academy_sync_replica_contention',
      'The local Academy sync replica changed too frequently to merge safely.',
    );
  }

  CurriculumSessionProgress _buildCheckpoint({
    required PersonalWorkspaceId workspaceId,
    required _AcademyReplicaState state,
    required PersonalSyncProjectionSnapshot projection,
  }) {
    if (state.workspaceId != workspaceId ||
        projection.workspaceId != workspaceId ||
        projection.kind != PersonalSyncEventKind.progress ||
        projection.mergePolicy != PersonalSyncMergePolicy.monotonicMaximum) {
      throw const PersonalSyncCurriculumReconcilerException(
        'academy_sync_projection_identity_conflict',
        'An Academy sync projection belongs to another workspace or contract.',
      );
    }
    final progress = _AcademyProgressWire.fromProjection(projection);
    if (progress.key != state.key ||
        projection.entityId != _progressEntityId(progress.key)) {
      throw const PersonalSyncCurriculumReconcilerException(
        'academy_sync_projection_key_conflict',
        'A personal Academy projection has an inconsistent session identity.',
      );
    }
    final responses = state.canonicalResponses();
    final completion = _chooseCompletion(
      progress: progress,
      history: state.completions.values,
    );
    final completed = progress.completed || completion != null;
    if (completed && completion == null) {
      throw const PersonalSyncCurriculumReconcilerException(
        'academy_sync_completion_missing_receipt',
        'A completed Academy sync projection requires a durable receipt.',
      );
    }
    final startedAt = _earliest(progress.startedAt, state.earliestAt);
    final updatedAt = _latest(
      _latest(projection.clientCreatedAt, state.latestAt),
      completion?.completedAt,
    );
    return CurriculumSessionProgress(
      key: progress.key,
      phase: completed
          ? CurriculumSessionProgressPhase.completed
          : CurriculumSessionProgressPhase.inProgress,
      interactionIndex: progress.interactionIndex,
      revision: projection.logicalRevision,
      startedAt: startedAt,
      updatedAt: updatedAt,
      choiceResponses: responses,
      completedAt: completion?.completedAt,
      completionReceiptId: completion?.completionReceiptId,
    );
  }
}

final class PersonalSyncCurriculumReconcilerException implements Exception {
  const PersonalSyncCurriculumReconcilerException(
    this.code,
    this.message, [
    this.cause,
  ]);

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() =>
      'PersonalSyncCurriculumReconcilerException($code): $message';
}

sealed class _AcademyReplicaMutation {
  const _AcademyReplicaMutation({
    required this.workspaceId,
    required this.key,
    required this.observedAt,
  });

  final PersonalWorkspaceId workspaceId;
  final CurriculumSessionProgressKey key;
  final DateTime observedAt;

  static _AcademyReplicaMutation? tryParse(DecryptedPersonalSyncEvent event) {
    try {
      return switch (event.envelope.stream) {
        'academy.attempt' => _AttemptMutation.fromEvent(event),
        'academy.history' => _CompletionMutation.fromEvent(event),
        'academy.progress' => _ProgressMutation.fromEvent(event),
        _ => null,
      };
    } on PersonalSyncCurriculumReconcilerException {
      rethrow;
    } on Object catch (error) {
      throw PersonalSyncCurriculumReconcilerException(
        'invalid_academy_sync_event',
        'A personal Academy sync event has an invalid structured payload.',
        error,
      );
    }
  }
}

final class _AttemptMutation extends _AcademyReplicaMutation {
  const _AttemptMutation({
    required super.workspaceId,
    required super.key,
    required super.observedAt,
    required this.attempt,
  });

  final _ReplicaAttempt attempt;

  factory _AttemptMutation.fromEvent(DecryptedPersonalSyncEvent event) {
    _requireEnvelope(
      event,
      kind: PersonalSyncEventKind.attempt,
      policy: PersonalSyncMergePolicy.appendOnly,
    );
    final key = _keyFromPayload(event.payload);
    final responseId = _string(event.payload, 'responseId');
    if (event.entityId != 'attempt:$responseId') {
      throw const PersonalSyncCurriculumReconcilerException(
        'academy_sync_attempt_identity_mismatch',
        'An Academy attempt does not match its encrypted entity identity.',
      );
    }
    return _AttemptMutation(
      workspaceId: event.envelope.workspaceId,
      key: key,
      observedAt: event.envelope.clientCreatedAt,
      attempt: _ReplicaAttempt(
        responseId: responseId,
        interactionId: _string(event.payload, 'interactionId'),
        selectedOptionId: _string(event.payload, 'selectedOptionId'),
        isCorrect: _bool(event.payload, 'isCorrect'),
        answeredAt: _time(event.payload, 'answeredAt'),
      ),
    );
  }
}

final class _CompletionMutation extends _AcademyReplicaMutation {
  const _CompletionMutation({
    required super.workspaceId,
    required super.key,
    required super.observedAt,
    required this.completion,
  });

  final _ReplicaCompletion completion;

  factory _CompletionMutation.fromEvent(DecryptedPersonalSyncEvent event) {
    _requireEnvelope(
      event,
      kind: PersonalSyncEventKind.studyHistory,
      policy: PersonalSyncMergePolicy.appendOnly,
    );
    final key = _keyFromPayload(event.payload);
    final receipt = _string(event.payload, 'completionReceiptId');
    if (event.entityId != 'completion:$receipt') {
      throw const PersonalSyncCurriculumReconcilerException(
        'academy_sync_completion_identity_mismatch',
        'An Academy completion does not match its encrypted entity identity.',
      );
    }
    return _CompletionMutation(
      workspaceId: event.envelope.workspaceId,
      key: key,
      observedAt: event.envelope.clientCreatedAt,
      completion: _ReplicaCompletion(
        completionReceiptId: receipt,
        completedAt: _time(event.payload, 'completedAt'),
      ),
    );
  }
}

final class _ProgressMutation extends _AcademyReplicaMutation {
  const _ProgressMutation({
    required super.workspaceId,
    required super.key,
    required super.observedAt,
  });

  factory _ProgressMutation.fromEvent(DecryptedPersonalSyncEvent event) {
    _requireEnvelope(
      event,
      kind: PersonalSyncEventKind.progress,
      policy: PersonalSyncMergePolicy.monotonicMaximum,
    );
    final key = _keyFromPayload(event.payload);
    if (event.entityId != _progressEntityId(key)) {
      throw const PersonalSyncCurriculumReconcilerException(
        'academy_sync_progress_identity_mismatch',
        'An Academy progress event does not match its encrypted session key.',
      );
    }
    // Structural validation happens here rather than waiting for a later
    // materialized read. This makes a poisoned remote event retry visibly and
    // fail closed without allowing an incomplete checkpoint to render.
    _AcademyProgressWire.fromPayload(
      payload: event.payload,
      logicalRevision: event.envelope.logicalRevision,
    );
    return _ProgressMutation(
      workspaceId: event.envelope.workspaceId,
      key: key,
      observedAt: event.envelope.clientCreatedAt,
    );
  }
}

final class _AcademyReplicaState {
  const _AcademyReplicaState({
    required this.workspaceId,
    required this.key,
    required this.earliestAt,
    required this.latestAt,
    required this.attempts,
    required this.completions,
  });

  factory _AcademyReplicaState.empty({
    required PersonalWorkspaceId workspaceId,
    required CurriculumSessionProgressKey key,
    required DateTime at,
  }) => _AcademyReplicaState(
    workspaceId: workspaceId,
    key: key,
    earliestAt: at.toUtc(),
    latestAt: at.toUtc(),
    attempts: const {},
    completions: const {},
  );

  factory _AcademyReplicaState.fromJson(Map<String, Object?> json) {
    try {
      if (json['schemaVersion'] !=
              PersonalSyncCurriculumReconciler._schemaVersion ||
          json['workspaceId'] is! String ||
          json['key'] is! Map ||
          json['earliestAt'] is! String ||
          json['latestAt'] is! String ||
          json['attempts'] is! Map ||
          json['completions'] is! Map) {
        throw const FormatException();
      }
      final attempts = <String, _ReplicaAttempt>{};
      for (final entry in (json['attempts'] as Map).entries) {
        if (entry.key is! String || entry.value is! Map) {
          throw const FormatException();
        }
        final value = _ReplicaAttempt.fromJson(
          Map<String, Object?>.from(entry.value as Map),
        );
        if (entry.key != value.responseId) throw const FormatException();
        attempts[value.responseId] = value;
      }
      final completions = <String, _ReplicaCompletion>{};
      for (final entry in (json['completions'] as Map).entries) {
        if (entry.key is! String || entry.value is! Map) {
          throw const FormatException();
        }
        final value = _ReplicaCompletion.fromJson(
          Map<String, Object?>.from(entry.value as Map),
        );
        if (entry.key != value.completionReceiptId) {
          throw const FormatException();
        }
        completions[value.completionReceiptId] = value;
      }
      final earliestAt = DateTime.parse(json['earliestAt'] as String).toUtc();
      final latestAt = DateTime.parse(json['latestAt'] as String).toUtc();
      if (earliestAt.microsecondsSinceEpoch <= 0 ||
          latestAt.isBefore(earliestAt)) {
        throw const FormatException();
      }
      return _AcademyReplicaState(
        workspaceId: json['workspaceId'] as String,
        key: CurriculumSessionProgressKey.fromJson(
          Map<String, Object?>.from(json['key'] as Map),
        ),
        earliestAt: earliestAt,
        latestAt: latestAt,
        attempts: Map.unmodifiable(attempts),
        completions: Map.unmodifiable(completions),
      );
    } on PersonalSyncCurriculumReconcilerException {
      rethrow;
    } on Object catch (error) {
      throw PersonalSyncCurriculumReconcilerException(
        'invalid_academy_sync_replica',
        'A local Academy sync replica failed integrity validation.',
        error,
      );
    }
  }

  final PersonalWorkspaceId workspaceId;
  final CurriculumSessionProgressKey key;
  final DateTime earliestAt;
  final DateTime latestAt;
  final Map<String, _ReplicaAttempt> attempts;
  final Map<String, _ReplicaCompletion> completions;

  _AcademyReplicaState apply(_AcademyReplicaMutation mutation) {
    if (workspaceId != mutation.workspaceId || key != mutation.key) {
      throw const PersonalSyncCurriculumReconcilerException(
        'academy_sync_replica_identity_conflict',
        'An Academy sync event changed the local replica identity.',
      );
    }
    final nextAttempts = <String, _ReplicaAttempt>{...attempts};
    final nextCompletions = <String, _ReplicaCompletion>{...completions};
    var changed = false;
    switch (mutation) {
      case _AttemptMutation(:final attempt):
        final prior = nextAttempts[attempt.responseId];
        if (prior == null) {
          nextAttempts[attempt.responseId] = attempt;
          changed = true;
        } else if (prior != attempt) {
          throw const PersonalSyncCurriculumReconcilerException(
            'academy_sync_attempt_receipt_conflict',
            'A synced Academy response receipt was reused with different data.',
          );
        }
      case _CompletionMutation(:final completion):
        final prior = nextCompletions[completion.completionReceiptId];
        if (prior == null) {
          nextCompletions[completion.completionReceiptId] = completion;
          changed = true;
        } else if (prior != completion) {
          throw const PersonalSyncCurriculumReconcilerException(
            'academy_sync_completion_receipt_conflict',
            'A synced Academy completion receipt was reused with different data.',
          );
        }
      case _ProgressMutation():
        // Generic projection storage is the authoritative materialization for
        // progress. It already carries the session timeline, so no duplicate
        // replica payload is needed until an attempt or history receipt lands.
        break;
    }
    final earliestAt = _earliest(this.earliestAt, mutation.observedAt);
    final latestAt = _latest(this.latestAt, mutation.observedAt);
    if (!changed &&
        earliestAt == this.earliestAt &&
        latestAt == this.latestAt) {
      return this;
    }
    return _AcademyReplicaState(
      workspaceId: workspaceId,
      key: key,
      earliestAt: earliestAt,
      latestAt: latestAt,
      attempts: Map.unmodifiable(nextAttempts),
      completions: Map.unmodifiable(nextCompletions),
    );
  }

  Map<CurriculumInteractionId, CurriculumChoiceResponse> canonicalResponses() {
    final byInteraction = <CurriculumInteractionId, List<_ReplicaAttempt>>{};
    for (final attempt in attempts.values) {
      (byInteraction[attempt.interactionId] ??= []).add(attempt);
    }
    final result = <CurriculumInteractionId, CurriculumChoiceResponse>{};
    for (final entry in byInteraction.entries) {
      final candidates = entry.value..sort(_compareAttempts);
      final chosen = candidates.last;
      result[entry.key] = CurriculumChoiceResponse(
        id: chosen.responseId,
        interactionId: chosen.interactionId,
        selectedOptionId: chosen.selectedOptionId,
        isCorrect: chosen.isCorrect,
        answeredAt: chosen.answeredAt,
      );
    }
    return Map.unmodifiable(result);
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': PersonalSyncCurriculumReconciler._schemaVersion,
    'workspaceId': workspaceId,
    'key': key.toJson(),
    'earliestAt': earliestAt.toUtc().toIso8601String(),
    'latestAt': latestAt.toUtc().toIso8601String(),
    'attempts': attempts.map(
      (id, value) => MapEntry<String, Object?>(id, value.toJson()),
    ),
    'completions': completions.map(
      (id, value) => MapEntry<String, Object?>(id, value.toJson()),
    ),
  };

  @override
  bool operator ==(Object other) =>
      other is _AcademyReplicaState &&
      workspaceId == other.workspaceId &&
      key == other.key &&
      earliestAt == other.earliestAt &&
      latestAt == other.latestAt &&
      _sameMap(attempts, other.attempts) &&
      _sameMap(completions, other.completions);

  @override
  int get hashCode => Object.hash(
    workspaceId,
    key,
    earliestAt,
    latestAt,
    attempts.length,
    completions.length,
  );
}

final class _ReplicaAttempt {
  const _ReplicaAttempt({
    required this.responseId,
    required this.interactionId,
    required this.selectedOptionId,
    required this.isCorrect,
    required this.answeredAt,
  });

  factory _ReplicaAttempt.fromJson(Map<String, Object?> json) =>
      _ReplicaAttempt(
        responseId: _string(json, 'responseId'),
        interactionId: _string(json, 'interactionId'),
        selectedOptionId: _string(json, 'selectedOptionId'),
        isCorrect: _bool(json, 'isCorrect'),
        answeredAt: _time(json, 'answeredAt'),
      );

  final String responseId;
  final CurriculumInteractionId interactionId;
  final String selectedOptionId;
  final bool isCorrect;
  final DateTime answeredAt;

  Map<String, Object?> toJson() => {
    'responseId': responseId,
    'interactionId': interactionId,
    'selectedOptionId': selectedOptionId,
    'isCorrect': isCorrect,
    'answeredAt': answeredAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is _ReplicaAttempt &&
      responseId == other.responseId &&
      interactionId == other.interactionId &&
      selectedOptionId == other.selectedOptionId &&
      isCorrect == other.isCorrect &&
      answeredAt == other.answeredAt;

  @override
  int get hashCode => Object.hash(
    responseId,
    interactionId,
    selectedOptionId,
    isCorrect,
    answeredAt,
  );
}

final class _ReplicaCompletion {
  const _ReplicaCompletion({
    required this.completionReceiptId,
    required this.completedAt,
  });

  factory _ReplicaCompletion.fromJson(Map<String, Object?> json) =>
      _ReplicaCompletion(
        completionReceiptId: _string(json, 'completionReceiptId'),
        completedAt: _time(json, 'completedAt'),
      );

  final String completionReceiptId;
  final DateTime completedAt;

  Map<String, Object?> toJson() => {
    'completionReceiptId': completionReceiptId,
    'completedAt': completedAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is _ReplicaCompletion &&
      completionReceiptId == other.completionReceiptId &&
      completedAt == other.completedAt;

  @override
  int get hashCode => Object.hash(completionReceiptId, completedAt);
}

final class _AcademyProgressWire {
  const _AcademyProgressWire({
    required this.key,
    required this.interactionIndex,
    required this.completed,
    required this.startedAt,
    required this.completedAt,
    required this.completionReceiptId,
  });

  factory _AcademyProgressWire.fromProjection(
    PersonalSyncProjectionSnapshot projection,
  ) => _AcademyProgressWire.fromPayload(
    payload: projection.payload,
    logicalRevision: projection.logicalRevision,
  );

  factory _AcademyProgressWire.fromPayload({
    required Map<String, Object?> payload,
    required int logicalRevision,
  }) {
    if (logicalRevision < 1) {
      throw const PersonalSyncCurriculumReconcilerException(
        'invalid_academy_sync_revision',
        'An Academy sync progress revision must be positive.',
      );
    }
    final completed = _bool(payload, 'completed');
    final completedAt = payload['completedAt'] == null
        ? null
        : _time(payload, 'completedAt');
    final completionReceiptId = payload['completionReceiptId'] == null
        ? null
        : _string(payload, 'completionReceiptId');
    if (completed && (completedAt == null || completionReceiptId == null)) {
      throw const PersonalSyncCurriculumReconcilerException(
        'academy_sync_completion_missing_receipt',
        'Completed Academy progress must include its receipt and timestamp.',
      );
    }
    if (!completed && (completedAt != null || completionReceiptId != null)) {
      throw const PersonalSyncCurriculumReconcilerException(
        'academy_sync_incomplete_completion_fields',
        'Incomplete Academy progress cannot include completion fields.',
      );
    }
    final startedAt = _time(payload, 'startedAt');
    if (completedAt != null && completedAt.isBefore(startedAt)) {
      throw const PersonalSyncCurriculumReconcilerException(
        'academy_sync_completion_time_conflict',
        'Academy completion cannot precede the session start time.',
      );
    }
    _nonNegativeInt(payload, 'choiceResponseCount');
    return _AcademyProgressWire(
      key: _keyFromPayload(payload),
      interactionIndex: _nonNegativeInt(payload, 'interactionIndex'),
      completed: completed,
      startedAt: startedAt,
      completedAt: completedAt,
      completionReceiptId: completionReceiptId,
    );
  }

  final CurriculumSessionProgressKey key;
  final int interactionIndex;
  final bool completed;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String? completionReceiptId;
}

_ReplicaCompletion? _chooseCompletion({
  required _AcademyProgressWire progress,
  required Iterable<_ReplicaCompletion> history,
}) {
  final candidates = <_ReplicaCompletion>[
    if (progress.completed)
      _ReplicaCompletion(
        completionReceiptId: progress.completionReceiptId!,
        completedAt: progress.completedAt!,
      ),
    ...history,
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

CurriculumSessionProgressKey _keyFromPayload(Map<String, Object?> payload) =>
    CurriculumSessionProgressKey(
      releaseId: _string(payload, 'releaseId'),
      microLessonNodeId: _string(payload, 'microLessonNodeId'),
      sessionId: _string(payload, 'sessionId'),
    );

void _requireEnvelope(
  DecryptedPersonalSyncEvent event, {
  required PersonalSyncEventKind kind,
  required PersonalSyncMergePolicy policy,
}) {
  if (event.envelope.kind != kind ||
      event.envelope.mergePolicy != policy ||
      event.envelope.tombstone) {
    throw const PersonalSyncCurriculumReconcilerException(
      'academy_sync_envelope_contract_mismatch',
      'An Academy sync event changed its declared kind or merge contract.',
    );
  }
}

String _string(Map<String, Object?> value, String key) {
  final result = value[key];
  if (result is! String ||
      !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:/-]*$').hasMatch(result)) {
    throw PersonalSyncCurriculumReconcilerException(
      'invalid_academy_sync_field',
      'Academy sync field `$key` is not a stable identifier.',
    );
  }
  return result;
}

bool _bool(Map<String, Object?> value, String key) {
  final result = value[key];
  if (result is! bool) {
    throw PersonalSyncCurriculumReconcilerException(
      'invalid_academy_sync_field',
      'Academy sync field `$key` must be a boolean.',
    );
  }
  return result;
}

int _nonNegativeInt(Map<String, Object?> value, String key) {
  final result = value[key];
  if (result is! int || result < 0) {
    throw PersonalSyncCurriculumReconcilerException(
      'invalid_academy_sync_field',
      'Academy sync field `$key` must be a non-negative integer.',
    );
  }
  return result;
}

DateTime _time(Map<String, Object?> value, String key) {
  final raw = value[key];
  final result = raw is String ? DateTime.tryParse(raw)?.toUtc() : null;
  if (result == null || result.microsecondsSinceEpoch <= 0) {
    throw PersonalSyncCurriculumReconcilerException(
      'invalid_academy_sync_field',
      'Academy sync field `$key` must be a valid timestamp.',
    );
  }
  return result;
}

String _replicaRecordId(CurriculumSessionProgressKey key) =>
    'session:${key.stableId}';

String _progressEntityId(CurriculumSessionProgressKey key) =>
    'session:${key.stableId}';

DateTime _earliest(DateTime left, DateTime right) =>
    left.isBefore(right) ? left.toUtc() : right.toUtc();

DateTime _latest(DateTime left, DateTime? right) =>
    right == null || left.isAfter(right) ? left.toUtc() : right.toUtc();

int _compareAttempts(_ReplicaAttempt left, _ReplicaAttempt right) {
  final time = left.answeredAt.compareTo(right.answeredAt);
  if (time != 0) return time;
  final response = left.responseId.compareTo(right.responseId);
  if (response != 0) return response;
  final option = left.selectedOptionId.compareTo(right.selectedOptionId);
  if (option != 0) return option;
  return left.isCorrect == right.isCorrect
      ? 0
      : left.isCorrect
      ? 1
      : -1;
}

bool _sameMap<T>(Map<String, T> left, Map<String, T> right) {
  if (left.length != right.length) return false;
  for (final entry in left.entries) {
    if (right[entry.key] != entry.value) return false;
  }
  return true;
}

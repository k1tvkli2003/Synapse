import 'dart:async';

import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_foundation/synapse_foundation.dart';

/// Local-first learner workspace attached to stable curriculum nodes.
///
/// This repository owns bounded personal notes, a node bookmark, and private
/// focus-time totals. It does not own immutable lesson bodies, session answers,
/// rewards, mastery, evidence authority, or cloud synchronization.
abstract interface class CurriculumStudyWorkspaceRepository {
  Future<CurriculumStudyWorkspace?> read(CurriculumStudyWorkspaceKey key);

  Future<CurriculumStudyWorkspace> open({
    required CurriculumStudyWorkspaceKey key,
    required CurriculumReleaseId releaseId,
  });

  Future<List<CurriculumStudyWorkspace>> listForSource(
    CurriculumSourceId sourceId, {
    bool bookmarkedOnly = false,
  });

  Future<CurriculumStudyWorkspace> setBookmarked({
    required CurriculumStudyWorkspaceKey key,
    required CurriculumReleaseId releaseId,
    required bool isBookmarked,
    required int expectedRevision,
  });

  Future<CurriculumStudyWorkspace> addNote({
    required CurriculumStudyWorkspaceKey key,
    required CurriculumReleaseId releaseId,
    required ContentLocale locale,
    required String body,
    required int expectedRevision,
    String? anchorId,
  });

  Future<CurriculumStudyWorkspace> updateNote({
    required CurriculumStudyWorkspaceKey key,
    required CurriculumReleaseId releaseId,
    required String noteId,
    required String body,
    required int expectedWorkspaceRevision,
    required int expectedNoteRevision,
  });

  Future<CurriculumStudyWorkspace> deleteNote({
    required CurriculumStudyWorkspaceKey key,
    required CurriculumReleaseId releaseId,
    required String noteId,
    required int expectedRevision,
  });

  Future<CurriculumStudyWorkspace> recordFocusSegment({
    required CurriculumStudyWorkspaceKey key,
    required CurriculumReleaseId releaseId,
    required String segmentId,
    required int durationSeconds,
    required int expectedRevision,
  });

  Future<List<CurriculumStudyWorkspaceIntegrityIssue>> auditIntegrity();
}

final class CurriculumStudyWorkspaceException implements Exception {
  const CurriculumStudyWorkspaceException(
    this.code,
    this.message, [
    this.cause,
  ]);

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'CurriculumStudyWorkspaceException($code): $message';
}

/// Privacy-safe integrity evidence. It never carries learner note bodies.
final class CurriculumStudyWorkspaceIntegrityIssue {
  const CurriculumStudyWorkspaceIntegrityIssue({
    required this.code,
    required this.message,
    this.workspaceId,
  });

  final String code;
  final String message;
  final String? workspaceId;
}

/// Versioned, atomic one-key adapter suitable for the current cross-platform
/// bootstrap store. The repository interface is intentionally storage-agnostic
/// so a later encrypted/database adapter can migrate records without changing
/// Academy presentation code.
final class LocalCurriculumStudyWorkspaceRepository
    implements CurriculumStudyWorkspaceRepository {
  LocalCurriculumStudyWorkspaceRepository({
    required KeyValueStore store,
    required Clock clock,
    required IdSource idSource,
  }) : this._(store, clock, idSource, _queueFor(store));

  LocalCurriculumStudyWorkspaceRepository._(
    this._store,
    this._clock,
    this._idSource,
    this._mutationQueue,
  );

  static const stateKey = '__synapse_curriculum_study_workspace_v1';
  static const currentSchemaVersion = 1;
  static final _stableIdPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:/-]*$');
  static final Expando<_WorkspaceMutationQueue> _mutationQueues = Expando();

  final KeyValueStore _store;
  final Clock _clock;
  final IdSource _idSource;
  final _WorkspaceMutationQueue _mutationQueue;

  @override
  Future<CurriculumStudyWorkspace?> read(CurriculumStudyWorkspaceKey key) =>
      _mutate(() async => (await _readState()).records[key.stableId]);

  @override
  Future<CurriculumStudyWorkspace> open({
    required CurriculumStudyWorkspaceKey key,
    required CurriculumReleaseId releaseId,
  }) => _mutate(() async {
    _requireStableId(releaseId, 'releaseId');
    final state = await _readState();
    final existing = state.records[key.stableId];
    if (existing != null && existing.lastOpenedReleaseId == releaseId) {
      return existing;
    }
    final now = _clock.nowUtc();
    final workspace = existing == null
        ? CurriculumStudyWorkspace(
            key: key,
            lastOpenedReleaseId: releaseId,
            isBookmarked: false,
            notes: const [],
            focusSecondsTotal: 0,
            focusSessionCount: 0,
            revision: 1,
            createdAt: now,
            updatedAt: now,
          )
        : _copyWorkspace(
            existing,
            lastOpenedReleaseId: releaseId,
            revision: existing.revision + 1,
            updatedAt: now,
          );
    state.records[key.stableId] = workspace;
    await _writeState(state);
    return workspace;
  });

  @override
  Future<List<CurriculumStudyWorkspace>> listForSource(
    CurriculumSourceId sourceId, {
    bool bookmarkedOnly = false,
  }) => _mutate(() async {
    _requireStableId(sourceId, 'sourceId');
    final values =
        (await _readState()).records.values
            .where(
              (workspace) =>
                  workspace.key.sourceId == sourceId &&
                  (!bookmarkedOnly || workspace.isBookmarked),
            )
            .toList()
          ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return List.unmodifiable(values);
  });

  @override
  Future<CurriculumStudyWorkspace> setBookmarked({
    required CurriculumStudyWorkspaceKey key,
    required CurriculumReleaseId releaseId,
    required bool isBookmarked,
    required int expectedRevision,
  }) => _mutate(() async {
    final state = await _readState();
    final existing = _requireWorkspace(state, key);
    _requireStableId(releaseId, 'releaseId');
    if (existing.isBookmarked == isBookmarked &&
        existing.lastOpenedReleaseId == releaseId) {
      return existing;
    }
    _requireRevision(existing, expectedRevision);
    final updated = _copyWorkspace(
      existing,
      lastOpenedReleaseId: releaseId,
      isBookmarked: isBookmarked,
      revision: existing.revision + 1,
      updatedAt: _clock.nowUtc(),
    );
    state.records[key.stableId] = updated;
    await _writeState(state);
    return updated;
  });

  @override
  Future<CurriculumStudyWorkspace> addNote({
    required CurriculumStudyWorkspaceKey key,
    required CurriculumReleaseId releaseId,
    required ContentLocale locale,
    required String body,
    required int expectedRevision,
    String? anchorId,
  }) => _mutate(() async {
    final state = await _readState();
    final existing = _requireWorkspace(state, key);
    _requireStableId(releaseId, 'releaseId');
    _requireRevision(existing, expectedRevision);
    if (existing.notes.length >=
        CurriculumStudyWorkspace.maxNotesPerWorkspace) {
      throw const CurriculumStudyWorkspaceException(
        'workspace_note_limit',
        'This study workspace reached its bounded local note limit.',
      );
    }
    final now = _clock.nowUtc();
    final note = CurriculumStudyNote(
      id: _idSource.nextId(),
      locale: locale,
      body: _normalizeNoteBody(body),
      anchorId: anchorId,
      revision: 1,
      createdAt: now,
      updatedAt: now,
    );
    final updated = _copyWorkspace(
      existing,
      lastOpenedReleaseId: releaseId,
      notes: [...existing.notes, note],
      revision: existing.revision + 1,
      updatedAt: now,
    );
    state.records[key.stableId] = updated;
    await _writeState(state);
    return updated;
  });

  @override
  Future<CurriculumStudyWorkspace> updateNote({
    required CurriculumStudyWorkspaceKey key,
    required CurriculumReleaseId releaseId,
    required String noteId,
    required String body,
    required int expectedWorkspaceRevision,
    required int expectedNoteRevision,
  }) => _mutate(() async {
    final state = await _readState();
    final existing = _requireWorkspace(state, key);
    _requireStableId(releaseId, 'releaseId');
    _requireStableId(noteId, 'noteId');
    _requireRevision(existing, expectedWorkspaceRevision);
    final index = existing.notes.indexWhere((note) => note.id == noteId);
    if (index < 0) {
      throw const CurriculumStudyWorkspaceException(
        'workspace_note_missing',
        'The requested study note does not exist.',
      );
    }
    final previous = existing.notes[index];
    if (previous.revision != expectedNoteRevision) {
      throw const CurriculumStudyWorkspaceException(
        'stale_workspace_note_revision',
        'The study note changed after this editor opened.',
      );
    }
    final normalized = _normalizeNoteBody(body);
    if (previous.body == normalized &&
        existing.lastOpenedReleaseId == releaseId) {
      return existing;
    }
    final now = _clock.nowUtc();
    final notes = [...existing.notes];
    notes[index] = CurriculumStudyNote(
      id: previous.id,
      locale: previous.locale,
      body: normalized,
      anchorId: previous.anchorId,
      revision: previous.revision + 1,
      createdAt: previous.createdAt,
      updatedAt: now,
    );
    final updated = _copyWorkspace(
      existing,
      lastOpenedReleaseId: releaseId,
      notes: notes,
      revision: existing.revision + 1,
      updatedAt: now,
    );
    state.records[key.stableId] = updated;
    await _writeState(state);
    return updated;
  });

  @override
  Future<CurriculumStudyWorkspace> deleteNote({
    required CurriculumStudyWorkspaceKey key,
    required CurriculumReleaseId releaseId,
    required String noteId,
    required int expectedRevision,
  }) => _mutate(() async {
    final state = await _readState();
    final existing = _requireWorkspace(state, key);
    _requireStableId(releaseId, 'releaseId');
    _requireStableId(noteId, 'noteId');
    _requireRevision(existing, expectedRevision);
    if (!existing.notes.any((note) => note.id == noteId)) {
      throw const CurriculumStudyWorkspaceException(
        'workspace_note_missing',
        'The requested study note does not exist.',
      );
    }
    final now = _clock.nowUtc();
    final updated = _copyWorkspace(
      existing,
      lastOpenedReleaseId: releaseId,
      notes: existing.notes.where((note) => note.id != noteId),
      revision: existing.revision + 1,
      updatedAt: now,
    );
    state.records[key.stableId] = updated;
    await _writeState(state);
    return updated;
  });

  @override
  Future<CurriculumStudyWorkspace> recordFocusSegment({
    required CurriculumStudyWorkspaceKey key,
    required CurriculumReleaseId releaseId,
    required String segmentId,
    required int durationSeconds,
    required int expectedRevision,
  }) => _mutate(() async {
    final state = await _readState();
    final existing = _requireWorkspace(state, key);
    _requireStableId(releaseId, 'releaseId');
    _requireStableId(segmentId, 'segmentId');
    if (durationSeconds < 1 ||
        durationSeconds > CurriculumStudyWorkspace.maxFocusSegmentSeconds) {
      throw ArgumentError.value(durationSeconds, 'durationSeconds');
    }
    if (existing.lastFocusSegmentId == segmentId) {
      if (existing.lastFocusSegmentSeconds != durationSeconds) {
        throw const CurriculumStudyWorkspaceException(
          'focus_segment_conflict',
          'A focus segment ID cannot be reused with another duration.',
        );
      }
      return existing;
    }
    _requireRevision(existing, expectedRevision);
    final now = _clock.nowUtc();
    final updated = _copyWorkspace(
      existing,
      lastOpenedReleaseId: releaseId,
      focusSecondsTotal: existing.focusSecondsTotal + durationSeconds,
      focusSessionCount: existing.focusSessionCount + 1,
      lastFocusSegmentId: segmentId,
      lastFocusSegmentSeconds: durationSeconds,
      lastFocusCompletedAt: now,
      revision: existing.revision + 1,
      updatedAt: now,
    );
    state.records[key.stableId] = updated;
    await _writeState(state);
    return updated;
  });

  @override
  Future<List<CurriculumStudyWorkspaceIntegrityIssue>> auditIntegrity() =>
      _mutate(() async {
        try {
          await _readState();
          return const [];
        } on CurriculumStudyWorkspaceException catch (error) {
          return [
            CurriculumStudyWorkspaceIntegrityIssue(
              code: error.code,
              message: error.message,
            ),
          ];
        }
      });

  Future<_WorkspaceRegistryState> _readState() async {
    final raw = await _store.read(stateKey);
    if (raw == null) return _WorkspaceRegistryState.empty();
    if (raw is! Map || raw.keys.any((key) => key is! String)) {
      throw const CurriculumStudyWorkspaceException(
        'corrupt_workspace_registry',
        'Study workspace registry is not a JSON object.',
      );
    }
    try {
      return _WorkspaceRegistryState.fromJson(Map<String, Object?>.from(raw));
    } on CurriculumStudyWorkspaceException {
      rethrow;
    } on Object catch (error) {
      throw CurriculumStudyWorkspaceException(
        'corrupt_workspace_registry',
        'Study workspace registry failed schema validation.',
        error,
      );
    }
  }

  Future<void> _writeState(_WorkspaceRegistryState state) =>
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

  static _WorkspaceMutationQueue _queueFor(KeyValueStore store) =>
      _mutationQueues[store] ??= _WorkspaceMutationQueue();

  static CurriculumStudyWorkspace _requireWorkspace(
    _WorkspaceRegistryState state,
    CurriculumStudyWorkspaceKey key,
  ) {
    final workspace = state.records[key.stableId];
    if (workspace == null) {
      throw const CurriculumStudyWorkspaceException(
        'workspace_missing',
        'Open the study workspace before changing it.',
      );
    }
    return workspace;
  }

  static void _requireRevision(
    CurriculumStudyWorkspace workspace,
    int expectedRevision,
  ) {
    if (workspace.revision != expectedRevision) {
      throw const CurriculumStudyWorkspaceException(
        'stale_workspace_revision',
        'The study workspace changed after this view opened.',
      );
    }
  }

  static void _requireStableId(String value, String field) {
    if (value != value.trim() || !_stableIdPattern.hasMatch(value)) {
      throw ArgumentError.value(value, field, 'Invalid stable ID.');
    }
  }

  static String _normalizeNoteBody(String value) =>
      value.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
}

final class _WorkspaceMutationQueue {
  Future<void> tail = Future.value();
}

final class _WorkspaceRegistryState {
  _WorkspaceRegistryState({
    required Map<String, CurriculumStudyWorkspace> records,
  }) : records = Map.of(records);

  factory _WorkspaceRegistryState.empty() =>
      _WorkspaceRegistryState(records: const {});

  final Map<String, CurriculumStudyWorkspace> records;

  Map<String, Object?> toJson() => {
    'schemaVersion':
        LocalCurriculumStudyWorkspaceRepository.currentSchemaVersion,
    'records': records.map(
      (id, workspace) => MapEntry<String, Object?>(id, workspace.toJson()),
    ),
    'integrity': {
      'recordCount': records.length,
      'noteCount': records.values.fold<int>(
        0,
        (total, workspace) => total + workspace.notes.length,
      ),
      'focusSessionCount': records.values.fold<int>(
        0,
        (total, workspace) => total + workspace.focusSessionCount,
      ),
    },
  };

  factory _WorkspaceRegistryState.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] !=
        LocalCurriculumStudyWorkspaceRepository.currentSchemaVersion) {
      throw const CurriculumStudyWorkspaceException(
        'unsupported_workspace_schema',
        'Unsupported study workspace registry schema.',
      );
    }
    final recordsJson = _jsonObject(json['records'], 'records');
    final records = <String, CurriculumStudyWorkspace>{};
    for (final entry in recordsJson.entries) {
      final workspace = CurriculumStudyWorkspace.fromJson(
        _jsonObject(entry.value, 'records.${entry.key}'),
      );
      if (workspace.key.stableId != entry.key) {
        throw const CurriculumStudyWorkspaceException(
          'corrupt_workspace_registry',
          'Study workspace identity does not match its registry key.',
        );
      }
      records[entry.key] = workspace;
    }
    final integrity = _jsonObject(json['integrity'], 'integrity');
    final expectedNotes = records.values.fold<int>(
      0,
      (total, workspace) => total + workspace.notes.length,
    );
    final expectedFocusSessions = records.values.fold<int>(
      0,
      (total, workspace) => total + workspace.focusSessionCount,
    );
    if (integrity['recordCount'] != records.length ||
        integrity['noteCount'] != expectedNotes ||
        integrity['focusSessionCount'] != expectedFocusSessions) {
      throw const CurriculumStudyWorkspaceException(
        'corrupt_workspace_registry',
        'Study workspace integrity summary does not match its records.',
      );
    }
    return _WorkspaceRegistryState(records: records);
  }
}

Map<String, Object?> _jsonObject(Object? value, String field) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw CurriculumStudyWorkspaceException(
      'corrupt_workspace_registry',
      '$field must be a JSON object.',
    );
  }
  return Map<String, Object?>.from(value);
}

CurriculumStudyWorkspace _copyWorkspace(
  CurriculumStudyWorkspace source, {
  CurriculumReleaseId? lastOpenedReleaseId,
  bool? isBookmarked,
  Iterable<CurriculumStudyNote>? notes,
  int? focusSecondsTotal,
  int? focusSessionCount,
  String? lastFocusSegmentId,
  int? lastFocusSegmentSeconds,
  DateTime? lastFocusCompletedAt,
  int? revision,
  DateTime? updatedAt,
}) => CurriculumStudyWorkspace(
  key: source.key,
  lastOpenedReleaseId: lastOpenedReleaseId ?? source.lastOpenedReleaseId,
  isBookmarked: isBookmarked ?? source.isBookmarked,
  notes: notes ?? source.notes,
  focusSecondsTotal: focusSecondsTotal ?? source.focusSecondsTotal,
  focusSessionCount: focusSessionCount ?? source.focusSessionCount,
  lastFocusSegmentId: lastFocusSegmentId ?? source.lastFocusSegmentId,
  lastFocusSegmentSeconds:
      lastFocusSegmentSeconds ?? source.lastFocusSegmentSeconds,
  lastFocusCompletedAt: lastFocusCompletedAt ?? source.lastFocusCompletedAt,
  revision: revision ?? source.revision,
  createdAt: source.createdAt,
  updatedAt: updatedAt ?? source.updatedAt,
);

import 'dart:math' as math;

import 'package:synapse_core/synapse_core.dart';

import '../workspace/resource_document_reading_state_repository.dart';
import '../workspace/resource_workspace_repository.dart';
import 'encrypted_indexed_learner_record_store.dart';
import 'indexed_resource_document_reading_state_repository.dart';
import 'indexed_resource_workspace_repository.dart';
import 'learner_data_migration_journal.dart';

final _legacyAnchorTimestamp = DateTime.utc(2000);

final class LearnerDataMigrationReceipt {
  const LearnerDataMigrationReceipt({
    required this.migrationId,
    required this.sourceSnapshotSha256,
    required this.importedCount,
    required this.completedAt,
    required this.legacySourceRetained,
  });

  final String migrationId;
  final String sourceSnapshotSha256;
  final int importedCount;
  final DateTime completedAt;
  final bool legacySourceRetained;
}

final class LegacyLearnerDataMigrationException implements Exception {
  const LegacyLearnerDataMigrationException(
    this.code,
    this.message, [
    this.cause,
  ]);

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'LegacyLearnerDataMigrationException($code): $message';
}

/// Crash-resumable migration from rollback-safe legacy registries into the
/// encrypted indexed Learner Data Plane.
///
/// Source keys are deliberately never deleted. A crash after an indexed batch
/// but before its journal checkpoint is safe because an exact batch retry is
/// idempotent and reconciliation runs before completion is recorded.
final class LegacyLearnerDataMigrationCoordinator {
  factory LegacyLearnerDataMigrationCoordinator({
    required IndexedLearnerRecordStore records,
    required LearnerDataMigrationJournal journal,
    required IndexedResourceWorkspaceRepository indexedWorkspace,
    required IndexedResourceDocumentReadingStateRepository indexedReadingState,
    int chunkSize = 100,
  }) {
    if (chunkSize < 1 || chunkSize > 500) {
      throw ArgumentError.value(
        chunkSize,
        'chunkSize',
        'Migration chunks must contain between 1 and 500 records.',
      );
    }
    return LegacyLearnerDataMigrationCoordinator._(
      records,
      journal,
      indexedWorkspace,
      indexedReadingState,
      chunkSize,
    );
  }

  LegacyLearnerDataMigrationCoordinator._(
    this._records,
    this._journal,
    this._indexedWorkspace,
    this._indexedReadingState,
    this.chunkSize,
  );

  static const workspaceMigrationId = 'resource-workspace-v1-to-indexed-v1';
  static const readingStateMigrationId =
      'resource-reading-state-v1-to-indexed-v1';

  final IndexedLearnerRecordStore _records;
  final LearnerDataMigrationJournal _journal;
  final IndexedResourceWorkspaceRepository _indexedWorkspace;
  final IndexedResourceDocumentReadingStateRepository _indexedReadingState;
  final int chunkSize;

  Future<LearnerDataMigrationReceipt> migrateWorkspace(
    ResourceWorkspaceRepository legacy,
  ) async {
    final snapshot = await legacy.exportSnapshot();
    final sourceDigest = LearnerDataMigrationJournal.snapshotDigest(
      snapshot.toJson(),
    );
    final anchorsById = {
      for (final value in snapshot.anchors) value.stableId: value,
    };
    final drafts = <PrivateLearnerRecordDraft>[
      ...snapshot.documents.map(_documentDraft),
      ...snapshot.anchors.map(_anchorDraft),
      ...snapshot.annotations.map(
        (value) => _annotationDraft(value, anchorsById),
      ),
      ...snapshot.bookmarks.map((value) => _bookmarkDraft(value, anchorsById)),
      ...snapshot.crossReferences.map(_crossReferenceDraft),
    ];
    final completed = await _migrate(
      migrationId: workspaceMigrationId,
      sourceKey: LocalResourceWorkspaceRepository.stateKey,
      sourceSnapshotSha256: sourceDigest,
      drafts: drafts,
      reconcile: () async {
        await _reconcileDrafts(drafts);
        final issues = await _indexedWorkspace.auditIntegrity();
        if (issues.isNotEmpty) {
          throw const LegacyLearnerDataMigrationException(
            'workspace_migration_integrity_failed',
            'Indexed workspace failed post-migration integrity validation.',
          );
        }
      },
    );
    return _receipt(completed);
  }

  Future<LearnerDataMigrationReceipt> migrateReadingState(
    ResourceDocumentReadingStateRepository legacy,
  ) async {
    final positions = (await legacy.listRecent()).toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    final sourceDigest = LearnerDataMigrationJournal.snapshotDigest({
      'schemaVersion': 1,
      'records': positions.map((value) => value.toJson()).toList(),
    });
    final drafts = positions
        .map(
          (value) => PrivateLearnerRecordDraft(
            namespace: IndexedResourceDocumentReadingStateRepository.namespace,
            recordId: value.id,
            scopeId: value.documentId,
            kind: IndexedResourceDocumentReadingStateRepository.kind,
            updatedAt: value.updatedAt,
            payload: value.toJson(),
          ),
        )
        .toList(growable: false);
    final completed = await _migrate(
      migrationId: readingStateMigrationId,
      sourceKey: LocalResourceDocumentReadingStateRepository.stateKey,
      sourceSnapshotSha256: sourceDigest,
      drafts: drafts,
      reconcile: () async {
        await _reconcileDrafts(drafts);
        final issues = await _indexedReadingState.auditIntegrity();
        if (issues.isNotEmpty) {
          throw const LegacyLearnerDataMigrationException(
            'reading_state_migration_integrity_failed',
            'Indexed reading state failed post-migration integrity validation.',
          );
        }
      },
    );
    return _receipt(completed);
  }

  /// Exports the indexed workspace back into the preserved v1 legacy key.
  /// The caller must prevent concurrent workspace writes for this operation.
  Future<LearnerDataMigrationReceipt> prepareWorkspaceRollback(
    LocalResourceWorkspaceRepository legacy,
  ) async {
    final checkpoint = await _requireCompleted(workspaceMigrationId);
    final snapshot = await _indexedWorkspace.exportSnapshot();
    final restored = await legacy.replaceSnapshotForRollback(snapshot);
    if (CanonicalJson.encode(restored.toJson()) !=
        CanonicalJson.encode(snapshot.toJson())) {
      throw const LegacyLearnerDataMigrationException(
        'workspace_rollback_reconciliation_failed',
        'Legacy workspace rollback snapshot does not match indexed state.',
      );
    }
    final rolledBack = await _journal.markRolledBack(
      migrationId: checkpoint.migrationId,
      expectedCursor: checkpoint.cursor,
    );
    return _receipt(rolledBack);
  }

  /// Exports indexed PDF positions back into the preserved v1 legacy key.
  /// The caller must prevent concurrent reading-state writes while it runs.
  Future<LearnerDataMigrationReceipt> prepareReadingStateRollback(
    LocalResourceDocumentReadingStateRepository legacy,
  ) async {
    final checkpoint = await _requireCompleted(readingStateMigrationId);
    final positions = await _indexedReadingState.listRecent();
    final restored = await legacy.replacePositionsForRollback(positions);
    if (CanonicalJson.encode(
          restored.map((value) => value.toJson()).toList(),
        ) !=
        CanonicalJson.encode(
          (positions.toList()
                ..sort((left, right) => left.id.compareTo(right.id)))
              .map((value) => value.toJson())
              .toList(),
        )) {
      throw const LegacyLearnerDataMigrationException(
        'reading_state_rollback_reconciliation_failed',
        'Legacy reading-state rollback does not match indexed state.',
      );
    }
    final rolledBack = await _journal.markRolledBack(
      migrationId: checkpoint.migrationId,
      expectedCursor: checkpoint.cursor,
    );
    return _receipt(rolledBack);
  }

  Future<LearnerDataMigrationCheckpoint> _requireCompleted(
    String migrationId,
  ) async {
    final checkpoint = await _journal.read(migrationId);
    if (checkpoint?.state != LearnerDataMigrationState.completed) {
      throw const LegacyLearnerDataMigrationException(
        'migration_not_ready_for_rollback',
        'Only a completed migration can produce a rollback snapshot.',
      );
    }
    return checkpoint!;
  }

  Future<LearnerDataMigrationCheckpoint> _migrate({
    required String migrationId,
    required String sourceKey,
    required String sourceSnapshotSha256,
    required List<PrivateLearnerRecordDraft> drafts,
    required Future<void> Function() reconcile,
  }) async {
    var checkpoint = await _journal.begin(
      migrationId: migrationId,
      sourceKey: sourceKey,
      sourceSnapshotSha256: sourceSnapshotSha256,
    );
    if (checkpoint.state == LearnerDataMigrationState.rolledBack) {
      throw const LegacyLearnerDataMigrationException(
        'migration_previously_rolled_back',
        'A rolled-back migration requires a new reviewed migration version.',
      );
    }
    try {
      while (checkpoint.cursor < drafts.length) {
        if (checkpoint.state == LearnerDataMigrationState.completed) {
          throw const LegacyLearnerDataMigrationException(
            'completed_migration_cursor_mismatch',
            'Completed migration journal does not cover its source snapshot.',
          );
        }
        if (checkpoint.state == LearnerDataMigrationState.failed) {
          checkpoint = await _journal.begin(
            migrationId: migrationId,
            sourceKey: sourceKey,
            sourceSnapshotSha256: sourceSnapshotSha256,
          );
          continue;
        }
        final end = math.min(checkpoint.cursor + chunkSize, drafts.length);
        final batch = drafts
            .sublist(checkpoint.cursor, end)
            .map(
              (draft) => PrivateLearnerRecordMutation(
                draft: draft,
                expectedRevision: null,
              ),
            );
        await _records.putBatch(batch);
        try {
          checkpoint = await _journal.checkpoint(
            migrationId: migrationId,
            expectedCursor: checkpoint.cursor,
            nextCursor: end,
            importedCount: end,
          );
        } on LearnerDataMigrationJournalException catch (error) {
          if (error.code != 'stale_migration_cursor') rethrow;
          checkpoint = (await _journal.read(migrationId))!;
        }
      }
      await reconcile();
      if (checkpoint.state == LearnerDataMigrationState.completed) {
        return checkpoint;
      }
      return await _journal.complete(
        migrationId: migrationId,
        expectedCursor: checkpoint.cursor,
        importedCount: drafts.length,
      );
    } on Object catch (error) {
      await _recordFailure(migrationId);
      if (error is LegacyLearnerDataMigrationException) rethrow;
      throw LegacyLearnerDataMigrationException(
        'legacy_learner_data_migration_failed',
        'Legacy learner data could not be migrated safely.',
        error,
      );
    }
  }

  Future<void> _recordFailure(String migrationId) async {
    try {
      final current = await _journal.read(migrationId);
      if (current?.state == LearnerDataMigrationState.running) {
        await _journal.fail(
          migrationId: migrationId,
          expectedCursor: current!.cursor,
          errorCode: 'legacy_import_interrupted',
        );
      }
    } on Object {
      // Never replace the original migration failure with journal cleanup.
    }
  }

  Future<void> _reconcileDrafts(
    Iterable<PrivateLearnerRecordDraft> drafts,
  ) async {
    for (final expected in drafts) {
      final actual = await _records.read(
        namespace: expected.namespace,
        recordId: expected.recordId,
      );
      if (actual == null || !_sameRecord(expected, actual)) {
        throw const LegacyLearnerDataMigrationException(
          'migration_reconciliation_failed',
          'Indexed migration output does not match its source snapshot.',
        );
      }
    }
  }
}

LearnerDataMigrationReceipt _receipt(
  LearnerDataMigrationCheckpoint checkpoint,
) => LearnerDataMigrationReceipt(
  migrationId: checkpoint.migrationId,
  sourceSnapshotSha256: checkpoint.sourceSnapshotSha256,
  importedCount: checkpoint.importedCount,
  completedAt: checkpoint.completedAt ?? checkpoint.updatedAt,
  legacySourceRetained: true,
);

PrivateLearnerRecordDraft _documentDraft(ResourceDocument value) =>
    PrivateLearnerRecordDraft(
      namespace: IndexedResourceWorkspaceRepository.documentNamespace,
      recordId: value.id,
      scopeId: value.contentAddress,
      kind: 'document',
      updatedAt: value.createdAt,
      payload: value.toJson(),
    );

PrivateLearnerRecordDraft _anchorDraft(ResourceAnchor value) =>
    PrivateLearnerRecordDraft(
      namespace: IndexedResourceWorkspaceRepository.anchorNamespace,
      recordId: value.stableId,
      scopeId: value.resource.stableId,
      kind: value.kind.name.toLowerCase(),
      updatedAt: _legacyAnchorTimestamp,
      payload: value.toJson(),
    );

PrivateLearnerRecordDraft _annotationDraft(
  ResourceAnnotation value,
  Map<ResourceAnchorId, ResourceAnchor> anchors,
) {
  final anchor = anchors[value.anchorId];
  if (anchor == null) {
    throw const LegacyLearnerDataMigrationException(
      'migration_annotation_anchor_missing',
      'Workspace snapshot contains an annotation without its anchor.',
    );
  }
  return PrivateLearnerRecordDraft(
    namespace: IndexedResourceWorkspaceRepository.annotationNamespace,
    recordId: value.id,
    scopeId: anchor.resource.stableId,
    kind: value.kind.name.toLowerCase(),
    updatedAt: value.updatedAt,
    payload: value.toJson(),
    tombstone: value.state == ResourceAnnotationState.deleted,
  );
}

PrivateLearnerRecordDraft _bookmarkDraft(
  ResourceBookmark value,
  Map<ResourceAnchorId, ResourceAnchor> anchors,
) {
  final anchor = anchors[value.anchorId];
  if (anchor == null) {
    throw const LegacyLearnerDataMigrationException(
      'migration_bookmark_anchor_missing',
      'Workspace snapshot contains a bookmark without its anchor.',
    );
  }
  return PrivateLearnerRecordDraft(
    namespace: IndexedResourceWorkspaceRepository.bookmarkNamespace,
    recordId: value.id,
    scopeId: anchor.resource.stableId,
    kind: 'bookmark',
    updatedAt: value.updatedAt,
    payload: value.toJson(),
    tombstone: value.isDeleted,
  );
}

PrivateLearnerRecordDraft _crossReferenceDraft(ResourceCrossReference value) =>
    PrivateLearnerRecordDraft(
      namespace: IndexedResourceWorkspaceRepository.crossReferenceNamespace,
      recordId: value.id,
      scopeId: value.from.stableId,
      kind: value.kind.name.toLowerCase(),
      updatedAt: value.updatedAt,
      payload: value.toJson(),
      tombstone: value.isDeleted,
    );

bool _sameRecord(
  PrivateLearnerRecordDraft expected,
  PrivateLearnerRecord actual,
) =>
    expected.namespace == actual.namespace &&
    expected.recordId == actual.recordId &&
    expected.scopeId == actual.scopeId &&
    expected.kind == actual.kind &&
    expected.updatedAt == actual.updatedAt &&
    expected.tombstone == actual.tombstone &&
    CanonicalJson.encode(expected.payload) ==
        CanonicalJson.encode(actual.payload);

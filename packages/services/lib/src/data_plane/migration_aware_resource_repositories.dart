import 'package:synapse_core/synapse_core.dart';

import '../workspace/resource_document_reading_state_repository.dart';
import '../workspace/resource_workspace_repository.dart';
import 'legacy_learner_data_migration_coordinator.dart';

enum LearnerDataPlaneActivationMode { indexed, legacyFallback }

final class LearnerDataPlaneActivationStatus {
  const LearnerDataPlaneActivationStatus({
    required this.mode,
    this.failureCode,
  });

  final LearnerDataPlaneActivationMode mode;
  final String? failureCode;
}

final class MigrationAwareResourceWorkspaceRepository
    implements ResourceWorkspaceRepository {
  MigrationAwareResourceWorkspaceRepository({
    required ResourceWorkspaceRepository legacy,
    required ResourceWorkspaceRepository indexed,
    required Future<void> Function() migrate,
  }) : _activation = _activate(
         legacy: legacy,
         indexed: indexed,
         migrate: migrate,
         fallbackCode: 'resource_workspace_migration_failed',
       );

  final Future<_RepositoryActivation<ResourceWorkspaceRepository>> _activation;

  Future<LearnerDataPlaneActivationStatus> get activationStatus async =>
      (await _activation).status;

  Future<ResourceWorkspaceRepository> get _active async =>
      (await _activation).repository;

  @override
  Future<ResourceWorkspaceSnapshot> exportSnapshot() async =>
      (await _active).exportSnapshot();

  @override
  Future<ResourceDocument?> readDocument(ResourceDocumentId id) async =>
      (await _active).readDocument(id);

  @override
  Future<ResourceDocument?> findDocumentByDigest(String contentSha256) async =>
      (await _active).findDocumentByDigest(contentSha256);

  @override
  Future<List<ResourceDocument>> listDocuments() async =>
      (await _active).listDocuments();

  @override
  Future<ResourceDocument> registerDocument(ResourceDocument document) async =>
      (await _active).registerDocument(document);

  @override
  Future<ResourceAnchor?> readAnchor(ResourceAnchorId id) async =>
      (await _active).readAnchor(id);

  @override
  Future<ResourceAnchor> registerAnchor(ResourceAnchor anchor) async =>
      (await _active).registerAnchor(anchor);

  @override
  Future<List<ResourceAnchor>> listAnchorsForResource(
    ResourceReference resource,
  ) async => (await _active).listAnchorsForResource(resource);

  @override
  Future<ResourceAnnotation> addHighlight({
    required ResourceAnchor anchor,
    required ResourceArtifactColor color,
    Iterable<String> tagIds = const [],
  }) async => (await _active).addHighlight(
    anchor: anchor,
    color: color,
    tagIds: tagIds,
  );

  @override
  Future<ResourceAnnotation> addComment({
    required ResourceAnchor anchor,
    required ContentLocale locale,
    required String body,
    required ResourceArtifactColor color,
    Iterable<String> tagIds = const [],
  }) async => (await _active).addComment(
    anchor: anchor,
    locale: locale,
    body: body,
    color: color,
    tagIds: tagIds,
  );

  @override
  Future<ResourceAnnotation> addInk({
    required DocumentRegionResourceAnchor anchor,
    required Iterable<ResourceInkStroke> strokes,
    required ResourceArtifactColor color,
    Iterable<String> tagIds = const [],
  }) async => (await _active).addInk(
    anchor: anchor,
    strokes: strokes,
    color: color,
    tagIds: tagIds,
  );

  @override
  Future<ResourceAnnotation> setAnnotationState({
    required ResourceAnnotationId annotationId,
    required ResourceAnnotationState state,
    required int expectedRevision,
  }) async => (await _active).setAnnotationState(
    annotationId: annotationId,
    state: state,
    expectedRevision: expectedRevision,
  );

  @override
  Future<List<ResourceAnnotation>> listAnnotationsForResource(
    ResourceReference resource, {
    bool includeDeleted = false,
  }) async => (await _active).listAnnotationsForResource(
    resource,
    includeDeleted: includeDeleted,
  );

  @override
  Future<ResourceBookmark?> readBookmark(
    ResourceAnchorId anchorId, {
    bool includeDeleted = false,
  }) async =>
      (await _active).readBookmark(anchorId, includeDeleted: includeDeleted);

  @override
  Future<ResourceBookmark> setBookmarked({
    required ResourceAnchor anchor,
    required bool isBookmarked,
    required ResourceArtifactColor color,
    int? expectedRevision,
    String? label,
  }) async => (await _active).setBookmarked(
    anchor: anchor,
    isBookmarked: isBookmarked,
    color: color,
    expectedRevision: expectedRevision,
    label: label,
  );

  @override
  Future<List<ResourceBookmark>> listBookmarksForResource(
    ResourceReference resource, {
    bool includeDeleted = false,
  }) async => (await _active).listBookmarksForResource(
    resource,
    includeDeleted: includeDeleted,
  );

  @override
  Future<ResourceCrossReference?> readCrossReference(
    ResourceCrossReferenceId id, {
    bool includeDeleted = false,
  }) async =>
      (await _active).readCrossReference(id, includeDeleted: includeDeleted);

  @override
  Future<ResourceCrossReference> setCrossReference({
    required ResourceReference from,
    required ResourceReference to,
    required ResourceCrossReferenceKind kind,
    required bool isLinked,
    int? expectedRevision,
  }) async => (await _active).setCrossReference(
    from: from,
    to: to,
    kind: kind,
    isLinked: isLinked,
    expectedRevision: expectedRevision,
  );

  @override
  Future<List<ResourceCrossReference>> listCrossReferencesFrom(
    ResourceReference resource, {
    ResourceCrossReferenceKind? kind,
    bool includeDeleted = false,
  }) async => (await _active).listCrossReferencesFrom(
    resource,
    kind: kind,
    includeDeleted: includeDeleted,
  );

  @override
  Future<List<ResourceWorkspaceIntegrityIssue>> auditIntegrity() async =>
      (await _active).auditIntegrity();
}

final class MigrationAwareResourceDocumentReadingStateRepository
    implements ResourceDocumentReadingStateRepository {
  MigrationAwareResourceDocumentReadingStateRepository({
    required ResourceDocumentReadingStateRepository legacy,
    required ResourceDocumentReadingStateRepository indexed,
    required Future<void> Function() migrate,
  }) : _activation = _activate(
         legacy: legacy,
         indexed: indexed,
         migrate: migrate,
         fallbackCode: 'resource_reading_state_migration_failed',
       );

  final Future<_RepositoryActivation<ResourceDocumentReadingStateRepository>>
  _activation;

  Future<LearnerDataPlaneActivationStatus> get activationStatus async =>
      (await _activation).status;

  Future<ResourceDocumentReadingStateRepository> get _active async =>
      (await _activation).repository;

  @override
  Future<ResourceDocumentReadingPosition?> read(
    ResourceDocumentId documentId,
  ) async => (await _active).read(documentId);

  @override
  Future<List<ResourceDocumentReadingPosition>> listRecent() async =>
      (await _active).listRecent();

  @override
  Future<ResourceDocumentReadingPosition> savePosition({
    required ResourceDocument document,
    required int pageNumber,
    required int pagePositionMillionths,
    required int? expectedRevision,
  }) async => (await _active).savePosition(
    document: document,
    pageNumber: pageNumber,
    pagePositionMillionths: pagePositionMillionths,
    expectedRevision: expectedRevision,
  );

  @override
  Future<bool> clear({
    required ResourceDocumentId documentId,
    required int expectedRevision,
  }) async => (await _active).clear(
    documentId: documentId,
    expectedRevision: expectedRevision,
  );

  @override
  Future<List<ResourceDocumentReadingStateIntegrityIssue>>
  auditIntegrity() async => (await _active).auditIntegrity();
}

Future<_RepositoryActivation<T>> _activate<T>({
  required T legacy,
  required T indexed,
  required Future<void> Function() migrate,
  required String fallbackCode,
}) async {
  try {
    await migrate();
    return _RepositoryActivation(
      repository: indexed,
      status: const LearnerDataPlaneActivationStatus(
        mode: LearnerDataPlaneActivationMode.indexed,
      ),
    );
  } on LegacyLearnerDataMigrationException catch (error) {
    return _RepositoryActivation(
      repository: legacy,
      status: LearnerDataPlaneActivationStatus(
        mode: LearnerDataPlaneActivationMode.legacyFallback,
        failureCode: error.code,
      ),
    );
  } on Object {
    return _RepositoryActivation(
      repository: legacy,
      status: LearnerDataPlaneActivationStatus(
        mode: LearnerDataPlaneActivationMode.legacyFallback,
        failureCode: fallbackCode,
      ),
    );
  }
}

final class _RepositoryActivation<T> {
  const _RepositoryActivation({required this.repository, required this.status});

  final T repository;
  final LearnerDataPlaneActivationStatus status;
}

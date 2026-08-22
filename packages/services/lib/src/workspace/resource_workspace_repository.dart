import 'dart:async';

import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_foundation/synapse_foundation.dart';

/// Shared local-first metadata and learner-artifact authority for every
/// curriculum, document, case, and evidence context.
///
/// Binary document bytes deliberately live behind a separate blob-store port.
/// This registry stores only content-addressed metadata, universal anchors,
/// private annotations, and bookmark tombstones.
abstract interface class ResourceWorkspaceRepository {
  Future<ResourceWorkspaceSnapshot> exportSnapshot();

  Future<ResourceDocument?> readDocument(ResourceDocumentId id);

  Future<ResourceDocument?> findDocumentByDigest(String contentSha256);

  Future<List<ResourceDocument>> listDocuments();

  Future<ResourceDocument> registerDocument(ResourceDocument document);

  Future<ResourceAnchor?> readAnchor(ResourceAnchorId id);

  Future<ResourceAnchor> registerAnchor(ResourceAnchor anchor);

  Future<List<ResourceAnchor>> listAnchorsForResource(
    ResourceReference resource,
  );

  Future<ResourceAnnotation> addHighlight({
    required ResourceAnchor anchor,
    required ResourceArtifactColor color,
    Iterable<String> tagIds = const [],
  });

  Future<ResourceAnnotation> addComment({
    required ResourceAnchor anchor,
    required ContentLocale locale,
    required String body,
    required ResourceArtifactColor color,
    Iterable<String> tagIds = const [],
  });

  Future<ResourceAnnotation> addInk({
    required DocumentRegionResourceAnchor anchor,
    required Iterable<ResourceInkStroke> strokes,
    required ResourceArtifactColor color,
    Iterable<String> tagIds = const [],
  });

  Future<ResourceAnnotation> setAnnotationState({
    required ResourceAnnotationId annotationId,
    required ResourceAnnotationState state,
    required int expectedRevision,
  });

  Future<List<ResourceAnnotation>> listAnnotationsForResource(
    ResourceReference resource, {
    bool includeDeleted = false,
  });

  Future<ResourceBookmark?> readBookmark(
    ResourceAnchorId anchorId, {
    bool includeDeleted = false,
  });

  Future<ResourceBookmark> setBookmarked({
    required ResourceAnchor anchor,
    required bool isBookmarked,
    required ResourceArtifactColor color,
    int? expectedRevision,
    String? label,
  });

  Future<List<ResourceBookmark>> listBookmarksForResource(
    ResourceReference resource, {
    bool includeDeleted = false,
  });

  Future<ResourceCrossReference?> readCrossReference(
    ResourceCrossReferenceId id, {
    bool includeDeleted = false,
  });

  Future<ResourceCrossReference> setCrossReference({
    required ResourceReference from,
    required ResourceReference to,
    required ResourceCrossReferenceKind kind,
    required bool isLinked,
    int? expectedRevision,
  });

  Future<List<ResourceCrossReference>> listCrossReferencesFrom(
    ResourceReference resource, {
    ResourceCrossReferenceKind? kind,
    bool includeDeleted = false,
  });

  Future<List<ResourceWorkspaceIntegrityIssue>> auditIntegrity();
}

final class ResourceWorkspaceException implements Exception {
  const ResourceWorkspaceException(this.code, this.message, [this.cause]);

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'ResourceWorkspaceException($code): $message';
}

/// Privacy-safe audit evidence; learner text and source paths are never copied.
final class ResourceWorkspaceIntegrityIssue {
  const ResourceWorkspaceIntegrityIssue({
    required this.code,
    required this.message,
    this.recordId,
  });

  final String code;
  final String message;
  final String? recordId;
}

/// Deterministic, in-memory workspace snapshot used for private backup and
/// rollback-safe storage migrations. Callers must treat its JSON as learner
/// data: it must never enter logs, analytics, migration journals, or docs.
final class ResourceWorkspaceSnapshot {
  ResourceWorkspaceSnapshot._({
    required Iterable<ResourceDocument> documents,
    required Iterable<ResourceAnchor> anchors,
    required Iterable<ResourceAnnotation> annotations,
    required Iterable<ResourceBookmark> bookmarks,
    required Iterable<ResourceCrossReference> crossReferences,
  }) : documents = List.unmodifiable(documents),
       anchors = List.unmodifiable(anchors),
       annotations = List.unmodifiable(annotations),
       bookmarks = List.unmodifiable(bookmarks),
       crossReferences = List.unmodifiable(crossReferences);

  final List<ResourceDocument> documents;
  final List<ResourceAnchor> anchors;
  final List<ResourceAnnotation> annotations;
  final List<ResourceBookmark> bookmarks;
  final List<ResourceCrossReference> crossReferences;

  int get recordCount =>
      documents.length +
      anchors.length +
      annotations.length +
      bookmarks.length +
      crossReferences.length;

  Map<String, Object?> toJson() => _ResourceWorkspaceState(
    documents: {for (final value in documents) value.id: value},
    anchors: {for (final value in anchors) value.stableId: value},
    annotations: {for (final value in annotations) value.id: value},
    bookmarks: {for (final value in bookmarks) value.id: value},
    crossReferences: {for (final value in crossReferences) value.id: value},
  ).toJson();

  factory ResourceWorkspaceSnapshot.fromJson(Map<String, Object?> json) =>
      ResourceWorkspaceSnapshot._fromState(
        _ResourceWorkspaceState.fromJson(json),
      );

  factory ResourceWorkspaceSnapshot.fromRecords({
    required Iterable<ResourceDocument> documents,
    required Iterable<ResourceAnchor> anchors,
    required Iterable<ResourceAnnotation> annotations,
    required Iterable<ResourceBookmark> bookmarks,
    required Iterable<ResourceCrossReference> crossReferences,
  }) {
    final state = _ResourceWorkspaceState(
      documents: {for (final value in documents) value.id: value},
      anchors: {for (final value in anchors) value.stableId: value},
      annotations: {for (final value in annotations) value.id: value},
      bookmarks: {for (final value in bookmarks) value.id: value},
      crossReferences: {for (final value in crossReferences) value.id: value},
    );
    return ResourceWorkspaceSnapshot._fromState(
      _ResourceWorkspaceState.fromJson(state.toJson()),
    );
  }

  factory ResourceWorkspaceSnapshot._fromState(_ResourceWorkspaceState state) {
    List<T> sorted<T>(Iterable<T> values, String Function(T value) id) {
      final result = values.toList()
        ..sort((left, right) => id(left).compareTo(id(right)));
      return result;
    }

    return ResourceWorkspaceSnapshot._(
      documents: sorted(state.documents.values, (value) => value.id),
      anchors: sorted(state.anchors.values, (value) => value.stableId),
      annotations: sorted(state.annotations.values, (value) => value.id),
      bookmarks: sorted(state.bookmarks.values, (value) => value.id),
      crossReferences: sorted(
        state.crossReferences.values,
        (value) => value.id,
      ),
    );
  }
}

/// Additive bootstrap adapter for universal workspace metadata and artifacts.
///
/// The interface is intentionally storage-agnostic. This compact JSON registry
/// is a rollback-safe bridge until the indexed, encrypted local database lands;
/// it is not claimed to be the final large-PDF or multi-device storage engine.
final class LocalResourceWorkspaceRepository
    implements ResourceWorkspaceRepository {
  LocalResourceWorkspaceRepository({
    required KeyValueStore store,
    required Clock clock,
    required IdSource idSource,
  }) : this._(store, clock, idSource, _queueFor(store));

  LocalResourceWorkspaceRepository._(
    this._store,
    this._clock,
    this._idSource,
    this._mutationQueue,
  );

  static const stateKey = '__synapse_resource_workspace_v1';
  static const currentSchemaVersion = 1;
  static final _digestPattern = RegExp(r'^[0-9a-f]{64}$');
  static final Expando<_ResourceMutationQueue> _mutationQueues = Expando();

  final KeyValueStore _store;
  final Clock _clock;
  final IdSource _idSource;
  final _ResourceMutationQueue _mutationQueue;

  @override
  Future<ResourceWorkspaceSnapshot> exportSnapshot() => _mutate(() async {
    return ResourceWorkspaceSnapshot._fromState(await _readState());
  });

  /// Replaces only the legacy workspace key with a fully validated snapshot.
  /// Callers must quiesce workspace writes before using this explicit
  /// downgrade/export boundary.
  Future<ResourceWorkspaceSnapshot> replaceSnapshotForRollback(
    ResourceWorkspaceSnapshot snapshot,
  ) => _mutate(() async {
    final state = _ResourceWorkspaceState.fromJson(snapshot.toJson());
    await _writeState(state);
    final restored = ResourceWorkspaceSnapshot._fromState(await _readState());
    if (CanonicalJson.encode(restored.toJson()) !=
        CanonicalJson.encode(snapshot.toJson())) {
      throw const ResourceWorkspaceException(
        'resource_workspace_rollback_verification_failed',
        'Legacy workspace rollback snapshot failed read-after-write validation.',
      );
    }
    return restored;
  });

  @override
  Future<ResourceDocument?> readDocument(ResourceDocumentId id) =>
      _mutate(() async => (await _readState()).documents[id]);

  @override
  Future<ResourceDocument?> findDocumentByDigest(String contentSha256) =>
      _mutate(() async {
        _requireDigest(contentSha256);
        for (final document in (await _readState()).documents.values) {
          if (document.contentSha256 == contentSha256) return document;
        }
        return null;
      });

  @override
  Future<List<ResourceDocument>> listDocuments() => _mutate(() async {
    final values = (await _readState()).documents.values.toList()
      ..sort((left, right) {
        final byTime = right.createdAt.compareTo(left.createdAt);
        return byTime != 0 ? byTime : right.id.compareTo(left.id);
      });
    return List.unmodifiable(values);
  });

  @override
  Future<ResourceDocument> registerDocument(ResourceDocument document) =>
      _mutate(() async {
        final state = await _readState();
        final existing = state.documents[document.id];
        if (existing != null) {
          if (CanonicalJson.encode(existing.toJson()) ==
              CanonicalJson.encode(document.toJson())) {
            return existing;
          }
          throw const ResourceWorkspaceException(
            'resource_document_identity_collision',
            'A document ID already addresses different immutable metadata.',
          );
        }
        _validateDigestLengthConsistency(state, document);
        state.documents[document.id] = document;
        await _writeState(state);
        return document;
      });

  @override
  Future<ResourceAnchor?> readAnchor(ResourceAnchorId id) =>
      _mutate(() async => (await _readState()).anchors[id]);

  @override
  Future<ResourceAnchor> registerAnchor(ResourceAnchor anchor) =>
      _mutate(() async {
        final state = await _readState();
        _registerAnchorInState(state, anchor);
        await _writeState(state);
        return state.anchors[anchor.stableId]!;
      });

  @override
  Future<List<ResourceAnchor>> listAnchorsForResource(
    ResourceReference resource,
  ) => _mutate(() async {
    final values =
        (await _readState()).anchors.values
            .where((anchor) => anchor.resource == resource)
            .toList()
          ..sort((left, right) => left.stableId.compareTo(right.stableId));
    return List.unmodifiable(values);
  });

  @override
  Future<ResourceAnnotation> addHighlight({
    required ResourceAnchor anchor,
    required ResourceArtifactColor color,
    Iterable<String> tagIds = const [],
  }) => _mutate(() async {
    if (anchor is! CurriculumBlockResourceAnchor &&
        anchor is! DocumentTextRangeResourceAnchor &&
        anchor is! DocumentRegionResourceAnchor) {
      throw const ResourceWorkspaceException(
        'unsupported_highlight_anchor',
        'Highlights require a Block, text-range, or document-region anchor.',
      );
    }
    final state = await _readState();
    _registerAnchorInState(state, anchor);
    final now = _clock.nowUtc();
    final annotation = ResourceAnnotation(
      id: _nextUniqueAnnotationId(state),
      anchorId: anchor.stableId,
      kind: ResourceAnnotationKind.highlight,
      color: color,
      tagIds: tagIds,
      state: ResourceAnnotationState.active,
      revision: 1,
      createdAt: now,
      updatedAt: now,
      stateChangedAt: now,
    );
    state.annotations[annotation.id] = annotation;
    await _writeState(state);
    return annotation;
  });

  @override
  Future<ResourceAnnotation> addComment({
    required ResourceAnchor anchor,
    required ContentLocale locale,
    required String body,
    required ResourceArtifactColor color,
    Iterable<String> tagIds = const [],
  }) => _mutate(() async {
    final state = await _readState();
    _registerAnchorInState(state, anchor);
    final now = _clock.nowUtc();
    final annotation = ResourceAnnotation(
      id: _nextUniqueAnnotationId(state),
      anchorId: anchor.stableId,
      kind: ResourceAnnotationKind.comment,
      color: color,
      locale: locale,
      body: body,
      tagIds: tagIds,
      state: ResourceAnnotationState.active,
      revision: 1,
      createdAt: now,
      updatedAt: now,
      stateChangedAt: now,
    );
    state.annotations[annotation.id] = annotation;
    await _writeState(state);
    return annotation;
  });

  @override
  Future<ResourceAnnotation> addInk({
    required DocumentRegionResourceAnchor anchor,
    required Iterable<ResourceInkStroke> strokes,
    required ResourceArtifactColor color,
    Iterable<String> tagIds = const [],
  }) => _mutate(() async {
    final state = await _readState();
    _registerAnchorInState(state, anchor);
    final now = _clock.nowUtc();
    final annotation = ResourceAnnotation(
      id: _nextUniqueAnnotationId(state),
      anchorId: anchor.stableId,
      kind: ResourceAnnotationKind.ink,
      color: color,
      inkStrokes: strokes,
      tagIds: tagIds,
      state: ResourceAnnotationState.active,
      revision: 1,
      createdAt: now,
      updatedAt: now,
      stateChangedAt: now,
    );
    state.annotations[annotation.id] = annotation;
    await _writeState(state);
    return annotation;
  });

  @override
  Future<ResourceAnnotation> setAnnotationState({
    required ResourceAnnotationId annotationId,
    required ResourceAnnotationState state,
    required int expectedRevision,
  }) => _mutate(() async {
    final registry = await _readState();
    final existing = registry.annotations[annotationId];
    if (existing == null) {
      throw const ResourceWorkspaceException(
        'resource_annotation_missing',
        'The annotation does not exist.',
      );
    }
    if (existing.state == state) return existing;
    if (existing.revision != expectedRevision) {
      throw const ResourceWorkspaceException(
        'stale_resource_annotation_revision',
        'The annotation changed after this view opened.',
      );
    }
    final now = _clock.nowUtc();
    final updated = _copyAnnotation(
      existing,
      state: state,
      revision: existing.revision + 1,
      updatedAt: now,
      stateChangedAt: now,
    );
    registry.annotations[annotationId] = updated;
    await _writeState(registry);
    return updated;
  });

  @override
  Future<List<ResourceAnnotation>> listAnnotationsForResource(
    ResourceReference resource, {
    bool includeDeleted = false,
  }) => _mutate(() async {
    final state = await _readState();
    final anchorIds = state.anchors.values
        .where((anchor) => anchor.resource == resource)
        .map((anchor) => anchor.stableId)
        .toSet();
    final values =
        state.annotations.values
            .where(
              (annotation) =>
                  anchorIds.contains(annotation.anchorId) &&
                  (includeDeleted ||
                      annotation.state != ResourceAnnotationState.deleted),
            )
            .toList()
          ..sort((left, right) {
            final byTime = right.updatedAt.compareTo(left.updatedAt);
            return byTime != 0 ? byTime : right.id.compareTo(left.id);
          });
    return List.unmodifiable(values);
  });

  @override
  Future<ResourceBookmark?> readBookmark(
    ResourceAnchorId anchorId, {
    bool includeDeleted = false,
  }) => _mutate(() async {
    final id = ResourceBookmark.stableIdForAnchor(anchorId);
    final bookmark = (await _readState()).bookmarks[id];
    return bookmark == null || (!includeDeleted && bookmark.isDeleted)
        ? null
        : bookmark;
  });

  @override
  Future<ResourceBookmark> setBookmarked({
    required ResourceAnchor anchor,
    required bool isBookmarked,
    required ResourceArtifactColor color,
    int? expectedRevision,
    String? label,
  }) => _mutate(() async {
    final state = await _readState();
    _registerAnchorInState(state, anchor);
    final id = ResourceBookmark.stableIdForAnchor(anchor.stableId);
    final existing = state.bookmarks[id];
    final desiredDeleted = !isBookmarked;
    if (existing != null &&
        existing.isDeleted == desiredDeleted &&
        existing.color == color &&
        existing.label == label) {
      return existing;
    }
    if (existing == null) {
      if (expectedRevision != null) {
        throw const ResourceWorkspaceException(
          'stale_resource_bookmark_revision',
          'The bookmark changed after this view opened.',
        );
      }
    } else if (existing.revision != expectedRevision) {
      throw const ResourceWorkspaceException(
        'stale_resource_bookmark_revision',
        'The bookmark changed after this view opened.',
      );
    }
    final now = _clock.nowUtc();
    final bookmark = ResourceBookmark(
      id: id,
      anchorId: anchor.stableId,
      label: label,
      color: color,
      isDeleted: desiredDeleted,
      revision: (existing?.revision ?? 0) + 1,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    state.bookmarks[id] = bookmark;
    await _writeState(state);
    return bookmark;
  });

  @override
  Future<List<ResourceBookmark>> listBookmarksForResource(
    ResourceReference resource, {
    bool includeDeleted = false,
  }) => _mutate(() async {
    final state = await _readState();
    final anchorIds = state.anchors.values
        .where((anchor) => anchor.resource == resource)
        .map((anchor) => anchor.stableId)
        .toSet();
    final values =
        state.bookmarks.values
            .where(
              (bookmark) =>
                  anchorIds.contains(bookmark.anchorId) &&
                  (includeDeleted || !bookmark.isDeleted),
            )
            .toList()
          ..sort((left, right) {
            final byTime = right.updatedAt.compareTo(left.updatedAt);
            return byTime != 0 ? byTime : right.id.compareTo(left.id);
          });
    return List.unmodifiable(values);
  });

  @override
  Future<ResourceCrossReference?> readCrossReference(
    ResourceCrossReferenceId id, {
    bool includeDeleted = false,
  }) => _mutate(() async {
    final reference = (await _readState()).crossReferences[id];
    return reference == null || (!includeDeleted && reference.isDeleted)
        ? null
        : reference;
  });

  @override
  Future<ResourceCrossReference> setCrossReference({
    required ResourceReference from,
    required ResourceReference to,
    required ResourceCrossReferenceKind kind,
    required bool isLinked,
    int? expectedRevision,
  }) => _mutate(() async {
    final state = await _readState();
    _validateResourceReference(state, from);
    _validateResourceReference(state, to);
    final id = ResourceCrossReference.stableIdFor(
      from: from,
      to: to,
      kind: kind,
    );
    final existing = state.crossReferences[id];
    final desiredDeleted = !isLinked;
    if (existing != null && existing.isDeleted == desiredDeleted) {
      return existing;
    }
    if (existing == null) {
      if (expectedRevision != null) {
        throw const ResourceWorkspaceException(
          'stale_resource_cross_reference_revision',
          'The resource relationship changed after this view opened.',
        );
      }
    } else if (existing.revision != expectedRevision) {
      throw const ResourceWorkspaceException(
        'stale_resource_cross_reference_revision',
        'The resource relationship changed after this view opened.',
      );
    }
    final now = _clock.nowUtc();
    final reference = ResourceCrossReference(
      id: id,
      from: from,
      to: to,
      kind: kind,
      isDeleted: desiredDeleted,
      revision: (existing?.revision ?? 0) + 1,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    state.crossReferences[id] = reference;
    await _writeState(state);
    return reference;
  });

  @override
  Future<List<ResourceCrossReference>> listCrossReferencesFrom(
    ResourceReference resource, {
    ResourceCrossReferenceKind? kind,
    bool includeDeleted = false,
  }) => _mutate(() async {
    final values =
        (await _readState()).crossReferences.values
            .where(
              (reference) =>
                  reference.from == resource &&
                  (kind == null || reference.kind == kind) &&
                  (includeDeleted || !reference.isDeleted),
            )
            .toList()
          ..sort((left, right) {
            final byTime = right.updatedAt.compareTo(left.updatedAt);
            return byTime != 0 ? byTime : right.id.compareTo(left.id);
          });
    return List.unmodifiable(values);
  });

  @override
  Future<List<ResourceWorkspaceIntegrityIssue>> auditIntegrity() =>
      _mutate(() async {
        try {
          await _readState();
          return const [];
        } on ResourceWorkspaceException catch (error) {
          return [
            ResourceWorkspaceIntegrityIssue(
              code: error.code,
              message: error.message,
            ),
          ];
        }
      });

  void _registerAnchorInState(
    _ResourceWorkspaceState state,
    ResourceAnchor anchor,
  ) {
    final documentId = anchor.resource.kind == ResourceReferenceKind.document
        ? anchor.resource.resourceId
        : null;
    if (documentId != null && !state.documents.containsKey(documentId)) {
      throw const ResourceWorkspaceException(
        'resource_anchor_document_missing',
        'A document anchor requires registered immutable document metadata.',
      );
    }
    // Same semantic anchor may receive refreshed non-identity fallback metadata
    // such as a curriculum Block ordinal after a reviewed package reorder.
    state.anchors[anchor.stableId] = anchor;
  }

  static void _validateResourceReference(
    _ResourceWorkspaceState state,
    ResourceReference reference,
  ) {
    if (reference.kind == ResourceReferenceKind.document &&
        !state.documents.containsKey(reference.resourceId)) {
      throw const ResourceWorkspaceException(
        'resource_cross_reference_document_missing',
        'A relationship cannot target missing document metadata.',
      );
    }
  }

  String _nextUniqueAnnotationId(_ResourceWorkspaceState state) {
    final id = _idSource.nextId();
    if (state.annotations.containsKey(id)) {
      throw const ResourceWorkspaceException(
        'resource_annotation_identity_collision',
        'The generated annotation ID already exists.',
      );
    }
    return id;
  }

  Future<_ResourceWorkspaceState> _readState() async {
    final raw = await _store.read(stateKey);
    if (raw == null) return _ResourceWorkspaceState.empty();
    if (raw is! Map || raw.keys.any((key) => key is! String)) {
      throw const ResourceWorkspaceException(
        'corrupt_resource_workspace_registry',
        'Resource workspace registry is not a JSON object.',
      );
    }
    try {
      return _ResourceWorkspaceState.fromJson(Map<String, Object?>.from(raw));
    } on ResourceWorkspaceException {
      rethrow;
    } on Object catch (error) {
      throw ResourceWorkspaceException(
        'corrupt_resource_workspace_registry',
        'Resource workspace registry failed schema validation.',
        error,
      );
    }
  }

  Future<void> _writeState(_ResourceWorkspaceState state) =>
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

  static _ResourceMutationQueue _queueFor(KeyValueStore store) =>
      _mutationQueues[store] ??= _ResourceMutationQueue();

  static void _requireDigest(String value) {
    if (!_digestPattern.hasMatch(value)) {
      throw ArgumentError.value(value, 'contentSha256');
    }
  }

  static void _validateDigestLengthConsistency(
    _ResourceWorkspaceState state,
    ResourceDocument incoming,
  ) {
    for (final existing in state.documents.values) {
      if (existing.contentSha256 == incoming.contentSha256 &&
          existing.byteLength != incoming.byteLength) {
        throw const ResourceWorkspaceException(
          'resource_document_digest_length_mismatch',
          'The same content digest cannot declare two byte lengths.',
        );
      }
    }
  }
}

final class _ResourceMutationQueue {
  Future<void> tail = Future.value();
}

final class _ResourceWorkspaceState {
  _ResourceWorkspaceState({
    required Map<ResourceDocumentId, ResourceDocument> documents,
    required Map<ResourceAnchorId, ResourceAnchor> anchors,
    required Map<ResourceAnnotationId, ResourceAnnotation> annotations,
    required Map<ResourceBookmarkId, ResourceBookmark> bookmarks,
    required Map<ResourceCrossReferenceId, ResourceCrossReference>
    crossReferences,
  }) : documents = Map.of(documents),
       anchors = Map.of(anchors),
       annotations = Map.of(annotations),
       bookmarks = Map.of(bookmarks),
       crossReferences = Map.of(crossReferences);

  factory _ResourceWorkspaceState.empty() => _ResourceWorkspaceState(
    documents: const {},
    anchors: const {},
    annotations: const {},
    bookmarks: const {},
    crossReferences: const {},
  );

  final Map<ResourceDocumentId, ResourceDocument> documents;
  final Map<ResourceAnchorId, ResourceAnchor> anchors;
  final Map<ResourceAnnotationId, ResourceAnnotation> annotations;
  final Map<ResourceBookmarkId, ResourceBookmark> bookmarks;
  final Map<ResourceCrossReferenceId, ResourceCrossReference> crossReferences;

  Map<String, Object?> toJson() {
    final blobLengths = <String, int>{};
    for (final document in documents.values) {
      blobLengths[document.contentSha256] = document.byteLength;
    }
    return {
      'schemaVersion': LocalResourceWorkspaceRepository.currentSchemaVersion,
      'documents': documents.map(
        (id, document) => MapEntry<String, Object?>(id, document.toJson()),
      ),
      'anchors': anchors.map(
        (id, anchor) => MapEntry<String, Object?>(id, anchor.toJson()),
      ),
      'annotations': annotations.map(
        (id, annotation) => MapEntry<String, Object?>(id, annotation.toJson()),
      ),
      'bookmarks': bookmarks.map(
        (id, bookmark) => MapEntry<String, Object?>(id, bookmark.toJson()),
      ),
      'crossReferences': crossReferences.map(
        (id, reference) => MapEntry<String, Object?>(id, reference.toJson()),
      ),
      'integrity': {
        'documentCount': documents.length,
        'anchorCount': anchors.length,
        'annotationCount': annotations.length,
        'bookmarkCount': bookmarks.length,
        'crossReferenceCount': crossReferences.length,
        'uniqueBlobCount': blobLengths.length,
        'uniqueBlobBytes': blobLengths.values.fold<int>(
          0,
          (total, value) => total + value,
        ),
      },
    };
  }

  factory _ResourceWorkspaceState.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] !=
        LocalResourceWorkspaceRepository.currentSchemaVersion) {
      throw const ResourceWorkspaceException(
        'unsupported_resource_workspace_schema',
        'Unsupported resource workspace registry schema.',
      );
    }
    final documents = <ResourceDocumentId, ResourceDocument>{};
    for (final entry in _jsonObject(json['documents'], 'documents').entries) {
      final document = ResourceDocument.fromJson(
        _jsonObject(entry.value, 'documents.${entry.key}'),
      );
      if (document.id != entry.key) {
        throw const ResourceWorkspaceException(
          'corrupt_resource_workspace_registry',
          'Document identity does not match its registry key.',
        );
      }
      documents[entry.key] = document;
    }
    final anchors = <ResourceAnchorId, ResourceAnchor>{};
    for (final entry in _jsonObject(json['anchors'], 'anchors').entries) {
      final anchor = ResourceAnchor.fromJson(
        _jsonObject(entry.value, 'anchors.${entry.key}'),
      );
      if (anchor.stableId != entry.key) {
        throw const ResourceWorkspaceException(
          'corrupt_resource_workspace_registry',
          'Anchor identity does not match its registry key.',
        );
      }
      if (anchor.resource.kind == ResourceReferenceKind.document &&
          !documents.containsKey(anchor.resource.resourceId)) {
        throw const ResourceWorkspaceException(
          'corrupt_resource_workspace_registry',
          'A document anchor references missing document metadata.',
        );
      }
      anchors[entry.key] = anchor;
    }
    final annotations = <ResourceAnnotationId, ResourceAnnotation>{};
    for (final entry in _jsonObject(
      json['annotations'],
      'annotations',
    ).entries) {
      final annotation = ResourceAnnotation.fromJson(
        _jsonObject(entry.value, 'annotations.${entry.key}'),
      );
      if (annotation.id != entry.key ||
          !anchors.containsKey(annotation.anchorId)) {
        throw const ResourceWorkspaceException(
          'corrupt_resource_workspace_registry',
          'Annotation identity or anchor relationship is invalid.',
        );
      }
      annotations[entry.key] = annotation;
    }
    final bookmarks = <ResourceBookmarkId, ResourceBookmark>{};
    for (final entry in _jsonObject(json['bookmarks'], 'bookmarks').entries) {
      final bookmark = ResourceBookmark.fromJson(
        _jsonObject(entry.value, 'bookmarks.${entry.key}'),
      );
      if (bookmark.id != entry.key || !anchors.containsKey(bookmark.anchorId)) {
        throw const ResourceWorkspaceException(
          'corrupt_resource_workspace_registry',
          'Bookmark identity or anchor relationship is invalid.',
        );
      }
      bookmarks[entry.key] = bookmark;
    }
    final crossReferences =
        <ResourceCrossReferenceId, ResourceCrossReference>{};
    for (final entry in _jsonObject(
      json['crossReferences'],
      'crossReferences',
    ).entries) {
      final reference = ResourceCrossReference.fromJson(
        _jsonObject(entry.value, 'crossReferences.${entry.key}'),
      );
      if (reference.id != entry.key ||
          !_resourceReferenceExists(documents, reference.from) ||
          !_resourceReferenceExists(documents, reference.to)) {
        throw const ResourceWorkspaceException(
          'corrupt_resource_workspace_registry',
          'Cross-reference identity or document relationship is invalid.',
        );
      }
      crossReferences[entry.key] = reference;
    }
    final state = _ResourceWorkspaceState(
      documents: documents,
      anchors: anchors,
      annotations: annotations,
      bookmarks: bookmarks,
      crossReferences: crossReferences,
    );
    _verifyDocumentDigests(state);
    final expected = _jsonObject(state.toJson()['integrity'], 'expected');
    final actual = _jsonObject(json['integrity'], 'integrity');
    if (CanonicalJson.encode(actual) != CanonicalJson.encode(expected)) {
      throw const ResourceWorkspaceException(
        'corrupt_resource_workspace_registry',
        'Resource workspace integrity summary does not match its records.',
      );
    }
    return state;
  }
}

ResourceAnnotation _copyAnnotation(
  ResourceAnnotation value, {
  required ResourceAnnotationState state,
  required int revision,
  required DateTime updatedAt,
  required DateTime stateChangedAt,
}) => ResourceAnnotation(
  id: value.id,
  anchorId: value.anchorId,
  kind: value.kind,
  color: value.color,
  locale: value.locale,
  body: value.body,
  inkStrokes: value.inkStrokes,
  tagIds: value.tagIds,
  state: state,
  revision: revision,
  createdAt: value.createdAt,
  updatedAt: updatedAt,
  stateChangedAt: stateChangedAt,
);

void _verifyDocumentDigests(_ResourceWorkspaceState state) {
  final byteLengths = <String, int>{};
  for (final document in state.documents.values) {
    final prior = byteLengths[document.contentSha256];
    if (prior != null && prior != document.byteLength) {
      throw const ResourceWorkspaceException(
        'corrupt_resource_workspace_registry',
        'One document digest declares inconsistent byte lengths.',
      );
    }
    byteLengths[document.contentSha256] = document.byteLength;
  }
}

bool _resourceReferenceExists(
  Map<ResourceDocumentId, ResourceDocument> documents,
  ResourceReference reference,
) =>
    reference.kind != ResourceReferenceKind.document ||
    documents.containsKey(reference.resourceId);

Map<String, Object?> _jsonObject(Object? value, String field) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw ResourceWorkspaceException(
      'corrupt_resource_workspace_registry',
      '$field must be a JSON object.',
    );
  }
  return Map<String, Object?>.from(value);
}

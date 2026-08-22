import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_foundation/synapse_foundation.dart';

import '../workspace/resource_workspace_repository.dart';
import 'encrypted_indexed_learner_record_store.dart';

/// Record-oriented encrypted implementation of the universal resource
/// workspace. Every document, anchor, annotation, bookmark and relationship is
/// independently queryable while multi-record mutations remain atomic.
final class IndexedResourceWorkspaceRepository
    implements ResourceWorkspaceRepository {
  IndexedResourceWorkspaceRepository({
    required IndexedLearnerRecordStore records,
    required Clock clock,
    required IdSource idSource,
  }) : this._(records, clock, idSource);

  IndexedResourceWorkspaceRepository._(
    this._records,
    this._clock,
    this._idSource,
  );

  static const documentNamespace = 'resource.document';
  static const anchorNamespace = 'resource.anchor';
  static const annotationNamespace = 'resource.annotation';
  static const bookmarkNamespace = 'resource.bookmark';
  static const crossReferenceNamespace = 'resource.cross-reference';

  final IndexedLearnerRecordStore _records;
  final Clock _clock;
  final IdSource _idSource;

  @override
  Future<ResourceWorkspaceSnapshot> exportSnapshot() => _guard(() async {
    final documents = (await _records.exportNamespace(
      documentNamespace,
    )).map(_document);
    final anchors = (await _records.exportNamespace(
      anchorNamespace,
    )).map(_anchor);
    final annotations = (await _records.exportNamespace(
      annotationNamespace,
    )).map(_annotation);
    final bookmarks = (await _records.exportNamespace(
      bookmarkNamespace,
    )).map(_bookmark);
    final crossReferences = (await _records.exportNamespace(
      crossReferenceNamespace,
    )).map(_crossReference);
    return ResourceWorkspaceSnapshot.fromRecords(
      documents: documents,
      anchors: anchors,
      annotations: annotations,
      bookmarks: bookmarks,
      crossReferences: crossReferences,
    );
  });

  @override
  Future<ResourceDocument?> readDocument(ResourceDocumentId id) =>
      _guard(() async {
        final record = await _records.read(
          namespace: documentNamespace,
          recordId: id,
        );
        return record == null ? null : _document(record);
      });

  @override
  Future<ResourceDocument?> findDocumentByDigest(String contentSha256) =>
      _guard(() async {
        _requireDigest(contentSha256);
        final values = await _records.query(
          PrivateLearnerRecordQuery(
            namespace: documentNamespace,
            scopeId: 'sha256:$contentSha256',
            kind: 'document',
            limit: 2,
          ),
        );
        if (values.length > 1) {
          final lengths = values.map((value) => _document(value).byteLength);
          if (lengths.toSet().length != 1) {
            throw const ResourceWorkspaceException(
              'resource_document_digest_length_drift',
              'One document digest declares inconsistent byte lengths.',
            );
          }
        }
        return values.isEmpty ? null : _document(values.first);
      });

  @override
  Future<List<ResourceDocument>> listDocuments() => _guard(() async {
    final values =
        (await _records.exportNamespace(
            documentNamespace,
          )).where((record) => !record.tombstone).map(_document).toList()
          ..sort((left, right) {
            final byTime = right.createdAt.compareTo(left.createdAt);
            return byTime != 0 ? byTime : right.id.compareTo(left.id);
          });
    return List.unmodifiable(values);
  });

  @override
  Future<ResourceDocument> registerDocument(ResourceDocument document) =>
      _guard(() async {
        final existing = await readDocument(document.id);
        if (existing != null &&
            CanonicalJson.encode(existing.toJson()) !=
                CanonicalJson.encode(document.toJson())) {
          throw const ResourceWorkspaceException(
            'resource_document_identity_collision',
            'A document ID already addresses different immutable metadata.',
          );
        }
        final digestMatch = await findDocumentByDigest(document.contentSha256);
        if (digestMatch != null &&
            digestMatch.byteLength != document.byteLength) {
          throw const ResourceWorkspaceException(
            'resource_document_digest_length_drift',
            'One document digest declares inconsistent byte lengths.',
          );
        }
        final saved = await _records.put(
          _documentDraft(document),
          expectedRevision: null,
        );
        return _document(saved);
      });

  @override
  Future<ResourceAnchor?> readAnchor(ResourceAnchorId id) => _guard(() async {
    final record = await _records.read(
      namespace: anchorNamespace,
      recordId: id,
    );
    return record == null ? null : _anchor(record);
  });

  @override
  Future<ResourceAnchor> registerAnchor(ResourceAnchor anchor) =>
      _guard(() async {
        await _requireDocumentReference(anchor.resource);
        final existing = await _records.read(
          namespace: anchorNamespace,
          recordId: anchor.stableId,
        );
        final saved = await _records.put(
          _anchorDraft(anchor, _clock.nowUtc()),
          expectedRevision: existing?.revision,
        );
        return _anchor(saved);
      });

  @override
  Future<List<ResourceAnchor>> listAnchorsForResource(
    ResourceReference resource,
  ) => _guard(() async {
    final values =
        (await _queryAll(
            PrivateLearnerRecordQuery(
              namespace: anchorNamespace,
              scopeId: resource.stableId,
              includeTombstones: false,
              limit: 500,
            ),
          )).map(_anchor).toList()
          ..sort((left, right) => left.stableId.compareTo(right.stableId));
    return List.unmodifiable(values);
  });

  @override
  Future<ResourceAnnotation> addHighlight({
    required ResourceAnchor anchor,
    required ResourceArtifactColor color,
    Iterable<String> tagIds = const [],
  }) => _guard(() async {
    if (anchor is! CurriculumBlockResourceAnchor &&
        anchor is! DocumentTextRangeResourceAnchor &&
        anchor is! DocumentRegionResourceAnchor) {
      throw const ResourceWorkspaceException(
        'unsupported_highlight_anchor',
        'Highlights require a Block, text-range, or document-region anchor.',
      );
    }
    final now = _clock.nowUtc();
    return _addAnnotation(
      anchor: anchor,
      annotation: ResourceAnnotation(
        id: await _nextUniqueAnnotationId(),
        anchorId: anchor.stableId,
        kind: ResourceAnnotationKind.highlight,
        color: color,
        tagIds: tagIds,
        state: ResourceAnnotationState.active,
        revision: 1,
        createdAt: now,
        updatedAt: now,
        stateChangedAt: now,
      ),
    );
  });

  @override
  Future<ResourceAnnotation> addComment({
    required ResourceAnchor anchor,
    required ContentLocale locale,
    required String body,
    required ResourceArtifactColor color,
    Iterable<String> tagIds = const [],
  }) => _guard(() async {
    final now = _clock.nowUtc();
    return _addAnnotation(
      anchor: anchor,
      annotation: ResourceAnnotation(
        id: await _nextUniqueAnnotationId(),
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
      ),
    );
  });

  @override
  Future<ResourceAnnotation> addInk({
    required DocumentRegionResourceAnchor anchor,
    required Iterable<ResourceInkStroke> strokes,
    required ResourceArtifactColor color,
    Iterable<String> tagIds = const [],
  }) => _guard(() async {
    final now = _clock.nowUtc();
    return _addAnnotation(
      anchor: anchor,
      annotation: ResourceAnnotation(
        id: await _nextUniqueAnnotationId(),
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
      ),
    );
  });

  @override
  Future<ResourceAnnotation> setAnnotationState({
    required ResourceAnnotationId annotationId,
    required ResourceAnnotationState state,
    required int expectedRevision,
  }) => _guard(() async {
    final record = await _records.read(
      namespace: annotationNamespace,
      recordId: annotationId,
    );
    if (record == null) {
      throw const ResourceWorkspaceException(
        'resource_annotation_missing',
        'The annotation does not exist.',
      );
    }
    final existing = _annotation(record);
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
    return _annotation(
      await _records.put(
        _annotationDraft(updated, resourceStableId: record.scopeId),
        expectedRevision: record.revision,
      ),
    );
  });

  @override
  Future<List<ResourceAnnotation>> listAnnotationsForResource(
    ResourceReference resource, {
    bool includeDeleted = false,
  }) => _guard(() async {
    final values =
        (await _queryAll(
            PrivateLearnerRecordQuery(
              namespace: annotationNamespace,
              scopeId: resource.stableId,
              includeTombstones: includeDeleted,
              limit: 500,
            ),
          )).map(_annotation).where((value) {
            return includeDeleted ||
                value.state != ResourceAnnotationState.deleted;
          }).toList()
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
  }) => _guard(() async {
    final id = ResourceBookmark.stableIdForAnchor(anchorId);
    final record = await _records.read(
      namespace: bookmarkNamespace,
      recordId: id,
    );
    if (record == null || (!includeDeleted && record.tombstone)) return null;
    final bookmark = _bookmark(record);
    return !includeDeleted && bookmark.isDeleted ? null : bookmark;
  });

  @override
  Future<ResourceBookmark> setBookmarked({
    required ResourceAnchor anchor,
    required bool isBookmarked,
    required ResourceArtifactColor color,
    int? expectedRevision,
    String? label,
  }) => _guard(() async {
    await _requireDocumentReference(anchor.resource);
    final id = ResourceBookmark.stableIdForAnchor(anchor.stableId);
    final anchorRecord = await _records.read(
      namespace: anchorNamespace,
      recordId: anchor.stableId,
    );
    final bookmarkRecord = await _records.read(
      namespace: bookmarkNamespace,
      recordId: id,
    );
    final existing = bookmarkRecord == null ? null : _bookmark(bookmarkRecord);
    final desiredDeleted = !isBookmarked;
    if (existing != null &&
        existing.isDeleted == desiredDeleted &&
        existing.color == color &&
        existing.label == label) {
      return existing;
    }
    if (existing == null && expectedRevision != null ||
        existing != null && existing.revision != expectedRevision) {
      throw const ResourceWorkspaceException(
        'stale_resource_bookmark_revision',
        'The bookmark changed after this view opened.',
      );
    }
    final now = _clock.nowUtc();
    final value = ResourceBookmark(
      id: id,
      anchorId: anchor.stableId,
      label: label,
      color: color,
      isDeleted: desiredDeleted,
      revision: (existing?.revision ?? 0) + 1,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    final saved = await _records.putBatch([
      PrivateLearnerRecordMutation(
        draft: _anchorDraft(anchor, now),
        expectedRevision: anchorRecord?.revision,
      ),
      PrivateLearnerRecordMutation(
        draft: _bookmarkDraft(
          value,
          resourceStableId: anchor.resource.stableId,
        ),
        expectedRevision: bookmarkRecord?.revision,
      ),
    ]);
    return _bookmark(saved[1]);
  });

  @override
  Future<List<ResourceBookmark>> listBookmarksForResource(
    ResourceReference resource, {
    bool includeDeleted = false,
  }) => _guard(() async {
    final values =
        (await _queryAll(
            PrivateLearnerRecordQuery(
              namespace: bookmarkNamespace,
              scopeId: resource.stableId,
              includeTombstones: includeDeleted,
              limit: 500,
            ),
          )).map(_bookmark).where((value) {
            return includeDeleted || !value.isDeleted;
          }).toList()
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
  }) => _guard(() async {
    final record = await _records.read(
      namespace: crossReferenceNamespace,
      recordId: id,
    );
    if (record == null || (!includeDeleted && record.tombstone)) return null;
    final reference = _crossReference(record);
    return !includeDeleted && reference.isDeleted ? null : reference;
  });

  @override
  Future<ResourceCrossReference> setCrossReference({
    required ResourceReference from,
    required ResourceReference to,
    required ResourceCrossReferenceKind kind,
    required bool isLinked,
    int? expectedRevision,
  }) => _guard(() async {
    await _requireDocumentReference(from);
    await _requireDocumentReference(to);
    final id = ResourceCrossReference.stableIdFor(
      from: from,
      to: to,
      kind: kind,
    );
    final record = await _records.read(
      namespace: crossReferenceNamespace,
      recordId: id,
    );
    final existing = record == null ? null : _crossReference(record);
    final desiredDeleted = !isLinked;
    if (existing != null && existing.isDeleted == desiredDeleted) {
      return existing;
    }
    if (existing == null && expectedRevision != null ||
        existing != null && existing.revision != expectedRevision) {
      throw const ResourceWorkspaceException(
        'stale_resource_cross_reference_revision',
        'The resource relationship changed after this view opened.',
      );
    }
    final now = _clock.nowUtc();
    final value = ResourceCrossReference(
      id: id,
      from: from,
      to: to,
      kind: kind,
      isDeleted: desiredDeleted,
      revision: (existing?.revision ?? 0) + 1,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    return _crossReference(
      await _records.put(
        _crossReferenceDraft(value),
        expectedRevision: record?.revision,
      ),
    );
  });

  @override
  Future<List<ResourceCrossReference>> listCrossReferencesFrom(
    ResourceReference resource, {
    ResourceCrossReferenceKind? kind,
    bool includeDeleted = false,
  }) => _guard(() async {
    final values =
        (await _queryAll(
            PrivateLearnerRecordQuery(
              namespace: crossReferenceNamespace,
              scopeId: resource.stableId,
              kind: kind?.name.toLowerCase(),
              includeTombstones: includeDeleted,
              limit: 500,
            ),
          )).map(_crossReference).where((value) {
            return includeDeleted || !value.isDeleted;
          }).toList()
          ..sort((left, right) {
            final byTime = right.updatedAt.compareTo(left.updatedAt);
            return byTime != 0 ? byTime : right.id.compareTo(left.id);
          });
    return List.unmodifiable(values);
  });

  @override
  Future<List<ResourceWorkspaceIntegrityIssue>> auditIntegrity() async {
    final encryptedIssues = await _records.auditIntegrity();
    final workspaceEncryptedIssues = encryptedIssues.where(
      (issue) => const {
        documentNamespace,
        anchorNamespace,
        annotationNamespace,
        bookmarkNamespace,
        crossReferenceNamespace,
      }.contains(issue.namespace),
    );
    if (workspaceEncryptedIssues.isNotEmpty) {
      return workspaceEncryptedIssues
          .map(
            (issue) => ResourceWorkspaceIntegrityIssue(
              code: issue.code,
              message: issue.message,
              recordId: issue.recordIdHash,
            ),
          )
          .toList(growable: false);
    }
    try {
      final documents = {
        for (final record in await _records.exportNamespace(documentNamespace))
          record.recordId: _document(record),
      };
      final anchors = {
        for (final record in await _records.exportNamespace(anchorNamespace))
          record.recordId: _anchor(record),
      };
      final digestLengths = <String, int>{};
      for (final document in documents.values) {
        final prior = digestLengths[document.contentSha256];
        if (prior != null && prior != document.byteLength) {
          throw const ResourceWorkspaceException(
            'resource_document_digest_length_drift',
            'One document digest declares inconsistent byte lengths.',
          );
        }
        digestLengths[document.contentSha256] = document.byteLength;
      }
      for (final anchor in anchors.values) {
        _verifyDocumentReference(documents, anchor.resource);
      }
      for (final record in await _records.exportNamespace(
        annotationNamespace,
      )) {
        final value = _annotation(record);
        if (!anchors.containsKey(value.anchorId)) {
          throw const ResourceWorkspaceException(
            'resource_annotation_anchor_missing',
            'An annotation references a missing resource anchor.',
          );
        }
      }
      for (final record in await _records.exportNamespace(bookmarkNamespace)) {
        final value = _bookmark(record);
        if (!anchors.containsKey(value.anchorId)) {
          throw const ResourceWorkspaceException(
            'resource_bookmark_anchor_missing',
            'A bookmark references a missing resource anchor.',
          );
        }
      }
      for (final record in await _records.exportNamespace(
        crossReferenceNamespace,
      )) {
        final value = _crossReference(record);
        _verifyDocumentReference(documents, value.from);
        _verifyDocumentReference(documents, value.to);
      }
      return const [];
    } on ResourceWorkspaceException catch (error) {
      return [
        ResourceWorkspaceIntegrityIssue(
          code: error.code,
          message: error.message,
        ),
      ];
    } on Object {
      return const [
        ResourceWorkspaceIntegrityIssue(
          code: 'corrupt_indexed_resource_workspace',
          message: 'Indexed resource workspace failed schema validation.',
        ),
      ];
    }
  }

  Future<ResourceAnnotation> _addAnnotation({
    required ResourceAnchor anchor,
    required ResourceAnnotation annotation,
  }) async {
    await _requireDocumentReference(anchor.resource);
    final anchorRecord = await _records.read(
      namespace: anchorNamespace,
      recordId: anchor.stableId,
    );
    final saved = await _records.putBatch([
      PrivateLearnerRecordMutation(
        draft: _anchorDraft(anchor, annotation.updatedAt),
        expectedRevision: anchorRecord?.revision,
      ),
      PrivateLearnerRecordMutation(
        draft: _annotationDraft(
          annotation,
          resourceStableId: anchor.resource.stableId,
        ),
        expectedRevision: null,
      ),
    ]);
    return _annotation(saved[1]);
  }

  Future<String> _nextUniqueAnnotationId() async {
    final id = _idSource.nextId();
    if (await _records.read(namespace: annotationNamespace, recordId: id) !=
        null) {
      throw const ResourceWorkspaceException(
        'resource_annotation_identity_collision',
        'The generated annotation ID already exists.',
      );
    }
    return id;
  }

  Future<void> _requireDocumentReference(ResourceReference reference) async {
    if (reference.kind == ResourceReferenceKind.document &&
        await readDocument(reference.resourceId) == null) {
      throw const ResourceWorkspaceException(
        'resource_reference_document_missing',
        'A resource operation requires registered document metadata.',
      );
    }
  }

  Future<List<PrivateLearnerRecord>> _queryAll(
    PrivateLearnerRecordQuery query,
  ) async {
    final values = <PrivateLearnerRecord>[];
    String? cursor = query.cursor;
    final seenCursors = <String>{};
    do {
      final page = await _records.queryPage(
        PrivateLearnerRecordQuery(
          namespace: query.namespace,
          scopeId: query.scopeId,
          kind: query.kind,
          includeTombstones: query.includeTombstones,
          limit: query.limit,
          cursor: cursor,
        ),
      );
      values.addAll(page.records);
      cursor = page.nextCursor;
      if (cursor != null && !seenCursors.add(cursor)) {
        throw const ResourceWorkspaceException(
          'resource_query_cursor_cycle',
          'Indexed resource query returned a repeated pagination cursor.',
        );
      }
    } while (cursor != null);
    return List.unmodifiable(values);
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ResourceWorkspaceException {
      rethrow;
    } on LearnerDataPlaneException catch (error) {
      throw ResourceWorkspaceException(
        'indexed_${error.code}',
        'The private indexed resource workspace operation failed.',
        error,
      );
    } on Object catch (error) {
      throw ResourceWorkspaceException(
        'corrupt_indexed_resource_workspace',
        'Indexed resource workspace failed schema validation.',
        error,
      );
    }
  }
}

PrivateLearnerRecordDraft _documentDraft(ResourceDocument value) =>
    PrivateLearnerRecordDraft(
      namespace: IndexedResourceWorkspaceRepository.documentNamespace,
      recordId: value.id,
      scopeId: value.contentAddress,
      kind: 'document',
      updatedAt: value.createdAt,
      payload: value.toJson(),
    );

PrivateLearnerRecordDraft _anchorDraft(
  ResourceAnchor value,
  DateTime updatedAt,
) => PrivateLearnerRecordDraft(
  namespace: IndexedResourceWorkspaceRepository.anchorNamespace,
  recordId: value.stableId,
  scopeId: value.resource.stableId,
  kind: value.kind.name.toLowerCase(),
  updatedAt: updatedAt,
  payload: value.toJson(),
);

PrivateLearnerRecordDraft _annotationDraft(
  ResourceAnnotation value, {
  required String resourceStableId,
}) => PrivateLearnerRecordDraft(
  namespace: IndexedResourceWorkspaceRepository.annotationNamespace,
  recordId: value.id,
  scopeId: resourceStableId,
  kind: value.kind.name.toLowerCase(),
  updatedAt: value.updatedAt,
  payload: value.toJson(),
  tombstone: value.state == ResourceAnnotationState.deleted,
);

PrivateLearnerRecordDraft _bookmarkDraft(
  ResourceBookmark value, {
  required String resourceStableId,
}) => PrivateLearnerRecordDraft(
  namespace: IndexedResourceWorkspaceRepository.bookmarkNamespace,
  recordId: value.id,
  scopeId: resourceStableId,
  kind: 'bookmark',
  updatedAt: value.updatedAt,
  payload: value.toJson(),
  tombstone: value.isDeleted,
);

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

ResourceDocument _document(PrivateLearnerRecord record) =>
    ResourceDocument.fromJson(record.payload);

ResourceAnchor _anchor(PrivateLearnerRecord record) =>
    ResourceAnchor.fromJson(record.payload);

ResourceAnnotation _annotation(PrivateLearnerRecord record) =>
    ResourceAnnotation.fromJson(record.payload);

ResourceBookmark _bookmark(PrivateLearnerRecord record) =>
    ResourceBookmark.fromJson(record.payload);

ResourceCrossReference _crossReference(PrivateLearnerRecord record) =>
    ResourceCrossReference.fromJson(record.payload);

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

void _verifyDocumentReference(
  Map<ResourceDocumentId, ResourceDocument> documents,
  ResourceReference reference,
) {
  if (reference.kind == ResourceReferenceKind.document &&
      !documents.containsKey(reference.resourceId)) {
    throw const ResourceWorkspaceException(
      'resource_reference_document_missing',
      'A resource relationship references missing document metadata.',
    );
  }
}

void _requireDigest(String value) {
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
    throw const ResourceWorkspaceException(
      'invalid_resource_document_digest',
      'A resource document digest must be lowercase SHA-256.',
    );
  }
}

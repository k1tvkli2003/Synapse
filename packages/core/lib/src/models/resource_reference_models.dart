import 'package:equatable/equatable.dart';

import '../serialization/canonical_json.dart';
import '../serialization/stable_enum_codec.dart';
import 'ids.dart';

/// The canonical domain family addressed by a workspace artifact.
///
/// The wire value is intentionally independent from route names, localized
/// labels, filenames, and legacy database table names.
enum ResourceReferenceKind {
  curriculumNode,
  curriculumStudyDocument,
  document,
  clinicalCase,
  evidenceRecord,
}

/// How an immutable document blob entered the learner's workspace.
enum ResourceDocumentOrigin {
  userImport,
  curriculumAttachment,
  evidenceAttachment,
  migratedImport,
}

/// The exact semantic or paged shape addressed by a [ResourceAnchor].
enum ResourceAnchorKind {
  wholeResource,
  curriculumBlock,
  documentPageRange,
  documentTextRange,
  documentRegion,
}

final _referenceKindCodec = StableEnumCodec<ResourceReferenceKind>({
  'curriculum_node': ResourceReferenceKind.curriculumNode,
  'curriculum_study_document': ResourceReferenceKind.curriculumStudyDocument,
  'document': ResourceReferenceKind.document,
  'clinical_case': ResourceReferenceKind.clinicalCase,
  'evidence_record': ResourceReferenceKind.evidenceRecord,
});

final _documentOriginCodec = StableEnumCodec<ResourceDocumentOrigin>({
  'user_import': ResourceDocumentOrigin.userImport,
  'curriculum_attachment': ResourceDocumentOrigin.curriculumAttachment,
  'evidence_attachment': ResourceDocumentOrigin.evidenceAttachment,
  'migrated_import': ResourceDocumentOrigin.migratedImport,
});

final _anchorKindCodec = StableEnumCodec<ResourceAnchorKind>({
  'whole_resource': ResourceAnchorKind.wholeResource,
  'curriculum_block': ResourceAnchorKind.curriculumBlock,
  'document_page_range': ResourceAnchorKind.documentPageRange,
  'document_text_range': ResourceAnchorKind.documentTextRange,
  'document_region': ResourceAnchorKind.documentRegion,
});

final _resourceIdPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:/-]*$');
final _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');
final _mediaTypePattern = RegExp(
  r'^[a-z0-9][a-z0-9!#$&^_.+-]*/[a-z0-9][a-z0-9!#$&^_.+-]*$',
);
final _controlCharacterPattern = RegExp(r'[\u0000-\u001f\u007f]');

String _resourceId(String value, String field) {
  if (value.length > 200 ||
      value != value.trim() ||
      !_resourceIdPattern.hasMatch(value)) {
    throw ArgumentError.value(value, field, 'Invalid stable ID.');
  }
  return value;
}

String _sha256(String value, String field) {
  if (!_sha256Pattern.hasMatch(value)) {
    throw ArgumentError.value(value, field, 'Expected lowercase SHA-256.');
  }
  return value;
}

String _boundedText(String value, String field, {required int maximum}) {
  if (value != value.trim() ||
      value.isEmpty ||
      value.length > maximum ||
      _controlCharacterPattern.hasMatch(value)) {
    throw ArgumentError.value(value, field, 'Invalid bounded text.');
  }
  return value;
}

Map<String, Object?> _resourceMap(Object? value, String field) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw FormatException('$field must be a JSON object.');
  }
  return Map<String, Object?>.from(value);
}

DateTime _resourceTime(Object? value, String field) {
  if (value is! String) {
    throw FormatException('$field must be an ISO-8601 timestamp.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('$field must be an ISO-8601 timestamp.');
  }
  return parsed.toUtc();
}

/// A locale-, route-, and release-neutral reference to one product resource.
///
/// Curriculum resources require [scopeId] so identical source ordinals in two
/// independently imported corpora cannot collide. Other resource families use
/// their canonical ID directly and reject an ambiguous extra scope.
final class ResourceReference extends Equatable {
  ResourceReference({
    required this.kind,
    required this.resourceId,
    this.scopeId,
  }) {
    _resourceId(resourceId, 'resourceId');
    if (_isCurriculum) {
      if (scopeId == null) {
        throw ArgumentError('Curriculum resources require a source scope.');
      }
      _resourceId(scopeId!, 'scopeId');
    } else if (scopeId != null) {
      throw ArgumentError('Only curriculum resources may declare a scope.');
    }
  }

  factory ResourceReference.curriculumNode({
    required String sourceId,
    required String nodeId,
  }) => ResourceReference(
    kind: ResourceReferenceKind.curriculumNode,
    scopeId: sourceId,
    resourceId: nodeId,
  );

  factory ResourceReference.curriculumStudyDocument({
    required String sourceId,
    required String documentId,
  }) => ResourceReference(
    kind: ResourceReferenceKind.curriculumStudyDocument,
    scopeId: sourceId,
    resourceId: documentId,
  );

  factory ResourceReference.document(String documentId) => ResourceReference(
    kind: ResourceReferenceKind.document,
    resourceId: documentId,
  );

  factory ResourceReference.clinicalCase(String caseId) => ResourceReference(
    kind: ResourceReferenceKind.clinicalCase,
    resourceId: caseId,
  );

  factory ResourceReference.evidenceRecord(String evidenceId) =>
      ResourceReference(
        kind: ResourceReferenceKind.evidenceRecord,
        resourceId: evidenceId,
      );

  final ResourceReferenceKind kind;
  final String resourceId;
  final String? scopeId;

  bool get _isCurriculum =>
      kind == ResourceReferenceKind.curriculumNode ||
      kind == ResourceReferenceKind.curriculumStudyDocument;

  ResourceReferenceId get stableId =>
      '${_referenceKindCodec.encode(kind)}|${scopeId ?? ''}|$resourceId';

  Map<String, Object?> toJson() => {
    'kind': _referenceKindCodec.encode(kind),
    'resourceId': resourceId,
    'scopeId': scopeId,
  };

  factory ResourceReference.fromJson(Map<String, Object?> json) =>
      ResourceReference(
        kind: _referenceKindCodec.decode(json['kind']),
        resourceId: json['resourceId'] as String,
        scopeId: json['scopeId'] as String?,
      );

  @override
  List<Object?> get props => [kind, resourceId, scopeId];
}

/// Import-only lineage. It never becomes the live ownership relation.
///
/// In particular, a prior database's integer PDF ID belongs here; it must not
/// be reused as [ResourceDocument.id] or as an annotation foreign key.
final class ResourceImportProvenance extends Equatable {
  ResourceImportProvenance({
    required this.sourceSystemId,
    required this.sourceEntityKind,
    required this.sourceRecordId,
    required DateTime importedAt,
    this.sourceSchemaVersion,
    this.sourceContentSha256,
  }) : importedAt = importedAt.toUtc() {
    _resourceId(sourceSystemId, 'sourceSystemId');
    _resourceId(sourceEntityKind, 'sourceEntityKind');
    _boundedText(sourceRecordId, 'sourceRecordId', maximum: 512);
    if (sourceSchemaVersion != null && sourceSchemaVersion! < 1) {
      throw ArgumentError.value(sourceSchemaVersion, 'sourceSchemaVersion');
    }
    if (sourceContentSha256 != null) {
      _sha256(sourceContentSha256!, 'sourceContentSha256');
    }
  }

  final String sourceSystemId;
  final String sourceEntityKind;
  final String sourceRecordId;
  final int? sourceSchemaVersion;
  final String? sourceContentSha256;
  final DateTime importedAt;

  Map<String, Object?> toJson() => {
    'sourceSystemId': sourceSystemId,
    'sourceEntityKind': sourceEntityKind,
    'sourceRecordId': sourceRecordId,
    'sourceSchemaVersion': sourceSchemaVersion,
    'sourceContentSha256': sourceContentSha256,
    'importedAt': importedAt.toIso8601String(),
  };

  factory ResourceImportProvenance.fromJson(Map<String, Object?> json) =>
      ResourceImportProvenance(
        sourceSystemId: json['sourceSystemId'] as String,
        sourceEntityKind: json['sourceEntityKind'] as String,
        sourceRecordId: json['sourceRecordId'] as String,
        sourceSchemaVersion: json['sourceSchemaVersion'] as int?,
        sourceContentSha256: json['sourceContentSha256'] as String?,
        importedAt: _resourceTime(json['importedAt'], 'importedAt'),
      );

  @override
  List<Object?> get props => [
    sourceSystemId,
    sourceEntityKind,
    sourceRecordId,
    sourceSchemaVersion,
    sourceContentSha256,
    importedAt,
  ];
}

/// Immutable metadata for one content-addressed learner document.
///
/// Bytes live in a blob store addressed by [contentAddress]. This record never
/// embeds base64 bytes or an absolute local path, so the same metadata contract
/// works on mobile, desktop, and Web storage adapters.
final class ResourceDocument extends Equatable {
  ResourceDocument({
    required this.id,
    required this.displayName,
    required this.mediaType,
    required this.contentSha256,
    required this.byteLength,
    required this.origin,
    required DateTime createdAt,
    this.pageCount,
    this.importProvenance,
  }) : createdAt = createdAt.toUtc() {
    _resourceId(id, 'id');
    _boundedText(displayName, 'displayName', maximum: 240);
    if (mediaType != mediaType.toLowerCase() ||
        !_mediaTypePattern.hasMatch(mediaType)) {
      throw ArgumentError.value(mediaType, 'mediaType', 'Invalid media type.');
    }
    _sha256(contentSha256, 'contentSha256');
    if (byteLength < 1) throw ArgumentError.value(byteLength, 'byteLength');
    if (pageCount != null && pageCount! < 1) {
      throw ArgumentError.value(pageCount, 'pageCount');
    }
    if (origin == ResourceDocumentOrigin.migratedImport &&
        importProvenance == null) {
      throw ArgumentError('Migrated documents require import provenance.');
    }
    if (origin != ResourceDocumentOrigin.migratedImport &&
        importProvenance != null) {
      throw ArgumentError(
        'Import provenance is reserved for migrated documents.',
      );
    }
  }

  final ResourceDocumentId id;
  final String displayName;
  final String mediaType;
  final String contentSha256;
  final int byteLength;
  final int? pageCount;
  final ResourceDocumentOrigin origin;
  final DateTime createdAt;
  final ResourceImportProvenance? importProvenance;

  String get contentAddress => 'sha256:$contentSha256';
  ResourceReference get reference => ResourceReference.document(id);

  Map<String, Object?> toJson() => {
    'id': id,
    'displayName': displayName,
    'mediaType': mediaType,
    'contentSha256': contentSha256,
    'byteLength': byteLength,
    'pageCount': pageCount,
    'origin': _documentOriginCodec.encode(origin),
    'createdAt': createdAt.toIso8601String(),
    'importProvenance': importProvenance?.toJson(),
  };

  factory ResourceDocument.fromJson(Map<String, Object?> json) =>
      ResourceDocument(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        mediaType: json['mediaType'] as String,
        contentSha256: json['contentSha256'] as String,
        byteLength: json['byteLength'] as int,
        pageCount: json['pageCount'] as int?,
        origin: _documentOriginCodec.decode(json['origin']),
        createdAt: _resourceTime(json['createdAt'], 'createdAt'),
        importProvenance: json['importProvenance'] == null
            ? null
            : ResourceImportProvenance.fromJson(
                _resourceMap(json['importProvenance'], 'importProvenance'),
              ),
      );

  @override
  List<Object?> get props => [
    id,
    displayName,
    mediaType,
    contentSha256,
    byteLength,
    pageCount,
    origin,
    createdAt,
    importProvenance,
  ];
}

/// Platform-neutral PDF region using integer millionths of the page bounds.
///
/// Integer coordinates avoid platform-dependent floating-point serialization.
final class NormalizedResourceRegion extends Equatable {
  NormalizedResourceRegion({
    required this.leftMillionths,
    required this.topMillionths,
    required this.widthMillionths,
    required this.heightMillionths,
  }) {
    if (leftMillionths < 0 || topMillionths < 0) {
      throw ArgumentError('Region origin cannot be negative.');
    }
    if (widthMillionths < 1 || heightMillionths < 1) {
      throw ArgumentError('Region size must be positive.');
    }
    if (leftMillionths + widthMillionths > scale ||
        topMillionths + heightMillionths > scale) {
      throw ArgumentError('Region must remain inside the page bounds.');
    }
  }

  static const scale = 1000000;

  final int leftMillionths;
  final int topMillionths;
  final int widthMillionths;
  final int heightMillionths;

  Map<String, Object?> toJson() => {
    'leftMillionths': leftMillionths,
    'topMillionths': topMillionths,
    'widthMillionths': widthMillionths,
    'heightMillionths': heightMillionths,
  };

  factory NormalizedResourceRegion.fromJson(Map<String, Object?> json) =>
      NormalizedResourceRegion(
        leftMillionths: json['leftMillionths'] as int,
        topMillionths: json['topMillionths'] as int,
        widthMillionths: json['widthMillionths'] as int,
        heightMillionths: json['heightMillionths'] as int,
      );

  @override
  List<Object?> get props => [
    leftMillionths,
    topMillionths,
    widthMillionths,
    heightMillionths,
  ];
}

/// One validated target for notes, bookmarks, reading state, and annotations.
///
/// [stableId] is derived from semantic identity, not a title, path, release, or
/// prior database key. JSON readers verify the derived ID to detect drift or
/// tampering before an artifact is attached to the wrong medical context.
sealed class ResourceAnchor extends Equatable {
  const ResourceAnchor({required this.resource});

  static const schemaVersion = 1;

  final ResourceReference resource;

  ResourceAnchorKind get kind;
  Map<String, Object?> get _identityPayload;
  Map<String, Object?> get _metadataPayload => const {};

  ResourceAnchorId get stableId =>
      'anchor.${CanonicalJson.sha256Hex(_identityJson)}';

  Map<String, Object?> get _identityJson => {
    'kind': _anchorKindCodec.encode(kind),
    'resource': resource.toJson(),
    'target': _identityPayload,
  };

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'id': stableId,
    ..._identityJson,
    ..._metadataPayload,
  };

  factory ResourceAnchor.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != schemaVersion) {
      throw const FormatException('Unsupported resource-anchor schema.');
    }
    final resource = ResourceReference.fromJson(
      _resourceMap(json['resource'], 'resource'),
    );
    final target = _resourceMap(json['target'], 'target');
    final kind = _anchorKindCodec.decode(json['kind']);
    final anchor = switch (kind) {
      ResourceAnchorKind.wholeResource => WholeResourceAnchor(resource),
      ResourceAnchorKind.curriculumBlock => CurriculumBlockResourceAnchor(
        resource: resource,
        blockId: target['blockId'] as String,
        localizationUnitId: target['localizationUnitId'] as String?,
        blockOrdinal: json['blockOrdinal'] as int,
      ),
      ResourceAnchorKind.documentPageRange => DocumentPageRangeResourceAnchor(
        resource: resource,
        startPage: target['startPage'] as int,
        endPage: target['endPage'] as int,
      ),
      ResourceAnchorKind.documentTextRange => DocumentTextRangeResourceAnchor(
        resource: resource,
        pageNumber: target['pageNumber'] as int,
        startOffset: target['startOffset'] as int,
        endOffset: target['endOffset'] as int,
        selectedTextSha256: target['selectedTextSha256'] as String,
      ),
      ResourceAnchorKind.documentRegion => DocumentRegionResourceAnchor(
        resource: resource,
        pageNumber: target['pageNumber'] as int,
        region: NormalizedResourceRegion.fromJson(
          _resourceMap(target['region'], 'target.region'),
        ),
      ),
    };
    if (json['id'] != anchor.stableId) {
      throw const FormatException(
        'Resource-anchor identity does not match payload.',
      );
    }
    return anchor;
  }

  @override
  List<Object?> get props => [stableId, ..._metadataPayload.values];
}

final class WholeResourceAnchor extends ResourceAnchor {
  const WholeResourceAnchor(ResourceReference resource)
    : super(resource: resource);

  @override
  ResourceAnchorKind get kind => ResourceAnchorKind.wholeResource;

  @override
  Map<String, Object?> get _identityPayload => const {};
}

/// Exact Deep Study Block anchor with an ordinal retained only for fallback.
final class CurriculumBlockResourceAnchor extends ResourceAnchor {
  CurriculumBlockResourceAnchor({
    required super.resource,
    required this.blockId,
    required this.blockOrdinal,
    this.localizationUnitId,
  }) {
    if (resource.kind != ResourceReferenceKind.curriculumStudyDocument) {
      throw ArgumentError(
        'A curriculum Block must target a curriculum Study document.',
      );
    }
    _resourceId(blockId, 'blockId');
    if (localizationUnitId != null) {
      _resourceId(localizationUnitId!, 'localizationUnitId');
    }
    if (blockOrdinal < 1) {
      throw ArgumentError.value(blockOrdinal, 'blockOrdinal');
    }
  }

  final String blockId;
  final int blockOrdinal;
  final String? localizationUnitId;

  @override
  ResourceAnchorKind get kind => ResourceAnchorKind.curriculumBlock;

  @override
  Map<String, Object?> get _identityPayload => {
    'blockId': blockId,
    'localizationUnitId': localizationUnitId,
  };

  @override
  Map<String, Object?> get _metadataPayload => {'blockOrdinal': blockOrdinal};
}

abstract base class _DocumentResourceAnchor extends ResourceAnchor {
  _DocumentResourceAnchor({required super.resource}) {
    if (resource.kind != ResourceReferenceKind.document) {
      throw ArgumentError('A paged anchor must target a document resource.');
    }
  }

  static void requirePage(int page, String field) {
    if (page < 1) throw ArgumentError.value(page, field);
  }
}

final class DocumentPageRangeResourceAnchor extends _DocumentResourceAnchor {
  DocumentPageRangeResourceAnchor({
    required super.resource,
    required this.startPage,
    required this.endPage,
  }) {
    _DocumentResourceAnchor.requirePage(startPage, 'startPage');
    _DocumentResourceAnchor.requirePage(endPage, 'endPage');
    if (endPage < startPage) {
      throw ArgumentError('endPage cannot precede startPage.');
    }
  }

  final int startPage;
  final int endPage;

  @override
  ResourceAnchorKind get kind => ResourceAnchorKind.documentPageRange;

  @override
  Map<String, Object?> get _identityPayload => {
    'startPage': startPage,
    'endPage': endPage,
  };
}

/// Text selection without copied source text.
///
/// The normalized selected-text digest supports drift detection/re-anchoring;
/// source text itself stays in the document/index authority.
final class DocumentTextRangeResourceAnchor extends _DocumentResourceAnchor {
  DocumentTextRangeResourceAnchor({
    required super.resource,
    required this.pageNumber,
    required this.startOffset,
    required this.endOffset,
    required this.selectedTextSha256,
  }) {
    _DocumentResourceAnchor.requirePage(pageNumber, 'pageNumber');
    if (startOffset < 0 || endOffset <= startOffset) {
      throw ArgumentError('Text offsets must describe a non-empty range.');
    }
    _sha256(selectedTextSha256, 'selectedTextSha256');
  }

  final int pageNumber;
  final int startOffset;
  final int endOffset;
  final String selectedTextSha256;

  @override
  ResourceAnchorKind get kind => ResourceAnchorKind.documentTextRange;

  @override
  Map<String, Object?> get _identityPayload => {
    'pageNumber': pageNumber,
    'startOffset': startOffset,
    'endOffset': endOffset,
    'selectedTextSha256': selectedTextSha256,
  };
}

final class DocumentRegionResourceAnchor extends _DocumentResourceAnchor {
  DocumentRegionResourceAnchor({
    required super.resource,
    required this.pageNumber,
    required this.region,
  }) {
    _DocumentResourceAnchor.requirePage(pageNumber, 'pageNumber');
  }

  final int pageNumber;
  final NormalizedResourceRegion region;

  @override
  ResourceAnchorKind get kind => ResourceAnchorKind.documentRegion;

  @override
  Map<String, Object?> get _identityPayload => {
    'pageNumber': pageNumber,
    'region': region.toJson(),
  };
}

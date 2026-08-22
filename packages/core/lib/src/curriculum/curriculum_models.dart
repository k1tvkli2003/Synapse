import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';

import '../models/ids.dart';
import '../serialization/stable_enum_codec.dart';
import 'curriculum_identity.dart';

enum CurriculumReleaseChannel { internal, beta, stable }

enum ContentLifecycleState {
  raw,
  reviewed,
  validated,
  published,
  withdrawn,
  superseded,
  quarantined,
}

enum CurriculumNodeKind { course, chapter, unit, conceptCluster, microLesson }

enum CurriculumIdentityState { candidate, approved, superseded }

enum ContentLocale { en, fa }

enum ContentDirection { ltr, rtl }

enum LocalizedVariantStatus {
  draft,
  authored,
  medicalReviewed,
  nativeReviewed,
  approved,
}

enum LocalizationPairState {
  draft,
  semanticParityReviewed,
  medicalParityReviewed,
  nativeLanguageReviewed,
  publishable,
}

enum ContentSemanticRole {
  title,
  objective,
  instruction,
  explanation,
  prompt,
  option,
  hint,
  feedbackFlash,
  feedbackRepair,
  feedbackDeep,
  whyCorrect,
  whyWrong,
  caption,
  altText,
  accessibleAlternative,
  recap,
  debrief,
  disclaimer,
}

final _channelCodec = StableEnumCodec<CurriculumReleaseChannel>({
  'internal': CurriculumReleaseChannel.internal,
  'beta': CurriculumReleaseChannel.beta,
  'stable': CurriculumReleaseChannel.stable,
});

final _lifecycleCodec = StableEnumCodec<ContentLifecycleState>({
  'raw': ContentLifecycleState.raw,
  'reviewed': ContentLifecycleState.reviewed,
  'validated': ContentLifecycleState.validated,
  'published': ContentLifecycleState.published,
  'withdrawn': ContentLifecycleState.withdrawn,
  'superseded': ContentLifecycleState.superseded,
  'quarantined': ContentLifecycleState.quarantined,
});

final _nodeKindCodec = StableEnumCodec<CurriculumNodeKind>({
  'course': CurriculumNodeKind.course,
  'chapter': CurriculumNodeKind.chapter,
  'unit': CurriculumNodeKind.unit,
  'concept_cluster': CurriculumNodeKind.conceptCluster,
  'micro_lesson': CurriculumNodeKind.microLesson,
});

final _identityStateCodec = StableEnumCodec<CurriculumIdentityState>({
  'candidate': CurriculumIdentityState.candidate,
  'approved': CurriculumIdentityState.approved,
  'superseded': CurriculumIdentityState.superseded,
});

final _localeCodec = StableEnumCodec<ContentLocale>({
  'en': ContentLocale.en,
  'fa': ContentLocale.fa,
});

final _directionCodec = StableEnumCodec<ContentDirection>({
  'ltr': ContentDirection.ltr,
  'rtl': ContentDirection.rtl,
});

final _variantStatusCodec = StableEnumCodec<LocalizedVariantStatus>({
  'draft': LocalizedVariantStatus.draft,
  'authored': LocalizedVariantStatus.authored,
  'medical_reviewed': LocalizedVariantStatus.medicalReviewed,
  'native_reviewed': LocalizedVariantStatus.nativeReviewed,
  'approved': LocalizedVariantStatus.approved,
});

final _pairStateCodec = StableEnumCodec<LocalizationPairState>({
  'draft': LocalizationPairState.draft,
  'semantic_parity_reviewed': LocalizationPairState.semanticParityReviewed,
  'medical_parity_reviewed': LocalizationPairState.medicalParityReviewed,
  'native_language_reviewed': LocalizationPairState.nativeLanguageReviewed,
  'publishable': LocalizationPairState.publishable,
});

final _semanticRoleCodec = StableEnumCodec<ContentSemanticRole>({
  'title': ContentSemanticRole.title,
  'objective': ContentSemanticRole.objective,
  'instruction': ContentSemanticRole.instruction,
  'explanation': ContentSemanticRole.explanation,
  'prompt': ContentSemanticRole.prompt,
  'option': ContentSemanticRole.option,
  'hint': ContentSemanticRole.hint,
  'feedback_flash': ContentSemanticRole.feedbackFlash,
  'feedback_repair': ContentSemanticRole.feedbackRepair,
  'feedback_deep': ContentSemanticRole.feedbackDeep,
  'why_correct': ContentSemanticRole.whyCorrect,
  'why_wrong': ContentSemanticRole.whyWrong,
  'caption': ContentSemanticRole.caption,
  'alt_text': ContentSemanticRole.altText,
  'accessible_alternative': ContentSemanticRole.accessibleAlternative,
  'recap': ContentSemanticRole.recap,
  'debrief': ContentSemanticRole.debrief,
  'disclaimer': ContentSemanticRole.disclaimer,
});

final _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');
final _stableIdPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:/-]*$');

String _requiredString(String value, String field) {
  if (value != value.trim() || value.isEmpty) {
    throw ArgumentError.value(value, field, 'Must be non-empty and trimmed.');
  }
  return value;
}

String _stableId(String value, String field) {
  _requiredString(value, field);
  if (!_stableIdPattern.hasMatch(value)) {
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

List<String> _ids(
  Iterable<String> values,
  String field, {
  bool nonEmpty = false,
}) {
  final result = values
      .map((value) => _stableId(value, field))
      .toList(growable: false);
  if (nonEmpty && result.isEmpty) {
    throw ArgumentError.value(result, field, 'Must not be empty.');
  }
  if (result.toSet().length != result.length) {
    throw ArgumentError.value(result, field, 'Duplicate IDs are not allowed.');
  }
  return List.unmodifiable(result);
}

List<String> _jsonStringList(Object? value, String field) {
  if (value is! List || value.any((item) => item is! String)) {
    throw SerializationException(
      code: SerializationIssueCode.invalidField,
      message: '$field must be an array of strings.',
      source: value,
    );
  }
  return value.cast<String>();
}

DateTime _dateTime(Object? value, String field) {
  if (value is! String) {
    throw SerializationException(
      code: SerializationIssueCode.invalidField,
      message: '$field must be an ISO-8601 timestamp.',
      source: value,
    );
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw SerializationException(
      code: SerializationIssueCode.invalidField,
      message: '$field must be an ISO-8601 timestamp.',
      source: value,
    );
  }
  return parsed.toUtc();
}

String _textSha256(String text) => sha256.convert(utf8.encode(text)).toString();

/// A distributable description of a source corpus. It intentionally has no
/// local filesystem path field.
final class CurriculumSource extends Equatable {
  CurriculumSource({
    required this.id,
    required this.sourceKey,
    required this.classification,
    required this.sourceTreeSha256,
    required this.scanManifestId,
    required this.priorityCourseSourceKey,
  }) {
    _stableId(id, 'id');
    _stableId(sourceKey, 'sourceKey');
    _requiredString(classification, 'classification');
    _sha256(sourceTreeSha256, 'sourceTreeSha256');
    _stableId(scanManifestId, 'scanManifestId');
    if (!CurriculumIdentity.isValidSourceKey(priorityCourseSourceKey)) {
      throw ArgumentError.value(
        priorityCourseSourceKey,
        'priorityCourseSourceKey',
        'Expected a normalized source course key.',
      );
    }
  }

  final CurriculumSourceId id;
  final String sourceKey;
  final String classification;
  final String sourceTreeSha256;
  final String scanManifestId;
  final String priorityCourseSourceKey;

  static const localRootDistributable = false;

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceKey': sourceKey,
    'classification': classification,
    'sourceTreeSha256': sourceTreeSha256,
    'scanManifestId': scanManifestId,
    'localRootDistributable': localRootDistributable,
    'priorityCourseSourceKey': priorityCourseSourceKey,
  };

  factory CurriculumSource.fromJson(Map<String, dynamic> json) {
    if (json['localRootDistributable'] != false) {
      throw const SerializationException(
        code: SerializationIssueCode.invalidField,
        message: 'A local source root must never be distributable.',
      );
    }
    return CurriculumSource(
      id: json['id'] as String,
      sourceKey: json['sourceKey'] as String,
      classification: json['classification'] as String,
      sourceTreeSha256: json['sourceTreeSha256'] as String,
      scanManifestId: json['scanManifestId'] as String,
      priorityCourseSourceKey: json['priorityCourseSourceKey'] as String,
    );
  }

  @override
  List<Object?> get props => [
    id,
    sourceKey,
    classification,
    sourceTreeSha256,
    scanManifestId,
    priorityCourseSourceKey,
  ];
}

final class CurriculumRelease extends Equatable {
  CurriculumRelease({
    required this.id,
    required this.sourceId,
    required this.version,
    required this.channel,
    required this.contractVersion,
    required this.authoringProtocolVersion,
    required this.sourceTreeSha256,
    required this.contentState,
    required DateTime createdAt,
    this.parentReleaseId,
    Iterable<String> generatorRunIds = const [],
  }) : createdAt = createdAt.toUtc(),
       generatorRunIds = _ids(generatorRunIds, 'generatorRunIds') {
    _stableId(id, 'id');
    _stableId(sourceId, 'sourceId');
    _requiredString(version, 'version');
    if (contractVersion < 1) {
      throw ArgumentError.value(contractVersion, 'contractVersion');
    }
    _requiredString(authoringProtocolVersion, 'authoringProtocolVersion');
    _sha256(sourceTreeSha256, 'sourceTreeSha256');
    if (parentReleaseId != null) {
      _stableId(parentReleaseId!, 'parentReleaseId');
      if (parentReleaseId == id) {
        throw ArgumentError('A release cannot be its own parent.');
      }
    }
  }

  final CurriculumReleaseId id;
  final CurriculumSourceId sourceId;
  final String version;
  final CurriculumReleaseId? parentReleaseId;
  final CurriculumReleaseChannel channel;
  final int contractVersion;
  final String authoringProtocolVersion;
  final String sourceTreeSha256;
  final ContentLifecycleState contentState;
  final DateTime createdAt;
  final List<String> generatorRunIds;

  bool get isLearnerVisible => contentState == ContentLifecycleState.published;

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceId': sourceId,
    'version': version,
    'parentReleaseId': parentReleaseId,
    'channel': _channelCodec.encode(channel),
    'contractVersion': contractVersion,
    'authoringProtocolVersion': authoringProtocolVersion,
    'sourceTreeSha256': sourceTreeSha256,
    'contentState': _lifecycleCodec.encode(contentState),
    'createdAt': createdAt.toIso8601String(),
    'generatorRunIds': generatorRunIds,
  };

  factory CurriculumRelease.fromJson(Map<String, dynamic> json) =>
      CurriculumRelease(
        id: json['id'] as String,
        sourceId: json['sourceId'] as String,
        version: json['version'] as String,
        parentReleaseId: json['parentReleaseId'] as String?,
        channel: _channelCodec.decode(json['channel']),
        contractVersion: json['contractVersion'] as int,
        authoringProtocolVersion: json['authoringProtocolVersion'] as String,
        sourceTreeSha256: json['sourceTreeSha256'] as String,
        contentState: _lifecycleCodec.decode(json['contentState']),
        createdAt: _dateTime(json['createdAt'], 'createdAt'),
        generatorRunIds: _jsonStringList(
          json['generatorRunIds'],
          'generatorRunIds',
        ),
      );

  @override
  List<Object?> get props => [
    id,
    sourceId,
    version,
    parentReleaseId,
    channel,
    contractVersion,
    authoringProtocolVersion,
    sourceTreeSha256,
    contentState,
    createdAt,
    generatorRunIds,
  ];
}

final class CurriculumChannelPointer extends Equatable {
  CurriculumChannelPointer({
    required this.sourceId,
    required this.channel,
    required this.releaseId,
    required DateTime updatedAt,
  }) : updatedAt = updatedAt.toUtc() {
    _stableId(sourceId, 'sourceId');
    _stableId(releaseId, 'releaseId');
  }

  final CurriculumSourceId sourceId;
  final CurriculumReleaseChannel channel;
  final CurriculumReleaseId releaseId;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'sourceId': sourceId,
    'channel': _channelCodec.encode(channel),
    'releaseId': releaseId,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory CurriculumChannelPointer.fromJson(Map<String, dynamic> json) =>
      CurriculumChannelPointer(
        sourceId: json['sourceId'] as String,
        channel: _channelCodec.decode(json['channel']),
        releaseId: json['releaseId'] as String,
        updatedAt: _dateTime(json['updatedAt'], 'updatedAt'),
      );

  @override
  List<Object?> get props => [sourceId, channel, releaseId, updatedAt];
}

final class CurriculumNode extends Equatable {
  CurriculumNode({
    required this.id,
    required this.sourceKey,
    required this.kind,
    required this.ordinal,
    required this.identityState,
    required this.titleUnitId,
    this.parentId,
    Iterable<String> sourceContainerKeys = const [],
    Iterable<String> conceptIds = const [],
    Iterable<String> prerequisiteNodeIds = const [],
    Iterable<String> supersedesNodeIds = const [],
  }) : sourceContainerKeys = _ids(sourceContainerKeys, 'sourceContainerKeys'),
       conceptIds = _ids(conceptIds, 'conceptIds'),
       prerequisiteNodeIds = _ids(prerequisiteNodeIds, 'prerequisiteNodeIds'),
       supersedesNodeIds = _ids(supersedesNodeIds, 'supersedesNodeIds') {
    _stableId(id, 'id');
    if (!CurriculumIdentity.isValidSourceKey(sourceKey)) {
      throw ArgumentError.value(sourceKey, 'sourceKey');
    }
    final expectedId = CurriculumIdentity.fromSourceKey(sourceKey);
    if (id != expectedId) {
      throw ArgumentError.value(
        id,
        'id',
        'Expected UUIDv5 $expectedId for $sourceKey.',
      );
    }
    if (ordinal < 1) throw ArgumentError.value(ordinal, 'ordinal');
    _stableId(titleUnitId, 'titleUnitId');
    if (parentId != null) _stableId(parentId!, 'parentId');
    if (prerequisiteNodeIds.contains(id) || supersedesNodeIds.contains(id)) {
      throw ArgumentError('A node cannot reference itself.');
    }
  }

  factory CurriculumNode.fromSourceKey({
    required String sourceKey,
    required CurriculumNodeKind kind,
    required int ordinal,
    required CurriculumIdentityState identityState,
    required CurriculumLocalizationUnitId titleUnitId,
    CurriculumNodeId? parentId,
    Iterable<String> sourceContainerKeys = const [],
    Iterable<String> conceptIds = const [],
    Iterable<String> prerequisiteNodeIds = const [],
    Iterable<String> supersedesNodeIds = const [],
  }) => CurriculumNode(
    id: CurriculumIdentity.fromSourceKey(sourceKey),
    sourceKey: sourceKey,
    kind: kind,
    ordinal: ordinal,
    identityState: identityState,
    titleUnitId: titleUnitId,
    parentId: parentId,
    sourceContainerKeys: sourceContainerKeys,
    conceptIds: conceptIds,
    prerequisiteNodeIds: prerequisiteNodeIds,
    supersedesNodeIds: supersedesNodeIds,
  );

  final CurriculumNodeId id;
  final String sourceKey;
  final CurriculumNodeId? parentId;
  final CurriculumNodeKind kind;
  final int ordinal;
  final CurriculumIdentityState identityState;
  final CurriculumLocalizationUnitId titleUnitId;
  final List<String> sourceContainerKeys;
  final List<String> conceptIds;
  final List<CurriculumNodeId> prerequisiteNodeIds;
  final List<CurriculumNodeId> supersedesNodeIds;

  bool get isPlayable =>
      kind == CurriculumNodeKind.microLesson &&
      identityState == CurriculumIdentityState.approved;

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceKey': sourceKey,
    'parentId': parentId,
    'kind': _nodeKindCodec.encode(kind),
    'ordinal': ordinal,
    'identityState': _identityStateCodec.encode(identityState),
    'titleUnitId': titleUnitId,
    'sourceContainerKeys': sourceContainerKeys,
    'conceptIds': conceptIds,
    'prerequisiteNodeIds': prerequisiteNodeIds,
    'supersedesNodeIds': supersedesNodeIds,
  };

  factory CurriculumNode.fromJson(Map<String, dynamic> json) => CurriculumNode(
    id: json['id'] as String,
    sourceKey: json['sourceKey'] as String,
    parentId: json['parentId'] as String?,
    kind: _nodeKindCodec.decode(json['kind']),
    ordinal: json['ordinal'] as int,
    identityState: _identityStateCodec.decode(json['identityState']),
    titleUnitId: json['titleUnitId'] as String,
    sourceContainerKeys: _jsonStringList(
      json['sourceContainerKeys'],
      'sourceContainerKeys',
    ),
    conceptIds: _jsonStringList(json['conceptIds'], 'conceptIds'),
    prerequisiteNodeIds: _jsonStringList(
      json['prerequisiteNodeIds'],
      'prerequisiteNodeIds',
    ),
    supersedesNodeIds: _jsonStringList(
      json['supersedesNodeIds'],
      'supersedesNodeIds',
    ),
  );

  @override
  List<Object?> get props => [
    id,
    sourceKey,
    parentId,
    kind,
    ordinal,
    identityState,
    titleUnitId,
    sourceContainerKeys,
    conceptIds,
    prerequisiteNodeIds,
    supersedesNodeIds,
  ];
}

final class CurriculumInvariantException implements Exception {
  const CurriculumInvariantException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'CurriculumInvariantException($code): $message';
}

/// An immutable, validated hierarchy projection. Source anchors are lineage
/// metadata and never appear as a learner-facing node kind.
final class CurriculumTree {
  factory CurriculumTree(Iterable<CurriculumNode> values) {
    final nodes = List<CurriculumNode>.unmodifiable(values);
    return CurriculumTree._(nodes, {for (final node in nodes) node.id: node});
  }

  CurriculumTree._(this.nodes, this._byId) {
    _validate();
  }

  final List<CurriculumNode> nodes;
  final Map<CurriculumNodeId, CurriculumNode> _byId;

  static const _parentKind = <CurriculumNodeKind, CurriculumNodeKind?>{
    CurriculumNodeKind.course: null,
    CurriculumNodeKind.chapter: CurriculumNodeKind.course,
    CurriculumNodeKind.unit: CurriculumNodeKind.chapter,
    CurriculumNodeKind.conceptCluster: CurriculumNodeKind.unit,
    CurriculumNodeKind.microLesson: CurriculumNodeKind.conceptCluster,
  };

  CurriculumNode? byId(CurriculumNodeId id) => _byId[id];

  List<CurriculumNode> childrenOf(CurriculumNodeId? parentId) =>
      nodes.where((node) => node.parentId == parentId).toList(growable: false)
        ..sort((left, right) => left.ordinal.compareTo(right.ordinal));

  void _validate() {
    if (_byId.length != nodes.length) {
      throw const CurriculumInvariantException(
        'duplicate_id',
        'Node IDs must be unique.',
      );
    }
    if (nodes.map((node) => node.sourceKey).toSet().length != nodes.length) {
      throw const CurriculumInvariantException(
        'duplicate_source_key',
        'Node source keys must be unique.',
      );
    }

    final siblingOrdinals = <String>{};
    for (final node in nodes) {
      final expectedParentKind = _parentKind[node.kind];
      if (expectedParentKind == null) {
        if (node.parentId != null) {
          throw CurriculumInvariantException(
            'course_has_parent',
            '${node.id} is a Course and must not have a parent.',
          );
        }
      } else {
        final parent = node.parentId == null ? null : _byId[node.parentId];
        if (parent == null) {
          throw CurriculumInvariantException(
            'missing_parent',
            '${node.id} has no resolvable parent.',
          );
        }
        if (parent.kind != expectedParentKind) {
          throw CurriculumInvariantException(
            'invalid_parent_kind',
            '${node.kind.name} requires ${expectedParentKind.name}, not ${parent.kind.name}.',
          );
        }
      }
      final siblingKey =
          '${node.parentId ?? 'root'}|${node.kind.name}|${node.ordinal}';
      if (!siblingOrdinals.add(siblingKey)) {
        throw CurriculumInvariantException(
          'duplicate_sibling_ordinal',
          'Duplicate ordinal ${node.ordinal} under ${node.parentId ?? 'root'}.',
        );
      }
      for (final prerequisiteId in node.prerequisiteNodeIds) {
        if (!_byId.containsKey(prerequisiteId)) {
          throw CurriculumInvariantException(
            'missing_prerequisite',
            '${node.id} references missing prerequisite $prerequisiteId.',
          );
        }
      }
    }
    _assertAcyclic(
      nodes,
      (node) => [
        if (node.parentId != null) node.parentId!,
        ...node.prerequisiteNodeIds,
      ],
    );
  }

  void _assertAcyclic(
    Iterable<CurriculumNode> values,
    Iterable<CurriculumNodeId> Function(CurriculumNode node) edges,
  ) {
    final visiting = <CurriculumNodeId>{};
    final visited = <CurriculumNodeId>{};

    void visit(CurriculumNode node) {
      if (visited.contains(node.id)) return;
      if (!visiting.add(node.id)) {
        throw CurriculumInvariantException(
          'cycle',
          'Hierarchy/prerequisite cycle reaches ${node.id}.',
        );
      }
      for (final targetId in edges(node)) {
        final target = _byId[targetId];
        if (target != null) visit(target);
      }
      visiting.remove(node.id);
      visited.add(node.id);
    }

    for (final node in values) {
      visit(node);
    }
  }
}

final class LocalizedVariant extends Equatable {
  LocalizedVariant({
    required this.locale,
    required this.direction,
    required this.text,
    required this.textSha256,
    required this.status,
    required this.authorId,
    this.reviewerId,
    DateTime? reviewedAt,
  }) : reviewedAt = reviewedAt?.toUtc() {
    _requiredString(text, 'text');
    _sha256(textSha256, 'textSha256');
    final actual = _textSha256(text);
    if (actual != textSha256) {
      throw ArgumentError.value(textSha256, 'textSha256', 'Expected $actual.');
    }
    final expectedDirection = locale == ContentLocale.fa
        ? ContentDirection.rtl
        : ContentDirection.ltr;
    if (direction != expectedDirection) {
      throw ArgumentError(
        'Locale ${locale.name} requires ${expectedDirection.name}.',
      );
    }
    _stableId(authorId, 'authorId');
    if (reviewerId != null) _stableId(reviewerId!, 'reviewerId');
    if (status == LocalizedVariantStatus.approved &&
        (reviewerId == null || this.reviewedAt == null)) {
      throw ArgumentError('Approved text requires reviewerId and reviewedAt.');
    }
    if (status == LocalizedVariantStatus.approved && reviewerId == authorId) {
      throw ArgumentError('Approved text requires an independent reviewer.');
    }
  }

  factory LocalizedVariant.authored({
    required ContentLocale locale,
    required String text,
    required LocalizedVariantStatus status,
    required String authorId,
    String? reviewerId,
    DateTime? reviewedAt,
  }) => LocalizedVariant(
    locale: locale,
    direction: locale == ContentLocale.fa
        ? ContentDirection.rtl
        : ContentDirection.ltr,
    text: text,
    textSha256: _textSha256(text),
    status: status,
    authorId: authorId,
    reviewerId: reviewerId,
    reviewedAt: reviewedAt,
  );

  final ContentLocale locale;
  final ContentDirection direction;
  final String text;
  final String textSha256;
  final LocalizedVariantStatus status;
  final String authorId;
  final String? reviewerId;
  final DateTime? reviewedAt;

  Map<String, dynamic> toJson() => {
    'locale': _localeCodec.encode(locale),
    'direction': _directionCodec.encode(direction),
    'text': text,
    'textSha256': textSha256,
    'status': _variantStatusCodec.encode(status),
    'authorId': authorId,
    'reviewerId': reviewerId,
    'reviewedAt': reviewedAt?.toIso8601String(),
  };

  factory LocalizedVariant.fromJson(Map<String, dynamic> json) =>
      LocalizedVariant(
        locale: _localeCodec.decode(json['locale']),
        direction: _directionCodec.decode(json['direction']),
        text: json['text'] as String,
        textSha256: json['textSha256'] as String,
        status: _variantStatusCodec.decode(json['status']),
        authorId: json['authorId'] as String,
        reviewerId: json['reviewerId'] as String?,
        reviewedAt: json['reviewedAt'] == null
            ? null
            : _dateTime(json['reviewedAt'], 'reviewedAt'),
      );

  @override
  List<Object?> get props => [
    locale,
    direction,
    text,
    textSha256,
    status,
    authorId,
    reviewerId,
    reviewedAt,
  ];
}

final class CurriculumLocalizationUnit extends Equatable {
  CurriculumLocalizationUnit({
    required this.id,
    required this.semanticRole,
    required this.semanticSkeletonSha256,
    required this.en,
    required this.fa,
    required this.pairState,
    Iterable<String> claimIds = const [],
    Iterable<String> sourceAtomIds = const [],
    Iterable<String> conceptIds = const [],
    Iterable<String> terminologyIds = const [],
    Iterable<String> numericTokenIds = const [],
  }) : claimIds = _ids(claimIds, 'claimIds'),
       sourceAtomIds = _ids(sourceAtomIds, 'sourceAtomIds'),
       conceptIds = _ids(conceptIds, 'conceptIds'),
       terminologyIds = _ids(terminologyIds, 'terminologyIds'),
       numericTokenIds = _ids(numericTokenIds, 'numericTokenIds') {
    _stableId(id, 'id');
    _sha256(semanticSkeletonSha256, 'semanticSkeletonSha256');
    if (en.locale != ContentLocale.en || fa.locale != ContentLocale.fa) {
      throw ArgumentError(
        'Localization units require one English and one Persian variant.',
      );
    }
    if (pairState == LocalizationPairState.publishable &&
        (en.status != LocalizedVariantStatus.approved ||
            fa.status != LocalizedVariantStatus.approved)) {
      throw ArgumentError(
        'A publishable pair requires approved EN and FA variants.',
      );
    }
  }

  final CurriculumLocalizationUnitId id;
  final ContentSemanticRole semanticRole;
  final String semanticSkeletonSha256;
  final List<String> claimIds;
  final List<SourceAtomId> sourceAtomIds;
  final List<String> conceptIds;
  final List<String> terminologyIds;
  final List<String> numericTokenIds;
  final LocalizedVariant en;
  final LocalizedVariant fa;
  final LocalizationPairState pairState;

  bool get isPublishable => pairState == LocalizationPairState.publishable;

  LocalizedVariant variant(ContentLocale locale) =>
      locale == ContentLocale.fa ? fa : en;

  Map<String, dynamic> toJson() => {
    'id': id,
    'semanticRole': _semanticRoleCodec.encode(semanticRole),
    'semanticSkeletonSha256': semanticSkeletonSha256,
    'claimIds': claimIds,
    'sourceAtomIds': sourceAtomIds,
    'conceptIds': conceptIds,
    'terminologyIds': terminologyIds,
    'numericTokenIds': numericTokenIds,
    'en': en.toJson(),
    'fa': fa.toJson(),
    'pairState': _pairStateCodec.encode(pairState),
  };

  factory CurriculumLocalizationUnit.fromJson(
    Map<String, dynamic> json,
  ) => CurriculumLocalizationUnit(
    id: json['id'] as String,
    semanticRole: _semanticRoleCodec.decode(json['semanticRole']),
    semanticSkeletonSha256: json['semanticSkeletonSha256'] as String,
    claimIds: _jsonStringList(json['claimIds'], 'claimIds'),
    sourceAtomIds: _jsonStringList(json['sourceAtomIds'], 'sourceAtomIds'),
    conceptIds: _jsonStringList(json['conceptIds'], 'conceptIds'),
    terminologyIds: _jsonStringList(json['terminologyIds'], 'terminologyIds'),
    numericTokenIds: _jsonStringList(
      json['numericTokenIds'],
      'numericTokenIds',
    ),
    en: LocalizedVariant.fromJson(Map<String, dynamic>.from(json['en'] as Map)),
    fa: LocalizedVariant.fromJson(Map<String, dynamic>.from(json['fa'] as Map)),
    pairState: _pairStateCodec.decode(json['pairState']),
  );

  @override
  List<Object?> get props => [
    id,
    semanticRole,
    semanticSkeletonSha256,
    claimIds,
    sourceAtomIds,
    conceptIds,
    terminologyIds,
    numericTokenIds,
    en,
    fa,
    pairState,
  ];
}

final class LocaleDuration extends Equatable {
  LocaleDuration({required this.enSeconds, required this.faSeconds}) {
    if (enSeconds < 1) throw ArgumentError.value(enSeconds, 'enSeconds');
    if (faSeconds < 1) throw ArgumentError.value(faSeconds, 'faSeconds');
  }

  final int enSeconds;
  final int faSeconds;

  int forLocale(ContentLocale locale) =>
      locale == ContentLocale.fa ? faSeconds : enSeconds;

  Map<String, dynamic> toJson() => {'en': enSeconds, 'fa': faSeconds};

  factory LocaleDuration.fromJson(Map<String, dynamic> json) => LocaleDuration(
    enSeconds: json['en'] as int,
    faSeconds: json['fa'] as int,
  );

  @override
  List<Object?> get props => [enSeconds, faSeconds];
}

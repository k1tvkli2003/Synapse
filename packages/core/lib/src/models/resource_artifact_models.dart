import 'package:equatable/equatable.dart';

import '../curriculum/curriculum_models.dart';
import '../serialization/canonical_json.dart';
import '../serialization/stable_enum_codec.dart';
import 'ids.dart';
import 'resource_reference_models.dart';

/// Learner-authored annotation shape. It is never published as medical truth.
enum ResourceAnnotationKind { highlight, comment, ink }

/// Explicit lifecycle used by sync and recovery; deletion is a tombstone.
enum ResourceAnnotationState { active, resolved, deleted }

/// Stable semantic palette role instead of a platform-specific raw color.
enum ResourceArtifactColor { cyan, gold, coral, violet, green }

/// Explicit relationship between two universal resources.
enum ResourceCrossReferenceKind {
  supportingDocument,
  evidenceSupport,
  relatedContext,
}

final _annotationKindCodec = StableEnumCodec<ResourceAnnotationKind>({
  'highlight': ResourceAnnotationKind.highlight,
  'comment': ResourceAnnotationKind.comment,
  'ink': ResourceAnnotationKind.ink,
});

final _annotationStateCodec = StableEnumCodec<ResourceAnnotationState>({
  'active': ResourceAnnotationState.active,
  'resolved': ResourceAnnotationState.resolved,
  'deleted': ResourceAnnotationState.deleted,
});

final _artifactColorCodec = StableEnumCodec<ResourceArtifactColor>({
  'cyan': ResourceArtifactColor.cyan,
  'gold': ResourceArtifactColor.gold,
  'coral': ResourceArtifactColor.coral,
  'violet': ResourceArtifactColor.violet,
  'green': ResourceArtifactColor.green,
});

final _crossReferenceKindCodec = StableEnumCodec<ResourceCrossReferenceKind>({
  'supporting_document': ResourceCrossReferenceKind.supportingDocument,
  'evidence_support': ResourceCrossReferenceKind.evidenceSupport,
  'related_context': ResourceCrossReferenceKind.relatedContext,
});

final _artifactIdPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:/-]*$');
final _artifactControlPattern = RegExp(
  r'[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]',
);

String _artifactId(String value, String field) {
  if (value.length > 200 ||
      value != value.trim() ||
      !_artifactIdPattern.hasMatch(value)) {
    throw ArgumentError.value(value, field, 'Invalid stable ID.');
  }
  return value;
}

String _artifactBody(String value, String field, {required int maximum}) {
  if (value != value.trim() ||
      value.isEmpty ||
      value.length > maximum ||
      _artifactControlPattern.hasMatch(value)) {
    throw ArgumentError.value(value, field, 'Invalid learner-authored text.');
  }
  return value;
}

DateTime _artifactTime(Object? value, String field) {
  if (value is! String) {
    throw FormatException('$field must be an ISO-8601 timestamp.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('$field must be an ISO-8601 timestamp.');
  }
  return parsed.toUtc();
}

Map<String, Object?> _artifactMap(Object? value, String field) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw FormatException('$field must be a JSON object.');
  }
  return Map<String, Object?>.from(value);
}

List<Object?> _artifactList(Object? value, String field) {
  if (value is! List) throw FormatException('$field must be a JSON array.');
  return List<Object?>.from(value);
}

List<String> _artifactTags(Iterable<String> values) {
  final result = List<String>.unmodifiable(values);
  if (result.length > 32) {
    throw ArgumentError.value(result.length, 'tagIds', 'Maximum is 32.');
  }
  for (final value in result) {
    _artifactId(value, 'tagIds');
  }
  if (result.toSet().length != result.length) {
    throw ArgumentError.value(result, 'tagIds', 'Duplicates are not allowed.');
  }
  return result;
}

/// One point inside an annotation region, expressed in integer millionths.
final class ResourceInkPoint extends Equatable {
  ResourceInkPoint({
    required this.xMillionths,
    required this.yMillionths,
    required this.pressurePermille,
  }) {
    if (xMillionths < 0 ||
        xMillionths > scale ||
        yMillionths < 0 ||
        yMillionths > scale) {
      throw ArgumentError('Ink point must remain inside normalized bounds.');
    }
    if (pressurePermille < 0 || pressurePermille > 1000) {
      throw ArgumentError.value(pressurePermille, 'pressurePermille');
    }
  }

  static const scale = 1000000;

  final int xMillionths;
  final int yMillionths;
  final int pressurePermille;

  Map<String, Object?> toJson() => {
    'xMillionths': xMillionths,
    'yMillionths': yMillionths,
    'pressurePermille': pressurePermille,
  };

  factory ResourceInkPoint.fromJson(Map<String, Object?> json) =>
      ResourceInkPoint(
        xMillionths: json['xMillionths'] as int,
        yMillionths: json['yMillionths'] as int,
        pressurePermille: json['pressurePermille'] as int,
      );

  @override
  List<Object?> get props => [xMillionths, yMillionths, pressurePermille];
}

/// A bounded, platform-neutral ink stroke; no unvalidated path JSON is stored.
final class ResourceInkStroke extends Equatable {
  ResourceInkStroke({
    required this.id,
    required Iterable<ResourceInkPoint> points,
    required this.widthMillionths,
    required this.opacityPermille,
  }) : points = List<ResourceInkPoint>.unmodifiable(points) {
    _artifactId(id, 'id');
    if (this.points.length < 2 || this.points.length > maxPoints) {
      throw ArgumentError.value(
        this.points.length,
        'points',
        'A stroke requires 2–$maxPoints points.',
      );
    }
    if (widthMillionths < 1 || widthMillionths > 50000) {
      throw ArgumentError.value(widthMillionths, 'widthMillionths');
    }
    if (opacityPermille < 1 || opacityPermille > 1000) {
      throw ArgumentError.value(opacityPermille, 'opacityPermille');
    }
  }

  static const maxPoints = 2048;

  final String id;
  final List<ResourceInkPoint> points;
  final int widthMillionths;
  final int opacityPermille;

  Map<String, Object?> toJson() => {
    'id': id,
    'points': points.map((point) => point.toJson()).toList(),
    'widthMillionths': widthMillionths,
    'opacityPermille': opacityPermille,
  };

  factory ResourceInkStroke.fromJson(Map<String, Object?> json) =>
      ResourceInkStroke(
        id: json['id'] as String,
        points: _artifactList(json['points'], 'points').map(
          (value) => ResourceInkPoint.fromJson(_artifactMap(value, 'points[]')),
        ),
        widthMillionths: json['widthMillionths'] as int,
        opacityPermille: json['opacityPermille'] as int,
      );

  @override
  List<Object?> get props => [id, points, widthMillionths, opacityPermille];
}

/// A private learner annotation attached through one universal anchor.
///
/// Highlights carry no copied source body. Comments hold bounded private user
/// text. Ink uses normalized validated strokes. State changes are revisioned,
/// and delete is retained as a tombstone for future offline reconciliation.
final class ResourceAnnotation extends Equatable {
  ResourceAnnotation({
    required this.id,
    required this.anchorId,
    required this.kind,
    required this.color,
    required this.state,
    required this.revision,
    required DateTime createdAt,
    required DateTime updatedAt,
    required DateTime stateChangedAt,
    Iterable<String> tagIds = const [],
    Iterable<ResourceInkStroke> inkStrokes = const [],
    this.locale,
    this.body,
  }) : tagIds = _artifactTags(tagIds),
       inkStrokes = List<ResourceInkStroke>.unmodifiable(inkStrokes),
       createdAt = createdAt.toUtc(),
       updatedAt = updatedAt.toUtc(),
       stateChangedAt = stateChangedAt.toUtc() {
    _artifactId(id, 'id');
    _artifactId(anchorId, 'anchorId');
    if (!anchorId.startsWith('anchor.')) {
      throw ArgumentError.value(anchorId, 'anchorId', 'Expected an anchor ID.');
    }
    if (revision < 1) throw ArgumentError.value(revision, 'revision');
    if (this.updatedAt.isBefore(this.createdAt) ||
        this.stateChangedAt.isBefore(this.createdAt) ||
        this.stateChangedAt.isAfter(this.updatedAt)) {
      throw ArgumentError('Annotation timestamps are inconsistent.');
    }
    if (this.inkStrokes.length > maxInkStrokes) {
      throw ArgumentError.value(
        this.inkStrokes.length,
        'inkStrokes',
        'Maximum is $maxInkStrokes.',
      );
    }
    switch (kind) {
      case ResourceAnnotationKind.highlight:
        if (body != null || locale != null || this.inkStrokes.isNotEmpty) {
          throw ArgumentError('A highlight cannot carry comment or ink data.');
        }
      case ResourceAnnotationKind.comment:
        if (body == null || locale == null || this.inkStrokes.isNotEmpty) {
          throw ArgumentError('A comment requires locale and body only.');
        }
        _artifactBody(body!, 'body', maximum: maxCommentLength);
      case ResourceAnnotationKind.ink:
        if (body != null || locale != null || this.inkStrokes.isEmpty) {
          throw ArgumentError('An ink annotation requires strokes only.');
        }
    }
  }

  static const maxCommentLength = 20000;
  static const maxInkStrokes = 64;

  final ResourceAnnotationId id;
  final ResourceAnchorId anchorId;
  final ResourceAnnotationKind kind;
  final ResourceArtifactColor color;
  final ContentLocale? locale;
  final String? body;
  final List<ResourceInkStroke> inkStrokes;
  final List<String> tagIds;
  final ResourceAnnotationState state;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime stateChangedAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'anchorId': anchorId,
    'kind': _annotationKindCodec.encode(kind),
    'color': _artifactColorCodec.encode(color),
    'locale': locale?.name,
    'body': body,
    'inkStrokes': inkStrokes.map((stroke) => stroke.toJson()).toList(),
    'tagIds': tagIds,
    'state': _annotationStateCodec.encode(state),
    'revision': revision,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'stateChangedAt': stateChangedAt.toIso8601String(),
  };

  factory ResourceAnnotation.fromJson(Map<String, Object?> json) =>
      ResourceAnnotation(
        id: json['id'] as String,
        anchorId: json['anchorId'] as String,
        kind: _annotationKindCodec.decode(json['kind']),
        color: _artifactColorCodec.decode(json['color']),
        locale: json['locale'] == null
            ? null
            : ContentLocale.values.byName(json['locale'] as String),
        body: json['body'] as String?,
        inkStrokes: _artifactList(json['inkStrokes'], 'inkStrokes').map(
          (value) =>
              ResourceInkStroke.fromJson(_artifactMap(value, 'inkStrokes[]')),
        ),
        tagIds: _artifactList(json['tagIds'], 'tagIds').cast<String>(),
        state: _annotationStateCodec.decode(json['state']),
        revision: json['revision'] as int,
        createdAt: _artifactTime(json['createdAt'], 'createdAt'),
        updatedAt: _artifactTime(json['updatedAt'], 'updatedAt'),
        stateChangedAt: _artifactTime(json['stateChangedAt'], 'stateChangedAt'),
      );

  @override
  List<Object?> get props => [
    id,
    anchorId,
    kind,
    color,
    locale,
    body,
    inkStrokes,
    tagIds,
    state,
    revision,
    createdAt,
    updatedAt,
    stateChangedAt,
  ];
}

/// One idempotent bookmark per exact semantic anchor.
final class ResourceBookmark extends Equatable {
  ResourceBookmark({
    required this.id,
    required this.anchorId,
    required this.color,
    required this.isDeleted,
    required this.revision,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.label,
  }) : createdAt = createdAt.toUtc(),
       updatedAt = updatedAt.toUtc() {
    _artifactId(anchorId, 'anchorId');
    if (!anchorId.startsWith('anchor.')) {
      throw ArgumentError.value(anchorId, 'anchorId', 'Expected an anchor ID.');
    }
    if (id != stableIdForAnchor(anchorId)) {
      throw ArgumentError.value(id, 'id', 'Bookmark ID does not match anchor.');
    }
    if (label != null) {
      _artifactBody(label!, 'label', maximum: maxLabelLength);
    }
    if (revision < 1) throw ArgumentError.value(revision, 'revision');
    if (this.updatedAt.isBefore(this.createdAt)) {
      throw ArgumentError('updatedAt cannot precede createdAt.');
    }
  }

  static const maxLabelLength = 240;

  final ResourceBookmarkId id;
  final ResourceAnchorId anchorId;
  final String? label;
  final ResourceArtifactColor color;
  final bool isDeleted;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;

  static ResourceBookmarkId stableIdForAnchor(ResourceAnchorId anchorId) {
    _artifactId(anchorId, 'anchorId');
    return 'bookmark.${CanonicalJson.sha256Hex({'anchorId': anchorId})}';
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'anchorId': anchorId,
    'label': label,
    'color': _artifactColorCodec.encode(color),
    'isDeleted': isDeleted,
    'revision': revision,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory ResourceBookmark.fromJson(Map<String, Object?> json) =>
      ResourceBookmark(
        id: json['id'] as String,
        anchorId: json['anchorId'] as String,
        label: json['label'] as String?,
        color: _artifactColorCodec.decode(json['color']),
        isDeleted: json['isDeleted'] as bool,
        revision: json['revision'] as int,
        createdAt: _artifactTime(json['createdAt'], 'createdAt'),
        updatedAt: _artifactTime(json['updatedAt'], 'updatedAt'),
      );

  @override
  List<Object?> get props => [
    id,
    anchorId,
    label,
    color,
    isDeleted,
    revision,
    createdAt,
    updatedAt,
  ];
}

/// One deterministic, tombstone-safe relationship between product resources.
///
/// A document can support many lessons without changing blob ownership, and a
/// lesson can collect several references without embedding PDF-specific keys.
final class ResourceCrossReference extends Equatable {
  ResourceCrossReference({
    required this.id,
    required this.from,
    required this.to,
    required this.kind,
    required this.isDeleted,
    required this.revision,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : createdAt = createdAt.toUtc(),
       updatedAt = updatedAt.toUtc() {
    if (from == to) {
      throw ArgumentError('A resource cannot cross-reference itself.');
    }
    if (id != stableIdFor(from: from, to: to, kind: kind)) {
      throw ArgumentError.value(
        id,
        'id',
        'Cross-reference ID does not match its endpoints.',
      );
    }
    if (revision < 1) throw ArgumentError.value(revision, 'revision');
    if (this.updatedAt.isBefore(this.createdAt)) {
      throw ArgumentError('updatedAt cannot precede createdAt.');
    }
  }

  final ResourceCrossReferenceId id;
  final ResourceReference from;
  final ResourceReference to;
  final ResourceCrossReferenceKind kind;
  final bool isDeleted;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;

  static ResourceCrossReferenceId stableIdFor({
    required ResourceReference from,
    required ResourceReference to,
    required ResourceCrossReferenceKind kind,
  }) =>
      'crossref.${CanonicalJson.sha256Hex({'from': from.toJson(), 'to': to.toJson(), 'kind': _crossReferenceKindCodec.encode(kind)})}';

  Map<String, Object?> toJson() => {
    'id': id,
    'from': from.toJson(),
    'to': to.toJson(),
    'kind': _crossReferenceKindCodec.encode(kind),
    'isDeleted': isDeleted,
    'revision': revision,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory ResourceCrossReference.fromJson(Map<String, Object?> json) =>
      ResourceCrossReference(
        id: json['id'] as String,
        from: ResourceReference.fromJson(_artifactMap(json['from'], 'from')),
        to: ResourceReference.fromJson(_artifactMap(json['to'], 'to')),
        kind: _crossReferenceKindCodec.decode(json['kind']),
        isDeleted: json['isDeleted'] as bool,
        revision: json['revision'] as int,
        createdAt: _artifactTime(json['createdAt'], 'createdAt'),
        updatedAt: _artifactTime(json['updatedAt'], 'updatedAt'),
      );

  @override
  List<Object?> get props => [
    id,
    from,
    to,
    kind,
    isDeleted,
    revision,
    createdAt,
    updatedAt,
  ];
}

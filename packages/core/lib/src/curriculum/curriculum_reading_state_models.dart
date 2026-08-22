import 'package:equatable/equatable.dart';

import '../models/ids.dart';
import '../models/resource_reference_models.dart';
import 'curriculum_models.dart';

final _readingIdPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:/-]*$');

String _readingId(String value, String field) {
  if (value != value.trim() || !_readingIdPattern.hasMatch(value)) {
    throw ArgumentError.value(value, field, 'Invalid stable ID.');
  }
  return value;
}

DateTime _readingTime(Object? value, String field) {
  if (value is! String) {
    throw FormatException('$field must be an ISO-8601 timestamp.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('$field must be an ISO-8601 timestamp.');
  }
  return parsed.toUtc();
}

Map<String, Object?> _readingMap(Object? value, String field) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw FormatException('$field must be a JSON object.');
  }
  return Map<String, Object?>.from(value);
}

/// Stable identity for one package-authored Deep Study document's reading
/// position.
///
/// Release and locale are deliberately absent. A reviewed package update or
/// language switch can resume at the same semantic document and Block IDs;
/// the record separately retains the last release and locale as provenance.
final class CurriculumReadingPositionKey extends Equatable {
  CurriculumReadingPositionKey({
    required this.sourceId,
    required this.microLessonNodeId,
    required this.documentId,
  }) {
    _readingId(sourceId, 'sourceId');
    _readingId(microLessonNodeId, 'microLessonNodeId');
    _readingId(documentId, 'documentId');
  }

  final CurriculumSourceId sourceId;
  final CurriculumNodeId microLessonNodeId;
  final CurriculumStudyDocumentId documentId;

  CurriculumReadingPositionId get stableId =>
      '$sourceId|$microLessonNodeId|$documentId';

  Map<String, Object?> toJson() => {
    'sourceId': sourceId,
    'microLessonNodeId': microLessonNodeId,
    'documentId': documentId,
  };

  factory CurriculumReadingPositionKey.fromJson(Map<String, Object?> json) =>
      CurriculumReadingPositionKey(
        sourceId: json['sourceId'] as String,
        microLessonNodeId: json['microLessonNodeId'] as String,
        documentId: json['documentId'] as String,
      );

  @override
  List<Object?> get props => [sourceId, microLessonNodeId, documentId];
}

/// A local-first semantic resume anchor with no copied curriculum body.
///
/// [documentPositionPermille] is approximate navigation position, never a
/// completion, mastery, reward, or competence claim. [anchorUnitId] points to
/// an immutable localization-unit identity rather than storing source text.
final class CurriculumReadingPosition extends Equatable {
  CurriculumReadingPosition({
    required this.key,
    required this.lastReadReleaseId,
    required this.blockId,
    required this.blockOrdinal,
    required this.documentPositionPermille,
    required this.lastLocale,
    required this.revision,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.anchorUnitId,
  }) : createdAt = createdAt.toUtc(),
       updatedAt = updatedAt.toUtc() {
    _readingId(lastReadReleaseId, 'lastReadReleaseId');
    _readingId(blockId, 'blockId');
    if (anchorUnitId != null) {
      _readingId(anchorUnitId!, 'anchorUnitId');
    }
    if (blockOrdinal < 1) {
      throw ArgumentError.value(blockOrdinal, 'blockOrdinal');
    }
    if (documentPositionPermille < 0 || documentPositionPermille > 1000) {
      throw ArgumentError.value(
        documentPositionPermille,
        'documentPositionPermille',
      );
    }
    if (revision < 1) {
      throw ArgumentError.value(revision, 'revision');
    }
    if (this.updatedAt.isBefore(this.createdAt)) {
      throw ArgumentError('updatedAt cannot precede createdAt.');
    }
  }

  final CurriculumReadingPositionKey key;
  final CurriculumReleaseId lastReadReleaseId;
  final CurriculumStudyBlockId blockId;
  final int blockOrdinal;
  final CurriculumLocalizationUnitId? anchorUnitId;
  final int documentPositionPermille;
  final ContentLocale lastLocale;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;

  ResourceReference get resourceReference =>
      ResourceReference.curriculumStudyDocument(
        sourceId: key.sourceId,
        documentId: key.documentId,
      );

  CurriculumBlockResourceAnchor get resourceAnchor =>
      CurriculumBlockResourceAnchor(
        resource: resourceReference,
        blockId: blockId,
        blockOrdinal: blockOrdinal,
        localizationUnitId: anchorUnitId,
      );

  ResourceAnchorId get resourceAnchorId => resourceAnchor.stableId;

  Map<String, Object?> toJson() => {
    'key': key.toJson(),
    'lastReadReleaseId': lastReadReleaseId,
    'blockId': blockId,
    'blockOrdinal': blockOrdinal,
    'anchorUnitId': anchorUnitId,
    'documentPositionPermille': documentPositionPermille,
    'lastLocale': lastLocale.name,
    'revision': revision,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory CurriculumReadingPosition.fromJson(Map<String, Object?> json) =>
      CurriculumReadingPosition(
        key: CurriculumReadingPositionKey.fromJson(
          _readingMap(json['key'], 'key'),
        ),
        lastReadReleaseId: json['lastReadReleaseId'] as String,
        blockId: json['blockId'] as String,
        blockOrdinal: json['blockOrdinal'] as int,
        anchorUnitId: json['anchorUnitId'] as String?,
        documentPositionPermille: json['documentPositionPermille'] as int,
        lastLocale: ContentLocale.values.byName(json['lastLocale'] as String),
        revision: json['revision'] as int,
        createdAt: _readingTime(json['createdAt'], 'createdAt'),
        updatedAt: _readingTime(json['updatedAt'], 'updatedAt'),
      );

  @override
  List<Object?> get props => [
    key,
    lastReadReleaseId,
    blockId,
    blockOrdinal,
    anchorUnitId,
    documentPositionPermille,
    lastLocale,
    revision,
    createdAt,
    updatedAt,
  ];
}

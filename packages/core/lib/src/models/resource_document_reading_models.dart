import 'package:equatable/equatable.dart';

import '../serialization/canonical_json.dart';
import 'ids.dart';
import 'resource_reference_models.dart';

final _stableResourceIdPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:/-]*$');

/// Private, reward-neutral resume state for one immutable local document.
///
/// This record says only where the learner last read. It is deliberately not
/// mastery, completion, XP, a streak event, or evidence of clinical ability.
final class ResourceDocumentReadingPosition extends Equatable {
  ResourceDocumentReadingPosition({
    required this.id,
    required this.documentId,
    required this.documentContentSha256,
    required this.pageNumber,
    required this.pageCountAtSave,
    required this.pagePositionMillionths,
    required this.revision,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : createdAt = createdAt.toUtc(),
       updatedAt = updatedAt.toUtc() {
    if (documentId.length > 200 ||
        documentId != documentId.trim() ||
        !_stableResourceIdPattern.hasMatch(documentId)) {
      throw ArgumentError.value(documentId, 'documentId', 'Invalid ID.');
    }
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(documentContentSha256)) {
      throw ArgumentError.value(
        documentContentSha256,
        'documentContentSha256',
        'Expected a lowercase SHA-256 digest.',
      );
    }
    if (id != stableIdFor(documentId)) {
      throw ArgumentError.value(id, 'id', 'Reading-position ID mismatch.');
    }
    if (pageCountAtSave < 1 || pageNumber < 1 || pageNumber > pageCountAtSave) {
      throw ArgumentError('Page position is outside the document bounds.');
    }
    if (pagePositionMillionths < 0 || pagePositionMillionths > 1000000) {
      throw ArgumentError.value(
        pagePositionMillionths,
        'pagePositionMillionths',
      );
    }
    if (revision < 1) throw ArgumentError.value(revision, 'revision');
    if (this.updatedAt.isBefore(this.createdAt)) {
      throw ArgumentError('updatedAt cannot precede createdAt.');
    }
  }

  final ResourceDocumentReadingPositionId id;
  final ResourceDocumentId documentId;
  final String documentContentSha256;
  final int pageNumber;
  final int pageCountAtSave;
  final int pagePositionMillionths;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;

  ResourceReference get resource => ResourceReference.document(documentId);

  DocumentPageRangeResourceAnchor get resourceAnchor =>
      DocumentPageRangeResourceAnchor(
        resource: resource,
        startPage: pageNumber,
        endPage: pageNumber,
      );

  /// Position along the document, not a completion score.
  int get documentPositionPermille => pageCountAtSave == 1
      ? 0
      : (((pageNumber - 1) * 1000) / (pageCountAtSave - 1)).round();

  static ResourceDocumentReadingPositionId stableIdFor(
    ResourceDocumentId documentId,
  ) =>
      'document-reading.${CanonicalJson.sha256Hex({'documentId': documentId})}';

  Map<String, Object?> toJson() => {
    'id': id,
    'documentId': documentId,
    'documentContentSha256': documentContentSha256,
    'pageNumber': pageNumber,
    'pageCountAtSave': pageCountAtSave,
    'pagePositionMillionths': pagePositionMillionths,
    'revision': revision,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory ResourceDocumentReadingPosition.fromJson(Map<String, Object?> json) =>
      ResourceDocumentReadingPosition(
        id: json['id'] as String,
        documentId: json['documentId'] as String,
        documentContentSha256: json['documentContentSha256'] as String,
        pageNumber: json['pageNumber'] as int,
        pageCountAtSave: json['pageCountAtSave'] as int,
        pagePositionMillionths: json['pagePositionMillionths'] as int,
        revision: json['revision'] as int,
        createdAt: _readingTime(json['createdAt'], 'createdAt'),
        updatedAt: _readingTime(json['updatedAt'], 'updatedAt'),
      );

  @override
  List<Object?> get props => [
    id,
    documentId,
    documentContentSha256,
    pageNumber,
    pageCountAtSave,
    pagePositionMillionths,
    revision,
    createdAt,
    updatedAt,
  ];
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

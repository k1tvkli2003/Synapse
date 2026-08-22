import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_foundation/synapse_foundation.dart';

import '../workspace/resource_document_reading_state_repository.dart';
import 'encrypted_indexed_learner_record_store.dart';

/// Encrypted, record-oriented PDF resume state.
///
/// A clear document identity, content digest, reading position, and timestamp
/// never enter SQLite. Clear operations write authenticated tombstones so a
/// stale writer cannot silently resurrect a position.
final class IndexedResourceDocumentReadingStateRepository
    implements ResourceDocumentReadingStateRepository {
  IndexedResourceDocumentReadingStateRepository({
    required IndexedLearnerRecordStore records,
    required Clock clock,
  }) : this._(records, clock);

  IndexedResourceDocumentReadingStateRepository._(this._records, this._clock);

  static const namespace = 'resource.reading-position';
  static const kind = 'pdf-position';

  final IndexedLearnerRecordStore _records;
  final Clock _clock;

  @override
  Future<ResourceDocumentReadingPosition?> read(
    ResourceDocumentId documentId,
  ) => _guard(() async {
    final record = await _readRecord(documentId);
    return record == null || record.tombstone ? null : _position(record);
  });

  @override
  Future<List<ResourceDocumentReadingPosition>> listRecent() =>
      _guard(() async {
        final values =
            (await _records.exportNamespace(
                namespace,
              )).where((record) => !record.tombstone).map(_position).toList()
              ..sort((left, right) {
                final byTime = right.updatedAt.compareTo(left.updatedAt);
                return byTime != 0 ? byTime : right.id.compareTo(left.id);
              });
        return List.unmodifiable(values);
      });

  @override
  Future<ResourceDocumentReadingPosition> savePosition({
    required ResourceDocument document,
    required int pageNumber,
    required int pagePositionMillionths,
    required int? expectedRevision,
  }) => _guard(() async {
    if (document.mediaType != 'application/pdf' || document.pageCount == null) {
      throw const ResourceDocumentReadingStateException(
        'document_not_page_addressable',
        'Reading position requires immutable paged PDF metadata.',
      );
    }
    final record = await _readRecord(document.id);
    final existing = record == null || record.tombstone
        ? null
        : _position(record);
    if (existing != null &&
        existing.documentContentSha256 != document.contentSha256) {
      throw const ResourceDocumentReadingStateException(
        'document_identity_drift',
        'Document identity no longer matches the saved content digest.',
      );
    }
    if (existing != null &&
        existing.pageNumber == pageNumber &&
        existing.pagePositionMillionths == pagePositionMillionths &&
        existing.pageCountAtSave == document.pageCount) {
      return existing;
    }
    if (existing == null) {
      if (expectedRevision != null) {
        throw const ResourceDocumentReadingStateException(
          'stale_document_reading_position_revision',
          'The document reading position changed after this view opened.',
        );
      }
    } else if (existing.revision != expectedRevision) {
      throw const ResourceDocumentReadingStateException(
        'stale_document_reading_position_revision',
        'The document reading position changed after this view opened.',
      );
    }
    final now = _clock.nowUtc();
    final value = ResourceDocumentReadingPosition(
      id: ResourceDocumentReadingPosition.stableIdFor(document.id),
      documentId: document.id,
      documentContentSha256: document.contentSha256,
      pageNumber: pageNumber,
      pageCountAtSave: document.pageCount!,
      pagePositionMillionths: pagePositionMillionths,
      revision: (existing?.revision ?? 0) + 1,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    return _position(
      await _records.put(_draft(value), expectedRevision: record?.revision),
    );
  });

  @override
  Future<bool> clear({
    required ResourceDocumentId documentId,
    required int expectedRevision,
  }) => _guard(() async {
    final record = await _readRecord(documentId);
    if (record == null || record.tombstone) return false;
    final existing = _position(record);
    if (existing.revision != expectedRevision) {
      throw const ResourceDocumentReadingStateException(
        'stale_document_reading_position_revision',
        'The document reading position changed after this view opened.',
      );
    }
    await _records.put(
      PrivateLearnerRecordDraft(
        namespace: namespace,
        recordId: existing.id,
        scopeId: existing.documentId,
        kind: kind,
        updatedAt: _clock.nowUtc(),
        payload: existing.toJson(),
        tombstone: true,
      ),
      expectedRevision: record.revision,
    );
    return true;
  });

  @override
  Future<List<ResourceDocumentReadingStateIntegrityIssue>>
  auditIntegrity() async {
    final encryptedIssues = await _records.auditIntegrity();
    final readingStateEncryptedIssues = encryptedIssues.where(
      (issue) => issue.namespace == namespace,
    );
    if (readingStateEncryptedIssues.isNotEmpty) {
      return readingStateEncryptedIssues
          .map(
            (issue) => ResourceDocumentReadingStateIntegrityIssue(
              code: issue.code,
              message: issue.message,
            ),
          )
          .toList(growable: false);
    }
    try {
      for (final record in await _records.exportNamespace(namespace)) {
        final value = _position(record);
        if (record.recordId != value.id || record.scopeId != value.documentId) {
          throw const ResourceDocumentReadingStateException(
            'corrupt_indexed_document_reading_state',
            'Indexed document reading-state identity failed validation.',
          );
        }
      }
      return const [];
    } on ResourceDocumentReadingStateException catch (error) {
      return [
        ResourceDocumentReadingStateIntegrityIssue(
          code: error.code,
          message: error.message,
        ),
      ];
    } on LearnerDataPlaneException catch (error) {
      return [
        ResourceDocumentReadingStateIntegrityIssue(
          code: 'indexed_${error.code}',
          message: 'Private indexed reading-state validation failed.',
        ),
      ];
    } on Object {
      return const [
        ResourceDocumentReadingStateIntegrityIssue(
          code: 'corrupt_indexed_document_reading_state',
          message: 'Indexed document reading state failed schema validation.',
        ),
      ];
    }
  }

  Future<PrivateLearnerRecord?> _readRecord(ResourceDocumentId documentId) =>
      _records.read(
        namespace: namespace,
        recordId: ResourceDocumentReadingPosition.stableIdFor(documentId),
      );

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ResourceDocumentReadingStateException {
      rethrow;
    } on LearnerDataPlaneException catch (error) {
      throw ResourceDocumentReadingStateException(
        'indexed_${error.code}',
        'The private indexed document reading-state operation failed.',
        error,
      );
    } on Object catch (error) {
      throw ResourceDocumentReadingStateException(
        'corrupt_indexed_document_reading_state',
        'Indexed document reading state failed schema validation.',
        error,
      );
    }
  }
}

PrivateLearnerRecordDraft _draft(ResourceDocumentReadingPosition value) =>
    PrivateLearnerRecordDraft(
      namespace: IndexedResourceDocumentReadingStateRepository.namespace,
      recordId: value.id,
      scopeId: value.documentId,
      kind: IndexedResourceDocumentReadingStateRepository.kind,
      updatedAt: value.updatedAt,
      payload: value.toJson(),
    );

ResourceDocumentReadingPosition _position(PrivateLearnerRecord record) =>
    ResourceDocumentReadingPosition.fromJson(record.payload);

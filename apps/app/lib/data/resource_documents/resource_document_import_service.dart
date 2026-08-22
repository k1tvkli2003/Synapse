import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_foundation/synapse_foundation.dart';
import 'package:synapse_services/synapse_services.dart';

import 'resource_document_blob_store.dart';

final class ResourceDocumentImportResult {
  const ResourceDocumentImportResult({
    required this.document,
    required this.reusedExistingDocument,
    required this.reusedExistingBlob,
  });

  final ResourceDocument document;
  final bool reusedExistingDocument;
  final bool reusedExistingBlob;
}

/// Coordinates file selection, blob validation, deduplication, and metadata
/// publication without ever persisting an absolute source path.
final class ResourceDocumentImportService {
  const ResourceDocumentImportService({
    required this.blobs,
    required this.metadata,
    required this.clock,
    required this.ids,
  });

  final ResourceDocumentBlobStore blobs;
  final ResourceWorkspaceRepository metadata;
  final Clock clock;
  final IdSource ids;

  Future<ResourceDocumentImportResult?> pickAndImportPdf({
    ResourceReference? context,
  }) async {
    const typeGroup = XTypeGroup(
      label: 'PDF',
      extensions: ['pdf'],
      mimeTypes: ['application/pdf'],
      uniformTypeIdentifiers: ['com.adobe.pdf'],
      webWildCards: ['application/pdf'],
    );
    final selected = await openFile(
      acceptedTypeGroups: const [typeGroup],
      confirmButtonText: 'Import reference',
    );
    if (selected == null) return null;
    return importPdf(selected, context: context);
  }

  Future<ResourceDocumentImportResult> importPdf(
    XFile selected, {
    ResourceDocumentOrigin origin = ResourceDocumentOrigin.userImport,
    ResourceImportProvenance? importProvenance,
    ResourceReference? context,
  }) async {
    final receipt = await blobs.storePickedFile(selected);
    final existing = await metadata.findDocumentByDigest(receipt.contentSha256);
    if (existing != null) {
      if (existing.byteLength != receipt.byteLength) {
        throw const ResourceDocumentBlobException(
          'pdf_digest_length_mismatch',
          'Existing document metadata disagrees with the imported PDF.',
        );
      }
      await _attachIfRequested(context, existing);
      return ResourceDocumentImportResult(
        document: existing,
        reusedExistingDocument: true,
        reusedExistingBlob: true,
      );
    }
    final document = ResourceDocument(
      id: 'document.${ids.nextId()}',
      displayName: _safeDisplayName(selected.name),
      mediaType: 'application/pdf',
      contentSha256: receipt.contentSha256,
      byteLength: receipt.byteLength,
      pageCount: receipt.pageCount,
      origin: origin,
      createdAt: clock.nowUtc(),
      importProvenance: importProvenance,
    );
    final registered = await metadata.registerDocument(document);
    await _attachIfRequested(context, registered);
    return ResourceDocumentImportResult(
      document: registered,
      reusedExistingDocument: false,
      reusedExistingBlob: receipt.alreadyExisted,
    );
  }

  Future<void> _attachIfRequested(
    ResourceReference? context,
    ResourceDocument document,
  ) async {
    if (context == null) return;
    const kind = ResourceCrossReferenceKind.supportingDocument;
    final id = ResourceCrossReference.stableIdFor(
      from: context,
      to: document.reference,
      kind: kind,
    );
    final existing = await metadata.readCrossReference(
      id,
      includeDeleted: true,
    );
    await metadata.setCrossReference(
      from: context,
      to: document.reference,
      kind: kind,
      isLinked: true,
      expectedRevision: existing?.revision,
    );
  }

  static String _safeDisplayName(String value) {
    final basename = p
        .basename(value)
        .replaceAll(RegExp(r'[\u0000-\u001f\u007f]'), '_');
    final trimmed = basename.trim();
    final fallback = trimmed.isEmpty ? 'Imported reference.pdf' : trimmed;
    if (fallback.length <= 240) return fallback;
    final extension = p.extension(fallback);
    final keep = 240 - extension.length;
    return '${fallback.substring(0, keep)}$extension';
  }
}

import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:synapse_core/synapse_core.dart';

final class ResourceDocumentBlobException implements Exception {
  const ResourceDocumentBlobException(this.code, this.message, [this.cause]);

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'ResourceDocumentBlobException($code): $message';
}

/// Immutable receipt produced only after the selected PDF is validated and its
/// content-addressed blob is durable in the platform store.
final class ResourceDocumentBlobReceipt {
  const ResourceDocumentBlobReceipt({
    required this.contentSha256,
    required this.byteLength,
    required this.pageCount,
    required this.alreadyExisted,
  });

  final String contentSha256;
  final int byteLength;
  final int pageCount;
  final bool alreadyExisted;
}

/// Ephemeral viewer handle. File paths never enter domain metadata or logs.
sealed class ResourceDocumentSource {
  const ResourceDocumentSource({
    required this.contentSha256,
    required this.byteLength,
  });

  const factory ResourceDocumentSource.file({
    required String contentSha256,
    required int byteLength,
    required String filePath,
  }) = ResourceDocumentFileSource;

  const factory ResourceDocumentSource.bytes({
    required String contentSha256,
    required int byteLength,
    required Uint8List bytes,
  }) = ResourceDocumentBytesSource;

  final String contentSha256;
  final int byteLength;
}

final class ResourceDocumentFileSource extends ResourceDocumentSource {
  const ResourceDocumentFileSource({
    required super.contentSha256,
    required super.byteLength,
    required this.filePath,
  });

  final String filePath;
}

final class ResourceDocumentBytesSource extends ResourceDocumentSource {
  const ResourceDocumentBytesSource({
    required super.contentSha256,
    required super.byteLength,
    required this.bytes,
  });

  final Uint8List bytes;
}

final class ResourceDocumentBlobVerification {
  const ResourceDocumentBlobVerification._({
    required this.isValid,
    required this.code,
  });

  const ResourceDocumentBlobVerification.valid()
    : this._(isValid: true, code: 'valid');

  const ResourceDocumentBlobVerification.invalid(String code)
    : this._(isValid: false, code: code);

  final bool isValid;
  final String code;
}

abstract interface class ResourceDocumentBlobStore {
  Future<ResourceDocumentBlobReceipt> storePickedFile(XFile source);

  Future<ResourceDocumentSource?> resolve(ResourceDocument document);

  Future<ResourceDocumentBlobVerification> verify(ResourceDocument document);

  Future<void> close();
}

abstract final class ResourceDocumentBlobPolicy {
  static const maxByteLength = 512 * 1024 * 1024;
  static const _pdfHeader = [0x25, 0x50, 0x44, 0x46, 0x2d];

  static void validateLength(int byteLength) {
    if (byteLength < _pdfHeader.length) {
      throw const ResourceDocumentBlobException(
        'empty_or_truncated_pdf',
        'The selected file is empty or truncated.',
      );
    }
    if (byteLength > maxByteLength) {
      throw const ResourceDocumentBlobException(
        'pdf_size_limit',
        'The selected PDF exceeds the local import limit.',
      );
    }
  }

  static void validatePdfHeader(List<int> bytes) {
    if (bytes.length < _pdfHeader.length) {
      throw const ResourceDocumentBlobException(
        'empty_or_truncated_pdf',
        'The selected file is empty or truncated.',
      );
    }
    for (var index = 0; index < _pdfHeader.length; index++) {
      if (bytes[index] != _pdfHeader[index]) {
        throw const ResourceDocumentBlobException(
          'unsupported_document_type',
          'The selected file is not a PDF document.',
        );
      }
    }
  }
}

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:synapse_core/synapse_core.dart';

import 'resource_document_blob_store_base.dart';

ResourceDocumentBlobStore createResourceDocumentBlobStore() =>
    IoResourceDocumentBlobStore();

final class IoResourceDocumentBlobStore implements ResourceDocumentBlobStore {
  IoResourceDocumentBlobStore({
    Future<Directory> Function()? applicationSupportDirectory,
  }) : _applicationSupportDirectory =
           applicationSupportDirectory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _applicationSupportDirectory;

  @override
  Future<ResourceDocumentBlobReceipt> storePickedFile(XFile source) async {
    File? temporary;
    File? destination;
    var wroteNewBlob = false;
    try {
      final sourceFile = source.path.isEmpty ? null : File(source.path);
      final hasSourceFile = sourceFile != null && await sourceFile.exists();
      final byteLength = hasSourceFile
          ? await sourceFile.length()
          : await source.length();
      ResourceDocumentBlobPolicy.validateLength(byteLength);

      late String digest;
      Uint8List? sourceBytes;
      if (hasSourceFile) {
        ResourceDocumentBlobPolicy.validatePdfHeader(
          await _readHeader(sourceFile),
        );
        digest = await _fileDigest(sourceFile);
      } else {
        sourceBytes = await source.readAsBytes();
        ResourceDocumentBlobPolicy.validateLength(sourceBytes.length);
        ResourceDocumentBlobPolicy.validatePdfHeader(sourceBytes);
        digest = sha256.convert(sourceBytes).toString();
      }

      final root = await _blobRoot();
      final shard = Directory(p.join(root.path, digest.substring(0, 2)));
      await shard.create(recursive: true);
      destination = File(p.join(shard.path, '$digest.pdf'));
      var alreadyExisted = await destination.exists();
      if (alreadyExisted) {
        final verification = await _verifyFile(
          destination,
          expectedDigest: digest,
          expectedLength: byteLength,
        );
        if (!verification.isValid) {
          throw const ResourceDocumentBlobException(
            'stored_pdf_corrupt',
            'The existing local PDF blob failed integrity verification.',
          );
        }
      } else {
        temporary = File(
          p.join(
            shard.path,
            '.$digest.${DateTime.now().microsecondsSinceEpoch}.tmp',
          ),
        );
        if (hasSourceFile) {
          await sourceFile.copy(temporary.path);
        } else {
          await temporary.writeAsBytes(sourceBytes!, flush: true);
        }
        final verification = await _verifyFile(
          temporary,
          expectedDigest: digest,
          expectedLength: byteLength,
        );
        if (!verification.isValid) {
          throw const ResourceDocumentBlobException(
            'pdf_changed_during_import',
            'The selected PDF changed while it was being imported.',
          );
        }
        try {
          await temporary.rename(destination.path);
          wroteNewBlob = true;
          temporary = null;
        } on FileSystemException {
          if (!await destination.exists()) rethrow;
          await temporary!.delete();
          temporary = null;
          alreadyExisted = true;
        }
      }

      final pageCount = await _pageCountFromFile(destination);
      return ResourceDocumentBlobReceipt(
        contentSha256: digest,
        byteLength: byteLength,
        pageCount: pageCount,
        alreadyExisted: alreadyExisted,
      );
    } on ResourceDocumentBlobException {
      if (wroteNewBlob && destination != null && await destination.exists()) {
        await destination.delete();
      }
      rethrow;
    } on Object catch (error) {
      if (wroteNewBlob && destination != null && await destination.exists()) {
        await destination.delete();
      }
      throw ResourceDocumentBlobException(
        'pdf_import_failed',
        'The PDF could not be imported into local storage.',
        error,
      );
    } finally {
      if (temporary != null && await temporary.exists()) {
        await temporary.delete();
      }
    }
  }

  @override
  Future<ResourceDocumentSource?> resolve(ResourceDocument document) async {
    final file = await _fileForDigest(document.contentSha256);
    if (!await file.exists()) return null;
    final verification = await _verifyFile(
      file,
      expectedDigest: document.contentSha256,
      expectedLength: document.byteLength,
    );
    if (verification.code == 'length_mismatch') {
      throw const ResourceDocumentBlobException(
        'stored_pdf_length_mismatch',
        'The local PDF blob length does not match its metadata.',
      );
    }
    if (verification.code == 'header_mismatch') {
      throw const ResourceDocumentBlobException(
        'stored_pdf_header_mismatch',
        'The local PDF blob header does not match a PDF document.',
      );
    }
    if (!verification.isValid) {
      throw const ResourceDocumentBlobException(
        'stored_pdf_digest_mismatch',
        'The local PDF blob digest does not match its metadata.',
      );
    }
    return ResourceDocumentSource.file(
      contentSha256: document.contentSha256,
      byteLength: document.byteLength,
      filePath: file.path,
    );
  }

  @override
  Future<ResourceDocumentBlobVerification> verify(
    ResourceDocument document,
  ) async {
    final file = await _fileForDigest(document.contentSha256);
    if (!await file.exists()) {
      return const ResourceDocumentBlobVerification.invalid('blob_missing');
    }
    return _verifyFile(
      file,
      expectedDigest: document.contentSha256,
      expectedLength: document.byteLength,
    );
  }

  @override
  Future<void> close() async {}

  Future<Directory> _blobRoot() async {
    final support = await _applicationSupportDirectory();
    return Directory(
      p.join(support.path, 'synapse', 'resource_blobs', 'sha256'),
    );
  }

  Future<File> _fileForDigest(String digest) async {
    final root = await _blobRoot();
    return File(p.join(root.path, digest.substring(0, 2), '$digest.pdf'));
  }

  Future<ResourceDocumentBlobVerification> _verifyFile(
    File file, {
    required String expectedDigest,
    required int expectedLength,
  }) async {
    if (await file.length() != expectedLength) {
      return const ResourceDocumentBlobVerification.invalid('length_mismatch');
    }
    try {
      ResourceDocumentBlobPolicy.validatePdfHeader(await _readHeader(file));
    } on ResourceDocumentBlobException {
      return const ResourceDocumentBlobVerification.invalid('header_mismatch');
    }
    final digest = await _fileDigest(file);
    return digest == expectedDigest
        ? const ResourceDocumentBlobVerification.valid()
        : const ResourceDocumentBlobVerification.invalid('digest_mismatch');
  }

  Future<List<int>> _readHeader(File file) =>
      file.openRead(0, 5).expand((chunk) => chunk).take(5).toList();

  Future<String> _fileDigest(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  Future<int> _pageCountFromFile(File file) async {
    PdfDocument? document;
    try {
      document = await PdfDocument.openFile(file.path);
      final count = document.pages.length;
      if (count < 1) {
        throw const ResourceDocumentBlobException(
          'empty_pdf',
          'The selected PDF contains no readable pages.',
        );
      }
      return count;
    } on ResourceDocumentBlobException {
      rethrow;
    } on Object catch (error) {
      throw ResourceDocumentBlobException(
        'invalid_pdf',
        'The selected file could not be parsed as a PDF.',
        error,
      );
    } finally {
      await document?.dispose();
    }
  }
}

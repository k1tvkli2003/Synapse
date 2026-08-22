import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:idb_shim/idb_browser.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:synapse_core/synapse_core.dart';

import 'resource_document_blob_store_base.dart';

ResourceDocumentBlobStore createResourceDocumentBlobStore() =>
    WebResourceDocumentBlobStore();

final class WebResourceDocumentBlobStore implements ResourceDocumentBlobStore {
  WebResourceDocumentBlobStore() : _database = _openDatabase();

  static const _databaseName = 'synapse-resource-blobs';
  static const _storeName = 'pdf_blobs';
  static const _databaseVersion = 1;

  final Future<Database> _database;

  @override
  Future<ResourceDocumentBlobReceipt> storePickedFile(XFile source) async {
    final bytes = await source.readAsBytes();
    ResourceDocumentBlobPolicy.validateLength(bytes.length);
    ResourceDocumentBlobPolicy.validatePdfHeader(bytes);
    final digest = sha256.convert(bytes).toString();
    final pageCount = await _pageCountFromBytes(bytes);
    final database = await _database;
    final transaction = database.transaction(_storeName, idbModeReadWrite);
    final store = transaction.objectStore(_storeName);
    final prior = await store.getObject(digest);
    var alreadyExisted = false;
    if (prior != null) {
      alreadyExisted = true;
      final record = _record(prior);
      final priorBytes = _bytes(record['bytes']);
      if (record['byteLength'] != bytes.length ||
          sha256.convert(priorBytes).toString() != digest) {
        transaction.abort();
        throw const ResourceDocumentBlobException(
          'stored_pdf_corrupt',
          'The existing browser PDF blob failed integrity verification.',
        );
      }
    } else {
      await store.put({
        'schemaVersion': 1,
        'digest': digest,
        'byteLength': bytes.length,
        'bytes': bytes,
      }, digest);
    }
    await transaction.completed;
    return ResourceDocumentBlobReceipt(
      contentSha256: digest,
      byteLength: bytes.length,
      pageCount: pageCount,
      alreadyExisted: alreadyExisted,
    );
  }

  @override
  Future<ResourceDocumentSource?> resolve(ResourceDocument document) async {
    final record = await _readRecord(document.contentSha256);
    if (record == null) return null;
    final bytes = _bytes(record['bytes']);
    if (record['byteLength'] != document.byteLength ||
        bytes.length != document.byteLength) {
      throw const ResourceDocumentBlobException(
        'stored_pdf_length_mismatch',
        'The browser PDF blob length does not match its metadata.',
      );
    }
    ResourceDocumentBlobPolicy.validatePdfHeader(bytes);
    if (sha256.convert(bytes).toString() != document.contentSha256) {
      throw const ResourceDocumentBlobException(
        'stored_pdf_digest_mismatch',
        'The browser PDF blob digest does not match its metadata.',
      );
    }
    return ResourceDocumentSource.bytes(
      contentSha256: document.contentSha256,
      byteLength: bytes.length,
      bytes: bytes,
    );
  }

  @override
  Future<ResourceDocumentBlobVerification> verify(
    ResourceDocument document,
  ) async {
    final record = await _readRecord(document.contentSha256);
    if (record == null) {
      return const ResourceDocumentBlobVerification.invalid('blob_missing');
    }
    final bytes = _bytes(record['bytes']);
    if (record['byteLength'] != document.byteLength ||
        bytes.length != document.byteLength) {
      return const ResourceDocumentBlobVerification.invalid('length_mismatch');
    }
    try {
      ResourceDocumentBlobPolicy.validatePdfHeader(bytes);
    } on ResourceDocumentBlobException {
      return const ResourceDocumentBlobVerification.invalid('header_mismatch');
    }
    return sha256.convert(bytes).toString() == document.contentSha256
        ? const ResourceDocumentBlobVerification.valid()
        : const ResourceDocumentBlobVerification.invalid('digest_mismatch');
  }

  @override
  Future<void> close() async => (await _database).close();

  Future<Map<String, Object?>?> _readRecord(String digest) async {
    final database = await _database;
    final transaction = database.transaction(_storeName, idbModeReadOnly);
    final value = await transaction.objectStore(_storeName).getObject(digest);
    await transaction.completed;
    return value == null ? null : _record(value);
  }

  static Future<Database> _openDatabase() => idbFactoryBrowser.open(
    _databaseName,
    version: _databaseVersion,
    onUpgradeNeeded: (event) {
      if (!event.database.objectStoreNames.contains(_storeName)) {
        event.database.createObjectStore(_storeName);
      }
    },
  );

  static Map<String, Object?> _record(Object value) {
    if (value is! Map || value.keys.any((key) => key is! String)) {
      throw const ResourceDocumentBlobException(
        'stored_pdf_corrupt',
        'The browser PDF record has an invalid shape.',
      );
    }
    return Map<String, Object?>.from(value);
  }

  static Uint8List _bytes(Object? value) {
    if (value is Uint8List) return value;
    if (value is List) return Uint8List.fromList(value.cast<int>());
    throw const ResourceDocumentBlobException(
      'stored_pdf_corrupt',
      'The browser PDF record has no valid byte payload.',
    );
  }

  static Future<int> _pageCountFromBytes(Uint8List bytes) async {
    PdfDocument? document;
    try {
      document = await PdfDocument.openData(
        bytes,
        sourceName: 'content-addressed.pdf',
      );
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

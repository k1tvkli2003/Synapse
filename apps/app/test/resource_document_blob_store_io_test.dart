import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synapse_app/data/resource_documents/resource_document_blob_store.dart';
import 'package:synapse_core/synapse_core.dart';

void main() {
  late Directory sandbox;
  late Directory supportDirectory;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp(
      'synapse-resource-blob-store-',
    );
    supportDirectory = Directory(
      '${sandbox.path}${Platform.pathSeparator}application-support',
    );
  });

  tearDown(() async {
    if (await sandbox.exists()) {
      await sandbox.delete(recursive: true);
    }
  });

  test(
    'native PDF blobs are content-addressed, deduplicated, and resolved',
    () async {
      final bytes = _minimalPdfBytes();
      final digest = sha256.convert(bytes).toString();
      final sourceFile = File(
        '${sandbox.path}${Platform.pathSeparator}Cardiology reference.pdf',
      );
      await sourceFile.writeAsBytes(bytes, flush: true);
      final store = IoResourceDocumentBlobStore(
        applicationSupportDirectory: () async => supportDirectory,
      );
      addTearDown(store.close);

      final first = await store.storePickedFile(
        XFile(sourceFile.path, mimeType: 'application/pdf'),
      );
      final second = await store.storePickedFile(
        XFile(sourceFile.path, mimeType: 'application/pdf'),
      );

      expect(first.contentSha256, digest);
      expect(first.byteLength, bytes.length);
      expect(first.pageCount, 1);
      expect(first.alreadyExisted, isFalse);
      expect(second.contentSha256, first.contentSha256);
      expect(second.alreadyExisted, isTrue);

      final document = _document(first);
      final verification = await store.verify(document);
      expect(verification.isValid, isTrue);
      final source = await store.resolve(document);
      expect(source, isA<ResourceDocumentFileSource>());
      final resolved = source! as ResourceDocumentFileSource;
      expect(resolved.filePath, isNot(sourceFile.path));
      expect(resolved.filePath, contains(digest.substring(0, 2)));
      expect(resolved.filePath, endsWith('$digest.pdf'));
      expect(await File(resolved.filePath).readAsBytes(), bytes);
    },
  );

  test('native resolve refuses a same-length digest drift', () async {
    final bytes = _minimalPdfBytes();
    final sourceFile = File(
      '${sandbox.path}${Platform.pathSeparator}Evidence.pdf',
    );
    await sourceFile.writeAsBytes(bytes, flush: true);
    final store = IoResourceDocumentBlobStore(
      applicationSupportDirectory: () async => supportDirectory,
    );
    addTearDown(store.close);
    final receipt = await store.storePickedFile(XFile(sourceFile.path));
    final document = _document(receipt);
    final source = await store.resolve(document) as ResourceDocumentFileSource;
    final corrupted = Uint8List.fromList(bytes)..[bytes.length - 2] ^= 0x01;
    await File(source.filePath).writeAsBytes(corrupted, flush: true);

    final verification = await store.verify(document);

    expect(verification.isValid, isFalse);
    expect(verification.code, 'digest_mismatch');
    await expectLater(
      store.resolve(document),
      throwsA(
        isA<ResourceDocumentBlobException>()
            .having((error) => error.code, 'code', 'stored_pdf_digest_mismatch')
            .having(
              (error) => error.toString(),
              'privacy-safe error',
              isNot(contains(source.filePath)),
            ),
      ),
    );
  });
}

ResourceDocument _document(ResourceDocumentBlobReceipt receipt) =>
    ResourceDocument(
      id: 'document.${receipt.contentSha256.substring(0, 16)}',
      displayName: 'Cardiology reference.pdf',
      mediaType: 'application/pdf',
      contentSha256: receipt.contentSha256,
      byteLength: receipt.byteLength,
      pageCount: receipt.pageCount,
      origin: ResourceDocumentOrigin.userImport,
      createdAt: DateTime.utc(2026, 7, 22),
    );

Uint8List _minimalPdfBytes() {
  const stream = 'BT /F1 24 Tf 72 720 Td (Cardiology) Tj ET\n';
  final objects = <String>[
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    '<< /Length ${ascii.encode(stream).length} >>\nstream\n${stream}endstream',
  ];
  final buffer = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];
  for (var index = 0; index < objects.length; index++) {
    offsets.add(ascii.encode(buffer.toString()).length);
    buffer
      ..write('${index + 1} 0 obj\n')
      ..write(objects[index])
      ..write('\nendobj\n');
  }
  final xrefOffset = ascii.encode(buffer.toString()).length;
  buffer
    ..write('xref\n0 ${objects.length + 1}\n')
    ..write('0000000000 65535 f \n');
  for (final offset in offsets.skip(1)) {
    buffer.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  buffer
    ..write('trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n')
    ..write('startxref\n$xrefOffset\n%%EOF\n');
  return Uint8List.fromList(ascii.encode(buffer.toString()));
}

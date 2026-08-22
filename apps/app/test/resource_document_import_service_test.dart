import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synapse_app/data/resource_documents/resource_document_blob_store.dart';
import 'package:synapse_app/data/resource_documents/resource_document_import_service.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_foundation/synapse_foundation.dart';
import 'package:synapse_services/synapse_services.dart';

const _digest =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  test(
    'publishes validated content-addressed metadata and deduplicates',
    () async {
      final store = MemoryKeyValueStore();
      final clock = MutableClock(DateTime.utc(2026, 7, 22, 16));
      final metadata = LocalResourceWorkspaceRepository(
        store: store,
        clock: clock,
        idSource: SequenceIdSource(const ['unused.annotation']),
      );
      final blobs = _FakeBlobStore();
      final service = ResourceDocumentImportService(
        blobs: blobs,
        metadata: metadata,
        clock: clock,
        ids: SequenceIdSource(const ['import.001']),
      );
      final selected = XFile.fromData(
        Uint8List.fromList(const [0x25, 0x50, 0x44, 0x46, 0x2d]),
        name: 'Cardiology reference.pdf',
        mimeType: 'application/pdf',
      );
      final context = ResourceReference.curriculumNode(
        sourceId: 'source.harrison-sim',
        nodeId: 'node.micro.001',
      );

      final first = await service.importPdf(selected, context: context);
      final second = await service.importPdf(selected, context: context);

      expect(first.document.id, 'document.import.001');
      expect(first.document.contentAddress, 'sha256:$_digest');
      expect(first.document.pageCount, 42);
      expect(first.reusedExistingDocument, isFalse);
      expect(second.document, first.document);
      expect(second.reusedExistingDocument, isTrue);
      expect(blobs.storeCalls, 2);
      expect(await metadata.listDocuments(), [first.document]);
      final links = await metadata.listCrossReferencesFrom(
        context,
        kind: ResourceCrossReferenceKind.supportingDocument,
      );
      expect(links, hasLength(1));
      expect(links.single.to, first.document.reference);
      final wire = store.snapshot[LocalResourceWorkspaceRepository.stateKey]
          .toString();
      expect(wire, isNot(contains('base64')));
      expect(wire, isNot(contains(r'C:\Users')));
    },
  );

  test(
    'sanitizes control characters and bounds imported display name',
    () async {
      final metadata = LocalResourceWorkspaceRepository(
        store: MemoryKeyValueStore(),
        clock: MutableClock(DateTime.utc(2026, 7, 22, 16)),
        idSource: SequenceIdSource(const ['unused.annotation']),
      );
      final service = ResourceDocumentImportService(
        blobs: _FakeBlobStore(),
        metadata: metadata,
        clock: MutableClock(DateTime.utc(2026, 7, 22, 16)),
        ids: SequenceIdSource(const ['import.002']),
      );
      final selected = XFile.fromData(
        Uint8List(5),
        name: '${List.filled(250, 'A').join()}\n.pdf',
      );

      final result = await service.importPdf(selected);

      expect(result.document.displayName.length, lessThanOrEqualTo(240));
      expect(result.document.displayName, isNot(contains('\n')));
      expect(result.document.displayName, endsWith('.pdf'));
    },
  );
}

final class _FakeBlobStore implements ResourceDocumentBlobStore {
  int storeCalls = 0;

  @override
  Future<ResourceDocumentBlobReceipt> storePickedFile(XFile source) async {
    storeCalls++;
    return ResourceDocumentBlobReceipt(
      contentSha256: _digest,
      byteLength: 4096,
      pageCount: 42,
      alreadyExisted: storeCalls > 1,
    );
  }

  @override
  Future<ResourceDocumentSource?> resolve(ResourceDocument document) async =>
      null;

  @override
  Future<ResourceDocumentBlobVerification> verify(
    ResourceDocument document,
  ) async => const ResourceDocumentBlobVerification.valid();

  @override
  Future<void> close() async {}
}

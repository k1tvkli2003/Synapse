import 'package:synapse_core/synapse_core.dart';
import 'package:test/test.dart';

const _digestA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _digestB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

void main() {
  group('ResourceReference', () {
    test('round-trips every canonical resource family', () {
      final references = [
        ResourceReference.curriculumNode(
          sourceId: 'source.harrison-sim',
          nodeId: 'node.course.001',
        ),
        ResourceReference.curriculumStudyDocument(
          sourceId: 'source.harrison-sim',
          documentId: 'study.document.001',
        ),
        ResourceReference.document('document.001'),
        ResourceReference.clinicalCase('case.001'),
        ResourceReference.evidenceRecord('evidence.001'),
      ];

      for (final reference in references) {
        expect(ResourceReference.fromJson(reference.toJson()), reference);
        expect(reference.stableId, isNot(contains('localized title')));
      }
    });

    test('requires source scope only for curriculum resources', () {
      expect(
        () => ResourceReference(
          kind: ResourceReferenceKind.curriculumNode,
          resourceId: 'node.001',
        ),
        throwsArgumentError,
      );
      expect(
        () => ResourceReference(
          kind: ResourceReferenceKind.document,
          resourceId: 'document.001',
          scopeId: 'ambiguous.scope',
        ),
        throwsArgumentError,
      );
    });
  });

  group('ResourceDocument', () {
    test(
      'is content-addressed and retains migrated IDs as provenance only',
      () {
        final document = ResourceDocument(
          id: 'document.001',
          displayName: 'Cardiology reference.pdf',
          mediaType: 'application/pdf',
          contentSha256: _digestA,
          byteLength: 4096,
          pageCount: 12,
          origin: ResourceDocumentOrigin.migratedImport,
          createdAt: DateTime.utc(2026, 7, 22, 10),
          importProvenance: ResourceImportProvenance(
            sourceSystemId: 'legacy.study-workspace',
            sourceEntityKind: 'pdf',
            sourceRecordId: '42',
            sourceSchemaVersion: 17,
            sourceContentSha256: _digestA,
            importedAt: DateTime.utc(2026, 7, 22, 10),
          ),
        );

        expect(ResourceDocument.fromJson(document.toJson()), document);
        expect(document.contentAddress, 'sha256:$_digestA');
        expect(document.reference.stableId, 'document||document.001');
        expect(document.importProvenance!.sourceRecordId, '42');
        expect(document.id, isNot('42'));
        expect(document.toJson().toString(), isNot(contains('base64')));
        expect(document.toJson().toString(), isNot(contains(r'C:\Users')));
      },
    );

    test(
      'rejects missing migration provenance and malformed blob metadata',
      () {
        expect(
          () => ResourceDocument(
            id: 'document.001',
            displayName: 'Reference.pdf',
            mediaType: 'application/pdf',
            contentSha256: _digestA,
            byteLength: 1,
            origin: ResourceDocumentOrigin.migratedImport,
            createdAt: DateTime.utc(2026),
          ),
          throwsArgumentError,
        );
        expect(
          () => ResourceDocument(
            id: 'document.001',
            displayName: 'Reference.pdf',
            mediaType: 'Application/PDF',
            contentSha256: 'not-a-digest',
            byteLength: 0,
            origin: ResourceDocumentOrigin.userImport,
            createdAt: DateTime.utc(2026),
          ),
          throwsArgumentError,
        );
      },
    );
  });

  group('ResourceAnchor', () {
    test(
      'Block identity survives ordinal changes and verifies its wire ID',
      () {
        final resource = ResourceReference.curriculumStudyDocument(
          sourceId: 'source.harrison-sim',
          documentId: 'study.document.001',
        );
        final first = CurriculumBlockResourceAnchor(
          resource: resource,
          blockId: 'study.block.002',
          blockOrdinal: 2,
          localizationUnitId: 'l10n.study.body.002',
        );
        final reordered = CurriculumBlockResourceAnchor(
          resource: resource,
          blockId: 'study.block.002',
          blockOrdinal: 7,
          localizationUnitId: 'l10n.study.body.002',
        );

        expect(first.stableId, reordered.stableId);
        expect(ResourceAnchor.fromJson(first.toJson()), first);
        expect(first.toJson()['blockOrdinal'], 2);
      },
    );

    test('page range is typed, exact, and rejects reversed pages', () {
      final resource = ResourceReference.document('document.001');
      final anchor = DocumentPageRangeResourceAnchor(
        resource: resource,
        startPage: 3,
        endPage: 5,
      );

      expect(ResourceAnchor.fromJson(anchor.toJson()), anchor);
      expect(anchor.stableId, startsWith('anchor.'));
      expect(
        () => DocumentPageRangeResourceAnchor(
          resource: resource,
          startPage: 5,
          endPage: 3,
        ),
        throwsArgumentError,
      );
    });

    test('text range stores only offsets and a selected-text digest', () {
      final anchor = DocumentTextRangeResourceAnchor(
        resource: ResourceReference.document('document.001'),
        pageNumber: 4,
        startOffset: 120,
        endOffset: 168,
        selectedTextSha256: _digestB,
      );

      final wire = anchor.toJson();
      expect(ResourceAnchor.fromJson(wire), anchor);
      expect(wire.toString(), contains(_digestB));
      expect(wire.toString(), isNot(contains('selected medical source text')));
    });

    test('normalized region cannot escape the page', () {
      final anchor = DocumentRegionResourceAnchor(
        resource: ResourceReference.document('document.001'),
        pageNumber: 2,
        region: NormalizedResourceRegion(
          leftMillionths: 100000,
          topMillionths: 200000,
          widthMillionths: 300000,
          heightMillionths: 250000,
        ),
      );

      expect(ResourceAnchor.fromJson(anchor.toJson()), anchor);
      expect(
        () => NormalizedResourceRegion(
          leftMillionths: 900000,
          topMillionths: 0,
          widthMillionths: 200000,
          heightMillionths: 1,
        ),
        throwsArgumentError,
      );
    });

    test(
      'rejects an anchor whose payload no longer matches its derived ID',
      () {
        final anchor = DocumentPageRangeResourceAnchor(
          resource: ResourceReference.document('document.001'),
          startPage: 1,
          endPage: 1,
        );
        final tampered = Map<String, Object?>.from(anchor.toJson());
        final target = Map<String, Object?>.from(tampered['target']! as Map);
        target['endPage'] = 2;
        tampered['target'] = target;

        expect(() => ResourceAnchor.fromJson(tampered), throwsFormatException);
      },
    );
  });
}

import 'package:synapse_core/synapse_core.dart';
import 'package:test/test.dart';

const _digest =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  test('document reading position round-trips with a semantic page anchor', () {
    final position = ResourceDocumentReadingPosition(
      id: ResourceDocumentReadingPosition.stableIdFor('document.cardiology'),
      documentId: 'document.cardiology',
      documentContentSha256: _digest,
      pageNumber: 25,
      pageCountAtSave: 100,
      pagePositionMillionths: 125000,
      revision: 2,
      createdAt: DateTime.utc(2026, 7, 22, 10),
      updatedAt: DateTime.utc(2026, 7, 22, 11),
    );

    final restored = ResourceDocumentReadingPosition.fromJson(
      position.toJson(),
    );

    expect(restored, position);
    expect(restored.resourceAnchor.startPage, 25);
    expect(restored.resourceAnchor.endPage, 25);
    expect(restored.documentPositionPermille, 242);
  });

  test('document reading position rejects pages outside immutable bounds', () {
    expect(
      () => ResourceDocumentReadingPosition(
        id: ResourceDocumentReadingPosition.stableIdFor('document.invalid'),
        documentId: 'document.invalid',
        documentContentSha256: _digest,
        pageNumber: 8,
        pageCountAtSave: 7,
        pagePositionMillionths: 0,
        revision: 1,
        createdAt: DateTime.utc(2026, 7, 22),
        updatedAt: DateTime.utc(2026, 7, 22),
      ),
      throwsArgumentError,
    );
  });
}

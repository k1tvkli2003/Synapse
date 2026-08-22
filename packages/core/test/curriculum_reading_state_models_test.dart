import 'package:synapse_core/synapse_core.dart';
import 'package:test/test.dart';

void main() {
  test('semantic reading position round-trips without lesson body text', () {
    final position = _position();

    expect(CurriculumReadingPosition.fromJson(position.toJson()), position);
    expect(position.key.stableId, 'source.1|node.micro.1|study.document.1');
    expect(position.resourceAnchorId, startsWith('anchor.'));
    expect(position.resourceAnchor.resource, position.resourceReference);
    expect(
      ResourceAnchor.fromJson(position.resourceAnchor.toJson()),
      position.resourceAnchor,
    );
    expect(position.toJson().toString(), isNot(contains('lesson body')));
  });

  test('release and locale remain provenance rather than record identity', () {
    final first = _position();
    final next = _position(releaseId: 'release.2', locale: ContentLocale.fa);

    expect(first.key, next.key);
    expect(first.lastReadReleaseId, isNot(next.lastReadReleaseId));
    expect(first.lastLocale, isNot(next.lastLocale));
  });

  test('rejects invalid ordinal, approximate position, and anchor IDs', () {
    expect(() => _position(blockOrdinal: 0), throwsArgumentError);
    expect(() => _position(positionPermille: 1001), throwsArgumentError);
    expect(() => _position(anchorUnitId: ' copied text '), throwsArgumentError);
  });
}

CurriculumReadingPosition _position({
  String releaseId = 'release.1',
  int blockOrdinal = 2,
  int positionPermille = 500,
  String? anchorUnitId = 'l10n.study.body.2',
  ContentLocale locale = ContentLocale.en,
}) => CurriculumReadingPosition(
  key: CurriculumReadingPositionKey(
    sourceId: 'source.1',
    microLessonNodeId: 'node.micro.1',
    documentId: 'study.document.1',
  ),
  lastReadReleaseId: releaseId,
  blockId: 'study.block.2',
  blockOrdinal: blockOrdinal,
  anchorUnitId: anchorUnitId,
  documentPositionPermille: positionPermille,
  lastLocale: locale,
  revision: 1,
  createdAt: DateTime.utc(2026, 7, 18, 12),
  updatedAt: DateTime.utc(2026, 7, 18, 12, 1),
);

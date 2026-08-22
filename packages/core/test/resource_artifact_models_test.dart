import 'package:synapse_core/synapse_core.dart';
import 'package:test/test.dart';

void main() {
  final anchorId = DocumentTextRangeResourceAnchor(
    resource: ResourceReference.document('document.001'),
    pageNumber: 2,
    startOffset: 10,
    endOffset: 30,
    selectedTextSha256:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  ).stableId;
  final createdAt = DateTime.utc(2026, 7, 22, 12);

  test('comment round-trips as bounded private learner text', () {
    final annotation = ResourceAnnotation(
      id: 'annotation.001',
      anchorId: anchorId,
      kind: ResourceAnnotationKind.comment,
      color: ResourceArtifactColor.cyan,
      locale: ContentLocale.fa,
      body: 'این بخش را با مکانیسم قبلی مقایسه کنم.',
      state: ResourceAnnotationState.active,
      revision: 1,
      createdAt: createdAt,
      updatedAt: createdAt,
      stateChangedAt: createdAt,
      tagIds: const ['tag.compare'],
    );

    expect(ResourceAnnotation.fromJson(annotation.toJson()), annotation);
    expect(annotation.anchorId, anchorId);
  });

  test('highlight cannot smuggle comment or ink payloads', () {
    expect(
      () => ResourceAnnotation(
        id: 'annotation.001',
        anchorId: anchorId,
        kind: ResourceAnnotationKind.highlight,
        color: ResourceArtifactColor.gold,
        locale: ContentLocale.en,
        body: 'copied source body',
        state: ResourceAnnotationState.active,
        revision: 1,
        createdAt: createdAt,
        updatedAt: createdAt,
        stateChangedAt: createdAt,
      ),
      throwsArgumentError,
    );
  });

  test('ink uses bounded normalized points instead of raw path JSON', () {
    final stroke = ResourceInkStroke(
      id: 'stroke.001',
      points: [
        ResourceInkPoint(
          xMillionths: 0,
          yMillionths: 100000,
          pressurePermille: 400,
        ),
        ResourceInkPoint(
          xMillionths: 800000,
          yMillionths: 900000,
          pressurePermille: 700,
        ),
      ],
      widthMillionths: 12000,
      opacityPermille: 850,
    );
    final annotation = ResourceAnnotation(
      id: 'annotation.ink.001',
      anchorId: anchorId,
      kind: ResourceAnnotationKind.ink,
      color: ResourceArtifactColor.coral,
      inkStrokes: [stroke],
      state: ResourceAnnotationState.active,
      revision: 1,
      createdAt: createdAt,
      updatedAt: createdAt,
      stateChangedAt: createdAt,
    );

    expect(ResourceAnnotation.fromJson(annotation.toJson()), annotation);
    expect(annotation.toJson().toString(), isNot(contains('pathDataJson')));
    expect(
      () => ResourceInkPoint(
        xMillionths: 1000001,
        yMillionths: 0,
        pressurePermille: 1,
      ),
      throwsArgumentError,
    );
  });

  test(
    'annotation lifecycle keeps state-change time inside revision bounds',
    () {
      expect(
        () => ResourceAnnotation(
          id: 'annotation.001',
          anchorId: anchorId,
          kind: ResourceAnnotationKind.highlight,
          color: ResourceArtifactColor.gold,
          state: ResourceAnnotationState.resolved,
          revision: 2,
          createdAt: createdAt,
          updatedAt: createdAt.add(const Duration(minutes: 1)),
          stateChangedAt: createdAt.add(const Duration(minutes: 2)),
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'bookmark identity is deterministic per exact anchor and tombstone-safe',
    () {
      final id = ResourceBookmark.stableIdForAnchor(anchorId);
      final bookmark = ResourceBookmark(
        id: id,
        anchorId: anchorId,
        label: 'Revisit before rounds',
        color: ResourceArtifactColor.gold,
        isDeleted: false,
        revision: 1,
        createdAt: createdAt,
        updatedAt: createdAt,
      );

      expect(ResourceBookmark.fromJson(bookmark.toJson()), bookmark);
      expect(id, startsWith('bookmark.'));
      expect(
        () => ResourceBookmark(
          id: 'bookmark.wrong',
          anchorId: anchorId,
          color: ResourceArtifactColor.gold,
          isDeleted: false,
          revision: 1,
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
        throwsArgumentError,
      );
    },
  );

  test('cross-reference identity is deterministic and label-independent', () {
    final from = ResourceReference.curriculumNode(
      sourceId: 'source.harrison-sim',
      nodeId: 'node.micro.001',
    );
    final to = ResourceReference.document('document.001');
    final id = ResourceCrossReference.stableIdFor(
      from: from,
      to: to,
      kind: ResourceCrossReferenceKind.supportingDocument,
    );
    final reference = ResourceCrossReference(
      id: id,
      from: from,
      to: to,
      kind: ResourceCrossReferenceKind.supportingDocument,
      isDeleted: false,
      revision: 1,
      createdAt: createdAt,
      updatedAt: createdAt,
    );

    expect(ResourceCrossReference.fromJson(reference.toJson()), reference);
    expect(id, startsWith('crossref.'));
    expect(
      () => ResourceCrossReference(
        id: id,
        from: from,
        to: from,
        kind: ResourceCrossReferenceKind.relatedContext,
        isDeleted: false,
        revision: 1,
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
      throwsArgumentError,
    );
  });
}

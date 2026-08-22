import 'package:synapse_core/synapse_core.dart';
import 'package:test/test.dart';

void main() {
  group('curriculum identity', () {
    test('uses the frozen UUIDv5 namespace and ordinal source keys', () {
      expect(
        CurriculumIdentity.fromSourceKey('harrison-sim/course/06'),
        'df2c932e-1c79-515c-996d-804d502683a1',
      );
      expect(
        CurriculumIdentity.fromSourceKey('harrison-sim/course/06/chapter/001'),
        '27f49ef2-8b4a-545b-93dd-bbb668d0ffe4',
      );
      expect(
        CurriculumIdentity.fromSourceKey(
          'harrison-sim/course/06/chapter/001/unit/001',
        ),
        'dd37dc45-e99c-5e37-9a2c-91ea14bcead1',
      );
    });

    test('rejects title, locale, and path-shaped identity inputs', () {
      for (final invalid in [
        'Cardiology',
        'harrison-sim/course/06/fa',
        r'C:\Users\K1\Desktop\Harrison',
        '../course/06',
      ]) {
        expect(
          () => CurriculumIdentity.fromSourceKey(invalid),
          throwsArgumentError,
        );
      }
    });
  });

  group('source and immutable release contracts', () {
    test('round-trip without a distributable local root', () {
      final source = CurriculumSource(
        id: 'source.harrison-sim',
        sourceKey: 'harrison-sim',
        classification: 'user-provided-simulated-medical-reference',
        sourceTreeSha256: 'a' * 64,
        scanManifestId: 'scan.harrison-sim.full.v1',
        priorityCourseSourceKey: 'harrison-sim/course/06',
      );
      final release = CurriculumRelease(
        id: 'release.internal.2026-07-17.1',
        sourceId: source.id,
        version: '2026.07.17+1',
        channel: CurriculumReleaseChannel.internal,
        contractVersion: 1,
        authoringProtocolVersion: 'synapse-microlearning-v1',
        sourceTreeSha256: source.sourceTreeSha256,
        contentState: ContentLifecycleState.validated,
        createdAt: DateTime.utc(2026, 7, 17, 12),
        generatorRunIds: const ['generator.scan.001'],
      );

      expect(source.toJson(), isNot(contains('localRoot')));
      expect(CurriculumSource.fromJson(source.toJson()), source);
      expect(CurriculumRelease.fromJson(release.toJson()), release);
      expect(release.isLearnerVisible, isFalse);
    });

    test('unknown release wire states fail explicitly', () {
      final json = CurriculumRelease(
        id: 'release.internal.001',
        sourceId: 'source.harrison-sim',
        version: '1',
        channel: CurriculumReleaseChannel.internal,
        contractVersion: 1,
        authoringProtocolVersion: 'v1',
        sourceTreeSha256: 'b' * 64,
        contentState: ContentLifecycleState.raw,
        createdAt: DateTime.utc(2026),
      ).toJson();
      json['contentState'] = 'ready-ish';

      expect(
        () => CurriculumRelease.fromJson(json),
        throwsA(
          isA<SerializationException>().having(
            (error) => error.code,
            'code',
            SerializationIssueCode.unknownWireValue,
          ),
        ),
      );
    });
  });

  group('fine-grained curriculum hierarchy', () {
    test('validates Course to Micro-lesson parent kinds and ordinals', () {
      final nodes = _validTreeNodes();
      final tree = CurriculumTree(nodes);

      expect(tree.childrenOf(null), [nodes[0]]);
      expect(tree.childrenOf(nodes[1].id), [nodes[2]]);
      expect(nodes.last.isPlayable, isTrue);
      expect(CurriculumNode.fromJson(nodes.last.toJson()), nodes.last);
    });

    test('source anchors cannot appear as a learner-facing node kind', () {
      expect(
        CurriculumNodeKind.values.map((value) => value.name),
        isNot(contains('sourceLesson')),
      );
    });

    test('rejects invalid parent kinds and duplicate sibling ordinals', () {
      final nodes = _validTreeNodes();
      final wrongParent = CurriculumNode.fromSourceKey(
        sourceKey: 'harrison-sim/course/06/chapter/001/unit/002',
        parentId: nodes[0].id,
        kind: CurriculumNodeKind.unit,
        ordinal: 2,
        identityState: CurriculumIdentityState.approved,
        titleUnitId: 'l10n.unit.002.title',
      );
      expect(
        () => CurriculumTree([...nodes, wrongParent]),
        throwsA(
          isA<CurriculumInvariantException>().having(
            (error) => error.code,
            'code',
            'invalid_parent_kind',
          ),
        ),
      );

      final duplicate = CurriculumNode.fromSourceKey(
        sourceKey: 'harrison-sim/course/06/chapter/001/unit/002',
        parentId: nodes[1].id,
        kind: CurriculumNodeKind.unit,
        ordinal: 1,
        identityState: CurriculumIdentityState.candidate,
        titleUnitId: 'l10n.unit.002.title',
      );
      expect(
        () => CurriculumTree([...nodes, duplicate]),
        throwsA(
          isA<CurriculumInvariantException>().having(
            (error) => error.code,
            'code',
            'duplicate_sibling_ordinal',
          ),
        ),
      );
    });
  });

  group('atomic English and Persian localization pairs', () {
    test('publishes only independently reviewed EN and FA variants', () {
      final reviewedAt = DateTime.utc(2026, 7, 17, 13);
      final en = LocalizedVariant.authored(
        locale: ContentLocale.en,
        text: 'Recognize the mechanism before choosing an answer.',
        status: LocalizedVariantStatus.approved,
        authorId: 'author.en.001',
        reviewerId: 'reviewer.en.001',
        reviewedAt: reviewedAt,
      );
      final fa = LocalizedVariant.authored(
        locale: ContentLocale.fa,
        text: 'پیش از انتخاب پاسخ، سازوکار را تشخیص بدهید.',
        status: LocalizedVariantStatus.approved,
        authorId: 'author.fa.001',
        reviewerId: 'reviewer.fa.001',
        reviewedAt: reviewedAt,
      );
      final unit = CurriculumLocalizationUnit(
        id: 'l10n.objective.001',
        semanticRole: ContentSemanticRole.objective,
        semanticSkeletonSha256: 'c' * 64,
        claimIds: const ['claim.001'],
        sourceAtomIds: const ['source.atom.001'],
        conceptIds: const ['concept.001'],
        en: en,
        fa: fa,
        pairState: LocalizationPairState.publishable,
      );

      expect(unit.variant(ContentLocale.en).direction, ContentDirection.ltr);
      expect(unit.variant(ContentLocale.fa).direction, ContentDirection.rtl);
      expect(unit.isPublishable, isTrue);
      expect(CurriculumLocalizationUnit.fromJson(unit.toJson()), unit);
    });

    test(
      'rejects tampered hashes, self-review, and incomplete publishable pairs',
      () {
        expect(
          () => LocalizedVariant(
            locale: ContentLocale.en,
            direction: ContentDirection.ltr,
            text: 'Text',
            textSha256: '0' * 64,
            status: LocalizedVariantStatus.authored,
            authorId: 'author.001',
          ),
          throwsArgumentError,
        );
        expect(
          () => LocalizedVariant.authored(
            locale: ContentLocale.en,
            text: 'Text',
            status: LocalizedVariantStatus.approved,
            authorId: 'author.001',
            reviewerId: 'author.001',
            reviewedAt: DateTime.utc(2026),
          ),
          throwsArgumentError,
        );

        final en = LocalizedVariant.authored(
          locale: ContentLocale.en,
          text: 'Draft English',
          status: LocalizedVariantStatus.authored,
          authorId: 'author.en.001',
        );
        final fa = LocalizedVariant.authored(
          locale: ContentLocale.fa,
          text: 'پیش‌نویس فارسی',
          status: LocalizedVariantStatus.authored,
          authorId: 'author.fa.001',
        );
        expect(
          () => CurriculumLocalizationUnit(
            id: 'l10n.draft.001',
            semanticRole: ContentSemanticRole.explanation,
            semanticSkeletonSha256: 'd' * 64,
            en: en,
            fa: fa,
            pairState: LocalizationPairState.publishable,
          ),
          throwsArgumentError,
        );
      },
    );
  });

  test('locale duration rejects non-positive estimates', () {
    expect(
      () => LocaleDuration(enSeconds: 0, faSeconds: 120),
      throwsArgumentError,
    );
  });
}

List<CurriculumNode> _validTreeNodes() {
  final course = CurriculumNode.fromSourceKey(
    sourceKey: 'harrison-sim/course/06',
    kind: CurriculumNodeKind.course,
    ordinal: 6,
    identityState: CurriculumIdentityState.approved,
    titleUnitId: 'l10n.course.06.title',
    sourceContainerKeys: const ['harrison-sim/course/06'],
  );
  final chapter = CurriculumNode.fromSourceKey(
    sourceKey: 'harrison-sim/course/06/chapter/001',
    parentId: course.id,
    kind: CurriculumNodeKind.chapter,
    ordinal: 1,
    identityState: CurriculumIdentityState.approved,
    titleUnitId: 'l10n.chapter.001.title',
    sourceContainerKeys: const ['harrison-sim/course/06/chapter/001'],
  );
  final unit = CurriculumNode.fromSourceKey(
    sourceKey: 'harrison-sim/course/06/chapter/001/unit/001',
    parentId: chapter.id,
    kind: CurriculumNodeKind.unit,
    ordinal: 1,
    identityState: CurriculumIdentityState.approved,
    titleUnitId: 'l10n.unit.001.title',
  );
  final cluster = CurriculumNode.fromSourceKey(
    sourceKey:
        'harrison-sim/course/06/chapter/001/unit/001/concept-cluster/001',
    parentId: unit.id,
    kind: CurriculumNodeKind.conceptCluster,
    ordinal: 1,
    identityState: CurriculumIdentityState.approved,
    titleUnitId: 'l10n.cluster.001.title',
    conceptIds: const ['concept.cardiology.orientation'],
  );
  final microLesson = CurriculumNode.fromSourceKey(
    sourceKey:
        'harrison-sim/course/06/chapter/001/unit/001/concept-cluster/001/micro-lesson/001',
    parentId: cluster.id,
    kind: CurriculumNodeKind.microLesson,
    ordinal: 1,
    identityState: CurriculumIdentityState.approved,
    titleUnitId: 'l10n.micro-lesson.001.title',
    conceptIds: const ['concept.cardiology.orientation'],
  );
  return [course, chapter, unit, cluster, microLesson];
}

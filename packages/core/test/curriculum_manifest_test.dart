import 'dart:convert';

import 'package:synapse_core/synapse_core.dart';
import 'package:test/test.dart';

void main() {
  group('canonical JSON', () {
    test('sorts object keys recursively while preserving list order', () {
      final first = <String, Object?>{
        'z': [
          {'b': 2, 'a': 1},
          'second',
        ],
        'a': {'d': true, 'c': null},
      };
      final second = <String, Object?>{
        'a': {'c': null, 'd': true},
        'z': [
          {'a': 1, 'b': 2},
          'second',
        ],
      };

      expect(CanonicalJson.encode(first), CanonicalJson.encode(second));
      expect(CanonicalJson.sha256Hex(first), CanonicalJson.sha256Hex(second));
      expect(
        CanonicalJson.encode(first),
        '{"a":{"c":null,"d":true},"z":[{"a":1,"b":2},"second"]}',
      );
    });

    test('rejects non-finite numbers, non-string keys, and objects', () {
      expect(() => CanonicalJson.encode(double.nan), throwsArgumentError);
      expect(
        () => CanonicalJson.encode(<Object, Object>{1: 'invalid'}),
        throwsArgumentError,
      );
      expect(
        () => CanonicalJson.encode(DateTime.utc(2026)),
        throwsArgumentError,
      );
    });
  });

  group('curriculum manifest', () {
    test('round-trips an internal scaffold with a deterministic receipt', () {
      final manifest = _manifest();
      final encoded = CanonicalJson.encode(manifest.toJson());
      final restored = CurriculumManifest.fromJson(
        Map<String, dynamic>.from(jsonDecode(encoded) as Map),
      );

      expect(restored, manifest);
      expect(restored.isScaffold, isTrue);
      expect(restored.canonicalSha256, manifest.canonicalSha256);
      expect(restored.canonicalSha256, hasLength(64));
      expect(
        manifest.toJson()['schemaVersion'],
        CurriculumManifest.schemaVersion,
      );
    });

    test(
      'reads and re-emits schema v1 without inventing Deep Study fields',
      () {
        final source = _source();
        final legacy = CurriculumManifest(
          manifestSchemaVersion: CurriculumManifest.legacySchemaVersion,
          source: source,
          release: _release(source),
          nodes: [_courseNode()],
          localizationUnits: [_approvedTitle()],
        );
        final json = legacy.toJson();
        final restored = CurriculumManifest.fromJson(
          Map<String, dynamic>.from(json),
        );

        expect(restored, legacy);
        expect(json['schemaVersion'], CurriculumManifest.legacySchemaVersion);
        expect(json, isNot(contains('studyDocuments')));
        expect(json, isNot(contains('studyBlocks')));
        expect(restored.toJson(), json);
      },
    );

    test('does not silently ignore Deep Study fields inside schema v1', () {
      final json = _manifest().toJson()
        ..['schemaVersion'] = CurriculumManifest.legacySchemaVersion
        ..['studyDocuments'] = <Object>[];

      expect(
        () => CurriculumManifest.fromJson(json),
        throwsA(
          isA<CurriculumManifestException>().having(
            (error) => error.code,
            'code',
            'legacy_schema_study_body',
          ),
        ),
      );
    });

    test('rejects unsupported schemas and source/release hash drift', () {
      final json = _manifest().toJson();
      json['schemaVersion'] = 999;
      expect(
        () => CurriculumManifest.fromJson(json),
        throwsA(
          isA<CurriculumManifestException>().having(
            (error) => error.code,
            'code',
            'unsupported_schema',
          ),
        ),
      );

      final source = _source();
      expect(
        () => CurriculumManifest(
          source: source,
          release: _release(source, sourceTreeSha256: 'f' * 64),
          nodes: const [],
        ),
        throwsA(
          isA<CurriculumManifestException>().having(
            (error) => error.code,
            'code',
            'source_hash_mismatch',
          ),
        ),
      );
    });

    test('rejects missing localization references', () {
      final source = _source();
      expect(
        () => CurriculumManifest(
          source: source,
          release: _release(source),
          nodes: [_courseNode()],
        ),
        throwsA(
          isA<CurriculumManifestException>().having(
            (error) => error.code,
            'code',
            'missing_localization',
          ),
        ),
      );
    });

    test('refuses to publish a body-free scaffold', () {
      final source = _source();
      expect(
        () => CurriculumManifest(
          source: source,
          release: _release(
            source,
            channel: CurriculumReleaseChannel.stable,
            state: ContentLifecycleState.published,
          ),
          nodes: [_courseNode()],
          localizationUnits: [_approvedTitle()],
        ),
        throwsA(
          isA<CurriculumManifestException>().having(
            (error) => error.code,
            'code',
            'published_empty_scaffold',
          ),
        ),
      );
    });

    test('refuses unpublishable localization before learner visibility', () {
      final source = _source();
      expect(
        () => CurriculumManifest(
          source: source,
          release: _release(
            source,
            channel: CurriculumReleaseChannel.beta,
            state: ContentLifecycleState.published,
          ),
          nodes: [_courseNode()],
          localizationUnits: [_draftTitle()],
        ),
        throwsA(
          isA<CurriculumManifestException>().having(
            (error) => error.code,
            'code',
            'unpublishable_localization',
          ),
        ),
      );
    });
  });
}

CurriculumManifest _manifest() {
  final source = _source();
  return CurriculumManifest(
    source: source,
    release: _release(source),
    nodes: [_courseNode()],
    localizationUnits: [_approvedTitle()],
  );
}

CurriculumSource _source() => CurriculumSource(
  id: 'source.harrison-sim',
  sourceKey: 'harrison-sim',
  classification: 'user-provided-simulated-medical-reference',
  sourceTreeSha256: 'a' * 64,
  scanManifestId: 'scan.harrison-sim.full.v1',
  priorityCourseSourceKey: 'harrison-sim/course/06',
);

CurriculumRelease _release(
  CurriculumSource source, {
  String? sourceTreeSha256,
  CurriculumReleaseChannel channel = CurriculumReleaseChannel.internal,
  ContentLifecycleState state = ContentLifecycleState.validated,
}) => CurriculumRelease(
  id: 'release.internal.2026-07-17.1',
  sourceId: source.id,
  version: '2026.07.17+1',
  channel: channel,
  contractVersion: 1,
  authoringProtocolVersion: 'synapse-microlearning-v1',
  sourceTreeSha256: sourceTreeSha256 ?? source.sourceTreeSha256,
  contentState: state,
  createdAt: DateTime.utc(2026, 7, 17, 12),
);

CurriculumNode _courseNode() => CurriculumNode.fromSourceKey(
  sourceKey: 'harrison-sim/course/06',
  kind: CurriculumNodeKind.course,
  ordinal: 6,
  identityState: CurriculumIdentityState.approved,
  titleUnitId: 'l10n.course.06.title',
  sourceContainerKeys: const ['harrison-sim/course/06'],
);

CurriculumLocalizationUnit _approvedTitle() => CurriculumLocalizationUnit(
  id: 'l10n.course.06.title',
  semanticRole: ContentSemanticRole.title,
  semanticSkeletonSha256: 'b' * 64,
  en: LocalizedVariant.authored(
    locale: ContentLocale.en,
    text: 'Disorders of the Cardiovascular System',
    status: LocalizedVariantStatus.approved,
    authorId: 'author.en.001',
    reviewerId: 'reviewer.en.001',
    reviewedAt: DateTime.utc(2026, 7, 17, 13),
  ),
  fa: LocalizedVariant.authored(
    locale: ContentLocale.fa,
    text: 'اختلالات دستگاه قلب و عروق',
    status: LocalizedVariantStatus.approved,
    authorId: 'author.fa.001',
    reviewerId: 'reviewer.fa.001',
    reviewedAt: DateTime.utc(2026, 7, 17, 13),
  ),
  pairState: LocalizationPairState.publishable,
);

CurriculumLocalizationUnit _draftTitle() => CurriculumLocalizationUnit(
  id: 'l10n.course.06.title',
  semanticRole: ContentSemanticRole.title,
  semanticSkeletonSha256: 'c' * 64,
  en: LocalizedVariant.authored(
    locale: ContentLocale.en,
    text: 'Draft English title',
    status: LocalizedVariantStatus.authored,
    authorId: 'author.en.001',
  ),
  fa: LocalizedVariant.authored(
    locale: ContentLocale.fa,
    text: 'عنوان پیش‌نویس فارسی',
    status: LocalizedVariantStatus.authored,
    authorId: 'author.fa.001',
  ),
  pairState: LocalizationPairState.draft,
);

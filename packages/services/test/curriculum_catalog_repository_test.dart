import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_foundation/synapse_foundation.dart';
import 'package:synapse_services/synapse_services.dart';
import 'package:test/test.dart';

import 'support/curriculum_manifest_fixture.dart';

void main() {
  late MemoryKeyValueStore store;
  late MutableClock clock;
  late LocalCurriculumPackageRepository packages;
  late PackageCurriculumCatalogRepository catalogs;
  late CurriculumRuntimeBootCoordinator bootstrap;

  setUp(() {
    store = MemoryKeyValueStore();
    clock = MutableClock(DateTime.utc(2026, 7, 17, 12));
    packages = LocalCurriculumPackageRepository(
      store: store,
      clock: clock,
      idSource: SequenceIdSource([
        for (var index = 1; index <= 20; index++) 'activation.catalog.$index',
      ]),
    );
    catalogs = PackageCurriculumCatalogRepository(packages: packages);
    bootstrap = CurriculumRuntimeBootCoordinator(
      packages: packages,
      catalogs: catalogs,
    );
  });

  test('builds deterministic hierarchy and playback indexes', () {
    final manifest = buildPublishedManifest(
      releaseId: 'release.catalog.001',
      version: '2026.07.17+100',
    );
    final catalog = CurriculumCatalogSnapshot.fromManifest(manifest);

    expect(catalog.releaseId, manifest.release.id);
    expect(catalog.nodeCount, 5);
    expect(catalog.searchDocumentCount, catalog.nodeCount);
    expect(catalog.microLessonCount, 1);
    expect(catalog.sessionCount, 1);
    expect(catalog.studyDocumentCount, 1);
    expect(catalog.studyBlockCount, 3);
    expect(catalog.courses.single.node.kind, CurriculumNodeKind.course);

    final microNode = manifest.nodes.last;
    expect(catalog.ancestorsOf(microNode.id).map((entry) => entry.node.kind), [
      CurriculumNodeKind.course,
      CurriculumNodeKind.chapter,
      CurriculumNodeKind.unit,
      CurriculumNodeKind.conceptCluster,
    ]);
    final microLesson = catalog.microLessonForNode(microNode.id)!;
    final session = catalog.sessionsForMicroLesson(microLesson.id).single;
    expect(
      catalog.interactionsForSession(session.id).single.sessionId,
      session.id,
    );
    final studyDocument = catalog.primaryStudyDocumentForMicroLessonNode(
      microNode.id,
    );
    expect(studyDocument, isNotNull);
    expect(
      catalog
          .studyBlocksForDocument(studyDocument!.id)
          .map((block) => block.kind),
      [
        CurriculumStudyBlockKind.keyIdea,
        CurriculumStudyBlockKind.mechanismChain,
        CurriculumStudyBlockKind.recap,
      ],
    );
  });

  test('enforces published Deep Study ownership and answer isolation', () {
    final manifest = buildPublishedManifest(
      releaseId: 'release.catalog.deep-study-contract',
      version: '2026.07.17+98',
    );

    Map<String, dynamic> mutableManifest() =>
        jsonDecode(jsonEncode(manifest.toJson())) as Map<String, dynamic>;

    final withoutStudyBody = mutableManifest();
    (withoutStudyBody['studyDocuments'] as List<dynamic>).clear();
    (withoutStudyBody['studyBlocks'] as List<dynamic>).clear();
    expect(
      () => CurriculumManifest.fromJson(withoutStudyBody),
      throwsA(
        isA<CurriculumManifestException>().having(
          (error) => error.code,
          'code',
          'published_primary_study_document_count',
        ),
      ),
    );

    final withAnswerLeak = mutableManifest();
    final firstBlock =
        (withAnswerLeak['studyBlocks'] as List<dynamic>).first
            as Map<String, dynamic>;
    firstBlock['contentUnitIds'] = ['l10n.option.cardiology.correct'];
    expect(
      () => CurriculumManifest.fromJson(withAnswerLeak),
      throwsA(
        isA<CurriculumManifestException>().having(
          (error) => error.code,
          'code',
          'study_answer_surface_leak',
        ),
      ),
    );

    final withWrongOwner = mutableManifest();
    final ownedBlock =
        (withWrongOwner['studyBlocks'] as List<dynamic>).first
            as Map<String, dynamic>;
    ownedBlock['documentId'] = 'study.document.cardiology.somewhere-else';
    expect(
      () => CurriculumManifest.fromJson(withWrongOwner),
      throwsA(
        isA<CurriculumManifestException>().having(
          (error) => error.code,
          'code',
          'study_block_owner_mismatch',
        ),
      ),
    );
  });

  test('rejects undeclared and ambiguously owned playback content', () {
    final manifest = buildPublishedManifest(
      releaseId: 'release.catalog.playback-contract',
      version: '2026.07.17+99',
    );

    Map<String, dynamic> mutableManifest() =>
        jsonDecode(jsonEncode(manifest.toJson())) as Map<String, dynamic>;

    final withExtraSession = mutableManifest();
    final sessions = withExtraSession['sessions'] as List<dynamic>;
    final extraSession = Map<String, dynamic>.from(sessions.single as Map)
      ..['id'] = 'session.cardiology.undeclared'
      ..['ordinal'] = 2;
    sessions.add(extraSession);
    expect(
      () => CurriculumManifest.fromJson(withExtraSession),
      throwsA(
        isA<CurriculumManifestException>().having(
          (error) => error.code,
          'code',
          'undeclared_session',
        ),
      ),
    );

    final withExtraInteraction = mutableManifest();
    final interactions = withExtraInteraction['interactions'] as List<dynamic>;
    final extraInteraction =
        Map<String, dynamic>.from(interactions.single as Map)
          ..['id'] = 'interaction.cardiology.undeclared'
          ..['ordinal'] = 2;
    interactions.add(extraInteraction);
    expect(
      () => CurriculumManifest.fromJson(withExtraInteraction),
      throwsA(
        isA<CurriculumManifestException>().having(
          (error) => error.code,
          'code',
          'undeclared_interaction',
        ),
      ),
    );

    final withDuplicateLessonNode = mutableManifest();
    final lessons = withDuplicateLessonNode['microLessons'] as List<dynamic>;
    final duplicateLesson = Map<String, dynamic>.from(lessons.single as Map)
      ..['id'] = 'micro-lesson.cardiology.duplicate';
    lessons.add(duplicateLesson);
    expect(
      () => CurriculumManifest.fromJson(withDuplicateLessonNode),
      throwsA(
        isA<CurriculumManifestException>().having(
          (error) => error.code,
          'code',
          'duplicate_micro_lesson_node',
        ),
      ),
    );

    final withWrongSessionOrder = mutableManifest();
    final orderedSessions = withWrongSessionOrder['sessions'] as List<dynamic>;
    (orderedSessions.single as Map<String, dynamic>)['ordinal'] = 2;
    expect(
      () => CurriculumManifest.fromJson(withWrongSessionOrder),
      throwsA(
        isA<CurriculumManifestException>().having(
          (error) => error.code,
          'code',
          'session_order_mismatch',
        ),
      ),
    );

    final withoutLessonBody = mutableManifest();
    (withoutLessonBody['microLessons'] as List<dynamic>).clear();
    expect(
      () => CurriculumManifest.fromJson(withoutLessonBody),
      throwsA(
        isA<CurriculumManifestException>().having(
          (error) => error.code,
          'code',
          'missing_micro_lesson_body',
        ),
      ),
    );

    final withWrongLineage = mutableManifest();
    final alternateUnit = CurriculumNode.fromSourceKey(
      sourceKey: 'harrison-sim/course/06/chapter/001/unit/002',
      parentId: manifest.nodes[1].id,
      kind: CurriculumNodeKind.unit,
      ordinal: 2,
      identityState: CurriculumIdentityState.approved,
      titleUnitId: manifest.nodes[2].titleUnitId,
    );
    (withWrongLineage['nodes'] as List<dynamic>).add(alternateUnit.toJson());
    final lesson =
        (withWrongLineage['microLessons'] as List<dynamic>).single
            as Map<String, dynamic>;
    lesson['unitId'] = alternateUnit.id;
    expect(
      () => CurriculumManifest.fromJson(withWrongLineage),
      throwsA(
        isA<CurriculumManifestException>().having(
          (error) => error.code,
          'code',
          'micro_lesson_lineage_mismatch',
        ),
      ),
    );
  });

  test(
    'searches English and Persian with deterministic cross-locale fallback',
    () {
      final manifest = buildPublishedManifest(
        releaseId: 'release.catalog.search',
        version: '2026.07.17+101',
      );
      final catalog = CurriculumCatalogSnapshot.fromManifest(manifest);

      final english = catalog.search('english a course', ContentLocale.en);
      expect(english.first.entry.node.kind, CurriculumNodeKind.course);
      expect(english.first.matchTier, 0);
      expect(english.first.matchedLocale, ContentLocale.en);
      expect(
        english.first.matchOrigin,
        CurriculumCatalogMatchOrigin.requestedLocale,
      );

      final persianWithArabicYeh = catalog.search(
        'فارسي a course',
        ContentLocale.fa,
      );
      expect(
        persianWithArabicYeh.first.entry.node.kind,
        CurriculumNodeKind.course,
      );
      expect(persianWithArabicYeh.first.matchedLocale, ContentLocale.fa);

      final fallback = catalog.search('english a chapter', ContentLocale.fa);
      expect(fallback.first.entry.node.kind, CurriculumNodeKind.chapter);
      expect(fallback.first.matchedLocale, ContentLocale.en);
      expect(fallback.first.matchTier, 10);
      expect(
        fallback.first.matchOrigin,
        CurriculumCatalogMatchOrigin.fallbackLocale,
      );

      final sourceKey = catalog.search(
        'harrison-sim/course/06/chapter/001',
        ContentLocale.en,
      );
      expect(sourceKey.first.entry.node.kind, CurriculumNodeKind.chapter);
      expect(sourceKey.first.matchedLocale, isNull);
      expect(
        sourceKey.first.matchOrigin,
        CurriculumCatalogMatchOrigin.sourceKey,
      );

      final course = catalog.courses.single;
      final chapter = catalog.childrenOf(course.node.id).single;
      expect(
        catalog
            .search(
              'english a microLesson',
              ContentLocale.en,
              withinNodeId: chapter.node.id,
            )
            .single
            .entry
            .node
            .kind,
        CurriculumNodeKind.microLesson,
      );
      expect(
        catalog.search(
          'english a course',
          ContentLocale.en,
          withinNodeId: chapter.node.id,
        ),
        isEmpty,
      );
      expect(
        () =>
            catalog.search('', ContentLocale.en, withinNodeId: 'node.missing'),
        throwsA(
          isA<CurriculumCatalogException>().having(
            (error) => error.code,
            'code',
            'catalog_search_scope_missing',
          ),
        ),
      );

      final kindOnly = catalog.search(
        'english a',
        ContentLocale.en,
        kind: CurriculumNodeKind.conceptCluster,
      );
      expect(
        kindOnly.single.entry.node.kind,
        CurriculumNodeKind.conceptCluster,
      );
      expect(
        catalog.search('english a', ContentLocale.en, limit: 2),
        hasLength(2),
      );
      expect(
        () => catalog.search('english', ContentLocale.en, limit: 0),
        throwsRangeError,
      );

      final allHits = catalog.search('english a', ContentLocale.en, limit: 100);
      final expectedIds = allHits.map((hit) => hit.entry.node).toList()
        ..sort((left, right) {
          final ordinal = left.ordinal.compareTo(right.ordinal);
          return ordinal != 0 ? ordinal : left.id.compareTo(right.id);
        });
      expect(
        allHits.map((hit) => hit.entry.node.id),
        expectedIds.map((node) => node.id),
      );
    },
  );

  test('normalizes Persian Kaf, Yeh, diacritics, and ZWNJ', () {
    final catalog = CurriculumCatalogSnapshot.fromManifest(
      buildPublishedManifest(
        releaseId: 'release.catalog.search.fa',
        version: '2026.07.17+107',
        titleSuffix: 'کاردیو قلب‌وعروق',
      ),
    );

    final hits = catalog.search('فَارِسي كارديو قلب وعروق', ContentLocale.fa);
    expect(hits, isNotEmpty);
    expect(hits.first.matchedLocale, ContentLocale.fa);
    expect(
      hits.first.matchOrigin,
      CurriculumCatalogMatchOrigin.requestedLocale,
    );
  });

  test(
    'uses a two-budget LRU cache and rebuilds one evicted release',
    () async {
      final first = buildPublishedManifest(
        releaseId: 'release.cache.first',
        version: '2026.07.17+201',
        titleSuffix: 'First',
      );
      final second = buildPublishedManifest(
        releaseId: 'release.cache.second',
        version: '2026.07.17+202',
        titleSuffix: 'Second',
      );
      final third = buildPublishedManifest(
        releaseId: 'release.cache.third',
        version: '2026.07.17+203',
        titleSuffix: 'Third',
      );
      for (final manifest in [first, second, third]) {
        await _install(packages, 'candidate.${manifest.release.id}', manifest);
      }
      final bounded = PackageCurriculumCatalogRepository(
        packages: packages,
        maxCachedReleases: 2,
        maxCachedNodes: 10,
      );

      final firstSnapshot = await bounded.catalogForRelease(first.release.id);
      await bounded.catalogForRelease(second.release.id);
      expect(
        identical(
          firstSnapshot,
          await bounded.catalogForRelease(first.release.id),
        ),
        isTrue,
      );
      await bounded.catalogForRelease(third.release.id);

      expect(bounded.cacheStatus.releaseIdsLeastRecentFirst, [
        first.release.id,
        third.release.id,
      ]);
      expect(bounded.cacheStatus.totalNodeCount, 10);
      expect(bounded.cacheStatus.hitCount, 1);
      expect(bounded.cacheStatus.missCount, 3);
      expect(bounded.cacheStatus.evictionCount, 1);

      expect(bounded.evictRelease(first.release.id), isTrue);
      expect(bounded.evictRelease(first.release.id), isFalse);
      final rebuilt = await bounded.catalogForRelease(first.release.id);
      expect(identical(firstSnapshot, rebuilt), isFalse);
      expect(await packages.inventory(), hasLength(3));
    },
  );

  test('enforces the release-count budget independently', () async {
    final manifests = [
      buildPublishedManifest(
        releaseId: 'release.cache.count.first',
        version: '2026.07.17+212',
      ),
      buildPublishedManifest(
        releaseId: 'release.cache.count.second',
        version: '2026.07.17+213',
      ),
      buildPublishedManifest(
        releaseId: 'release.cache.count.third',
        version: '2026.07.17+214',
      ),
    ];
    for (final manifest in manifests) {
      await _install(packages, 'candidate.${manifest.release.id}', manifest);
    }
    final bounded = PackageCurriculumCatalogRepository(
      packages: packages,
      maxCachedReleases: 2,
      maxCachedNodes: 100,
    );

    for (final manifest in manifests) {
      await bounded.catalogForRelease(manifest.release.id);
    }

    expect(bounded.cacheStatus.releaseIdsLeastRecentFirst, [
      manifests[1].release.id,
      manifests[2].release.id,
    ]);
    expect(bounded.cacheStatus.totalNodeCount, 10);
    expect(bounded.cacheStatus.evictionCount, 1);
  });

  test('enforces the aggregate-node budget independently', () async {
    final manifests = [
      buildPublishedManifest(
        releaseId: 'release.cache.nodes.first',
        version: '2026.07.17+215',
      ),
      buildPublishedManifest(
        releaseId: 'release.cache.nodes.second',
        version: '2026.07.17+216',
      ),
      buildPublishedManifest(
        releaseId: 'release.cache.nodes.third',
        version: '2026.07.17+217',
      ),
    ];
    for (final manifest in manifests) {
      await _install(packages, 'candidate.${manifest.release.id}', manifest);
    }
    final bounded = PackageCurriculumCatalogRepository(
      packages: packages,
      maxCachedReleases: 10,
      maxCachedNodes: 10,
    );

    for (final manifest in manifests) {
      await bounded.catalogForRelease(manifest.release.id);
    }

    expect(bounded.cacheStatus.releaseIdsLeastRecentFirst, [
      manifests[1].release.id,
      manifests[2].release.id,
    ]);
    expect(bounded.cacheStatus.totalNodeCount, 10);
    expect(bounded.cacheStatus.evictionCount, 1);
  });

  test(
    'bypasses an oversized derived index without losing its package',
    () async {
      final manifest = buildPublishedManifest(
        releaseId: 'release.cache.oversized',
        version: '2026.07.17+204',
      );
      await _install(packages, 'candidate.cache.oversized', manifest);
      final bounded = PackageCurriculumCatalogRepository(
        packages: packages,
        maxCachedReleases: 2,
        maxCachedNodes: 4,
      );

      final first = await bounded.catalogForRelease(manifest.release.id);
      final second = await bounded.catalogForRelease(manifest.release.id);

      expect(identical(first, second), isFalse);
      expect(bounded.cacheStatus.releaseCount, 0);
      expect(bounded.cacheStatus.totalNodeCount, 0);
      expect(bounded.cacheStatus.missCount, 2);
      expect(bounded.cacheStatus.oversizedBypassCount, 2);
      expect(await packages.loadRelease(manifest.release.id), isNotNull);
    },
  );

  test('coalesces concurrent builds for the same immutable release', () async {
    final countingStore = _CountingKeyValueStore();
    final countingPackages = LocalCurriculumPackageRepository(
      store: countingStore,
      clock: clock,
      idSource: SequenceIdSource(const ['activation.cache.concurrent']),
    );
    final manifest = buildPublishedManifest(
      releaseId: 'release.cache.concurrent',
      version: '2026.07.17+205',
    );
    await _install(countingPackages, 'candidate.cache.concurrent', manifest);
    final concurrent = PackageCurriculumCatalogRepository(
      packages: countingPackages,
    );
    countingStore.resetReadCount();

    final first = concurrent.catalogForRelease(manifest.release.id);
    final second = concurrent.catalogForRelease(manifest.release.id);
    expect(concurrent.cacheStatus.inFlightBuildCount, 1);
    final snapshots = await Future.wait([first, second]);

    expect(identical(snapshots.first, snapshots.last), isTrue);
    expect(countingStore.readCount, 1);
    expect(concurrent.cacheStatus.inFlightBuildCount, 0);
  });

  test(
    'cache recovery invalidates a build that was already in flight',
    () async {
      final controlledStore = _ControlledReadKeyValueStore();
      final controlledPackages = LocalCurriculumPackageRepository(
        store: controlledStore,
        clock: clock,
        idSource: SequenceIdSource(const ['activation.cache.invalidated']),
      );
      final manifest = buildPublishedManifest(
        releaseId: 'release.cache.invalidated',
        version: '2026.07.17+206',
      );
      await _install(
        controlledPackages,
        'candidate.cache.invalidated',
        manifest,
      );
      final recovering = PackageCurriculumCatalogRepository(
        packages: controlledPackages,
      );
      controlledStore.pauseNextRead();

      final pending = recovering.catalogForRelease(manifest.release.id);
      await controlledStore.waitUntilReadPaused();
      recovering.clearMemoryCache();
      controlledStore.releasePausedRead();
      final snapshot = await pending;

      expect(snapshot.releaseId, manifest.release.id);
      expect(recovering.cacheStatus.releaseCount, 0);
      expect(recovering.cacheStatus.totalNodeCount, 0);
      expect(recovering.cacheStatus.invalidatedBuildCount, 1);
      expect(recovering.cacheStatus.inFlightBuildCount, 0);
    },
  );

  test('targeted eviction invalidates an active-catalog load', () async {
    final manifest = buildPublishedManifest(
      releaseId: 'release.cache.active-eviction',
      version: '2026.07.17+207',
    );
    final controlled = _ControlledPackageRepository(
      manifests: {manifest.release.id: manifest},
      active: {CurriculumActivationTarget.learner: manifest.release.id},
    )..pause(manifest.release.id);
    final recovering = PackageCurriculumCatalogRepository(packages: controlled);

    final pending = recovering.activeCatalog(
      CurriculumActivationTarget.learner,
    );
    await controlled.waitUntilStarted(manifest.release.id);
    expect(recovering.cacheStatus.inFlightBuildCount, 1);
    expect(recovering.evictRelease(manifest.release.id), isTrue);
    controlled.release(manifest.release.id);
    final snapshot = await pending;

    expect(snapshot?.releaseId, manifest.release.id);
    expect(recovering.cacheStatus.releaseCount, 0);
    expect(recovering.cacheStatus.invalidatedBuildCount, 1);
    expect(recovering.cacheStatus.inFlightBuildCount, 0);
  });

  test(
    'eviction during active-pointer lookup prevents later repopulation',
    () async {
      final manifest = buildPublishedManifest(
        releaseId: 'release.cache.active-lookup-eviction',
        version: '2026.07.17+220',
      );
      final controlled = _ControlledPackageRepository(
        manifests: {manifest.release.id: manifest},
        active: {CurriculumActivationTarget.learner: manifest.release.id},
      )..pauseActiveLookup();
      final recovering = PackageCurriculumCatalogRepository(
        packages: controlled,
      );

      final pending = recovering.activeCatalog(
        CurriculumActivationTarget.learner,
      );
      await controlled.waitUntilActiveLookupStarted();
      expect(recovering.cacheStatus.activeLookupCount, 1);
      expect(recovering.evictRelease(manifest.release.id), isTrue);
      controlled.releaseActiveLookup();
      final snapshot = await pending;

      expect(snapshot?.releaseId, manifest.release.id);
      expect(recovering.cacheStatus.releaseCount, 0);
      expect(recovering.cacheStatus.invalidatedBuildCount, 1);
      expect(recovering.cacheStatus.activeLookupCount, 0);
    },
  );

  test(
    'active catalog retries instead of returning a stale activation',
    () async {
      final first = buildPublishedManifest(
        releaseId: 'release.cache.active-race.first',
        version: '2026.07.17+221',
      );
      final second = buildPublishedManifest(
        releaseId: 'release.cache.active-race.second',
        version: '2026.07.17+222',
      );
      final active = <CurriculumActivationTarget, CurriculumReleaseId>{
        CurriculumActivationTarget.learner: first.release.id,
      };
      final controlled = _ControlledPackageRepository(
        manifests: {first.release.id: first, second.release.id: second},
        active: active,
      )..pause(first.release.id);
      final guarded = PackageCurriculumCatalogRepository(packages: controlled);

      final pending = guarded.activeCatalog(CurriculumActivationTarget.learner);
      await controlled.waitUntilStarted(first.release.id);
      active[CurriculumActivationTarget.learner] = second.release.id;
      controlled.release(first.release.id);
      final snapshot = await pending;

      expect(snapshot?.releaseId, second.release.id);
      expect(controlled.loadCounts[first.release.id], 1);
      expect(controlled.loadCounts[second.release.id], 1);
    },
  );

  test('targeted eviction does not invalidate an unrelated build', () async {
    final first = buildPublishedManifest(
      releaseId: 'release.cache.targeted.first',
      version: '2026.07.17+208',
    );
    final second = buildPublishedManifest(
      releaseId: 'release.cache.targeted.second',
      version: '2026.07.17+209',
    );
    final controlled =
        _ControlledPackageRepository(
            manifests: {first.release.id: first, second.release.id: second},
          )
          ..pause(first.release.id)
          ..pause(second.release.id);
    final recovering = PackageCurriculumCatalogRepository(packages: controlled);

    final firstPending = recovering.catalogForRelease(first.release.id);
    final secondPending = recovering.catalogForRelease(second.release.id);
    await Future.wait([
      controlled.waitUntilStarted(first.release.id),
      controlled.waitUntilStarted(second.release.id),
    ]);
    expect(recovering.evictRelease(first.release.id), isTrue);
    controlled.release(first.release.id);
    controlled.release(second.release.id);
    await Future.wait([firstPending, secondPending]);

    expect(recovering.cacheStatus.releaseIdsLeastRecentFirst, [
      second.release.id,
    ]);
    expect(recovering.cacheStatus.invalidatedBuildCount, 1);
  });

  test(
    'single-flight state cleans up after errors and permits retry',
    () async {
      final manifest = buildPublishedManifest(
        releaseId: 'release.cache.retry',
        version: '2026.07.17+210',
      );
      final controlled = _ControlledPackageRepository(
        manifests: {manifest.release.id: manifest},
      )..failNext(manifest.release.id);
      final recovering = PackageCurriculumCatalogRepository(
        packages: controlled,
      );

      await expectLater(
        recovering.catalogForRelease(manifest.release.id),
        throwsA(isA<CurriculumPackageException>()),
      );
      expect(recovering.cacheStatus.inFlightBuildCount, 0);

      final recovered = await recovering.catalogForRelease(manifest.release.id);
      expect(recovered.releaseId, manifest.release.id);
      expect(controlled.loadCounts[manifest.release.id], 2);
      expect(recovering.cacheStatus.inFlightBuildCount, 0);
    },
  );

  test(
    'rejects same-release canonical drift after first observation',
    () async {
      final original = buildPublishedManifest(
        releaseId: 'release.cache.drift',
        version: '2026.07.17+211',
        titleSuffix: 'Original',
      );
      final altered = buildPublishedManifest(
        releaseId: original.release.id,
        version: original.release.version,
        titleSuffix: 'Altered',
      );
      final controlled = _ControlledPackageRepository(
        manifests: {original.release.id: original},
      );
      final guarded = PackageCurriculumCatalogRepository(packages: controlled);
      await guarded.catalogForRelease(original.release.id);
      controlled.manifests[original.release.id] = altered;

      await expectLater(
        guarded.catalogForRelease(original.release.id),
        throwsA(
          isA<CurriculumCatalogException>().having(
            (error) => error.code,
            'code',
            'immutable_release_drift',
          ),
        ),
      );
      expect(guarded.cacheStatus.inFlightBuildCount, 0);
      expect(guarded.cacheStatus.releaseIdsLeastRecentFirst, [
        original.release.id,
      ]);
    },
  );

  test(
    'tracks activation changes without returning a stale cached release',
    () async {
      final first = buildPublishedManifest(
        releaseId: 'release.catalog.first',
        version: '2026.07.17+102',
        titleSuffix: 'First',
      );
      final second = buildPublishedManifest(
        releaseId: 'release.catalog.second',
        version: '2026.07.17+103',
        parentReleaseId: first.release.id,
        titleSuffix: 'Second',
      );
      await _install(packages, 'candidate.catalog.first', first);
      await _install(packages, 'candidate.catalog.second', second);
      await packages.activate(
        releaseId: first.release.id,
        target: CurriculumActivationTarget.learner,
      );

      final firstCatalog = (await catalogs.activeCatalog(
        CurriculumActivationTarget.learner,
      ))!;
      expect(firstCatalog.courses.single.titleEn, 'English First course');
      expect(
        identical(
          firstCatalog,
          await catalogs.catalogForRelease(first.release.id),
        ),
        isTrue,
      );

      await packages.activate(
        releaseId: second.release.id,
        target: CurriculumActivationTarget.learner,
      );
      final secondCatalog = (await catalogs.activeCatalog(
        CurriculumActivationTarget.learner,
      ))!;
      expect(secondCatalog.releaseId, second.release.id);
      expect(secondCatalog.courses.single.titleEn, 'English Second course');
      expect(identical(firstCatalog, secondCatalog), isFalse);

      catalogs.clearMemoryCache();
      expect(
        identical(
          secondCatalog,
          await catalogs.catalogForRelease(second.release.id),
        ),
        isFalse,
      );
    },
  );

  test('returns an intentional no-active-release bootstrap state', () async {
    final result = await bootstrap.boot(CurriculumActivationTarget.learner);

    expect(result.status, CurriculumRuntimeBootstrapStatus.noActiveRelease);
    expect(result.catalog, isNull);
    expect(result.canRetry, isFalse);
    expect(result.integrityIssues, isEmpty);
  });

  test(
    'boots an offline-ready active catalog and reports unrelated damage',
    () async {
      final active = buildPublishedManifest(
        releaseId: 'release.catalog.active',
        version: '2026.07.17+104',
        titleSuffix: 'Active',
      );
      final damaged = buildPublishedManifest(
        releaseId: 'release.catalog.damaged',
        version: '2026.07.17+105',
        parentReleaseId: active.release.id,
        titleSuffix: 'Damaged',
      );
      await _install(packages, 'candidate.catalog.active', active);
      await _install(packages, 'candidate.catalog.damaged', damaged);
      await packages.activate(
        releaseId: active.release.id,
        target: CurriculumActivationTarget.learner,
      );
      await _corruptStoredManifest(store, damaged.release.id);

      final result = await bootstrap.boot(CurriculumActivationTarget.learner);

      expect(result.status, CurriculumRuntimeBootstrapStatus.ready);
      expect(result.catalog?.releaseId, active.release.id);
      expect(result.integrityIssues.single.releaseId, damaged.release.id);
      expect(result.canRetry, isFalse);
    },
  );

  test(
    'preview control-plane damage does not block a healthy learner',
    () async {
      final learner = buildPublishedManifest(
        releaseId: 'release.catalog.learner.healthy',
        version: '2026.07.17+218',
      );
      final preview = buildScaffoldManifest(
        releaseId: 'release.catalog.preview.damaged',
        version: '2026.07.17+219',
      );
      await _install(packages, 'candidate.catalog.learner', learner);
      await _install(packages, 'candidate.catalog.preview', preview);
      await packages.activate(
        releaseId: learner.release.id,
        target: CurriculumActivationTarget.learner,
      );
      await packages.activate(
        releaseId: preview.release.id,
        target: CurriculumActivationTarget.preview,
      );
      final raw = await store.read(LocalCurriculumPackageRepository.stateKey);
      final registry = jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
      final active = registry['active'] as Map<String, dynamic>;
      active['preview'] = 'release.catalog.preview.missing';
      await store.write(LocalCurriculumPackageRepository.stateKey, registry);

      final learnerResult = await bootstrap.boot(
        CurriculumActivationTarget.learner,
      );
      expect(learnerResult.status, CurriculumRuntimeBootstrapStatus.ready);
      expect(learnerResult.catalog?.releaseId, learner.release.id);
      expect(
        learnerResult.integrityIssues.where(
          (issue) => issue.target == CurriculumActivationTarget.preview,
        ),
        isNotEmpty,
      );

      final previewResult = await bootstrap.boot(
        CurriculumActivationTarget.preview,
      );
      expect(
        previewResult.status,
        CurriculumRuntimeBootstrapStatus.integrityBlocked,
      );
      expect(previewResult.errorCode, 'missing_active_release');
    },
  );

  test(
    'blocks an active corrupt release without resetting the registry',
    () async {
      final manifest = buildPublishedManifest(
        releaseId: 'release.catalog.corrupt',
        version: '2026.07.17+106',
      );
      await _install(packages, 'candidate.catalog.corrupt', manifest);
      await packages.activate(
        releaseId: manifest.release.id,
        target: CurriculumActivationTarget.learner,
      );
      await _corruptStoredManifest(store, manifest.release.id);

      final result = await bootstrap.boot(CurriculumActivationTarget.learner);

      expect(result.status, CurriculumRuntimeBootstrapStatus.integrityBlocked);
      expect(result.errorCode, 'corrupt_installed_package');
      expect(result.catalog, isNull);
      expect(result.canRetry, isFalse);
      expect(
        await store.read(LocalCurriculumPackageRepository.stateKey),
        isNotNull,
      );
    },
  );

  test(
    'distinguishes corrupt and unsupported registry bootstrap failures',
    () async {
      await store.write(LocalCurriculumPackageRepository.stateKey, 'broken');
      var result = await bootstrap.boot(CurriculumActivationTarget.learner);
      expect(result.status, CurriculumRuntimeBootstrapStatus.integrityBlocked);
      expect(result.errorCode, 'corrupt_registry');

      await store.write(LocalCurriculumPackageRepository.stateKey, {
        'schemaVersion': 999,
        'packages': <String, Object?>{},
        'active': <String, Object?>{},
        'receipts': <Object?>[],
        'quarantine': <Object?>[],
      });
      result = await bootstrap.boot(CurriculumActivationTarget.learner);
      expect(result.status, CurriculumRuntimeBootstrapStatus.unsupportedSchema);
      expect(result.errorCode, 'unsupported_registry_schema');
    },
  );
}

Future<CurriculumInstallResult> _install(
  LocalCurriculumPackageRepository repository,
  String candidateId,
  CurriculumManifest manifest,
) {
  final manifestJson = jsonEncode(manifest.toJson());
  return repository.installBundledCandidate(
    candidateId: candidateId,
    manifestJson: manifestJson,
    expectedCanonicalSha256: manifest.canonicalSha256,
    expectedTransportSha256: sha256
        .convert(utf8.encode(manifestJson))
        .toString(),
  );
}

Future<void> _corruptStoredManifest(
  MemoryKeyValueStore store,
  CurriculumReleaseId releaseId,
) async {
  final raw = await store.read(LocalCurriculumPackageRepository.stateKey);
  final mutable = jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
  final packages = mutable['packages'] as Map<String, dynamic>;
  final stored = packages[releaseId] as Map<String, dynamic>;
  stored['manifestJson'] = '{}';
  await store.write(LocalCurriculumPackageRepository.stateKey, mutable);
}

final class _ControlledPackageRepository
    implements CurriculumPackageRepository {
  _ControlledPackageRepository({
    required this.manifests,
    this.active = const {},
  });

  final Map<CurriculumReleaseId, CurriculumManifest> manifests;
  final Map<CurriculumActivationTarget, CurriculumReleaseId> active;
  final Map<CurriculumReleaseId, int> loadCounts = {};
  final Map<CurriculumReleaseId, _LoadGate> _gates = {};
  final Set<CurriculumReleaseId> _failNext = {};
  _LoadGate? _activeLookupGate;

  void pause(CurriculumReleaseId releaseId) {
    _gates[releaseId] = _LoadGate();
  }

  Future<void> waitUntilStarted(CurriculumReleaseId releaseId) =>
      _gates[releaseId]!.started.future;

  void release(CurriculumReleaseId releaseId) {
    final gate = _gates[releaseId]!;
    if (!gate.released.isCompleted) gate.released.complete();
  }

  void failNext(CurriculumReleaseId releaseId) {
    _failNext.add(releaseId);
  }

  void pauseActiveLookup() {
    _activeLookupGate = _LoadGate();
  }

  Future<void> waitUntilActiveLookupStarted() =>
      _activeLookupGate!.started.future;

  void releaseActiveLookup() {
    final gate = _activeLookupGate!;
    if (!gate.released.isCompleted) gate.released.complete();
  }

  @override
  Future<CurriculumReleaseId?> activeReleaseId(
    CurriculumActivationTarget target,
  ) async {
    final gate = _activeLookupGate;
    if (gate != null) {
      if (!gate.started.isCompleted) gate.started.complete();
      await gate.released.future;
      _activeLookupGate = null;
    }
    return active[target];
  }

  @override
  Future<CurriculumManifest?> loadRelease(CurriculumReleaseId releaseId) async {
    loadCounts.update(releaseId, (count) => count + 1, ifAbsent: () => 1);
    final gate = _gates[releaseId];
    if (gate != null) {
      if (!gate.started.isCompleted) gate.started.complete();
      await gate.released.future;
      _gates.remove(releaseId);
    }
    if (_failNext.remove(releaseId)) {
      throw CurriculumPackageException(
        'controlled_load_failure',
        'Controlled package load failed for $releaseId.',
      );
    }
    return manifests[releaseId];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _LoadGate {
  final Completer<void> started = Completer<void>();
  final Completer<void> released = Completer<void>();
}

final class _CountingKeyValueStore implements KeyValueStore {
  final MemoryKeyValueStore _delegate = MemoryKeyValueStore();
  int readCount = 0;

  void resetReadCount() => readCount = 0;

  @override
  Future<void> clear() => _delegate.clear();

  @override
  Future<Object?> read(String key) {
    readCount += 1;
    return _delegate.read(key);
  }

  @override
  Future<void> remove(String key) => _delegate.remove(key);

  @override
  Future<void> write(String key, Object value) => _delegate.write(key, value);
}

final class _ControlledReadKeyValueStore implements KeyValueStore {
  final MemoryKeyValueStore _delegate = MemoryKeyValueStore();
  Completer<void>? _readStarted;
  Completer<void>? _releaseRead;

  void pauseNextRead() {
    if (_releaseRead != null) throw StateError('A read is already paused.');
    _readStarted = Completer<void>();
    _releaseRead = Completer<void>();
  }

  Future<void> waitUntilReadPaused() {
    final started = _readStarted;
    if (started == null) throw StateError('No read pause is armed.');
    return started.future;
  }

  void releasePausedRead() {
    final release = _releaseRead;
    if (release == null) throw StateError('No read is paused.');
    release.complete();
  }

  @override
  Future<void> clear() => _delegate.clear();

  @override
  Future<Object?> read(String key) async {
    final started = _readStarted;
    final release = _releaseRead;
    if (started != null && release != null) {
      if (!started.isCompleted) started.complete();
      await release.future;
      _readStarted = null;
      _releaseRead = null;
    }
    return _delegate.read(key);
  }

  @override
  Future<void> remove(String key) => _delegate.remove(key);

  @override
  Future<void> write(String key, Object value) => _delegate.write(key, value);
}

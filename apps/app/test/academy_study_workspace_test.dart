import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synapse_app/dev/academy_synthetic_fixture.dart';
import 'package:synapse_app/features/academy/academy_study_workspace_screen.dart';
import 'package:synapse_app/state/app_providers.dart';
import 'package:synapse_app/state/curriculum_provider.dart';
import 'package:synapse_app/state/persistence.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_services/synapse_services.dart';
import 'package:synapse_ui/synapse_ui.dart';

void main() {
  testWidgets(
    'study workspace renders reviewed context and persists personal material',
    (tester) async {
      await _setViewport(tester, const Size(390, 844));
      final fixture = await _fixture();

      await tester.pumpWidget(
        _host(
          fixture: fixture,
          child: AcademyStudyWorkspaceScreen(nodeId: fixture.nodeId),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Study Workspace'), findsOneWidget);
      expect(find.text('Preview microLesson'), findsWidgets);
      expect(find.text('Preview objective'), findsOneWidget);
      expect(find.text('Preview practice session'), findsOneWidget);
      expect(find.text('A Small System, Explained'), findsOneWidget);
      expect(
        find.text(
          'A stable result appears when every step receives a clear input and leaves a checkable output.',
        ),
        findsOneWidget,
      );
      expect(find.text('Confirm the observable output.'), findsOneWidget);
      expect(find.text('One transition'), findsOneWidget);
      expect(find.text('A review block is still locked'), findsOneWidget);
      expect(
        find.text(
          'This recap appears only after the linked session is complete.',
        ),
        findsNothing,
      );
      expect(find.text('Preview first option'), findsNothing);
      expect(find.text('Personal notes'), findsOneWidget);

      await tester.tap(find.byTooltip('Bookmark this lesson'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Remove bookmark'), findsOneWidget);

      await tester.enterText(
        find.byType(TextField),
        'Wide-complex tachycardia: inspect regularity before mechanism.',
      );
      await tester.ensureVisible(find.text('Save note'));
      await tester.tap(find.text('Save note'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Wide-complex tachycardia: inspect regularity before mechanism.',
        ),
        findsOneWidget,
      );

      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getString(
          LocalCurriculumSessionProgressRepository.stateKey,
        ),
        isNull,
        reason: 'Opening Deep Study must not manufacture Session progress.',
      );
      final raw = preferences.getString(
        LocalCurriculumStudyWorkspaceRepository.stateKey,
      );
      expect(raw, isNotNull);
      final registry = jsonDecode(raw!) as Map<String, dynamic>;
      final record =
          (registry['records'] as Map<String, dynamic>).values.single
              as Map<String, dynamic>;
      expect(
        record['isBookmarked'],
        isFalse,
        reason:
            'The legacy node flag is preserved but no longer receives new writes.',
      );
      expect(record['lastOpenedReleaseId'], fixture.catalog.releaseId);
      expect(record['notes'], hasLength(1));
      final note =
          (record['notes'] as List<dynamic>).single as Map<String, dynamic>;
      expect(note['anchorId'], startsWith('anchor.'));

      final resourceRaw = preferences.getString(
        LocalResourceWorkspaceRepository.stateKey,
      );
      expect(resourceRaw, isNotNull);
      final resourceRegistry = jsonDecode(resourceRaw!) as Map<String, dynamic>;
      final anchors = resourceRegistry['anchors'] as Map<String, dynamic>;
      expect(anchors, contains(note['anchorId']));
      final bookmark =
          (resourceRegistry['bookmarks'] as Map<String, dynamic>).values.single
              as Map<String, dynamic>;
      expect(bookmark['isDeleted'], isFalse);
      expect(anchors, contains(bookmark['anchorId']));

      // A new provider container restores learner-owned data instead of
      // deriving it from the immutable package or the widget tree.
      await tester.pumpWidget(
        KeyedSubtree(
          key: UniqueKey(),
          child: _host(
            fixture: fixture,
            child: AcademyStudyWorkspaceScreen(nodeId: fixture.nodeId),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Wide-complex tachycardia: inspect regularity before mechanism.',
        ),
        findsOneWidget,
      );
      expect(find.byTooltip('Remove bookmark'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'exact completed Session progress reveals its gated reviewed recap',
    (tester) async {
      await _setViewport(tester, const Size(390, 844));
      final fixture = await _fixture();
      final microLesson = fixture.catalog.microLessonForNode(fixture.nodeId)!;
      final session = fixture.catalog
          .sessionsForMicroLesson(microLesson.id)
          .single;
      final key = CurriculumSessionProgressKey(
        releaseId: fixture.catalog.releaseId,
        microLessonNodeId: fixture.nodeId,
        sessionId: session.id,
      );
      final completed = CurriculumSessionProgress(
        key: key,
        phase: CurriculumSessionProgressPhase.completed,
        interactionIndex: 0,
        revision: 2,
        startedAt: DateTime.utc(2026, 7, 18, 12),
        updatedAt: DateTime.utc(2026, 7, 18, 12, 2),
        completedAt: DateTime.utc(2026, 7, 18, 12, 2),
        completionReceiptId: 'completion.workspace.1',
      );
      await fixture.store.writeJson(
        LocalCurriculumSessionProgressRepository.stateKey,
        {
          'schemaVersion': 1,
          'records': {key.stableId: completed.toJson()},
        },
      );

      await tester.pumpWidget(
        _host(
          fixture: fixture,
          child: AcademyStudyWorkspaceScreen(nodeId: fixture.nodeId),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'This recap appears only after the linked session is complete.',
        ),
        findsOneWidget,
      );
      expect(find.text('A review block is still locked'), findsNothing);
      expect(find.text('Preview first option'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('corrupt progress stays fail-closed with a recovery action', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 844));
    final fixture = await _fixture();
    await fixture.store.writeJson(
      LocalCurriculumSessionProgressRepository.stateKey,
      {'schemaVersion': 99, 'records': <String, Object?>{}},
    );

    await tester.pumpWidget(
      _host(
        fixture: fixture,
        child: AcademyStudyWorkspaceScreen(nodeId: fixture.nodeId),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Progress could not be verified'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(
      find.text(
        'This recap appears only after the linked session is complete.',
      ),
      findsNothing,
    );
    expect(find.text('Preview first option'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('focus timer pauses into a private idempotent study log', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 844));
    final fixture = await _fixture();

    await tester.pumpWidget(
      _host(
        fixture: fixture,
        child: AcademyStudyWorkspaceScreen(nodeId: fixture.nodeId),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Focus'));
    await tester.tap(find.text('Focus'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start focus'));
    await tester.tap(find.text('Start focus'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Pause & save'), findsOneWidget);

    await tester.tap(find.text('Pause & save'));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(
      LocalCurriculumStudyWorkspaceRepository.stateKey,
    );
    final registry = jsonDecode(raw!) as Map<String, dynamic>;
    final record =
        (registry['records'] as Map<String, dynamic>).values.single
            as Map<String, dynamic>;
    expect(record['focusSessionCount'], 1);
    expect(record['focusSecondsTotal'] as int, greaterThanOrEqualTo(1));
    expect(record['lastFocusSegmentId'], isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'scrolling saves a semantic reading anchor and the next workspace resumes it',
    (tester) async {
      await _setViewport(tester, const Size(390, 844));
      final fixture = await _fixture();

      await tester.pumpWidget(
        _host(
          fixture: fixture,
          child: AcademyStudyWorkspaceScreen(nodeId: fixture.nodeId),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -1050),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(
        LocalCurriculumReadingStateRepository.stateKey,
      );
      expect(raw, isNotNull);
      expect(raw, isNot(contains('Preview first option')));
      expect(raw, isNot(contains('A stable result appears')));
      final registry = jsonDecode(raw!) as Map<String, dynamic>;
      expect(registry['schemaVersion'], 1);
      final record =
          (registry['records'] as Map<String, dynamic>).values.single
              as Map<String, dynamic>;
      expect(record['lastReadReleaseId'], fixture.catalog.releaseId);
      expect(record['blockId'], isNotEmpty);
      expect(record['blockOrdinal'], greaterThanOrEqualTo(1));
      expect(record['anchorUnitId'], isNotEmpty);
      expect(record['documentPositionPermille'], inInclusiveRange(0, 1000));

      final document = fixture.catalog.primaryStudyDocumentForMicroLessonNode(
        fixture.nodeId,
      )!;
      final block = fixture.catalog
          .studyBlocksForDocument(document.id)
          .singleWhere((item) => item.id == record['blockId']);
      final target = block.revealPolicy == CurriculumStudyRevealPolicy.always
          ? find.text(
              fixture.catalog.localizedText(
                block.headingUnitId!,
                ContentLocale.en,
              )!,
            )
          : find.text('A review block is still locked');

      await tester.pumpWidget(
        KeyedSubtree(
          key: UniqueKey(),
          child: _host(
            fixture: fixture,
            child: AcademyStudyWorkspaceScreen(nodeId: fixture.nodeId),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(target.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'corrupt reading state never blocks reviewed content and offers recovery',
    (tester) async {
      await _setViewport(tester, const Size(390, 844));
      final fixture = await _fixture();
      await fixture.store
          .writeJson(LocalCurriculumReadingStateRepository.stateKey, {
            'schemaVersion': 99,
            'records': <String, Object?>{},
            'integrity': <String, Object?>{},
          });

      await tester.pumpWidget(
        _host(
          fixture: fixture,
          child: AcademyStudyWorkspaceScreen(nodeId: fixture.nodeId),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('A Small System, Explained'), findsOneWidget);
      expect(
        find.textContaining('Your saved place could not be restored'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a retired semantic anchor falls back by ordinal with an explicit notice',
    (tester) async {
      await _setViewport(tester, const Size(390, 844));
      final fixture = await _fixture();
      final document = fixture.catalog.primaryStudyDocumentForMicroLessonNode(
        fixture.nodeId,
      )!;
      final key = CurriculumReadingPositionKey(
        sourceId: fixture.catalog.sourceId,
        microLessonNodeId: fixture.nodeId,
        documentId: document.id,
      );
      final position = CurriculumReadingPosition(
        key: key,
        lastReadReleaseId: 'release.previous',
        blockId: 'study.block.retired',
        blockOrdinal: 3,
        anchorUnitId: 'l10n.study.retired',
        documentPositionPermille: 500,
        lastLocale: ContentLocale.en,
        revision: 1,
        createdAt: DateTime.utc(2026, 7, 18, 12),
        updatedAt: DateTime.utc(2026, 7, 18, 12),
      );
      await fixture.store.writeJson(
        LocalCurriculumReadingStateRepository.stateKey,
        {
          'schemaVersion': 1,
          'records': {key.stableId: position.toJson()},
          'integrity': {'recordCount': 1, 'positionPermilleTotal': 500},
        },
      );

      await tester.pumpWidget(
        _host(
          fixture: fixture,
          child: AcademyStudyWorkspaceScreen(nodeId: fixture.nodeId),
        ),
      );
      await tester.pumpAndSettle();

      final fallbackBlock = fixture.catalog
          .studyBlocksForDocument(document.id)
          .singleWhere((item) => item.ordinal == 3);
      final fallbackHeading = fixture.catalog.localizedText(
        fallbackBlock.headingUnitId!,
        ContentLocale.en,
      )!;
      expect(find.text(fallbackHeading).hitTestable(), findsOneWidget);
      expect(find.textContaining('changed the saved anchor'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Sources shows only PDFs explicitly linked to the active lesson',
    (tester) async {
      await _setViewport(tester, const Size(390, 844));
      final fixture = await _fixture();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(fixture.store),
          ..._legacyResourceOverrides,
        ],
      );
      addTearDown(container.dispose);
      final repository = container.read(resourceWorkspaceRepositoryProvider);
      const digestA =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const digestB =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      final attached = ResourceDocument(
        id: 'document.cardiology.attached',
        displayName: 'Cardiology companion.pdf',
        mediaType: 'application/pdf',
        contentSha256: digestA,
        byteLength: 4096,
        pageCount: 18,
        origin: ResourceDocumentOrigin.userImport,
        createdAt: DateTime.utc(2026, 7, 22, 12),
      );
      final unrelated = ResourceDocument(
        id: 'document.neurology.unrelated',
        displayName: 'Unrelated neurology.pdf',
        mediaType: 'application/pdf',
        contentSha256: digestB,
        byteLength: 8192,
        pageCount: 31,
        origin: ResourceDocumentOrigin.userImport,
        createdAt: DateTime.utc(2026, 7, 22, 13),
      );
      await repository.registerDocument(attached);
      await repository.registerDocument(unrelated);
      await repository.setCrossReference(
        from: ResourceReference.curriculumNode(
          sourceId: fixture.catalog.sourceId,
          nodeId: fixture.nodeId,
        ),
        to: attached.reference,
        kind: ResourceCrossReferenceKind.supportingDocument,
        isLinked: true,
      );

      await tester.pumpWidget(
        _host(
          fixture: fixture,
          child: AcademyStudyWorkspaceScreen(nodeId: fixture.nodeId),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Sources'));
      await tester.tap(find.text('Sources'));
      await tester.pumpAndSettle();

      expect(find.text('Attached reading'), findsOneWidget);
      expect(find.text('Cardiology companion.pdf'), findsOneWidget);
      expect(find.text('Unrelated neurology.pdf'), findsNothing);
      expect(find.text('18 pages · 4 KB'), findsOneWidget);
      expect(find.text('Attach a PDF to this lesson'), findsOneWidget);

      await tester.ensureVisible(find.byTooltip('Detach from this lesson'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Detach from this lesson'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('bookmarks, and annotations will not be deleted'),
        findsOneWidget,
      );
      await tester.tap(find.text('Detach'));
      await tester.pumpAndSettle();

      expect(find.text('Cardiology companion.pdf'), findsNothing);
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(
        LocalResourceWorkspaceRepository.stateKey,
      );
      final registry = jsonDecode(raw!) as Map<String, dynamic>;
      expect(registry['documents'], hasLength(2));
      final crossReference =
          (registry['crossReferences'] as Map<String, dynamic>).values.single
              as Map<String, dynamic>;
      expect(crossReference['isDeleted'], isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Persian workspace remains RTL and safe at 200 percent text', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 844));
    final fixture = await _fixture(locale: 'fa');

    await tester.pumpWidget(
      _host(
        fixture: fixture,
        locale: const Locale('fa'),
        textScaler: const TextScaler.linear(2),
        child: AcademyStudyWorkspaceScreen(nodeId: fixture.nodeId),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('فضای مطالعه'), findsOneWidget);
    expect(find.text('هدف یادگیری آزمایشی'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('فضای مطالعه'))),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<_WorkspaceFixture> _fixture({String locale = 'en'}) async {
  SharedPreferences.setMockInitialValues({'settings': '{"locale":"$locale"}'});
  final preferences = await SharedPreferences.getInstance();
  final store = PersistedStore(preferences);
  final catalog = buildAcademyTestCatalog();
  final course = catalog.courses.single;
  final chapter = catalog.childrenOf(course.node.id).single;
  final unit = catalog.childrenOf(chapter.node.id).single;
  final cluster = catalog.childrenOf(unit.node.id).single;
  final microNode = catalog.childrenOf(cluster.node.id).single;
  return _WorkspaceFixture(
    store: store,
    catalog: catalog,
    nodeId: microNode.node.id,
    result: CurriculumRuntimeBootstrapResult.ready(
      target: CurriculumActivationTarget.learner,
      catalog: catalog,
      integrityIssues: const [],
    ),
  );
}

Widget _host({
  required _WorkspaceFixture fixture,
  required Widget child,
  Locale locale = const Locale('en'),
  TextScaler textScaler = TextScaler.noScaling,
}) => ProviderScope(
  overrides: [
    sharedPreferencesProvider.overrideWithValue(fixture.store),
    curriculumRuntimeProvider.overrideWith((ref) async => fixture.result),
    ..._legacyResourceOverrides,
  ],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: locale,
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    supportedLocales: const [Locale('en'), Locale('fa')],
    theme: SynapseTheme.light(),
    darkTheme: SynapseTheme.dark(),
    themeMode: ThemeMode.dark,
    builder: (context, renderedChild) {
      final media = MediaQuery.of(context);
      return MediaQuery(
        data: media.copyWith(textScaler: textScaler, disableAnimations: true),
        child: renderedChild ?? const SizedBox.shrink(),
      );
    },
    home: child,
  ),
);

/// Workspace UI regression tests intentionally exercise the documented
/// fallback. Indexed activation is covered separately with an in-memory Drift
/// database, so these assertions can continue proving downgrade readability.
final _legacyResourceOverrides = [
  resourceWorkspaceRepositoryProvider.overrideWith((ref) {
    return LocalResourceWorkspaceRepository(
      store: ref.watch(resourceWorkspaceStoreProvider),
      clock: ref.watch(clockProvider),
      idSource: ref.watch(operationalIdSourceProvider),
    );
  }),
  resourceDocumentReadingStateRepositoryProvider.overrideWith((ref) {
    return LocalResourceDocumentReadingStateRepository(
      store: ref.watch(resourceDocumentReadingStateStoreProvider),
      clock: ref.watch(clockProvider),
    );
  }),
];

final class _WorkspaceFixture {
  const _WorkspaceFixture({
    required this.store,
    required this.catalog,
    required this.nodeId,
    required this.result,
  });

  final PersistedStore store;
  final CurriculumCatalogSnapshot catalog;
  final String nodeId;
  final CurriculumRuntimeBootstrapResult result;
}

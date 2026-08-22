import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synapse_app/dev/academy_synthetic_fixture.dart';
import 'package:synapse_app/features/academy/academy_screens.dart';
import 'package:synapse_app/features/academy/academy_study_workspace_screen.dart';
import 'package:synapse_app/state/app_providers.dart';
import 'package:synapse_app/state/curriculum_provider.dart';
import 'package:synapse_app/state/persistence.dart';
import 'package:synapse_services/synapse_services.dart';
import 'package:synapse_ui/synapse_ui.dart';

void main() {
  testWidgets('Academy compact English implementation specimen', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 844));
    final fixture = await _fixture(locale: 'en');

    await tester.pumpWidget(
      _visualHost(
        fixture: fixture,
        locale: const Locale('en'),
        child: const AcademyHomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/academy-home-compact-en.png'),
    );
  });

  testWidgets('Academy medium Persian course-path implementation specimen', (
    tester,
  ) async {
    await _setViewport(tester, const Size(820, 1024));
    final fixture = await _fixture(locale: 'fa');
    final courseId = fixture.result.catalog!.courses.single.node.id;

    await tester.pumpWidget(
      _visualHost(
        fixture: fixture,
        locale: const Locale('fa'),
        child: AcademyCourseScreen(courseId: courseId),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/academy-course-medium-fa.png'),
    );
  });

  testWidgets('Academy wide English session implementation specimen', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1280, 800));
    final fixture = await _fixture(locale: 'en');
    final catalog = fixture.result.catalog!;
    final course = catalog.courses.single;
    final chapter = catalog.childrenOf(course.node.id).single;
    final unit = catalog.childrenOf(chapter.node.id).single;
    final cluster = catalog.childrenOf(unit.node.id).single;
    final microNode = catalog.childrenOf(cluster.node.id).single;
    final microLesson = catalog.microLessonForNode(microNode.node.id)!;
    final session = catalog.sessionsForMicroLesson(microLesson.id).single;

    await tester.pumpWidget(
      _visualHost(
        fixture: fixture,
        locale: const Locale('en'),
        child: AcademySessionScreen(
          microLessonNodeId: microNode.node.id,
          sessionId: session.id,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/academy-session-wide-en.png'),
    );
  });

  testWidgets('Academy compact English study workspace specimen', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 844));
    final fixture = await _fixture(locale: 'en');
    final nodeId = _microLessonNodeId(fixture.result.catalog!);

    await tester.pumpWidget(
      _visualHost(
        fixture: fixture,
        locale: const Locale('en'),
        child: AcademyStudyWorkspaceScreen(nodeId: nodeId),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/academy-workspace-compact-en.png'),
    );
  });

  testWidgets('Academy wide English study workspace specimen', (tester) async {
    await _setViewport(tester, const Size(1280, 800));
    final fixture = await _fixture(locale: 'en');
    final nodeId = _microLessonNodeId(fixture.result.catalog!);

    await tester.pumpWidget(
      _visualHost(
        fixture: fixture,
        locale: const Locale('en'),
        child: AcademyStudyWorkspaceScreen(nodeId: nodeId),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/academy-workspace-wide-en.png'),
    );
  });

  testWidgets('Academy compact Deep Study document specimen', (tester) async {
    await _setViewport(tester, const Size(390, 844));
    final fixture = await _fixture(locale: 'en');
    final nodeId = _microLessonNodeId(fixture.result.catalog!);

    await tester.pumpWidget(
      _visualHost(
        fixture: fixture,
        locale: const Locale('en'),
        child: AcademyStudyWorkspaceScreen(nodeId: nodeId),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('academy-deep-study-document')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/academy-deep-study-compact-en.png'),
    );
  });

  testWidgets('Academy wide Deep Study document specimen', (tester) async {
    await _setViewport(tester, const Size(1280, 800));
    final fixture = await _fixture(locale: 'en');
    final nodeId = _microLessonNodeId(fixture.result.catalog!);

    await tester.pumpWidget(
      _visualHost(
        fixture: fixture,
        locale: const Locale('en'),
        child: AcademyStudyWorkspaceScreen(nodeId: nodeId),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('academy-deep-study-document')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/academy-deep-study-wide-en.png'),
    );
  });
}

String _microLessonNodeId(CurriculumCatalogSnapshot catalog) {
  final course = catalog.courses.single;
  final chapter = catalog.childrenOf(course.node.id).single;
  final unit = catalog.childrenOf(chapter.node.id).single;
  final cluster = catalog.childrenOf(unit.node.id).single;
  return catalog.childrenOf(cluster.node.id).single.node.id;
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<_AcademyVisualFixture> _fixture({required String locale}) async {
  SharedPreferences.setMockInitialValues({'settings': '{"locale":"$locale"}'});
  final preferences = await SharedPreferences.getInstance();
  final store = PersistedStore(preferences);
  final catalog = buildAcademyTestCatalog();
  return _AcademyVisualFixture(
    store: store,
    result: CurriculumRuntimeBootstrapResult.ready(
      target: CurriculumActivationTarget.learner,
      catalog: catalog,
      integrityIssues: const [],
    ),
  );
}

Widget _visualHost({
  required _AcademyVisualFixture fixture,
  required Locale locale,
  required Widget child,
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
        data: media.copyWith(disableAnimations: true),
        child: renderedChild ?? const SizedBox.shrink(),
      );
    },
    home: child,
  ),
);

/// Geometry goldens verify the documented legacy-readable presentation path.
/// Indexed activation has its own in-memory Drift provider test; keeping native
/// storage plugins out of this host also makes the images deterministic.
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

final class _AcademyVisualFixture {
  const _AcademyVisualFixture({required this.store, required this.result});

  final PersistedStore store;
  final CurriculumRuntimeBootstrapResult result;
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synapse_app/features/academy/academy_screens.dart';
import 'package:synapse_app/features/academy/academy_study_workspace_loader.dart';
import 'package:synapse_app/router/routes.dart';
import 'package:synapse_app/state/app_providers.dart';
import 'package:synapse_app/state/curriculum_provider.dart';
import 'package:synapse_app/state/persistence.dart';
import 'package:synapse_services/synapse_services.dart';

import 'package:synapse_app/dev/academy_synthetic_fixture.dart';

void main() {
  testWidgets(
    'Academy keeps medical learning closed without a reviewed package',
    (tester) async {
      final store = await _store();
      final result = CurriculumRuntimeBootstrapResult.unavailable(
        target: CurriculumActivationTarget.learner,
        integrityIssues: const [],
      );

      await tester.pumpWidget(_host(store: store, result: result));
      await tester.pump();

      expect(
        find.text('A reviewed course package is not active yet'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Nothing has been substituted'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Academy session renders package labels and package feedback', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = await _store();
    final catalog = buildAcademyTestCatalog();
    final result = CurriculumRuntimeBootstrapResult.ready(
      target: CurriculumActivationTarget.learner,
      catalog: catalog,
      integrityIssues: const [],
    );
    final course = catalog.courses.single;
    final chapter = catalog.childrenOf(course.node.id).single;
    final unit = catalog.childrenOf(chapter.node.id).single;
    final cluster = catalog.childrenOf(unit.node.id).single;
    final microNode = catalog.childrenOf(cluster.node.id).single;
    final microLesson = catalog.microLessonForNode(microNode.node.id)!;
    final session = catalog.sessionsForMicroLesson(microLesson.id).single;

    await tester.pumpWidget(
      _host(
        store: store,
        result: result,
        child: AcademySessionScreen(
          microLessonNodeId: microNode.node.id,
          sessionId: session.id,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Preview synthetic prompt'), findsOneWidget);
    expect(find.text('Preview first option'), findsOneWidget);

    await tester.tap(find.text('Preview first option'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Check answer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Correct'), findsOneWidget);
    expect(find.text('Preview correct rationale'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Academy follows the package hierarchy from course path to session',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final store = await _store();
      final catalog = buildAcademyTestCatalog();
      final result = CurriculumRuntimeBootstrapResult.ready(
        target: CurriculumActivationTarget.learner,
        catalog: catalog,
        integrityIssues: const [],
      );

      await tester.pumpWidget(_routerHost(store: store, result: result));
      await tester.pumpAndSettle();

      expect(find.text('Course library'), findsOneWidget);
      expect(find.text('Preview course'), findsNWidgets(2));

      await tester.tap(find.text('Preview course').last);
      await tester.pumpAndSettle();

      expect(find.text('Next sequence'), findsOneWidget);
      expect(find.text('Preview chapter'), findsWidgets);
      expect(find.text('Preview unit'), findsWidgets);
      expect(find.text('Preview conceptCluster'), findsWidgets);
      expect(find.text('Preview microLesson'), findsWidgets);

      await tester.tap(find.text('Start learning path'));
      await tester.pumpAndSettle();

      expect(find.text('Preview synthetic prompt'), findsOneWidget);
      expect(find.text('Preview first option'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Academy keeps course path and contextual study workspace in one flow',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final store = await _store();
      final catalog = buildAcademyTestCatalog();
      final result = CurriculumRuntimeBootstrapResult.ready(
        target: CurriculumActivationTarget.learner,
        catalog: catalog,
        integrityIssues: const [],
      );
      final course = catalog.courses.single;

      await tester.pumpWidget(
        _routerHost(
          store: store,
          result: result,
          initialLocation: Routes.academyCourseFor(course.node.id),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open study workspace'));
      await tester.pumpAndSettle();
      expect(find.text('Study Workspace'), findsOneWidget);
      expect(find.text('Preview objective'), findsOneWidget);
      expect(find.text('Personal notes'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Next sequence'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Academy keeps Persian chrome, RTL direction, and package content together',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final store = await _store();
      await store.writeJson('settings', const {'locale': 'fa'});
      final catalog = buildAcademyTestCatalog();
      final result = CurriculumRuntimeBootstrapResult.ready(
        target: CurriculumActivationTarget.learner,
        catalog: catalog,
        integrityIssues: const [],
      );

      await tester.pumpWidget(
        _routerHost(store: store, result: result, locale: const Locale('fa')),
      );
      await tester.pumpAndSettle();

      expect(find.text('کتابخانهٔ درس‌ها'), findsOneWidget);
      expect(find.text('دوره آزمایشی'), findsNWidgets(2));
      expect(
        Directionality.of(tester.element(find.text('کتابخانهٔ درس‌ها'))),
        TextDirection.rtl,
      );

      await tester.tap(find.text('دوره آزمایشی').last);
      await tester.pumpAndSettle();

      expect(find.text('دنبالهٔ بعدی'), findsOneWidget);
      expect(find.text('فصل آزمایشی'), findsWidgets);
      expect(find.text('میکرودرس آزمایشی'), findsWidgets);

      await tester.tap(find.text('شروع مسیر یادگیری'));
      await tester.pumpAndSettle();

      expect(find.text('پرسش آزمایشی'), findsOneWidget);
      expect(find.text('گزینه اول آزمایشی'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Academy remains layout-safe with Persian at 200 percent text scale',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final store = await _store();
      await store.writeJson('settings', const {'locale': 'fa'});
      final catalog = buildAcademyTestCatalog();
      final result = CurriculumRuntimeBootstrapResult.ready(
        target: CurriculumActivationTarget.learner,
        catalog: catalog,
        integrityIssues: const [],
      );
      final course = catalog.courses.single;
      final chapter = catalog.childrenOf(course.node.id).single;
      final unit = catalog.childrenOf(chapter.node.id).single;
      final cluster = catalog.childrenOf(unit.node.id).single;
      final microNode = catalog.childrenOf(cluster.node.id).single;
      final microLesson = catalog.microLessonForNode(microNode.node.id)!;
      final session = catalog.sessionsForMicroLesson(microLesson.id).single;
      final locations = [
        Routes.academy,
        Routes.academyCourseFor(course.node.id),
        Routes.academySessionFor(microNode.node.id, session.id),
      ];

      for (final location in locations) {
        await tester.pumpWidget(
          KeyedSubtree(
            key: UniqueKey(),
            child: _routerHost(
              store: store,
              result: result,
              locale: const Locale('fa'),
              initialLocation: location,
              textScaler: const TextScaler.linear(2),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: location);
      }

      expect(find.text('پرسش آزمایشی'), findsOneWidget);
    },
  );

  testWidgets(
    'Academy restores a completed signed-session checkpoint after a restart',
    (tester) async {
      final store = await _store();
      final catalog = buildAcademyTestCatalog();
      final result = CurriculumRuntimeBootstrapResult.ready(
        target: CurriculumActivationTarget.learner,
        catalog: catalog,
        integrityIssues: const [],
      );
      final course = catalog.courses.single;
      final chapter = catalog.childrenOf(course.node.id).single;
      final unit = catalog.childrenOf(chapter.node.id).single;
      final cluster = catalog.childrenOf(unit.node.id).single;
      final microNode = catalog.childrenOf(cluster.node.id).single;
      final microLesson = catalog.microLessonForNode(microNode.node.id)!;
      final session = catalog.sessionsForMicroLesson(microLesson.id).single;
      final sessionScreen = AcademySessionScreen(
        microLessonNodeId: microNode.node.id,
        sessionId: session.id,
      );

      await tester.pumpWidget(
        _host(store: store, result: result, child: sessionScreen),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('Preview first option'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Check answer'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Finish session'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Completion resolves to one calm, durable surface. It must not stack a
      // dialog over the completed checkpoint and announce the same result
      // twice to assistive technology.
      expect(find.text('Session complete'), findsOneWidget);
      expect(find.text('Back to path'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.textContaining('reached the end of this reviewed session'),
        findsOneWidget,
      );

      final preferences = await SharedPreferences.getInstance();
      final rawRegistry = preferences.getString(
        LocalCurriculumSessionProgressRepository.stateKey,
      );
      expect(rawRegistry, isNotNull);
      final registry = jsonDecode(rawRegistry!) as Map<String, dynamic>;
      final records = registry['records'] as Map<String, dynamic>;
      final record = records.values.single as Map<String, dynamic>;
      expect(record['phase'], 'completed');
      expect(record['completionReceiptId'], isNotEmpty);
      expect(record['selectedOptionId'], isNull);

      // A fresh provider container uses the persisted release-bound checkpoint
      // rather than replaying the completed interaction or minting a reward.
      await tester.pumpWidget(
        KeyedSubtree(
          key: UniqueKey(),
          child: _host(store: store, result: result, child: sessionScreen),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Session complete'), findsOneWidget);
      expect(find.text('Back to path'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.textContaining('already recorded as complete on this device'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Future<PersistedStore> _store() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  return PersistedStore(preferences);
}

Widget _host({
  required PersistedStore store,
  required CurriculumRuntimeBootstrapResult result,
  Widget? child,
}) => ProviderScope(
  overrides: [
    sharedPreferencesProvider.overrideWithValue(store),
    curriculumRuntimeProvider.overrideWith((ref) async => result),
  ],
  child: MaterialApp(home: child ?? const AcademyHomeScreen()),
);

Widget _routerHost({
  required PersistedStore store,
  required CurriculumRuntimeBootstrapResult result,
  Locale locale = const Locale('en'),
  String initialLocation = Routes.academy,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: Routes.academy,
        builder: (_, _) => const AcademyHomeScreen(),
      ),
      GoRoute(
        path: Routes.academyCourse,
        builder: (_, state) => AcademyCourseScreen(
          courseId: state.uri.queryParameters['courseId'] ?? '',
        ),
      ),
      GoRoute(
        path: Routes.academySession,
        builder: (_, state) => AcademySessionScreen(
          microLessonNodeId:
              state.uri.queryParameters['microLessonNodeId'] ?? '',
          sessionId: state.uri.queryParameters['sessionId'] ?? '',
        ),
      ),
      GoRoute(
        path: Routes.academyWorkspace,
        builder: (_, state) => AcademyStudyWorkspaceLoader(
          nodeId: state.uri.queryParameters['nodeId'] ?? '',
        ),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(store),
      curriculumRuntimeProvider.overrideWith((ref) async => result),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      locale: locale,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('en'), Locale('fa')],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child ?? const SizedBox.shrink(),
      ),
    ),
  );
}

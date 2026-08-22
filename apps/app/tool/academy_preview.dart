import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_app/dev/academy_synthetic_fixture.dart';
import 'package:synapse_app/features/academy/academy_resource_document_screen.dart';
import 'package:synapse_app/features/academy/academy_screens.dart';
import 'package:synapse_app/features/academy/academy_study_workspace_loader.dart';
import 'package:synapse_app/router/routes.dart';
import 'package:synapse_app/state/curriculum_provider.dart';
import 'package:synapse_app/state/settings_provider.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_foundation/synapse_foundation.dart';
import 'package:synapse_services/synapse_services.dart';
import 'package:synapse_ui/synapse_ui.dart';

const _previewLocale = String.fromEnvironment(
  'SYNAPSE_PREVIEW_LOCALE',
  defaultValue: 'en',
);

void main() {
  final catalog = buildAcademyTestCatalog();
  final result = CurriculumRuntimeBootstrapResult.ready(
    target: CurriculumActivationTarget.learner,
    catalog: catalog,
    integrityIssues: const [],
  );
  final progress = LocalCurriculumSessionProgressRepository(
    store: MemoryKeyValueStore(),
    clock: const SystemClock(),
    idSource: SequenceIdSource(
      List.generate(64, (index) => 'preview-receipt-${index + 1}'),
    ),
  );
  final workspace = LocalCurriculumStudyWorkspaceRepository(
    store: MemoryKeyValueStore(),
    clock: const SystemClock(),
    idSource: SequenceIdSource(
      List.generate(64, (index) => 'preview-workspace-${index + 1}'),
    ),
  );
  final curriculumReading = LocalCurriculumReadingStateRepository(
    store: MemoryKeyValueStore(),
    clock: const SystemClock(),
  );
  final resources = LocalResourceWorkspaceRepository(
    store: MemoryKeyValueStore(),
    clock: const SystemClock(),
    idSource: SequenceIdSource(
      List.generate(64, (index) => 'preview-resource-${index + 1}'),
    ),
  );
  final documentReading = LocalResourceDocumentReadingStateRepository(
    store: MemoryKeyValueStore(),
    clock: const SystemClock(),
  );
  runApp(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(_PreviewSettingsNotifier.new),
        curriculumRuntimeProvider.overrideWith((ref) async => result),
        curriculumSessionProgressRepositoryProvider.overrideWithValue(progress),
        curriculumStudyWorkspaceRepositoryProvider.overrideWithValue(workspace),
        curriculumReadingStateRepositoryProvider.overrideWithValue(
          curriculumReading,
        ),
        resourceWorkspaceRepositoryProvider.overrideWithValue(resources),
        resourceDocumentReadingStateRepositoryProvider.overrideWithValue(
          documentReading,
        ),
      ],
      child: const _AcademyPreviewApp(),
    ),
  );
}

final class _PreviewSettingsNotifier extends SettingsNotifier {
  @override
  UserPrefs build() => UserPrefs(
    locale: _previewLocale.toLowerCase().startsWith('fa') ? 'fa' : 'en',
    theme: ThemeModePref.dark,
    motionMode: MotionModePref.reduced,
  );
}

class _AcademyPreviewApp extends StatelessWidget {
  const _AcademyPreviewApp();

  @override
  Widget build(BuildContext context) {
    final locale = _previewLocale.toLowerCase().startsWith('fa')
        ? const Locale('fa')
        : const Locale('en');
    final router = GoRouter(
      initialLocation: Routes.academy,
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
        GoRoute(
          path: Routes.academyDocument,
          builder: (_, state) => AcademyResourceDocumentScreen(
            documentId: state.uri.queryParameters['documentId'] ?? '',
            nodeId: state.uri.queryParameters['nodeId'],
          ),
        ),
      ],
    );
    return MaterialApp.router(
      title: 'Synapse Academy implementation preview',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      locale: locale,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('en'), Locale('fa')],
      theme: SynapseTheme.light(),
      darkTheme: SynapseTheme.dark(),
      themeMode: ThemeMode.dark,
    );
  }
}

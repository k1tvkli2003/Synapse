import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_core/synapse_core.dart';

import '../features/algorithms/algorithms_screens.dart';
import '../features/arena/arena_screens.dart';
import '../features/cards/cards_screens.dart';
import '../features/cases/cases_screens.dart';
import '../features/common/coming_soon.dart';
import '../features/copilot/copilot_screen.dart';
import '../features/ecg/ecg_screens.dart';
import '../features/home/concept_hub_screen.dart';
import '../features/home/hub_screen.dart';
import '../features/home/search_screen.dart';
import '../features/home/sub_hub_screen.dart';
import '../features/labs/labs_screens.dart';
import '../features/mnemonics/mnemonics_screens.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/onboarding/splash_screen.dart';
import '../features/orlab/orlab_screens.dart';
import '../features/profile/profile_screens.dart';
import '../features/review/review_screen.dart';
import '../features/social/social_screens.dart';
import '../features/sounds/sounds_screens.dart';
import '../features/terms/terms_screens.dart';
import '../shell/adaptive_shell.dart';
import 'routes.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// A single stable router instance for the app's lifetime.
final routerProvider = Provider<GoRouter>((ref) => buildRouter());

GoRouter buildRouter() {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.splash,
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.onboarding, builder: (_, _) => const OnboardingScreen()),

      // Full-screen surfaces above the shell.
      GoRoute(path: Routes.search, builder: (_, _) => const SearchScreen()),
      GoRoute(path: Routes.copilot, builder: (_, _) => const CopilotScreen()),
      GoRoute(path: Routes.review, builder: (_, _) => const ReviewScreen()),
      GoRoute(path: '/concept/:conceptId', builder: (_, s) => ConceptHubScreen(conceptId: s.pathParameters['conceptId']!)),
      GoRoute(path: Routes.cases, builder: (_, _) => const CasesListScreen()),
      GoRoute(path: '/cases/:caseId', builder: (_, s) => CasePlayerScreen(caseId: s.pathParameters['caseId']!)),

      // Drills / players (full-screen).
      GoRoute(path: '/learn/terms/lesson/:lessonId', builder: (_, s) => LessonScreen(lessonId: s.pathParameters['lessonId']!)),
      GoRoute(path: Routes.cardsStudy, builder: (_, _) => const ReviewScreen()),
      GoRoute(path: Routes.ecgDrill, builder: (_, _) => const EcgDrillScreen()),
      GoRoute(path: '/clinical/ecg/case/:caseId', builder: (_, s) => EcgDrillScreen(singleCaseId: s.pathParameters['caseId'])),
      GoRoute(path: Routes.soundsQuiz, builder: (_, _) => const SoundsQuizScreen()),
      GoRoute(path: '/clinical/algorithms/:algorithmId/play', builder: (_, s) => AlgorithmPlayerScreen(algorithmId: s.pathParameters['algorithmId']!)),
      GoRoute(path: Routes.arenaBattle, builder: (_, _) => const ArenaBattleScreen()),

      // The five-branch adaptive shell.
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AdaptiveShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.home, builder: (_, _) => const HubScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.learn,
              builder: (_, _) => const SubHubScreen(branch: ShellBranch.learn, title: 'Learn'),
              routes: [
                GoRoute(path: 'terms', builder: (_, _) => const TermsHomeScreen()),
                GoRoute(path: 'cards', builder: (_, _) => const CardsHomeScreen()),
                GoRoute(path: 'cards/deck/:deckId', builder: (_, s) => DeckScreen(deckId: s.pathParameters['deckId']!)),
                GoRoute(path: 'mnemonics', builder: (_, _) => const MnemonicsListScreen()),
                GoRoute(path: 'mnemonics/new', builder: (_, _) => const MnemonicsListScreen()),
                GoRoute(path: 'mnemonics/:mnemonicId', builder: (_, s) => MnemonicDetailScreen(mnemonicId: s.pathParameters['mnemonicId']!)),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.clinical,
              builder: (_, _) => const SubHubScreen(branch: ShellBranch.clinical, title: 'Clinical'),
              routes: [
                GoRoute(path: 'ecg', builder: (_, _) => const EcgHomeScreen()),
                GoRoute(path: 'sounds', builder: (_, _) => const SoundsHomeScreen()),
                GoRoute(path: 'sounds/:soundId', builder: (_, s) => SoundDetailScreen(soundId: s.pathParameters['soundId']!)),
                GoRoute(path: 'labs', builder: (_, _) => const LabsHomeScreen()),
                GoRoute(path: 'labs/panel/:panel', builder: (_, s) => LabPanelScreen(panel: LabPanelType.tryParse(s.pathParameters['panel'] ?? '') ?? LabPanelType.bmp)),
                GoRoute(path: 'algorithms', builder: (_, _) => const AlgorithmsHomeScreen()),
                GoRoute(path: 'algorithms/:algorithmId', builder: (_, s) => AlgorithmPlayerScreen(algorithmId: s.pathParameters['algorithmId']!)),
                GoRoute(path: 'or-lab', builder: (_, _) => const OrLabHomeScreen()),
                GoRoute(path: 'or-lab/:dramaId', builder: (_, s) => DramaPlayerScreen(dramaId: s.pathParameters['dramaId']!)),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.social,
              builder: (_, _) => const SubHubScreen(branch: ShellBranch.social, title: 'Social'),
              routes: [
                GoRoute(path: 'rounds', builder: (_, _) => const RoundsFeedScreen()),
                GoRoute(path: 'rounds/:roundId', builder: (_, s) => RoundDetailScreen(roundId: s.pathParameters['roundId']!)),
                GoRoute(path: 'buddies', builder: (_, _) => const BuddiesScreen()),
                GoRoute(path: 'arena', builder: (_, _) => const ArenaHubScreen()),
                GoRoute(path: 'arena/deck', builder: (_, _) => ComingSoonScreen(title: 'Deck builder', accent: Color(ModuleKey.arena.accentHex))),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.profile, builder: (_, _) => const ProfileScreen()),
          ]),
        ],
      ),

      // Global account routes (reachable from anywhere).
      GoRoute(path: Routes.rewards, builder: (_, _) => const RewardsScreen()),
      GoRoute(path: Routes.achievements, builder: (_, _) => const AchievementsScreen()),
      GoRoute(path: Routes.quests, builder: (_, _) => const QuestsScreen()),
      GoRoute(path: Routes.settings, builder: (_, _) => const SettingsScreen()),
      GoRoute(path: Routes.notifications, builder: (_, _) => const NotificationsScreen()),
      GoRoute(path: Routes.insights, builder: (_, _) => const InsightsScreen()),
    ],
    errorBuilder: (_, _) => const ComingSoonScreen(title: 'Not found'),
  );
}

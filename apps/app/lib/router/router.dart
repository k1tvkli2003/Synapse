import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_core/synapse_core.dart';

import '../features/admin/admin_screens.dart';
import '../features/algorithms/algorithms_screens.dart';
import '../features/arena/arena_screens.dart';
import '../features/cards/cards_screens.dart';
import '../features/cases/cases_screens.dart';
import '../features/common/coming_soon.dart';
import '../features/community/community_screens.dart';
import '../features/copilot/copilot_screen.dart';
import '../features/ecg/ecg_screens.dart';
import '../features/home/concept_hub_screen.dart';
import '../features/home/hub_screen.dart';
import '../features/home/search_screen.dart';
import '../features/home/sub_hub_screen.dart';
import '../features/integrations/import_screen.dart';
import '../features/labs/labs_screens.dart';
import '../features/library/diseases_screens.dart';
import '../features/library/drugs_screens.dart';
import '../features/library/library_banks.dart';
import '../features/library/library_hub.dart';
import '../features/library/tools_screens.dart';
import '../features/mnemonics/mnemonics_screens.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/onboarding/splash_screen.dart';
import '../features/org/org_screens.dart';
import '../features/orlab/orlab_screens.dart';
import '../features/osce/osce_screens.dart';
import '../features/plan/plan_screen.dart';
import '../features/profile/profile_screens.dart';
import '../features/review/review_screen.dart';
import '../features/settings/settings_screens.dart';
import '../features/shop/shop_screens.dart';
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

      // Study plan (prompt 35) + OSCE simulator (prompt 52) — full-screen.
      GoRoute(path: Routes.plan, builder: (_, _) => const PlanScreen()),
      GoRoute(path: '/plan/track/:id', builder: (_, s) => TrackScreen(id: s.pathParameters['id']!)),
      GoRoute(path: Routes.osce, builder: (_, _) => const OsceListScreen()),
      GoRoute(path: '/clinical/osce/:id', builder: (_, s) => OsceStationScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/clinical/osce/:id/play', builder: (_, s) => OscePlayScreen(id: s.pathParameters['id']!)),

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

      // ---- Library / reference banks (prompt 45–48) ----
      GoRoute(path: Routes.library, builder: (_, _) => const LibraryHubScreen()),
      GoRoute(path: Routes.diseases, builder: (_, _) => const DiseasesListScreen()),
      GoRoute(
        path: '/library/diseases/compare',
        builder: (_, s) => DiseaseCompareScreen(
          ids: (s.uri.queryParameters['ids'] ?? '').split(',').where((e) => e.isNotEmpty).toList(),
        ),
      ),
      GoRoute(path: '/library/diseases/:id', builder: (_, s) => DiseaseDetailScreen(id: s.pathParameters['id']!)),
      GoRoute(path: Routes.drugInteractions, builder: (_, _) => const InteractionCheckerScreen()),
      GoRoute(path: Routes.drugs, builder: (_, _) => const DrugsListScreen()),
      GoRoute(path: '/library/drugs/class/:id', builder: (_, s) => DrugClassScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/library/drugs/:id', builder: (_, s) => DrugDetailScreen(id: s.pathParameters['id']!)),
      GoRoute(path: Routes.tools, builder: (_, _) => const ToolsListScreen()),
      GoRoute(path: '/library/tools/:id', builder: (_, s) => ToolDetailScreen(id: s.pathParameters['id']!)),
      for (final kind in LibraryKind.values) ...[
        GoRoute(path: kind.route, builder: (_, _) => LibraryBankScreen(kind: kind)),
        GoRoute(path: '${kind.route}/:id', builder: (_, s) => LibraryEntryScreen(kind: kind, id: s.pathParameters['id']!)),
      ],

      // ---- Personalization & monetization (prompt 39 / 40) ----
      GoRoute(path: Routes.shop, builder: (_, _) => const ShopScreen()),
      GoRoute(path: Routes.pro, builder: (_, _) => const ProScreen()),
      GoRoute(path: Routes.profileCustomize, builder: (_, _) => const CustomizeScreen()),

      // ---- Settings sub-screens (prompt 42) ----
      GoRoute(path: '/settings/data', builder: (_, _) => const PrivacyDataScreen()),
      GoRoute(path: '/settings/privacy', builder: (_, _) => const PrivacyDataScreen()),
      GoRoute(path: '/settings/redeem', builder: (_, _) => const RedeemScreen()),
      GoRoute(path: '/settings/subscription', builder: (_, _) => const ProScreen()),
      GoRoute(path: '/legal/:doc', builder: (_, s) => LegalScreen(doc: s.pathParameters['doc']!)),

      // ---- Community, rooms, events & leaderboard (prompt 43) ----
      GoRoute(path: Routes.rooms, builder: (_, _) => const RoomsScreen()),
      GoRoute(path: '/social/rooms/:id', builder: (_, s) => RoomScreen(id: s.pathParameters['id']!)),
      GoRoute(path: Routes.community, builder: (_, _) => const CommunityScreen()),
      GoRoute(path: Routes.events, builder: (_, _) => const EventsScreen()),
      GoRoute(path: Routes.leaderboard, builder: (_, _) => const LeaderboardScreen()),

      // ---- CMS / admin + authoring (prompt 41) ----
      GoRoute(path: Routes.admin, builder: (_, _) => const AdminScreen()),
      GoRoute(path: '/admin/:section', builder: (_, s) => AdminListScreen(section: s.pathParameters['section']!)),
      GoRoute(path: Routes.create, builder: (_, _) => const CreateScreen()),

      // ---- Institutional / cohort mode (prompt 55) ----
      GoRoute(path: Routes.classes, builder: (_, _) => const ClassesScreen()),
      GoRoute(path: Routes.org, builder: (_, _) => const OrgScreen()),

      // ---- Account, inbox & chat (prompt 24 / 31 §F / 42) ----
      GoRoute(path: '/profile/edit', builder: (_, _) => const ProfileEditScreen()),
      GoRoute(path: '/profile/stats', builder: (_, _) => const InsightsScreen()),
      GoRoute(path: '/u/:handle', builder: (_, _) => const ProfileScreen()),
      GoRoute(path: Routes.inbox, builder: (_, _) => const InboxScreen()),
      GoRoute(path: '/chat', builder: (_, _) => const InboxScreen()),
      GoRoute(path: '/chat/:threadId', builder: (_, s) => ChatScreen(threadId: s.pathParameters['threadId'])),

      // ---- Integrations: import / export (prompt 44) ----
      GoRoute(path: '/learn/cards/import', builder: (_, _) => const ImportExportScreen()),
      GoRoute(path: '/integrations', builder: (_, _) => const ImportExportScreen()),

      // ---- Remaining route-map paths (prompt 31) — every path resolves. ----
      // Copilot threads.
      GoRoute(path: '/copilot/:threadId', builder: (_, _) => const CopilotScreen()),

      // Terms sub-routes.
      GoRoute(path: '/learn/terms/unit/:unitId', builder: (_, _) => const TermsHomeScreen()),
      GoRoute(path: '/learn/terms/practice', builder: (_, _) => const TermsHomeScreen()),
      GoRoute(path: '/learn/terms/stories', builder: (_, _) => ComingSoonScreen(title: 'Terms Stories', accent: Color(ModuleKey.terms.accentHex))),
      GoRoute(path: '/learn/terms/leaderboard', builder: (_, _) => const LeaderboardScreen()),

      // Cards sub-routes.
      GoRoute(path: '/learn/cards/graph', builder: (_, _) => ComingSoonScreen(title: 'Knowledge graph', accent: Color(ModuleKey.cards.accentHex))),
      GoRoute(path: '/learn/cards/deck/:deckId/edit', builder: (_, _) => ComingSoonScreen(title: 'Edit deck', accent: Color(ModuleKey.cards.accentHex))),
      GoRoute(path: '/learn/cards/card/:cardId/edit', builder: (_, _) => ComingSoonScreen(title: 'Edit card', accent: Color(ModuleKey.cards.accentHex))),

      // Mnemonics sub-routes.
      GoRoute(path: '/learn/mnemonics/collections', builder: (_, _) => const MnemonicsListScreen()),
      GoRoute(path: '/learn/mnemonics/collections/:collectionId', builder: (_, _) => const MnemonicsListScreen()),
      GoRoute(path: '/learn/mnemonics/mine', builder: (_, _) => const MnemonicsListScreen()),
      GoRoute(path: '/learn/mnemonics/tag/:tagId', builder: (_, _) => const MnemonicsListScreen()),
      GoRoute(path: '/learn/mnemonics/search', builder: (_, _) => const SearchScreen()),

      // ECG sub-routes.
      GoRoute(path: '/clinical/ecg/review', builder: (_, _) => const EcgDrillScreen()),
      GoRoute(path: '/clinical/ecg/generative', builder: (_, _) => const GenerativeEcgScreen()),
      GoRoute(path: '/clinical/ecg/stats', builder: (_, _) => const InsightsScreen()),

      // Sounds sub-routes.
      GoRoute(path: '/clinical/sounds/library', builder: (_, _) => const SoundsHomeScreen()),
      GoRoute(path: '/clinical/sounds/simulator', builder: (_, _) => ComingSoonScreen(title: 'Sound simulator', accent: Color(ModuleKey.sounds.accentHex))),
      GoRoute(path: '/clinical/sounds/stats', builder: (_, _) => const InsightsScreen()),

      // Labs sub-routes.
      GoRoute(path: '/clinical/labs/history', builder: (_, _) => ComingSoonScreen(title: 'Lab history', accent: Color(ModuleKey.labs.accentHex))),
      GoRoute(path: '/clinical/labs/result/:evaluationId', builder: (_, _) => const LabsHomeScreen()),
      GoRoute(path: '/clinical/labs/ruleset', builder: (_, _) => const LabRulesetScreen()),
      GoRoute(path: '/clinical/labs/learn', builder: (_, _) => const LabsHomeScreen()),

      // Algorithms sub-routes.
      GoRoute(path: '/clinical/algorithms/new', builder: (_, _) => const CreateScreen()),
      GoRoute(path: '/clinical/algorithms/:algorithmId/edit', builder: (_, _) => ComingSoonScreen(title: 'Edit algorithm', accent: Color(ModuleKey.algorithms.accentHex))),
      GoRoute(path: '/clinical/algorithms/sessions', builder: (_, _) => ComingSoonScreen(title: 'Saved sessions', accent: Color(ModuleKey.algorithms.accentHex))),
      GoRoute(path: '/clinical/algorithms/bookmarks', builder: (_, _) => ComingSoonScreen(title: 'Bookmarks', accent: Color(ModuleKey.algorithms.accentHex))),

      // OR Lab sub-routes.
      GoRoute(path: '/clinical/or-lab/:dramaId/play', builder: (_, s) => DramaPlayerScreen(dramaId: s.pathParameters['dramaId']!)),
      GoRoute(path: '/clinical/or-lab/:dramaId/sim', builder: (_, _) => ComingSoonScreen(title: 'OR visual mode', accent: Color(ModuleKey.orLab.accentHex))),
      GoRoute(path: '/clinical/or-lab/:dramaId/transcript', builder: (_, s) => DramaPlayerScreen(dramaId: s.pathParameters['dramaId']!)),

      // Rounds sub-routes.
      GoRoute(path: '/social/rounds/discover', builder: (_, _) => const RoundsFeedScreen()),
      GoRoute(path: '/social/rounds/record', builder: (_, _) => ComingSoonScreen(title: 'Record a round', accent: Color(ModuleKey.rounds.accentHex))),
      GoRoute(path: '/social/rounds/:roundId/comments', builder: (_, s) => RoundDetailScreen(roundId: s.pathParameters['roundId']!)),
      GoRoute(path: '/social/rounds/:roundId/remix', builder: (_, _) => ComingSoonScreen(title: 'Remix', accent: Color(ModuleKey.rounds.accentHex))),

      // Buddies sub-routes.
      GoRoute(path: '/social/buddies/discover', builder: (_, _) => const BuddiesScreen()),
      GoRoute(path: '/social/buddies/requests', builder: (_, _) => const BuddiesScreen()),
      GoRoute(path: '/social/buddies/matches', builder: (_, _) => const InboxScreen()),
      GoRoute(path: '/social/buddies/groups', builder: (_, _) => ComingSoonScreen(title: 'Study groups', accent: Color(ModuleKey.buddies.accentHex))),
      GoRoute(path: '/social/buddies/groups/:groupId', builder: (_, _) => ComingSoonScreen(title: 'Study group', accent: Color(ModuleKey.buddies.accentHex))),
      GoRoute(path: '/social/buddies/:userId', builder: (_, s) => ChatScreen(threadId: s.pathParameters['userId'])),

      // Arena sub-routes.
      GoRoute(path: '/social/arena/collection', builder: (_, _) => ComingSoonScreen(title: 'Card collection', accent: Color(ModuleKey.arena.accentHex))),
      GoRoute(path: '/social/arena/capsules', builder: (_, _) => ComingSoonScreen(title: 'Capsules', accent: Color(ModuleKey.arena.accentHex))),
      GoRoute(path: '/social/arena/shop', builder: (_, _) => const ShopScreen()),
      GoRoute(path: '/social/arena/clan', builder: (_, _) => ComingSoonScreen(title: 'Clan', accent: Color(ModuleKey.arena.accentHex))),
      GoRoute(path: '/social/arena/clan/:clanId', builder: (_, _) => ComingSoonScreen(title: 'Clan', accent: Color(ModuleKey.arena.accentHex))),
      GoRoute(path: '/social/arena/leaderboard', builder: (_, _) => const LeaderboardScreen()),
      GoRoute(path: '/social/arena/season', builder: (_, _) => const EventsScreen()),
      GoRoute(path: '/social/arena/replay/:replayId', builder: (_, _) => ComingSoonScreen(title: 'Replay', accent: Color(ModuleKey.arena.accentHex))),
    ],
    errorBuilder: (_, _) => const ComingSoonScreen(title: 'Not found'),
  );
}

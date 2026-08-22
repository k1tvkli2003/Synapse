import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_core/synapse_core.dart';

/// The single source of truth for paths + typed navigation helpers (prompt 31).
/// Modules navigate through these helpers only — never raw strings.
class Routes {
  const Routes._();

  // Outside the shell
  static const splash = '/splash';
  static const onboarding = '/onboarding';

  // Academy — the signed, package-driven medical learning path. Query
  // parameters keep stable curriculum IDs safe even when future IDs contain
  // URI-reserved characters.
  static const academy = '/academy';
  static const academyCourse = '/academy/course';
  static const academySession = '/academy/session';
  static const academyWorkspace = '/academy/workspace';
  static const academyDocument = '/academy/document';
  static String academyCourseFor(String courseId) => Uri(
    path: academyCourse,
    queryParameters: {'courseId': courseId},
  ).toString();
  static String academySessionFor(String microLessonNodeId, String sessionId) =>
      Uri(
        path: academySession,
        queryParameters: {
          'microLessonNodeId': microLessonNodeId,
          'sessionId': sessionId,
        },
      ).toString();
  static String academyWorkspaceFor(String nodeId) => Uri(
    path: academyWorkspace,
    queryParameters: {'nodeId': nodeId},
  ).toString();
  static String academyDocumentFor(
    ResourceDocumentId documentId,
    String nodeId,
  ) => Uri(
    path: academyDocument,
    queryParameters: {'documentId': documentId, 'nodeId': nodeId},
  ).toString();

  // Home branch
  static const home = '/home';
  static const review = '/review';
  static const search = '/search';
  static const copilot = '/copilot';
  static String concept(ConceptId id) => '/concept/$id';
  static String caseDetail(String id) => '/cases/$id';
  static const cases = '/cases';

  // Learn branch
  static const learn = '/learn';
  static const terms = '/learn/terms';
  static String termsLesson(String id) => '/learn/terms/lesson/$id';
  static const cards = '/learn/cards';
  static String deck(String id) => '/learn/cards/deck/$id';
  static const cardsStudy = '/learn/cards/study';
  static const cardsGraph = '/learn/cards/graph';
  static const mnemonics = '/learn/mnemonics';
  static String mnemonic(String id) => '/learn/mnemonics/$id';
  static const mnemonicNew = '/learn/mnemonics/new';

  // Clinical branch
  static const clinical = '/clinical';
  static const ecg = '/clinical/ecg';
  static const ecgDrill = '/clinical/ecg/drill';
  static String ecgCase(String id) => '/clinical/ecg/case/$id';
  static const sounds = '/clinical/sounds';
  static String sound(String id) => '/clinical/sounds/$id';
  static const soundsQuiz = '/clinical/sounds/quiz';
  static const labs = '/clinical/labs';
  static String labPanel(String panel) => '/clinical/labs/panel/$panel';
  static const algorithms = '/clinical/algorithms';
  static String algorithm(String id) => '/clinical/algorithms/$id';
  static String algorithmPlay(String id) => '/clinical/algorithms/$id/play';
  static const orLab = '/clinical/or-lab';
  static String drama(String id) => '/clinical/or-lab/$id';

  // Social branch
  static const social = '/social';
  static const rounds = '/social/rounds';
  static String round(String id) => '/social/rounds/$id';
  static const buddies = '/social/buddies';
  static const arena = '/social/arena';
  static const arenaBattle = '/social/arena/battle';
  static const arenaDeck = '/social/arena/deck';

  // Profile branch + global account
  static const profile = '/profile';
  static const rewards = '/rewards';
  static const achievements = '/achievements';
  static const quests = '/quests';
  static const settings = '/settings';
  static const notifications = '/notifications';
  static const insights = '/insights';
  static const inbox = '/inbox';

  // Library / reference banks (prompt 45–48)
  static const library = '/library';
  static const diseases = '/library/diseases';
  static String disease(String id) => '/library/diseases/$id';
  static String diseaseCompare(List<String> ids) =>
      '/library/diseases/compare?ids=${ids.join(',')}';
  static const drugs = '/library/drugs';
  static String drug(String id) => '/library/drugs/$id';
  static String drugClassRoute(String id) => '/library/drugs/class/$id';
  static const drugInteractions = '/library/drugs/interactions';
  static const tools = '/library/tools';
  static String tool(String id) => '/library/tools/$id';
  static String libraryEntryById(LibraryKind kind, String id) =>
      '${kind.route}/$id';

  // OSCE (prompt 52)
  static const osce = '/clinical/osce';
  static String osceStation(String id) => '/clinical/osce/$id';
  static String oscePlay(String id) => '/clinical/osce/$id/play';

  // Study plan (prompt 35)
  static const plan = '/plan';
  static String planTrack(String id) => '/plan/track/$id';

  // Personalization & monetization (prompt 39 / 40)
  static const shop = '/shop';
  static const profileCustomize = '/profile/customize';
  static const pro = '/pro';

  // Community (prompt 43)
  static const rooms = '/social/rooms';
  static String room(String id) => '/social/rooms/$id';
  static const community = '/social/community';
  static const events = '/social/events';
  static const leaderboard = '/social/leaderboard';

  // Institutional, CMS & authoring (prompt 41 / 55)
  static const classes = '/classes';
  static const org = '/org';
  static const admin = '/admin';
  static const create = '/create';
}

/// Convenience navigation extensions.
extension SynapseNav on BuildContext {
  void goConcept(ConceptId id) => push(Routes.concept(id));
  void goRoute(String route) => push(route);
}

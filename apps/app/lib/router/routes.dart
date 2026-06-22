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
}

/// Convenience navigation extensions.
extension SynapseNav on BuildContext {
  void goConcept(ConceptId id) => push(Routes.concept(id));
  void goRoute(String route) => push(route);
}

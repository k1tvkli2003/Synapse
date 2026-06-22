import 'package:synapse_core/synapse_core.dart';

/// Pairs an [Achievement] template with the counter metric that drives it.
class AchievementDef {
  const AchievementDef(this.achievement, this.metric);
  final Achievement achievement;
  final String metric;
}

/// The badge catalogue spanning every module (prompt 09 §2). Counters are kept
/// by the app (incremented from reward events) and synced here.
class AchievementCatalog {
  const AchievementCatalog._();

  static List<AchievementDef> all() => [
        // Streaks & levels (cross-module).
        _d('streak_3', 'Getting Warm', '3-day streak', 'flame', 3, 'streak'),
        _d('streak_7', 'On Fire', '7-day streak', 'flame', 7, 'streak'),
        _d('streak_30', 'Unstoppable', '30-day streak', 'flame', 30, 'streak'),
        _d('level_5', 'Apprentice', 'Reach level 5', 'star', 5, 'level'),
        _d('level_10', 'Clinician-in-Training', 'Reach level 10', 'star', 10, 'level'),
        _d('level_25', 'Attending', 'Reach level 25', 'crown', 25, 'level'),
        // Terms.
        _d('terms_1', 'First Words', 'Finish a Terms lesson', 'book', 1, 'terms.lesson', ModuleKey.terms),
        _d('terms_25', 'Polyglot', 'Finish 25 Terms lessons', 'book', 25, 'terms.lesson', ModuleKey.terms),
        // Cards.
        _d('cards_50', 'Memory Athlete', 'Review 50 cards', 'brain', 50, 'cards.review', ModuleKey.cards),
        _d('cards_200', 'Spaced Master', 'Review 200 cards', 'brain', 200, 'cards.review', ModuleKey.cards),
        // Mnemonics.
        _d('mnem_1', 'Hook Maker', 'Create a mnemonic', 'bolt', 1, 'mnemonics.created', ModuleKey.mnemonics),
        _d('mnem_100', 'Crowd Favourite', 'Earn 100 upvotes', 'medal', 100, 'mnemonics.upvotes', ModuleKey.mnemonics),
        // ECG.
        _d('ecg_10', 'Tracing Reader', 'Read 10 ECGs', 'heart', 10, 'ecg.correct', ModuleKey.ecg),
        _d('ecg_50', 'ECG Ace', 'Read 50 ECGs', 'heart', 50, 'ecg.correct', ModuleKey.ecg),
        // Sounds.
        _d('sounds_20', 'Good Ear', 'Identify 20 sounds', 'target', 20, 'sounds.correct', ModuleKey.sounds),
        // Labs.
        _d('labs_25', 'Panel Pro', 'Interpret 25 lab panels', 'check', 25, 'labs.eval', ModuleKey.labs),
        // Algorithms.
        _d('algo_10', 'Decision Maker', 'Complete 10 algorithms', 'target', 10, 'algorithms.completed', ModuleKey.algorithms),
        // Arena.
        _d('arena_1', 'First Blood', 'Win an Arena match', 'trophy', 1, 'arena.win', ModuleKey.arena),
        _d('arena_10', 'Resistance Buster', 'Win 10 Arena matches', 'trophy', 10, 'arena.win', ModuleKey.arena),
        // Rounds.
        _d('rounds_1', 'On Air', 'Post a round', 'bolt', 1, 'rounds.posted', ModuleKey.rounds),
        // Cases.
        _d('cases_1', 'First Patient', 'Complete a case', 'medal', 1, 'cases.completed', ModuleKey.copilot),
        _d('cases_10', 'Ward Veteran', 'Complete 10 cases', 'medal', 10, 'cases.completed'),
        // Mastery & review (cross-module).
        _d('mastered_10', 'Connected', 'Master 10 concepts', 'brain', 10, 'concepts.mastered'),
        _d('mastered_50', 'Web of Knowledge', 'Master 50 concepts', 'brain', 50, 'concepts.mastered'),
        _d('review_100', 'Reviewer', 'Do 100 reviews', 'check', 100, 'review.count'),
        _d('correct_500', 'Sharp', '500 correct answers', 'star', 500, 'total.correct'),
      ];

  static AchievementDef _d(
    String id,
    String title,
    String desc,
    String icon,
    int goal,
    String metric, [
    ModuleKey? module,
  ]) =>
      AchievementDef(
        Achievement(id: id, title: title, desc: desc, icon: icon, goal: goal, module: module),
        metric,
      );
}

class AchievementEngine {
  const AchievementEngine._();

  /// Sync achievement progress from a counter map, returning the refreshed list
  /// plus any newly unlocked badges (for celebration toasts).
  static AchievementSync sync(
    List<AchievementDef> defs,
    Map<String, int> counters,
    Map<String, DateTime> alreadyUnlocked,
  ) {
    final result = <Achievement>[];
    final newly = <Achievement>[];
    for (final def in defs) {
      final progress = counters[def.metric] ?? 0;
      final wasUnlocked = alreadyUnlocked.containsKey(def.achievement.id);
      final reached = progress >= def.achievement.goal;
      final unlockedAt = wasUnlocked
          ? alreadyUnlocked[def.achievement.id]
          : (reached ? DateTime.now() : null);
      final a = def.achievement.copyWith(
        progress: progress.clamp(0, def.achievement.goal),
        unlockedAt: unlockedAt,
      );
      result.add(a);
      if (!wasUnlocked && reached) newly.add(a);
    }
    return AchievementSync(result, newly);
  }
}

class AchievementSync {
  const AchievementSync(this.achievements, this.newlyUnlocked);
  final List<Achievement> achievements;
  final List<Achievement> newlyUnlocked;
}

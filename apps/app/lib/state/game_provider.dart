import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_engines/synapse_engines.dart';
import 'package:synapse_services/synapse_services.dart';

import 'app_providers.dart';
import 'toast_provider.dart';

/// The unified gameplay state — the integration hub. One place updates XP,
/// gems, hearts, streak, league, concept mastery, quests and achievements, and
/// publishes the matching [SynapseEvent]s so reactors elsewhere can respond
/// (prompt 09 / 32 / 33).
class GameState {
  const GameState({
    required this.game,
    required this.mastery,
    required this.quests,
    required this.counters,
    required this.achievements,
  });

  final GamificationState game;
  final Map<ConceptId, ConceptMastery> mastery;
  final List<Quest> quests;
  final Map<String, int> counters;
  final List<Achievement> achievements;

  GameState copyWith({
    GamificationState? game,
    Map<ConceptId, ConceptMastery>? mastery,
    List<Quest>? quests,
    Map<String, int>? counters,
    List<Achievement>? achievements,
  }) {
    return GameState(
      game: game ?? this.game,
      mastery: mastery ?? this.mastery,
      quests: quests ?? this.quests,
      counters: counters ?? this.counters,
      achievements: achievements ?? this.achievements,
    );
  }

  List<ConceptMastery> get weakConcepts =>
      (mastery.values.where((m) => m.isWeak).toList()
        ..sort((a, b) => a.mastery.compareTo(b.mastery)));

  int get masteredCount => mastery.values.where((m) => m.isMastered).length;
}

class GameNotifier extends Notifier<GameState> {
  static const _gameKey = 'game_state';
  static const _masteryKey = 'mastery';
  static const _questsKey = 'quests';
  static const _countersKey = 'counters';
  static const _unlockedKey = 'unlocked_at';

  final _engine = const GamificationEngine();
  Map<String, DateTime> _unlocked = {};

  @override
  GameState build() {
    final store = ref.watch(sharedPreferencesProvider);

    final gameJson = store.readJson(_gameKey);
    final game = gameJson != null ? GamificationState.fromJson(gameJson) : const GamificationState();

    final masteryJson = store.readJson(_masteryKey);
    final mastery = <ConceptId, ConceptMastery>{};
    if (masteryJson != null) {
      for (final entry in masteryJson.entries) {
        mastery[entry.key] =
            ConceptMastery.fromJson(Map<String, dynamic>.from(entry.value as Map));
      }
    }

    final countersJson = store.readJson(_countersKey);
    final counters = <String, int>{};
    if (countersJson != null) {
      countersJson.forEach((k, v) => counters[k] = (v as num).toInt());
    }

    final unlockedJson = store.readJson(_unlockedKey);
    _unlocked = {};
    if (unlockedJson != null) {
      unlockedJson.forEach((k, v) {
        final dt = DateTime.tryParse(v.toString());
        if (dt != null) _unlocked[k] = dt;
      });
    }

    // Quests: restore progress or seed fresh.
    final questsRaw = store.readJson(_questsKey);
    final quests = (questsRaw != null && questsRaw['list'] is List)
        ? _decodeQuests(questsRaw['list'] as List)
        : DemoSeed.quests();

    final achievements = _syncAchievements(counters, game);

    return GameState(
      game: game,
      mastery: mastery,
      quests: quests,
      counters: counters,
      achievements: achievements,
    );
  }

  // ---- Public API: the single entry point modules call ----

  /// Report the outcome of an activity. Returns nothing; side-effects (toasts)
  /// are pushed to [toastProvider]. This is what makes one action ripple across
  /// the app (reward + mastery + quests + achievements + events).
  void report({
    required ModuleKey source,
    required RewardKind kind,
    required bool correct,
    List<ConceptId> concepts = const [],
    int xp = 10,
    int gems = 0,
    bool firstTry = false,
    bool hearted = false,
    String achievementMetric = '',
    int metricBy = 1,
  }) {
    final bus = ref.read(eventBusProvider);
    var next = state;

    // 1) Publish concept events + update mastery (prompt 32/33).
    final mastery = Map<ConceptId, ConceptMastery>.from(next.mastery);
    for (final cid in concepts) {
      bus.publish(correct
          ? ConceptStudied(conceptId: cid, source: source, correct: true)
          : ConceptStruggled(conceptId: cid, source: source));
      final current = mastery[cid] ?? ConceptMastery(conceptId: cid);
      final updated = current.applyOutcome(wasCorrect: correct, source: source);
      mastery[cid] = updated;
      if (updated.isMastered && !current.isMastered) {
        bus.publish(ItemMastered(conceptId: cid));
      }
    }

    // 2) Counters (achievements) + correctness tally.
    final counters = Map<String, int>.from(next.counters);
    void bump(String k, [int by = 1]) => counters[k] = (counters[k] ?? 0) + by;
    if (correct) bump('total.correct');
    if (achievementMetric.isNotEmpty) bump(achievementMetric, metricBy);
    counters['concepts.mastered'] = mastery.values.where((m) => m.isMastered).length;

    // 3) Reward economy (only meaningful gains on success / contributions).
    var game = next.game;
    final intents = <RewardIntent>[];
    if (correct || kind == RewardKind.contribution || kind == RewardKind.review) {
      final event = RewardEvent(
        source: source,
        kind: kind,
        xp: xp,
        gems: gems,
        conceptIds: concepts,
        firstTry: firstTry,
        at: DateTime.now(),
      );
      final result = _engine.award(game, event);
      game = result.state;
      intents.addAll(result.intents);
      bus.publish(RewardGranted(event: event));

      // 4) Advance quests on the same event.
      final qUpdate = QuestEngine.apply(next.quests, event);
      next = next.copyWith(quests: qUpdate.quests);
      for (final qid in qUpdate.newlyComplete) {
        bus.publish(QuestProgressed(questId: qid));
        ref.read(toastProvider.notifier).push(ToastMessage(
              title: 'Quest complete!',
              subtitle: 'Claim your reward',
              icon: Icons.task_alt_rounded,
              color: const Color(0xFF7BE0A3),
            ));
      }
    } else if (hearted) {
      // 3b) Wrong answer in a hearted drill loses a life.
      game = _engine.loseHeart(game);
    }

    // Streak counter mirrors the engine streak.
    counters['streak'] = game.streak.current;
    counters['level'] = game.xp.level;

    // 5) Recompute achievements.
    final achievements = _syncAchievements(counters, game, intents: intents);

    next = next.copyWith(game: game, mastery: mastery, counters: counters, achievements: achievements);
    state = next;
    _persist();

    // 6) Toasts for the gameplay intents.
    _emitIntents(intents);
  }

  /// Mark a finished lesson/case (publishes the higher-level event too).
  void completeLesson({
    required ModuleKey source,
    required int correct,
    required int total,
    List<ConceptId> concepts = const [],
    int xp = 15,
  }) {
    ref.read(eventBusProvider).publish(
          LessonCompleted(source: source, correct: correct, total: total, conceptIds: concepts),
        );
    report(source: source, kind: RewardKind.lesson, correct: true, concepts: concepts, xp: xp, firstTry: correct == total);
  }

  void claimQuest(String id) {
    final quests = state.quests.map((q) {
      if (q.id == id && q.isComplete && !q.isClaimed) {
        // Pay out.
        final event = RewardEvent(source: ModuleKey.copilot, kind: RewardKind.lesson, xp: q.rewardXp, gems: q.rewardGems);
        final result = _engine.award(state.game, event);
        state = state.copyWith(game: result.state);
        _emitIntents(result.intents);
        return q.copyWith(claimedAt: DateTime.now());
      }
      return q;
    }).toList();
    state = state.copyWith(quests: quests);
    _persist();
  }

  void refillHeartsWithGems() {
    final game = _engine.refillHeartsWithGems(state.game);
    state = state.copyWith(game: game);
    _persist();
  }

  void grantPracticeHeart() {
    // Practice mode: top up one heart for free when empty (no-hearts mode).
    final h = state.game.hearts;
    if (h.current < h.max) {
      state = state.copyWith(game: state.game.copyWith(hearts: h.copyWith(current: h.current + 1)));
      _persist();
    }
  }

  ConceptMastery masteryFor(ConceptId id) =>
      state.mastery[id] ?? ConceptMastery(conceptId: id);

  // ---- internals ----

  List<Achievement> _syncAchievements(
    Map<String, int> counters,
    GamificationState game, {
    List<RewardIntent>? intents,
  }) {
    final sync = AchievementEngine.sync(AchievementCatalog.all(), counters, _unlocked);
    for (final a in sync.newlyUnlocked) {
      _unlocked[a.id] = a.unlockedAt ?? DateTime.now();
      ref.read(toastProvider.notifier).push(ToastMessage(
            title: 'Achievement: ${a.title}',
            subtitle: a.desc,
            icon: Icons.emoji_events_rounded,
            color: const Color(0xFFFFC773),
          ));
    }
    return sync.achievements;
  }

  void _emitIntents(List<RewardIntent> intents) {
    final toasts = ref.read(toastProvider.notifier);
    for (final i in intents) {
      switch (i) {
        case LevelUpIntent(:final newLevel):
          toasts.push(ToastMessage(
              title: 'Level $newLevel!',
              subtitle: 'You levelled up',
              icon: Icons.trending_up_rounded,
              color: const Color(0xFF8E9BFF)));
        case StreakUpIntent(:final days):
          toasts.push(ToastMessage(
              title: '$days-day streak!',
              subtitle: 'Keep it going',
              icon: Icons.local_fire_department_rounded,
              color: const Color(0xFFFF8A3D)));
        case XpGainedIntent(:final xp, :final gems):
          if (xp > 0) {
            toasts.push(ToastMessage(
                title: '+$xp XP${gems > 0 ? '  ·  +$gems 💎' : ''}',
                icon: Icons.bolt_rounded,
                color: const Color(0xFF8E9BFF)));
          }
      }
    }
  }

  List<Quest> _decodeQuests(List raw) {
    // Quests are re-seeded structurally; we only restore progress + claimed.
    final seed = DemoSeed.quests();
    final byId = <Object?, Map>{for (final m in raw) (m as Map)['id']: m};
    return seed.map((q) {
      final saved = byId[q.id];
      if (saved == null) return q;
      final goalsRaw = (saved['goals'] as List?) ?? const [];
      final goals = <QuestGoal>[];
      for (var i = 0; i < q.goals.length; i++) {
        final p = i < goalsRaw.length ? ((goalsRaw[i] as Map)['progress'] as num?)?.toInt() ?? 0 : 0;
        goals.add(q.goals[i].copyWith(progress: p));
      }
      final claimed = saved['claimedAt'] != null ? DateTime.tryParse(saved['claimedAt'].toString()) : null;
      return q.copyWith(goals: goals, claimedAt: claimed);
    }).toList();
  }

  void _persist() {
    final store = ref.read(sharedPreferencesProvider);
    store.writeJson(_gameKey, state.game.toJson());
    store.writeJson(_masteryKey, {for (final e in state.mastery.entries) e.key: e.value.toJson()});
    store.writeJson(_countersKey, state.counters);
    store.writeJson(_unlockedKey, {for (final e in _unlocked.entries) e.key: e.value.toIso8601String()});
    store.writeJson(_questsKey, {
      'list': state.quests
          .map((q) => {
                'id': q.id,
                'goals': q.goals.map((g) => {'progress': g.progress}).toList(),
                'claimedAt': q.claimedAt?.toIso8601String(),
              })
          .toList(),
    });
  }
}

final gameProvider = NotifierProvider<GameNotifier, GameState>(GameNotifier.new);

// ---- Fine-grained selectors (prompt 08 §2) ----
final xpProvider = Provider<XPState>((ref) => ref.watch(gameProvider).game.xp);
final heartsProvider = Provider<Hearts>((ref) => ref.watch(gameProvider).game.hearts);
final streakProvider = Provider<Streak>((ref) => ref.watch(gameProvider).game.streak);
final walletProvider = Provider<Wallet>((ref) => ref.watch(gameProvider).game.wallet);
final leagueProvider = Provider<League>((ref) => ref.watch(gameProvider).game.league);
final weekXpProvider = Provider<int>((ref) => ref.watch(gameProvider).game.weekXp);
final questsListProvider = Provider<List<Quest>>((ref) => ref.watch(gameProvider).quests);
final achievementsProvider = Provider<List<Achievement>>((ref) => ref.watch(gameProvider).achievements);
final weakConceptsProvider = Provider<List<ConceptMastery>>((ref) => ref.watch(gameProvider).weakConcepts);
final masteryMapProvider = Provider<Map<ConceptId, ConceptMastery>>((ref) => ref.watch(gameProvider).mastery);

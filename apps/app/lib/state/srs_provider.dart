import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_engines/synapse_engines.dart';

import 'app_providers.dart';
import 'game_provider.dart';
import 'user_provider.dart';

/// The shared SRS store across origins (Terms/Cards/Mnemonics) — one queue, one
/// Daily Review (prompt 22).
class SrsNotifier extends Notifier<List<SrsCard>> {
  static const _key = 'srs_cards';

  @override
  List<SrsCard> build() {
    final store = ref.watch(sharedPreferencesProvider);
    final repo = ref.watch(repositoryProvider);
    final userId = ref.watch(userProvider).id;
    final raw = store.readJson(_key);
    if (raw != null && raw['list'] is List) {
      return (raw['list'] as List)
          .map((e) => SrsCard.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return repo.seedCards(userId);
  }

  List<SrsCard> get dueQueue => SrsEngine.dueQueue(state);
  int get dueCount => SrsEngine.dueCount(state);

  /// Grade a card and reschedule it; reports the review to the game hub so it
  /// counts toward XP, streak, quests and mastery.
  void grade(String cardId, ReviewGrade grade) {
    final idx = state.indexWhere((c) => c.id == cardId);
    if (idx < 0) return;
    final card = state[idx];
    final updated = SrsEngine.grade(card, grade);
    state = [...state]..[idx] = updated;
    _persist();

    final correct = grade != ReviewGrade.again;
    ref.read(gameProvider.notifier).report(
          source: _moduleFor(card.origin),
          kind: RewardKind.review,
          correct: correct,
          concepts: [if (card.conceptId != null) card.conceptId!],
          xp: correct ? 5 : 0,
          achievementMetric: 'review.count',
        );
    if (card.origin == SrsOrigin.cards && correct) {
      ref.read(gameProvider.notifier).report(
            source: ModuleKey.cards,
            kind: RewardKind.review,
            correct: true,
            xp: 0,
            achievementMetric: 'cards.review',
          );
    }
  }

  void enroll(SrsCard card) {
    if (state.any((c) => c.id == card.id)) return;
    state = [...state, card];
    _persist();
  }

  ModuleKey _moduleFor(SrsOrigin o) => switch (o) {
        SrsOrigin.terms => ModuleKey.terms,
        SrsOrigin.cards => ModuleKey.cards,
        SrsOrigin.mnemonics => ModuleKey.mnemonics,
      };

  void _persist() {
    ref.read(sharedPreferencesProvider).writeJson(_key, {
      'list': state.map((c) => c.toJson()).toList(),
    });
  }
}

final srsProvider = NotifierProvider<SrsNotifier, List<SrsCard>>(SrsNotifier.new);

final dueCountProvider = Provider<int>((ref) {
  ref.watch(srsProvider);
  return ref.read(srsProvider.notifier).dueCount;
});

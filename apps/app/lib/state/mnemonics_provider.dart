import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synapse_core/synapse_core.dart';

import 'app_providers.dart';
import 'game_provider.dart';

/// Mutable Mnemonics state — votes, saves and user contributions (prompt 13).
class MnemonicsNotifier extends Notifier<List<Mnemonic>> {
  @override
  List<Mnemonic> build() => List.of(ref.watch(repositoryProvider).mnemonics)
    ..sort((a, b) => b.score.compareTo(a.score));

  void vote(String id, int dir) {
    state = state.map((m) {
      if (m.id != id) return m;
      final prev = m.myVote;
      var up = m.upvotes;
      var down = m.downvotes;
      // Remove previous vote.
      if (prev == 1) up--;
      if (prev == -1) down--;
      final next = prev == dir ? 0 : dir; // toggle off if same
      if (next == 1) up++;
      if (next == -1) down++;
      return m.copyWith(upvotes: up, downvotes: down, myVote: next);
    }).toList();
    ref.read(gameProvider.notifier).report(
          source: ModuleKey.mnemonics,
          kind: RewardKind.contribution,
          correct: true,
          xp: 1,
        );
  }

  void toggleSave(String id) {
    state = state.map((m) => m.id == id ? m.copyWith(saved: !m.saved) : m).toList();
  }

  void add(Mnemonic m) {
    state = [m, ...state];
    ref.read(eventBusProvider).publish(ContentCreated(source: ModuleKey.mnemonics, itemId: m.id));
    ref.read(gameProvider.notifier).report(
          source: ModuleKey.mnemonics,
          kind: RewardKind.contribution,
          correct: true,
          concepts: m.conceptIds,
          xp: 20,
          gems: 5,
          achievementMetric: 'mnemonics.created',
        );
  }

  Mnemonic? byId(String id) {
    for (final m in state) {
      if (m.id == id) return m;
    }
    return null;
  }
}

final mnemonicsProvider =
    NotifierProvider<MnemonicsNotifier, List<Mnemonic>>(MnemonicsNotifier.new);

import 'package:synapse_core/synapse_core.dart';

/// Advances cross-module quests from reward events (prompt 09 §2). The quest DSL
/// is expressed directly on [QuestGoal] (kind + optional module + target).
class QuestEngine {
  const QuestEngine._();

  /// Apply an event to all quests, returning the updated list plus the ids of
  /// quests that *became* complete on this event.
  static QuestUpdate apply(List<Quest> quests, RewardEvent event) {
    final newlyComplete = <String>[];
    final updated = quests.map((q) {
      if (q.isComplete) return q;
      final goals = q.goals.map((g) {
        if (g.isDone || !g.matches(event)) return g;
        return g.copyWith(progress: (g.progress + 1).clamp(0, g.target));
      }).toList();
      final next = q.copyWith(goals: goals);
      if (next.isComplete && !q.isComplete) newlyComplete.add(q.id);
      return next;
    }).toList();
    return QuestUpdate(updated, newlyComplete);
  }
}

class QuestUpdate {
  const QuestUpdate(this.quests, this.newlyComplete);
  final List<Quest> quests;
  final List<String> newlyComplete;
}

import 'package:equatable/equatable.dart';

import 'module_key.dart';
import 'reward.dart';

enum QuestPeriod { daily, weekly }

/// A single objective within a quest, e.g. "learn 5 terms". [module] null means
/// the goal counts activity from any module (prompt 09 §2 quest DSL).
class QuestGoal extends Equatable {
  const QuestGoal({
    required this.label,
    required this.kind,
    required this.target,
    this.module,
    this.progress = 0,
  });

  final String label;
  final RewardKind kind;
  final int target;
  final ModuleKey? module;
  final int progress;

  bool get isDone => progress >= target;
  double get ratio => target == 0 ? 1 : (progress / target).clamp(0.0, 1.0);

  /// Whether a reward event advances this goal.
  bool matches(RewardEvent e) {
    if (kind != e.kind) return false;
    if (module != null && module != e.source) return false;
    return true;
  }

  QuestGoal copyWith({int? progress}) => QuestGoal(
        label: label,
        kind: kind,
        target: target,
        module: module,
        progress: progress ?? this.progress,
      );

  @override
  List<Object?> get props => [label, kind, target, module, progress];
}

class Quest extends Equatable {
  const Quest({
    required this.id,
    required this.title,
    required this.period,
    required this.goals,
    this.rewardXp = 20,
    this.rewardGems = 5,
    this.claimedAt,
  });

  final String id;
  final String title;
  final QuestPeriod period;
  final List<QuestGoal> goals;
  final int rewardXp;
  final int rewardGems;
  final DateTime? claimedAt;

  bool get isComplete => goals.every((g) => g.isDone);
  bool get isClaimed => claimedAt != null;
  double get ratio =>
      goals.isEmpty ? 0 : goals.map((g) => g.ratio).reduce((a, b) => a + b) / goals.length;

  Quest copyWith({List<QuestGoal>? goals, DateTime? claimedAt}) => Quest(
        id: id,
        title: title,
        period: period,
        rewardXp: rewardXp,
        rewardGems: rewardGems,
        goals: goals ?? this.goals,
        claimedAt: claimedAt ?? this.claimedAt,
      );

  @override
  List<Object?> get props => [id, goals, claimedAt];
}

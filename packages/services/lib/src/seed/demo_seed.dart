import 'package:synapse_core/synapse_core.dart';

/// The local demo identity + starter quests/notifications so the app feels alive
/// on first launch with no backend (prompt 06/24).
class DemoSeed {
  const DemoSeed._();

  static const UserProfile user = UserProfile(
    id: 'local-user',
    handle: 'you',
    displayName: 'Dr. You',
    role: UserRole.student,
    specialty: 'Internal Medicine',
    year: 3,
    bio: 'Learning everything, one synapse at a time.',
  );

  static List<Quest> quests() => [
        const Quest(
          id: 'q_daily',
          title: 'Daily Mix',
          period: QuestPeriod.daily,
          rewardXp: 30,
          rewardGems: 10,
          goals: [
            QuestGoal(label: 'Finish a Terms lesson', kind: RewardKind.lesson, target: 1, module: ModuleKey.terms),
            QuestGoal(label: 'Read 3 ECGs', kind: RewardKind.correct, target: 3, module: ModuleKey.ecg),
            QuestGoal(label: 'Do 5 reviews', kind: RewardKind.review, target: 5),
          ],
        ),
        const Quest(
          id: 'q_weekly',
          title: 'Weekly Challenge',
          period: QuestPeriod.weekly,
          rewardXp: 120,
          rewardGems: 40,
          goals: [
            QuestGoal(label: 'Interpret 3 lab panels', kind: RewardKind.correct, target: 3, module: ModuleKey.labs),
            QuestGoal(label: 'Win 2 Arena matches', kind: RewardKind.win, target: 2, module: ModuleKey.arena),
            QuestGoal(label: 'Complete a case', kind: RewardKind.lesson, target: 1),
          ],
        ),
      ];

  static List<AppNotification> notifications() => [
        AppNotification(id: 'n1', kind: NotificationKind.review, title: 'Reviews are ready', body: 'You have cards due in your Daily Review.', iconKey: 'check', route: '/review', at: DateTime.now().subtract(const Duration(hours: 1))),
        AppNotification(id: 'n2', kind: NotificationKind.social, title: 'New round from Dr. Amaro', body: 'A pearl on reading ST elevation', iconKey: 'bell', route: '/social/rounds/r1', at: DateTime.now().subtract(const Duration(hours: 5))),
        AppNotification(id: 'n3', kind: NotificationKind.league, title: 'League starts soon', body: 'Earn XP this week to be promoted to Silver.', iconKey: 'trophy', route: '/rewards', at: DateTime.now().subtract(const Duration(days: 1))),
      ];
}

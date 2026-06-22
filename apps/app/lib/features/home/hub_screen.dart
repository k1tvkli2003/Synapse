import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../../router/routes.dart';
import '../../state/game_provider.dart';
import '../../state/notifications_provider.dart';
import '../../state/srs_provider.dart';
import '../../state/user_provider.dart';

class HubScreen extends ConsumerWidget {
  const HubScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final user = ref.watch(userProvider);
    final streak = ref.watch(streakProvider);
    final xp = ref.watch(xpProvider);
    final wallet = ref.watch(walletProvider);
    final due = ref.watch(dueCountProvider);
    final unread = ref.watch(unreadCountProvider);
    final cols = context.bp.gridColumns;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ContentBounds(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      AppAvatar(name: user.displayName, radius: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_greeting(),
                                style: TextStyle(color: t.textMuted, fontSize: 13)),
                            Text('Dr. ${user.firstName}',
                                style: Theme.of(context).textTheme.titleLarge),
                          ],
                        ),
                      ),
                      _Chip(child: StreakFlame(days: streak.current, compact: true)),
                      const SizedBox(width: 8),
                      _Chip(child: GemCounter(gems: wallet.gems)),
                      const SizedBox(width: 8),
                      _NotifBell(unread: unread),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                sliver: SliverToBoxAdapter(child: _LevelCard(xp: xp)),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                sliver: SliverToBoxAdapter(child: _DailyReviewCard(due: due)),
              ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                sliver: SliverToBoxAdapter(child: _QuestsCard()),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: SectionHeader(
                    title: 'Modules',
                    subtitle: 'Twelve rooms, one organism',
                    onAction: () => context.push(Routes.search),
                    actionLabel: 'Search',
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.05,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final m = ModuleKey.values[i];
                      return ModuleTile(
                        module: m,
                        stat: _statFor(m, due),
                        onTap: () => context.push(_routeFor(m)),
                      ).animate().fadeIn(delay: (i * 35).ms, duration: 280.ms).moveY(begin: 12, end: 0);
                    },
                    childCount: ModuleKey.values.length,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingCopilotButton(onPressed: () => context.push(Routes.copilot)),
    );
  }

  String? _statFor(ModuleKey m, int due) => switch (m) {
        ModuleKey.cards => due > 0 ? '$due due' : null,
        ModuleKey.ecg => '8 cases',
        ModuleKey.terms => '3 paths',
        ModuleKey.mnemonics => '12 hooks',
        ModuleKey.labs => 'CBC · BMP · LFT',
        ModuleKey.arena => 'Play now',
        _ => null,
      };

  String _routeFor(ModuleKey m) => switch (m) {
        ModuleKey.copilot => Routes.copilot,
        ModuleKey.terms => Routes.terms,
        ModuleKey.cards => Routes.cards,
        ModuleKey.mnemonics => Routes.mnemonics,
        ModuleKey.ecg => Routes.ecg,
        ModuleKey.sounds => Routes.sounds,
        ModuleKey.labs => Routes.labs,
        ModuleKey.algorithms => Routes.algorithms,
        ModuleKey.orLab => Routes.orLab,
        ModuleKey.rounds => Routes.rounds,
        ModuleKey.buddies => Routes.buddies,
        ModuleKey.arena => Routes.arena,
      };
}

class _Chip extends StatelessWidget {
  const _Chip({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: t.border),
      ),
      child: child,
    );
  }
}

class _NotifBell extends StatelessWidget {
  const _NotifBell({required this.unread});
  final int unread;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AppIconButton(
          icon: Icons.notifications_rounded,
          filled: true,
          onPressed: () => context.push(Routes.notifications),
          tooltip: 'Inbox',
        ),
        if (unread > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              width: 16,
              height: 16,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: t.danger, shape: BoxShape.circle),
              child: Text('$unread',
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
            ),
          ),
      ],
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.xp});
  final XPState xp;
  @override
  Widget build(BuildContext context) {
    return AppCard(child: XpBar(xp: xp));
  }
}

class _DailyReviewCard extends StatelessWidget {
  const _DailyReviewCard({required this.due});
  final int due;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      feature: true,
      accent: t.primary,
      onTap: () => context.push(Routes.review),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [t.primary, t.info]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.replay_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Daily Review', style: Theme.of(context).textTheme.titleLarge),
                Text(
                  due > 0 ? '$due items due across Terms, Cards & Mnemonics' : 'All caught up — review ahead',
                  style: TextStyle(color: t.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_rounded, color: t.primary),
        ],
      ),
    );
  }
}

class _QuestsCard extends ConsumerWidget {
  const _QuestsCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final quests = ref.watch(questsListProvider);
    final daily = quests.where((q) => q.period == QuestPeriod.daily).toList();
    if (daily.isEmpty) return const SizedBox.shrink();
    final q = daily.first;
    return AppCard(
      onTap: () => context.push(Routes.quests),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.task_alt_rounded, color: t.success, size: 20),
              const SizedBox(width: 8),
              Text(q.title, style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Text('+${q.rewardXp} XP', style: TextStyle(color: t.success, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          ...q.goals.map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(g.isDone ? Icons.check_circle_rounded : Icons.circle_outlined,
                        size: 16, color: g.isDone ? t.success : t.textFaint),
                    const SizedBox(width: 8),
                    Expanded(child: Text(g.label, style: TextStyle(color: t.text, fontSize: 13))),
                    Text('${g.progress}/${g.target}',
                        style: TextStyle(color: t.textMuted, fontSize: 12)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

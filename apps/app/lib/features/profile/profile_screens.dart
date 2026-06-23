import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_engines/synapse_engines.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../../router/routes.dart';
import '../../state/app_providers.dart';
import '../../state/entitlement_provider.dart';
import '../../state/game_provider.dart';
import '../../state/notifications_provider.dart';
import '../../state/settings_provider.dart';
import '../../state/srs_provider.dart';
import '../../state/study_plan_provider.dart';
import '../../state/user_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final user = ref.watch(userProvider);
    final xp = ref.watch(xpProvider);
    final streak = ref.watch(streakProvider);
    final league = ref.watch(leagueProvider);
    final mastered = ref.watch(gameProvider).masteredCount;

    final links = [
      (Icons.emoji_events_rounded, 'Rewards', Routes.rewards),
      (Icons.military_tech_rounded, 'Achievements', Routes.achievements),
      (Icons.task_alt_rounded, 'Quests', Routes.quests),
      (Icons.insights_rounded, 'Insights', Routes.insights),
      (Icons.notifications_rounded, 'Inbox', Routes.notifications),
      (Icons.settings_rounded, 'Settings', Routes.settings),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ContentBounds(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            children: [
              Row(
                children: [
                  AppAvatar(name: user.displayName, radius: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.displayName, style: Theme.of(context).textTheme.headlineSmall),
                        Text('@${user.handle} · ${user.specialty ?? _roleLabel(user.role)}', style: TextStyle(color: t.textMuted)),
                      ],
                    ),
                  ),
                  AppIconButton(icon: Icons.edit_rounded, tooltip: 'Edit', onPressed: () => _editSheet(context, ref)),
                ],
              ),
              if (user.bio != null) ...[
                const SizedBox(height: 12),
                Text(user.bio!, style: TextStyle(color: t.textMuted, height: 1.4)),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: StatTile(value: 'Lv ${xp.level}', label: 'Level', icon: Icons.bolt_rounded)),
                  const SizedBox(width: 12),
                  Expanded(child: StatTile(value: '${streak.current}', label: 'Day streak', icon: Icons.local_fire_department_rounded, accent: const Color(0xFFFF8A3D))),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: StatTile(value: league.label, label: 'League', icon: Icons.shield_rounded, accent: LeagueBadge.colorOf(league))),
                  const SizedBox(width: 12),
                  Expanded(child: StatTile(value: '$mastered', label: 'Mastered', icon: Icons.psychology_rounded, accent: t.success)),
                ],
              ),
              const SizedBox(height: 24),
              GridView.count(
                crossAxisCount: context.bp.isCompact ? 2 : 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.4,
                children: links
                    .map((l) => AppCard(
                          onTap: () => context.push(l.$3),
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Icon(l.$1, color: t.primary, size: 20),
                              const SizedBox(width: 10),
                              Expanded(child: Text(l.$2, style: Theme.of(context).textTheme.titleSmall)),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editSheet(BuildContext context, WidgetRef ref) {
    final user = ref.read(userProvider);
    final nameC = TextEditingController(text: user.displayName);
    final specC = TextEditingController(text: user.specialty ?? '');
    final bioC = TextEditingController(text: user.bio ?? '');
    showAppSheet(context, builder: (context) => Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Edit profile', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              AppTextField(controller: nameC, label: 'Display name'),
              const SizedBox(height: 12),
              AppTextField(controller: specC, label: 'Specialty'),
              const SizedBox(height: 12),
              AppTextField(controller: bioC, label: 'Bio', maxLines: 3),
              const SizedBox(height: 16),
              AppButton(label: 'Save', expand: true, onPressed: () {
                ref.read(userProvider.notifier).edit(displayName: nameC.text.trim(), specialty: specC.text.trim(), bio: bioC.text.trim());
                Navigator.of(context).pop();
              }),
            ],
          ),
        ));
  }

  String _roleLabel(UserRole r) => r.name[0].toUpperCase() + r.name.substring(1);
}

class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final game = ref.watch(gameProvider).game;
    final rank = LeagueEngine.simulatedRank(game.weekXp);
    return ModuleScaffold(
      title: 'Rewards',
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          AppCard(child: XpBar(xp: game.xp)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: StatTile(value: '${game.wallet.gems}', label: 'Gems', icon: Icons.diamond_rounded, accent: t.info)),
              const SizedBox(width: 12),
              Expanded(child: StatTile(value: '${game.hearts.current}/${game.hearts.max}', label: 'Hearts', icon: Icons.favorite_rounded, accent: t.danger)),
            ],
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'League'),
          AppCard(
            child: Row(
              children: [
                LeagueBadge(league: game.league, size: 44),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${game.league.label} League', style: Theme.of(context).textTheme.titleMedium),
                      Text('Rank #$rank · ${game.weekXp} XP this week', style: TextStyle(color: t.textMuted, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('Earn ${LeagueEngine.promoteThreshold} weekly XP to be promoted.', style: TextStyle(color: t.textFaint, fontSize: 12)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final list = ref.watch(achievementsProvider);
    final unlocked = list.where((a) => a.isUnlocked).length;
    return ModuleScaffold(
      title: 'Achievements',
      subtitle: '$unlocked / ${list.length} unlocked',
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 40),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: context.bp.isCompact ? 2 : 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.95,
        ),
        itemCount: list.length,
        itemBuilder: (context, i) {
          final a = list[i];
          final color = a.isUnlocked ? const Color(0xFFFFC773) : t.textFaint;
          return AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Opacity(
                  opacity: a.isUnlocked ? 1 : 0.4,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.16), shape: BoxShape.circle),
                    child: Icon(iconForKey(a.icon), color: color, size: 26),
                  ),
                ),
                const SizedBox(height: 10),
                Text(a.title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(a.desc, textAlign: TextAlign.center, style: TextStyle(color: t.textMuted, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                if (!a.isUnlocked) ...[
                  const SizedBox(height: 8),
                  AppProgressBar(value: a.ratio, height: 5),
                  Text('${a.progress}/${a.goal}', style: TextStyle(color: t.textFaint, fontSize: 10)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class QuestsScreen extends ConsumerWidget {
  const QuestsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final quests = ref.watch(questsListProvider);
    return ModuleScaffold(
      title: 'Quests',
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          ...quests.map((q) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: AppCard(
                  accent: q.isComplete ? t.success : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AppBadge(label: q.period.name.toUpperCase(), subtle: true, color: t.primary),
                          const SizedBox(width: 8),
                          Text(q.title, style: Theme.of(context).textTheme.titleMedium),
                          const Spacer(),
                          Text('+${q.rewardXp} XP · +${q.rewardGems}💎', style: TextStyle(color: t.success, fontWeight: FontWeight.w700, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...q.goals.map((g) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Icon(g.isDone ? Icons.check_circle_rounded : Icons.circle_outlined, size: 16, color: g.isDone ? t.success : t.textFaint),
                                const SizedBox(width: 8),
                                Expanded(child: Text(g.label, style: TextStyle(color: t.text, fontSize: 13))),
                                Text('${g.progress}/${g.target}', style: TextStyle(color: t.textMuted, fontSize: 12)),
                              ],
                            ),
                          )),
                      const SizedBox(height: 8),
                      if (q.isClaimed)
                        Row(children: [Icon(Icons.check_rounded, color: t.success, size: 16), const SizedBox(width: 6), Text('Claimed', style: TextStyle(color: t.success))])
                      else
                        AppButton(
                          label: q.isComplete ? 'Claim reward' : 'In progress',
                          expand: true,
                          size: AppButtonSize.small,
                          onPressed: q.isComplete ? () => ref.read(gameProvider.notifier).claimQuest(q.id) : null,
                        ),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final mastery = ref.watch(masteryMapProvider);
    final repo = ref.watch(repositoryProvider);
    final weak = ref.watch(weakConceptsProvider);
    final game = ref.watch(gameProvider);
    final preds = ref.watch(conceptPredictionsProvider);
    final studied = mastery.values.toList()..sort((a, b) => b.mastery.compareTo(a.mastery));

    // Exam readiness: blend of average mastery and coverage breadth.
    final avg = mastery.isEmpty ? 0.0 : mastery.values.map((m) => m.mastery).reduce((a, b) => a + b) / mastery.length;
    final coverage = repo.concepts.isEmpty ? 0.0 : mastery.length / repo.concepts.length;
    final readiness = ((avg * 0.7 + coverage * 0.3) * 100).round();

    // Per-module attempt breakdown aggregated from concept mastery.
    final perModule = <ModuleKey, int>{};
    for (final m in mastery.values) {
      m.perModule.forEach((k, v) => perModule[k] = (perModule[k] ?? 0) + v);
    }
    final atRisk = preds.where((p) => p.atRisk).take(6).toList();

    return ModuleScaffold(
      title: 'Insights',
      subtitle: 'The whole app, reflected back',
      scrollable: true,
      onCopilot: () => context.push(Routes.copilot),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          if (mastery.isEmpty)
            const EmptyState(
              icon: Icons.insights_rounded,
              title: 'No data yet',
              message: 'Study anything — a term, an ECG, a lab — and your mastery heatmap fills in here.',
            )
          else ...[
            // Exam readiness.
            AppCard(
              accent: t.primary,
              child: Row(children: [
                ProgressRing(value: readiness / 100, size: 64, color: readiness >= 60 ? t.success : t.warning, child: Text('$readiness', style: const TextStyle(fontWeight: FontWeight.w800))),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Exam readiness', style: Theme.of(context).textTheme.titleLarge),
                  Text(readiness >= 75 ? 'On track — keep the streak' : readiness >= 50 ? 'Building — focus weak areas' : 'Early days — stay consistent', style: TextStyle(color: t.textMuted)),
                ])),
              ]),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: StatTile(value: '${game.game.streak.current}', label: 'Day streak', icon: Icons.local_fire_department_rounded, accent: const Color(0xFFFF8A3D))),
              const SizedBox(width: 10),
              Expanded(child: StatTile(value: '${game.masteredCount}', label: 'Mastered', icon: Icons.workspace_premium_rounded, accent: t.success)),
              const SizedBox(width: 10),
              Expanded(child: StatTile(value: '${game.game.xp.total}', label: 'Total XP', icon: Icons.bolt_rounded, accent: t.primary)),
            ]),
            const SizedBox(height: 20),
            // Weekly recap (Copilot-style narrative).
            AppCard(color: t.surfaceAlt, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Icon(Icons.auto_awesome_rounded, color: t.primary, size: 18), const SizedBox(width: 8), Text('Your week, summarized', style: Theme.of(context).textTheme.titleSmall)]),
              const SizedBox(height: 6),
              Text(_recap(studied, weak, repo, game.game.weekXp), style: TextStyle(color: t.text, height: 1.5)),
            ])),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Concept mastery heatmap'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: studied.map((m) {
                final c = repo.concept(m.conceptId);
                final color = Color.lerp(t.danger, t.success, m.mastery)!;
                return GestureDetector(
                  onTap: () => context.push(Routes.concept(m.conceptId)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: color.withValues(alpha: 0.5)),
                    ),
                    child: Text('${c?.name ?? m.conceptId} · ${(m.mastery * 100).round()}%',
                        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                );
              }).toList(),
            ),
            if (perModule.isNotEmpty) ...[
              const SizedBox(height: 24),
              const SectionHeader(title: 'Where you practice'),
              for (final e in (perModule.entries.toList()..sort((a, b) => b.value.compareTo(a.value))))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Icon(Icons.circle, size: 10, color: Color(e.key.accentHex)),
                    const SizedBox(width: 8),
                    SizedBox(width: 96, child: Text(e.key.title, style: TextStyle(color: t.text, fontSize: 13))),
                    Expanded(child: AppProgressBar(value: (e.value / (perModule.values.reduce((a, b) => a > b ? a : b))).clamp(0.0, 1.0), color: Color(e.key.accentHex))),
                    const SizedBox(width: 8),
                    Text('${e.value}', style: TextStyle(color: t.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                ),
            ],
            if (atRisk.isNotEmpty) ...[
              const SizedBox(height: 24),
              SectionHeader(title: 'Forgetting forecast', subtitle: '${atRisk.length} concept(s) at risk'),
              ...atRisk.map((p) {
                final c = repo.concept(p.conceptId);
                return ListRow(
                  title: c?.name ?? p.conceptId,
                  subtitle: p.willForgetInDays == 0 ? 'Review now · ${p.reason}' : 'Forgetting in ~${p.willForgetInDays}d · ${p.reason}',
                  leadingIcon: Icons.schedule_rounded,
                  accent: t.warning,
                  trailing: TextButton(onPressed: () => context.push(Routes.review), child: const Text('Fix')),
                  onTap: () => context.push(Routes.concept(p.conceptId)),
                );
              }),
            ],
            if (weak.isNotEmpty) ...[
              const SizedBox(height: 24),
              SectionHeader(title: 'Weakest concepts', subtitle: '${weak.length} below 50%'),
              ...weak.take(6).map((m) {
                final c = repo.concept(m.conceptId);
                return ListRow(
                  title: c?.name ?? m.conceptId,
                  subtitle: 'Mastery ${(m.mastery * 100).round()}% · ${m.attempts} attempts',
                  leadingIcon: Icons.trending_down_rounded,
                  accent: t.warning,
                  trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                  onTap: () => context.push(Routes.concept(m.conceptId)),
                );
              }),
            ],
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  String _recap(List<ConceptMastery> studied, List<ConceptMastery> weak, dynamic repo, int weekXp) {
    if (studied.isEmpty) return 'Start studying to see your weekly recap.';
    final strong = studied.first;
    final strongName = repo.concept(strong.conceptId)?.name ?? 'a concept';
    final buffer = StringBuffer('You earned $weekXp XP this week. ');
    buffer.write('Your strongest area is $strongName (${(strong.mastery * 100).round()}%). ');
    if (weak.isNotEmpty) {
      final weakName = repo.concept(weak.first.conceptId)?.name ?? 'some concepts';
      buffer.write('$weakName needs the most work — a few mixed sessions will lift it fast.');
    } else {
      buffer.write('No weak areas right now — push into new material to keep growing.');
    }
    return buffer.toString();
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final prefs = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final isPro = ref.watch(entitlementProvider);
    return ModuleScaffold(
      title: 'Settings',
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const SectionHeader(title: 'Account'),
          AppCard(child: Column(children: [
            _NavRow(icon: Icons.person_rounded, label: 'Edit profile', onTap: () => context.push('${Routes.profile}/edit')),
            _NavRow(icon: Icons.workspace_premium_rounded, label: 'Subscription', value: isPro ? 'Pro' : 'Free', onTap: () => context.push(Routes.pro)),
            _NavRow(icon: Icons.card_giftcard_rounded, label: 'Redeem a code', onTap: () => context.push('/settings/redeem')),
            _NavRow(icon: Icons.brush_rounded, label: 'Customize identity', onTap: () => context.push(Routes.profileCustomize)),
          ])),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Appearance'),
          AppCard(
            child: Column(
              children: [
                _ThemeSelector(current: prefs.theme, onChanged: notifier.setTheme),
                const SizedBox(height: 4),
                AppSwitchTile(
                  title: 'Reduce motion',
                  subtitle: 'Minimise animations',
                  icon: Icons.animation_rounded,
                  value: prefs.reduceMotion,
                  onChanged: notifier.setReduceMotion,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Learning'),
          AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.flag_rounded, color: t.textMuted, size: 20),
                  const SizedBox(width: 12),
                  Text('Daily goal', style: Theme.of(context).textTheme.titleSmall),
                  const Spacer(),
                  Text('${prefs.dailyGoalXp} XP', style: TextStyle(color: t.primary, fontWeight: FontWeight.w700)),
                ]),
                Slider(
                  value: prefs.dailyGoalXp.toDouble().clamp(20, 200),
                  min: 20, max: 200, divisions: 18,
                  label: '${prefs.dailyGoalXp} XP',
                  onChanged: (v) => notifier.setDailyGoal(v.round()),
                ),
              ]),
            ),
            _NavRow(icon: Icons.timeline_rounded, label: 'Study plan & tracks', onTap: () => context.push(Routes.plan)),
          ])),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Notifications'),
          AppCard(child: _NavRow(icon: Icons.notifications_rounded, label: 'Reminders & inbox', onTap: () => context.push(Routes.notifications))),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Privacy & data'),
          AppCard(child: Column(children: [
            AppSwitchTile(
              title: 'Anonymous analytics',
              subtitle: 'Help improve Synapse',
              icon: Icons.analytics_rounded,
              value: prefs.analyticsOptIn,
              onChanged: notifier.setAnalyticsOptIn,
            ),
            _NavRow(icon: Icons.shield_rounded, label: 'Privacy & data controls', onTap: () => context.push('/settings/data')),
          ])),
          const SizedBox(height: 16),
          const SectionHeader(title: 'About & legal'),
          AppCard(child: Column(children: [
            _NavRow(icon: Icons.gavel_rounded, label: 'Terms, privacy & licenses', onTap: () => context.push('/legal/terms')),
            _NavRow(icon: Icons.school_rounded, label: 'Clinical governance', onTap: () => context.push('/legal/governance')),
          ])),
          const SizedBox(height: 12),
          const AppCard(child: DisclaimerBanner()),
          const SizedBox(height: 12),
          Text('Synapse · one codebase, six platforms.\nFor educational training only.',
              style: TextStyle(color: t.textFaint, fontSize: 12, height: 1.5)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

/// A standard navigation row used across the settings center.
class _NavRow extends StatelessWidget {
  const _NavRow({required this.icon, required this.label, this.value, this.onTap});
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: t.radii.cardR,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(children: [
          Icon(icon, color: t.textMuted, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: Theme.of(context).textTheme.titleSmall)),
          if (value != null) Text(value!, style: TextStyle(color: t.textMuted, fontSize: 13)),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, color: t.textFaint, size: 20),
        ]),
      ),
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector({required this.current, required this.onChanged});
  final ThemeModePref current;
  final ValueChanged<ThemeModePref> onChanged;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: ThemeModePref.values.map((m) {
        final selected = m == current;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: GestureDetector(
              onTap: () => onChanged(m),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? t.primary.withValues(alpha: 0.16) : t.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: selected ? t.primary : t.border),
                ),
                child: Column(
                  children: [
                    Icon(switch (m) {
                      ThemeModePref.dark => Icons.dark_mode_rounded,
                      ThemeModePref.light => Icons.light_mode_rounded,
                      ThemeModePref.system => Icons.brightness_auto_rounded,
                    }, color: selected ? t.primary : t.textMuted, size: 20),
                    const SizedBox(height: 4),
                    Text(m.name, style: TextStyle(color: selected ? t.primary : t.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final list = ref.watch(notificationsProvider);
    return ModuleScaffold(
      title: 'Inbox',
      actions: [
        TextButton(onPressed: () => ref.read(notificationsProvider.notifier).markAllRead(), child: const Text('Read all')),
      ],
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 40),
        children: [
          const _SmartReminders(),
          if (list.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 8, bottom: 8),
              child: Text('Activity', style: Theme.of(context).textTheme.titleSmall),
            ),
          for (final n in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                  color: n.isRead ? null : t.primary.withValues(alpha: 0.06),
                  onTap: () {
                    ref.read(notificationsProvider.notifier).markRead(n.id);
                    if (n.route != null) context.push(n.route!);
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: t.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                        child: Icon(iconForKey(n.iconKey), color: t.primary, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n.title, style: Theme.of(context).textTheme.titleSmall),
                            Text(n.body, style: TextStyle(color: t.textMuted, fontSize: 13)),
                          ],
                        ),
                      ),
                      if (!n.isRead) Container(width: 8, height: 8, decoration: BoxDecoration(color: t.primary, shape: BoxShape.circle)),
                    ],
                  ),
                ),
            ),
        ],
      ),
    );
  }
}

/// Plan-aware "smart reminders" sourced from the unified plan/SRS/streak, not
/// generic pings (prompt 38 §1).
class _SmartReminders extends ConsumerWidget {
  const _SmartReminders();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final due = ref.watch(dueCountProvider);
    final streak = ref.watch(streakProvider);
    final plan = ref.watch(studyPlanProvider);
    final reminders = <(IconData, String, String, Color, String)>[
      if (due > 0) (Icons.replay_rounded, '$due reviews due', 'Clear them to protect your retention', const Color(0xFF8E9BFF), Routes.review),
      if (streak.current > 0) (Icons.local_fire_department_rounded, 'Keep your ${streak.current}-day streak', 'A quick drill before the day ends saves it', const Color(0xFFFF8A3D), Routes.plan),
      if (plan.remaining.isNotEmpty) (Icons.checklist_rounded, 'Today: ${plan.remaining.first.title}', '~${plan.minutesLeft} min left in your plan', t.primary, Routes.plan),
      (Icons.local_hospital_rounded, 'Case of the day', 'A fresh Virtual Patient is ready', const Color(0xFFB794F6), Routes.cases),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text('Smart reminders', style: Theme.of(context).textTheme.titleSmall)),
      for (final (icon, title, body, color, route) in reminders)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            accent: color,
            onTap: () => context.push(route),
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 18)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                Text(body, style: TextStyle(color: t.textMuted, fontSize: 12.5)),
              ])),
              Icon(Icons.chevron_right_rounded, color: t.textFaint, size: 18),
            ]),
          ),
        ),
    ]);
  }
}

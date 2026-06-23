import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../../router/routes.dart';
import '../../state/app_providers.dart';
import '../../state/game_provider.dart';
import '../../state/user_provider.dart';

const _accent = Color(0xFFF7A8C4);

/// Live study rooms (prompt 43 §1) — co-op sessions on the shared spine.
class RoomsScreen extends ConsumerWidget {
  const RoomsScreen({super.key});

  static const _rooms = [
    ('room_review', 'Morning Review Sprint', 'Group Daily Review · Pomodoro', 6, Icons.timer_rounded),
    ('room_ecg', 'ECG Race', 'Live ECG quiz race', 4, Icons.monitor_heart_rounded),
    ('room_case', 'Co-op Case: Chest Pain', 'Solve a Virtual Patient together', 3, Icons.local_hospital_rounded),
    ('room_osce', 'OSCE Peer Practice', 'Take turns as patient & examiner', 2, Icons.record_voice_over_rounded),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    return ModuleScaffold(
      title: 'Study Rooms',
      subtitle: 'Learn together, live',
      accent: _accent,
      scrollable: true,
      actions: [AppIconButton(icon: Icons.leaderboard_rounded, tooltip: 'Leaderboard', onPressed: () => context.push(Routes.leaderboard))],
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _NavCard(icon: Icons.forum_rounded, label: 'Community channels', color: const Color(0xFF6FD3E8), onTap: () => context.push(Routes.community))),
          const SizedBox(width: 10),
          Expanded(child: _NavCard(icon: Icons.event_rounded, label: 'Events & tournaments', color: const Color(0xFFFFB07A), onTap: () => context.push(Routes.events))),
        ]),
        const SizedBox(height: 16),
        Text('Active rooms', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final (id, title, sub, members, icon) in _rooms)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              onTap: () => context.push(Routes.room(id)),
              child: Row(children: [
                Container(width: 46, height: 46, decoration: BoxDecoration(color: _accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: _accent)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  Text(sub, style: TextStyle(color: t.textMuted, fontSize: 12.5)),
                ])),
                Column(children: [
                  Icon(Icons.group_rounded, size: 14, color: t.success),
                  Text('$members', style: TextStyle(color: t.success, fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ]),
            ),
          ),
        const SizedBox(height: 24),
      ]),
    );
  }
}

class RoomScreen extends ConsumerWidget {
  const RoomScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final repo = ref.watch(repositoryProvider);
    final peers = repo.buddies.take(4).toList();
    final me = ref.watch(userProvider);
    return ModuleScaffold(
      title: 'Study Room',
      subtitle: 'Live · ${peers.length + 1} present',
      accent: _accent,
      scrollable: true,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        AppCard(accent: _accent, child: Row(children: [
          const Icon(Icons.podcasts_rounded, color: _accent),
          const SizedBox(width: 12),
          Expanded(child: Text('You are in a shared session. Everyone\'s progress feeds the room leaderboard.', style: TextStyle(color: t.text, height: 1.4))),
        ])),
        const SizedBox(height: 16),
        Text('In the room', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(spacing: 10, runSpacing: 10, children: [
          _Presence(name: me.displayName, you: true),
          for (final p in peers) _Presence(name: p.name, you: false),
        ]),
        const SizedBox(height: 20),
        AppButton(label: 'Start shared review', icon: Icons.play_arrow_rounded, accent: _accent, expand: true, onPressed: () => context.push(Routes.review)),
        const SizedBox(height: 10),
        AppButton(label: 'Open room chat', icon: Icons.chat_rounded, variant: AppButtonVariant.secondary, accent: _accent, expand: true, onPressed: () => context.push(Routes.inbox)),
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _Presence extends StatelessWidget {
  const _Presence({required this.name, required this.you});
  final String name;
  final bool you;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(children: [
      Stack(children: [
        AppAvatar(name: name, radius: 24, color: you ? t.primary : _accent),
        Positioned(right: 0, bottom: 0, child: Container(width: 12, height: 12, decoration: BoxDecoration(color: t.success, shape: BoxShape.circle, border: Border.all(color: t.bg, width: 2)))),
      ]),
      const SizedBox(height: 4),
      Text(you ? 'You' : name.split(' ').first, style: TextStyle(color: t.textMuted, fontSize: 11)),
    ]);
  }
}

/// Topic / specialty community channels (prompt 43 §2).
class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});
  static const _channels = [
    ('Cardiology', Icons.favorite_rounded, Color(0xFFFF8A8A), 1240),
    ('Pharmacology', Icons.medication_rounded, Color(0xFFC3E88D), 980),
    ('Internal Medicine', Icons.local_hospital_rounded, Color(0xFF8C9EFF), 1530),
    ('Emergency', Icons.emergency_rounded, Color(0xFFFFB07A), 760),
    ('Surgery', Icons.healing_rounded, Color(0xFFA6B6CC), 540),
    ('Exam prep', Icons.school_rounded, Color(0xFF7BE0A3), 2100),
  ];
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    return ModuleScaffold(
      title: 'Community',
      subtitle: 'Channels, Q&A & collections',
      accent: const Color(0xFF6FD3E8),
      scrollable: true,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        for (final (name, icon, color, members) in _channels)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ListRow(
              title: '#${name.toLowerCase().replaceAll(' ', '-')}',
              subtitle: '$name · ${(members / 1000).toStringAsFixed(1)}k members',
              leadingIcon: icon,
              accent: color,
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(Routes.rounds),
            ),
          ),
        const SizedBox(height: 12),
        AppCard(color: t.surfaceAlt, child: Row(children: [
          Icon(Icons.auto_awesome_rounded, color: t.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text('Ask a question and Copilot drafts a grounded, cited answer for the community to verify.', style: TextStyle(color: t.textMuted, fontSize: 12.5, height: 1.4))),
        ])),
        const SizedBox(height: 24),
      ]),
    );
  }
}

/// Scheduled events & tournaments (prompt 43 §3).
class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final events = [
      ('Arena Cup', 'Weekend antibiotic tournament', 'Starts in 2 days', Icons.emoji_events_rounded, const Color(0xFFFFB07A)),
      ('Cardio Challenge Week', 'Cross-module ECG + cases quests', 'Live now', Icons.monitor_heart_rounded, const Color(0xFFFF8A8A)),
      ('Step 1 Countdown', '30-day group sprint', 'Open', Icons.timer_rounded, const Color(0xFF8C9EFF)),
    ];
    return ModuleScaffold(
      title: 'Events',
      subtitle: 'Tournaments & challenge weeks',
      accent: const Color(0xFFFFB07A),
      scrollable: true,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        for (final (title, sub, whenLabel, icon, color) in events)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(onTap: () => context.push(Routes.leaderboard), child: Row(children: [
              Container(width: 46, height: 46, decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                Text(sub, style: TextStyle(color: t.textMuted, fontSize: 12.5)),
              ])),
              AppBadge(label: whenLabel, color: color, subtle: true),
            ])),
          ),
        const SizedBox(height: 24),
      ]),
    );
  }
}

/// Unified multi-scope leaderboard (prompt 43 §4).
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});
  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  int _scope = 0; // 0 global, 1 league, 2 friends
  static const _scopes = ['Global', 'League', 'Friends'];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final repo = ref.watch(repositoryProvider);
    final me = ref.watch(userProvider);
    final myXp = ref.watch(weekXpProvider);
    final league = ref.watch(leagueProvider);

    // Compose entries from seeded peers + the user, ranked by weekly XP.
    final peers = repo.buddies;
    final entries = <_LbEntry>[
      for (var i = 0; i < peers.length; i++)
        _LbEntry(peers[i].name, 120 + (peers[i].matchScore * 7) % 400 + i * 11, false),
      _LbEntry(me.displayName, myXp, true),
    ]..sort((a, b) => b.xp.compareTo(a.xp));

    return ModuleScaffold(
      title: 'Leaderboard',
      subtitle: '${league.name[0].toUpperCase()}${league.name.substring(1)} league · this week',
      accent: const Color(0xFFFFC773),
      body: Column(
        children: [
          const SizedBox(height: 8),
          SizedBox(height: 36, child: ListView(scrollDirection: Axis.horizontal, children: [
            for (var i = 0; i < _scopes.length; i++)
              Padding(padding: const EdgeInsets.only(right: 8), child: AppChip(label: _scopes[i], selected: _scope == i, accent: const Color(0xFFFFC773), onTap: () => setState(() => _scope = i))),
          ])),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, i) {
                final e = entries[i];
                final rank = i + 1;
                return AppCard(
                  accent: e.you ? t.primary : null,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(children: [
                    SizedBox(width: 28, child: Text('$rank', style: TextStyle(color: rank <= 3 ? const Color(0xFFFFC773) : t.textMuted, fontWeight: FontWeight.w800, fontSize: 16))),
                    AppAvatar(name: e.name, radius: 16, color: e.you ? t.primary : const Color(0xFFFFC773)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(e.you ? '${e.name} (you)' : e.name, style: TextStyle(fontWeight: e.you ? FontWeight.w800 : FontWeight.w600, color: t.text))),
                    Text('${e.xp} XP', style: TextStyle(color: t.textMuted, fontWeight: FontWeight.w700)),
                  ]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LbEntry {
  _LbEntry(this.name, this.xp, this.you);
  final String name;
  final int xp;
  final bool you;
}

/// Direct-message inbox (prompt 24 / 31 §F).
class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final repo = ref.watch(repositoryProvider);
    final buddies = repo.buddies;
    return ModuleScaffold(
      title: 'Inbox',
      subtitle: 'Messages & study buddies',
      accent: const Color(0xFF7FB5FF),
      body: buddies.isEmpty
          ? const EmptyState(icon: Icons.chat_bubble_outline_rounded, title: 'No messages yet')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
              itemCount: buddies.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, i) {
                final b = buddies[i];
                return ListRow(
                  title: b.name,
                  subtitle: b.specialty ?? b.role.name,
                  leading: AppAvatar(name: b.name, radius: 20),
                  trailing: Text('${b.matchScore}%', style: TextStyle(color: t.success, fontSize: 12, fontWeight: FontWeight.w700)),
                  onTap: () => context.push('/chat/${b.userId}'),
                );
              },
            ),
    );
  }
}

/// A simple 1:1 chat thread (prompt 31 §F). Local/offline demo.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, this.threadId});
  final String? threadId;
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _c = TextEditingController();
  final List<(bool, String)> _msgs = [(false, 'Hey! Want to review ECGs together this evening?')];

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final repo = ref.watch(repositoryProvider);
    final matches = widget.threadId == null ? const [] : repo.buddies.where((b) => b.userId == widget.threadId).toList();
    final buddy = matches.isEmpty ? null : matches.first;
    return ModuleScaffold(
      title: buddy?.name ?? 'Chat',
      accent: const Color(0xFF7FB5FF),
      body: Column(children: [
        Expanded(child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: _msgs.length,
          itemBuilder: (context, i) {
            final (mine, text) = _msgs[i];
            return Align(
              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
                decoration: BoxDecoration(color: mine ? const Color(0xFF7FB5FF).withValues(alpha: 0.2) : t.surfaceAlt, borderRadius: BorderRadius.circular(16)),
                child: Text(text, style: TextStyle(color: t.text)),
              ),
            );
          },
        )),
        Row(children: [
          Expanded(child: AppTextField(controller: _c, hint: 'Message…', accent: const Color(0xFF7FB5FF), onSubmitted: _send)),
          const SizedBox(width: 8),
          AppIconButton(icon: Icons.send_rounded, color: const Color(0xFF7FB5FF), onPressed: () => _send(_c.text)),
        ]),
        const SizedBox(height: 10),
      ]),
    );
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    setState(() { _msgs.add((true, text.trim())); _c.clear(); });
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: color, size: 20)),
        const SizedBox(height: 10),
        Text(label, style: Theme.of(context).textTheme.titleSmall),
      ]),
    );
  }
}

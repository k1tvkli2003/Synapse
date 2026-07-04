import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_services/synapse_services.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../../router/routes.dart';
import '../../state/app_providers.dart';
import '../../state/audio_provider.dart';
import '../../state/game_provider.dart';

final _roundsAccent = Color(ModuleKey.rounds.accentHex);
final _buddiesAccent = Color(ModuleKey.buddies.accentHex);

// ---- Rounds ----
class RoundsFeedScreen extends ConsumerStatefulWidget {
  const RoundsFeedScreen({super.key});
  @override
  ConsumerState<RoundsFeedScreen> createState() => _RoundsFeedScreenState();
}

class _RoundsFeedScreenState extends ConsumerState<RoundsFeedScreen> {
  late List<Round> _rounds;

  @override
  void initState() {
    super.initState();
    _rounds = [...ref.read(repositoryProvider).rounds];
  }

  void _toggleLike(int i) {
    setState(() {
      final r = _rounds[i];
      _rounds[i] = r.copyWith(liked: !r.liked, likes: r.likes + (r.liked ? -1 : 1));
    });
    ref.read(gameProvider.notifier).report(source: ModuleKey.rounds, kind: RewardKind.contribution, correct: true, xp: 1);
  }

  void _play(Round r) {
    ref.read(audioProvider.notifier).load(
          sourceId: r.id,
          title: r.title,
          subtitle: 'by ${r.authorName}',
          duration: Duration(seconds: r.durationSec.round()),
          accentHex: _roundsAccent.toARGB32(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final audio = ref.watch(audioProvider);
    return ModuleScaffold(
      title: 'Rounds',
      subtitle: ModuleKey.rounds.tagline,
      accent: _roundsAccent,
      onCopilot: () => context.push(Routes.copilot),
      body: ListView.separated(
        padding: const EdgeInsets.only(top: 8, bottom: 100),
        itemCount: _rounds.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final r = _rounds[i];
          final isPlaying = audio.sourceId == r.id && audio.isPlaying;
          return AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppAvatar(name: r.authorName, radius: 18, color: _roundsAccent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.authorName, style: Theme.of(context).textTheme.titleSmall),
                          Text('${r.durationSec.round()}s · @${r.authorHandle}', style: TextStyle(color: t.textFaint, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(r.title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => isPlaying ? ref.read(audioProvider.notifier).pause() : _play(r),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: _roundsAccent, shape: BoxShape.circle),
                        child: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: const Color(0xFF1A0F2E)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Waveform(seed: r.id.hashCode, color: _roundsAccent, height: 36, bars: 32)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _action(r.liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, '${r.likes}', r.liked ? t.danger : t.textMuted, () => _toggleLike(i)),
                    const SizedBox(width: 16),
                    _action(Icons.mode_comment_outlined, '${r.commentCount}', t.textMuted, () => context.push(Routes.round(r.id))),
                    const Spacer(),
                    if (r.conceptIds.isNotEmpty)
                      AppChip(label: 'See concept', icon: Icons.hub_rounded, onTap: () => context.push(Routes.concept(r.conceptIds.first))),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _action(IconData icon, String label, Color color, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 18, color: color), const SizedBox(width: 4), Text(label, style: TextStyle(color: color, fontSize: 13))]),
        ),
      );
}

class RoundDetailScreen extends ConsumerWidget {
  const RoundDetailScreen({super.key, required this.roundId});
  final String roundId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final r = ref.watch(repositoryProvider).rounds.firstWhere((x) => x.id == roundId, orElse: () => SocialSeed.rounds.first);
    return ModuleScaffold(
      title: r.title,
      subtitle: 'by ${r.authorName}',
      accent: _roundsAccent,
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          AppCard(accent: _roundsAccent, child: Waveform(seed: r.id.hashCode, color: _roundsAccent, height: 56)),
          const SizedBox(height: 16),
          if (r.transcript != null) AppCard(child: Text(r.transcript!, style: TextStyle(color: t.text, height: 1.6))),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ---- Buddies ----
class BuddiesScreen extends ConsumerStatefulWidget {
  const BuddiesScreen({super.key});
  @override
  ConsumerState<BuddiesScreen> createState() => _BuddiesScreenState();
}

class _BuddiesScreenState extends ConsumerState<BuddiesScreen> {
  late List<BuddyProfile> _buddies;

  @override
  void initState() {
    super.initState();
    _buddies = [...ref.read(repositoryProvider).buddies];
  }

  void _set(int i, BuddyStatus s) {
    setState(() => _buddies[i] = _buddies[i].copyWith(status: s));
    if (s == BuddyStatus.matched || s == BuddyStatus.requested) {
      ref.read(gameProvider.notifier).report(source: ModuleKey.buddies, kind: RewardKind.contribution, correct: true, xp: 2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ModuleScaffold(
      title: 'Study Buddies',
      subtitle: ModuleKey.buddies.tagline,
      accent: _buddiesAccent,
      onCopilot: () => context.push(Routes.copilot),
      body: ListView.separated(
        padding: const EdgeInsets.only(top: 8, bottom: 100),
        itemCount: _buddies.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final b = _buddies[i];
          return AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppAvatar(name: b.name, radius: 24, color: _buddiesAccent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.name, style: Theme.of(context).textTheme.titleMedium),
                          Text('${b.specialty ?? ''}${b.year != null ? ' · Year ${b.year}' : ''}', style: TextStyle(color: t.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Text('${b.matchScore}%', style: TextStyle(color: _buddiesAccent, fontWeight: FontWeight.w800, fontSize: 16)),
                        Text('match', style: TextStyle(color: t.textFaint, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
                if (b.bio != null) ...[
                  const SizedBox(height: 10),
                  Text(b.bio!, style: TextStyle(color: t.textMuted, fontSize: 13, height: 1.4)),
                ],
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: b.goals.map((g) => AppChip(label: g, accent: _buddiesAccent)).toList()),
                const SizedBox(height: 12),
                if (b.status == BuddyStatus.matched)
                  Row(children: [Icon(Icons.check_circle_rounded, color: t.success, size: 18), const SizedBox(width: 6), Text('Matched — say hi!', style: TextStyle(color: t.success, fontWeight: FontWeight.w600))])
                else if (b.status == BuddyStatus.requested)
                  Text('Request sent', style: TextStyle(color: t.textMuted))
                else
                  Row(
                    children: [
                      Expanded(child: AppButton(label: 'Pass', variant: AppButtonVariant.ghost, size: AppButtonSize.small, onPressed: () => _set(i, BuddyStatus.passed))),
                      const SizedBox(width: 10),
                      Expanded(child: AppButton(label: 'Connect', size: AppButtonSize.small, accent: _buddiesAccent, onPressed: () => _set(i, BuddyStatus.matched))),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

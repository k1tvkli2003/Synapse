import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../../router/routes.dart';
import '../../state/app_providers.dart';
import '../../state/srs_provider.dart';

final _accent = Color(ModuleKey.cards.accentHex);

class CardsHomeScreen extends ConsumerWidget {
  const CardsHomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final decks = ref.watch(repositoryProvider).decks;
    final due = ref.watch(dueCountProvider);
    return ModuleScaffold(
      title: 'Cards',
      subtitle: ModuleKey.cards.tagline,
      accent: _accent,
      onCopilot: () => context.push(Routes.copilot),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
            child: AppCard(
              accent: _accent,
              onTap: () => context.push(Routes.cardsStudy),
              child: Row(
                children: [
                  Icon(Icons.replay_rounded, color: _accent),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Study due cards', style: Theme.of(context).textTheme.titleMedium)),
                  AppBadge(label: '$due due', color: _accent),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: decks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final d = decks[i];
                final color = Color(d.colorHex);
                return AppCard(
                  accent: color,
                  onTap: () => context.push(Routes.deck(d.id)),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(14)),
                        child: Icon(Icons.style_rounded, color: color),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d.title, style: Theme.of(context).textTheme.titleMedium),
                            if (d.description != null) Text(d.description!, style: TextStyle(color: t.textMuted, fontSize: 13)),
                          ],
                        ),
                      ),
                      Text('${d.size}', style: TextStyle(color: t.textMuted, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class DeckScreen extends ConsumerWidget {
  const DeckScreen({super.key, required this.deckId});
  final String deckId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final repo = ref.watch(repositoryProvider);
    final deck = repo.decks.firstWhere((d) => d.id == deckId, orElse: () => repo.decks.first);
    final all = ref.watch(srsProvider);
    final cards = all.where((c) => deck.cardIds.contains(c.id)).toList();
    final color = Color(deck.colorHex);

    return ModuleScaffold(
      title: deck.title,
      subtitle: '${deck.size} cards',
      accent: color,
      onCopilot: () => context.push(Routes.copilot),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.cardsStudy),
        backgroundColor: color,
        foregroundColor: t.isDark ? const Color(0xFF080B1C) : Colors.white,
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('Study'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.only(top: 8, bottom: 100),
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final c = cards[i];
          return AppCard(
            onTap: c.conceptId != null ? () => context.push(Routes.concept(c.conceptId!)) : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.front, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(c.back, style: TextStyle(color: t.textMuted, fontSize: 13, height: 1.4)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    AppBadge(label: 'Box ${c.box}', subtle: true, color: color),
                    const Spacer(),
                    if (c.conceptId != null)
                      Text('See concept →', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
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

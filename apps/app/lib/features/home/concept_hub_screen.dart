import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../../router/routes.dart';
import '../../state/app_providers.dart';
import '../../state/game_provider.dart';

/// `/concept/:id` — the connective tissue (prompt 30 §6). From any item in any
/// module, "See also" lands here showing the user's mastery of the concept and
/// every related item across the whole app.
class ConceptHubScreen extends ConsumerWidget {
  const ConceptHubScreen({super.key, required this.conceptId});
  final String conceptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final repo = ref.watch(repositoryProvider);
    final concept = repo.concept(conceptId);
    final mastery = ref.watch(masteryMapProvider)[conceptId];
    final items = repo.itemsForConcept(conceptId);

    if (concept == null) {
      return ModuleScaffold(
        title: 'Concept',
        body: const EmptyState(icon: Icons.help_outline_rounded, title: 'Unknown concept'),
      );
    }

    final byModule = <ModuleKey, List<LearnItem>>{};
    for (final i in items) {
      byModule.putIfAbsent(i.module, () => []).add(i);
    }

    return ModuleScaffold(
      title: concept.name,
      subtitle: concept.domain.label,
      onCopilot: () => context.push(Routes.copilot),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          AppCard(
            child: Row(
              children: [
                ProgressRing(
                  value: mastery?.mastery ?? 0,
                  size: 64,
                  stroke: 7,
                  color: t.primary,
                  child: Text('${((mastery?.mastery ?? 0) * 100).round()}%',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your mastery', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        mastery == null
                            ? 'Not studied yet — start anywhere below.'
                            : '${mastery.correct}/${mastery.attempts} correct across ${mastery.perModule.length} module(s)',
                        style: TextStyle(color: t.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (concept.summary != null) ...[
            const SizedBox(height: 16),
            AppCard(
              child: Text(concept.summary!, style: TextStyle(color: t.text, height: 1.5)),
            ),
          ],
          if (concept.links.isNotEmpty) ...[
            const SizedBox(height: 20),
            const SectionHeader(title: 'Related concepts'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: concept.links.map((l) {
                final rc = repo.concept(l.to);
                if (rc == null) return const SizedBox.shrink();
                return AppChip(
                  label: rc.name,
                  icon: Icons.hub_rounded,
                  onTap: () => context.push(Routes.concept(rc.id)),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 24),
          SectionHeader(
            title: 'See also',
            subtitle: '${items.length} item(s) across ${byModule.length} module(s)',
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No linked items yet.', style: TextStyle(color: t.textFaint)),
              ),
            )
          else
            ...byModule.entries.map((e) => _ModuleGroup(module: e.key, items: e.value)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _ModuleGroup extends StatelessWidget {
  const _ModuleGroup({required this.module, required this.items});
  final ModuleKey module;
  final List<LearnItem> items;

  @override
  Widget build(BuildContext context) {
    final accent = Color(module.accentHex);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        accent: accent,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Row(
                children: [
                  Icon(ModuleVisuals.icon(module), color: accent, size: 18),
                  const SizedBox(width: 8),
                  Text(module.title, style: Theme.of(context).textTheme.titleSmall),
                ],
              ),
            ),
            ...items.map((i) => ListRow(
                  title: i.title,
                  subtitle: i.subtitle,
                  accent: accent,
                  leadingIcon: ModuleVisuals.icon(module),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                  onTap: () => context.push(i.route),
                )),
          ],
        ),
      ),
    );
  }
}

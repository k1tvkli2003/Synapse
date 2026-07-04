import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_services/synapse_services.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../../router/routes.dart';
import '../../state/app_providers.dart';
import 'reference_sections.dart';

Color _kindAccent(LibraryKind k) => switch (k) {
      LibraryKind.atlas => const Color(0xFFF7A8C4),
      LibraryKind.imaging => const Color(0xFF6FD3E8),
      LibraryKind.procedure => const Color(0xFFA6B6CC),
      LibraryKind.guideline => const Color(0xFF7BE0A3),
      LibraryKind.journal => const Color(0xFFFFC773),
    };

IconData _kindIcon(LibraryKind k) => switch (k) {
      LibraryKind.atlas => Icons.accessibility_new_rounded,
      LibraryKind.imaging => Icons.broken_image_rounded,
      LibraryKind.procedure => Icons.healing_rounded,
      LibraryKind.guideline => Icons.fact_check_rounded,
      LibraryKind.journal => Icons.article_rounded,
    };

/// Generic list screen for any of the five Library banks (prompt 48).
class LibraryBankScreen extends ConsumerStatefulWidget {
  const LibraryBankScreen({super.key, required this.kind});
  final LibraryKind kind;
  @override
  ConsumerState<LibraryBankScreen> createState() => _LibraryBankScreenState();
}

class _LibraryBankScreenState extends ConsumerState<LibraryBankScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final repo = ref.watch(repositoryProvider);
    final accent = _kindAccent(widget.kind);
    var list = repo.libraryOfKind(widget.kind);
    if (_query.isNotEmpty) list = list.where((e) => e.matches(_query)).toList();

    return ModuleScaffold(
      title: widget.kind.label,
      subtitle: '${repo.libraryOfKind(widget.kind).length} ${widget.kind.singular.toLowerCase()}s',
      accent: accent,
      showDisclaimer: true,
      onCopilot: () => context.push(Routes.copilot),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          SearchField(hint: 'Search ${widget.kind.label.toLowerCase()}…', onChanged: (v) => setState(() => _query = v)),
          const SizedBox(height: 12),
          Expanded(
            child: list.isEmpty
                ? EmptyState(icon: Icons.search_off_rounded, title: 'Nothing here yet', accent: accent)
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final e = list[i];
                      return AppCard(
                        onTap: () => context.push(Routes.libraryEntryById(e.kind, e.id)),
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(color: accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
                            child: Icon(_kindIcon(e.kind), color: accent, size: 21),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(e.title, style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 2),
                            Text(e.subtitle ?? e.summary, style: TextStyle(color: t.textMuted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ])),
                          if (e.year != null) AppBadge(label: '${e.year}', color: t.textMuted, subtle: true),
                          const Icon(Icons.chevron_right_rounded),
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

/// Generic detail screen with reveal-on-tap, steps, body and a sources footer.
class LibraryEntryScreen extends ConsumerWidget {
  const LibraryEntryScreen({super.key, required this.kind, required this.id});
  final LibraryKind kind;
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final repo = ref.watch(repositoryProvider);
    final e = repo.libraryEntry(id);
    final accent = _kindAccent(kind);
    if (e == null) {
      return ModuleScaffold(title: 'Not found', accent: accent, body: const EmptyState(icon: Icons.error_outline_rounded, title: 'Entry not found'));
    }

    return ModuleScaffold(
      title: e.title,
      subtitle: e.subtitle ?? e.kind.singular,
      accent: accent,
      showDisclaimer: true,
      scrollable: true,
      onCopilot: () => context.push(Routes.copilot),
      actions: [
        if (e.conceptIds.isNotEmpty)
          AppIconButton(icon: Icons.psychology_rounded, tooltip: 'See concept', onPressed: () => context.goConcept(e.conceptIds.first)),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          AppCard(accent: accent, child: Text(e.summary, style: TextStyle(color: t.text, height: 1.5))),
          const SizedBox(height: 12),
          for (final p in e.body) ...[
            Text(p, style: TextStyle(color: t.text, height: 1.55)),
            const SizedBox(height: 12),
          ],
          if (e.indications.isNotEmpty) RefBulletSection(title: 'Indications', items: e.indications),
          if (e.contraindications.isNotEmpty) RefBulletSection(title: 'Contraindications', items: e.contraindications),
          if (e.reveals.isNotEmpty) _RevealList(reveals: e.reveals, accent: accent),
          if (e.steps.isNotEmpty) _StepsList(steps: e.steps, accent: accent),
          if (e.bullets.isNotEmpty) HighYieldCard(points: e.bullets, accent: accent),
          const SizedBox(height: 8),
          _relatedRail(context, repo, e),
          const SizedBox(height: 16),
          SourcesFooter(evidence: e.evidence, review: e.review, onReport: () => showReportSheet(context, e.title)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _relatedRail(BuildContext context, ContentRepository repo, LibraryEntry e) {
    final chips = <RelatedChip>[
      for (final id in e.relatedDiseaseIds)
        if (repo.disease(id) != null)
          RelatedChip(label: repo.disease(id)!.name, icon: Icons.coronavirus_rounded, accent: const Color(0xFFFF8A8A), onTap: () => context.push(Routes.disease(id))),
      for (final id in e.relatedDrugIds)
        if (repo.drug(id) != null)
          RelatedChip(label: repo.drug(id)!.genericName, icon: Icons.medication_rounded, accent: const Color(0xFFC3E88D), onTap: () => context.push(Routes.drug(id))),
    ];
    return RelatedRail(title: 'Related', icon: Icons.link_rounded, chips: chips);
  }
}

/// Reveal-on-tap findings (imaging / atlas labels).
class _RevealList extends StatefulWidget {
  const _RevealList({required this.reveals, required this.accent});
  final List<RevealPoint> reveals;
  final Color accent;
  @override
  State<_RevealList> createState() => _RevealListState();
}

class _RevealListState extends State<_RevealList> {
  final Set<int> _revealed = {};

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.visibility_rounded, size: 16, color: widget.accent),
        const SizedBox(width: 8),
        Text('Tap to reveal findings', style: Theme.of(context).textTheme.titleSmall),
      ]),
      const SizedBox(height: 8),
      for (var i = 0; i < widget.reveals.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            accent: _revealed.contains(i) ? widget.accent : null,
            onTap: () => setState(() => _revealed.contains(i) ? _revealed.remove(i) : _revealed.add(i)),
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(_revealed.contains(i) ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 16, color: widget.accent),
                const SizedBox(width: 8),
                Expanded(child: Text(widget.reveals[i].label, style: Theme.of(context).textTheme.titleSmall)),
              ]),
              if (_revealed.contains(i)) Padding(
                padding: const EdgeInsets.only(top: 6, left: 24),
                child: Text(widget.reveals[i].detail, style: TextStyle(color: t.text, height: 1.4)),
              ),
            ]),
          ),
        ),
    ]);
  }
}

/// Numbered procedure steps with optional cautions.
class _StepsList extends StatelessWidget {
  const _StepsList({required this.steps, required this.accent});
  final List<LibraryStep> steps;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Steps', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      for (var i = 0; i < steps.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.16), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text('${i + 1}', style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 13)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(steps[i].title, style: Theme.of(context).textTheme.titleSmall),
              if (steps[i].detail != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(steps[i].detail!, style: TextStyle(color: t.textMuted, height: 1.4))),
              if (steps[i].caution != null) Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.warning_amber_rounded, size: 13, color: t.warning),
                  const SizedBox(width: 4),
                  Expanded(child: Text(steps[i].caution!, style: TextStyle(color: t.warning, fontSize: 12))),
                ]),
              ),
            ])),
          ]),
        ),
    ]);
  }
}

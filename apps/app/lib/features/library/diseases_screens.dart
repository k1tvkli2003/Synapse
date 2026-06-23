import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_services/synapse_services.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../../router/routes.dart';
import '../../state/app_providers.dart';
import '../../state/game_provider.dart';
import 'reference_sections.dart';

const _accent = Color(0xFFFF8A8A);

/// Browse the Disease Bank by system, with search (prompt 45 §3).
class DiseasesListScreen extends ConsumerStatefulWidget {
  const DiseasesListScreen({super.key});
  @override
  ConsumerState<DiseasesListScreen> createState() => _DiseasesListScreenState();
}

class _DiseasesListScreenState extends ConsumerState<DiseasesListScreen> {
  String _query = '';
  BodySystem? _system;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final repo = ref.watch(repositoryProvider);
    var list = repo.diseases;
    if (_system != null) list = list.where((d) => d.system == _system).toList();
    if (_query.isNotEmpty) list = list.where((d) => d.matches(_query)).toList();
    list = [...list]..sort((a, b) => a.name.compareTo(b.name));

    final systems = repo.diseases.map((d) => d.system).toSet().toList()
      ..sort((a, b) => a.label.compareTo(b.label));

    return ModuleScaffold(
      title: 'Diseases',
      subtitle: '${repo.diseases.length} conditions · Concept-anchored',
      accent: _accent,
      showDisclaimer: true,
      onCopilot: () => context.push(Routes.copilot),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          SearchField(hint: 'Search diseases…', onChanged: (v) => setState(() => _query = v)),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: AppChip(label: 'All', selected: _system == null, accent: _accent, onTap: () => setState(() => _system = null)),
                ),
                for (final s in systems)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AppChip(label: s.label, selected: _system == s, accent: _accent, onTap: () => setState(() => _system = s)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: list.isEmpty
                ? EmptyState(icon: Icons.search_off_rounded, title: 'No diseases found', message: 'Try a different search or filter.', accent: _accent)
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 24, top: 4),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final d = list[i];
                      return AppCard(
                        onTap: () => context.push(Routes.disease(d.id)),
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(color: _accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
                            child: Icon(Icons.coronavirus_rounded, color: _accent, size: 21),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(d.name, style: Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: 2),
                              Text('${d.system.label}${d.hasRedFlags ? ' · has red flags' : ''}',
                                  style: TextStyle(color: t.textMuted, fontSize: 12)),
                            ]),
                          ),
                          if (d.difficulty >= 4) AppBadge(label: 'Advanced', color: _accent, subtle: true),
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

/// A polished disease page (prompt 45 §3): sticky summary, collapsible sections,
/// a related rail, a mastery ring and a "Test yourself" CTA.
class DiseaseDetailScreen extends ConsumerWidget {
  const DiseaseDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final repo = ref.watch(repositoryProvider);
    final d = repo.disease(id);
    if (d == null) {
      return ModuleScaffold(title: 'Not found', accent: _accent, body: const EmptyState(icon: Icons.error_outline_rounded, title: 'Disease not found'));
    }
    final mastery = ref.watch(gameProvider).mastery[d.conceptId];

    return ModuleScaffold(
      title: d.name,
      subtitle: d.synonyms.isNotEmpty ? d.synonyms.join(' · ') : d.system.label,
      accent: _accent,
      showDisclaimer: true,
      scrollable: true,
      onCopilot: () => context.push(Routes.copilot),
      actions: [
        AppIconButton(
          icon: Icons.psychology_rounded,
          tooltip: 'See concept',
          onPressed: () => context.goConcept(d.conceptId),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          // Sticky-style summary card.
          AppCard(
            accent: _accent,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(d.summary, style: TextStyle(color: t.text, height: 1.5))),
                const SizedBox(width: 12),
                ConceptMasteryRing(value: mastery?.mastery ?? 0, accent: _accent),
              ]),
              if (d.icd10.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final c in d.icd10) AppBadge(label: 'ICD-10 $c', color: t.textMuted, subtle: true),
                  for (final s in d.specialty) AppBadge(label: s, color: _accent, subtle: true),
                ]),
              ],
            ]),
          ),
          const SizedBox(height: 12),
          if (d.hasRedFlags) RedFlagsCard(flags: d.redFlags),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: AppButton(
                label: 'Test yourself', icon: Icons.quiz_rounded, accent: _accent,
                onPressed: () {
                  ref.read(gameProvider.notifier).report(
                        source: ModuleKey.copilot, kind: RewardKind.review, correct: true,
                        concepts: [d.conceptId], xp: 8,
                      );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Quiz generated for ${d.name} — added to your plan'), behavior: SnackBarBehavior.floating),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            AppButton(
              label: 'Compare', variant: AppButtonVariant.secondary, accent: _accent, size: AppButtonSize.large,
              onPressed: d.differentials.isEmpty ? null : () => context.push(Routes.diseaseCompare([d.id, ...d.differentials.take(2)])),
            ),
          ]),
          const SizedBox(height: 16),
          if (d.epidemiology != null) RefSection(title: 'Epidemiology', body: d.epidemiology!),
          if (d.etiology != null) RefSection(title: 'Etiology', body: d.etiology!),
          if (d.pathophysiology != null) RefSection(title: 'Pathophysiology', body: d.pathophysiology!),
          if (d.riskFactors.isNotEmpty) RefBulletSection(title: 'Risk factors', items: d.riskFactors),
          if (d.presentation.symptoms.isNotEmpty || d.presentation.signs.isNotEmpty)
            RefSection.custom(title: 'Clinical presentation', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (d.presentation.symptoms.isNotEmpty) RefMiniList(label: 'Symptoms', items: d.presentation.symptoms),
              if (d.presentation.signs.isNotEmpty) RefMiniList(label: 'Signs', items: d.presentation.signs),
            ])),
          if (d.workup.labs.isNotEmpty || d.workup.imaging.isNotEmpty)
            RefSection.custom(title: 'Workup', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (d.workup.labs.isNotEmpty) RefMiniList(label: 'Labs', items: d.workup.labs),
              if (d.workup.imaging.isNotEmpty) RefMiniList(label: 'Imaging', items: d.workup.imaging),
            ])),
          if (d.criteria.isNotEmpty) RefBulletSection(title: 'Diagnostic criteria', items: d.criteria),
          _managementSection(context, ref, repo, d),
          if (d.complications.isNotEmpty) RefBulletSection(title: 'Complications', items: d.complications),
          if (d.prognosis != null) RefSection(title: 'Prognosis', body: d.prognosis!),
          if (d.prevention != null) RefSection(title: 'Prevention', body: d.prevention!),
          if (d.highYield.isNotEmpty) HighYieldCard(points: d.highYield, accent: _accent),
          const SizedBox(height: 12),
          _relatedRail(context, repo, d),
          const SizedBox(height: 16),
          SourcesFooter(
            evidence: d.evidence,
            review: d.review,
            onReport: () => showReportSheet(context, d.name),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _managementSection(BuildContext context, WidgetRef ref, ContentRepository repo, Disease d) {
    final m = d.management;
    if (m.conservative.isEmpty && m.medical.isEmpty && m.surgical.isEmpty && m.drugIds.isEmpty) {
      return const SizedBox.shrink();
    }
    return RefSection.custom(
      title: 'Management',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (m.conservative.isNotEmpty) RefMiniList(label: 'Conservative', items: m.conservative),
        if (m.medical.isNotEmpty) RefMiniList(label: 'Medical', items: m.medical),
        if (m.surgical.isNotEmpty) RefMiniList(label: 'Procedural / surgical', items: m.surgical),
        if (m.drugIds.isNotEmpty) ...[
          const SizedBox(height: 8),
          RelatedRail(
            title: 'Drugs',
            icon: Icons.medication_rounded,
            chips: [
              for (final id in m.drugIds)
                if (repo.drug(id) != null)
                  RelatedChip(
                    label: repo.drug(id)!.genericName,
                    icon: Icons.medication_rounded,
                    accent: const Color(0xFFC3E88D),
                    onTap: () => context.push(Routes.drug(id)),
                  ),
            ],
          ),
        ],
        if (m.algorithmId != null) ...[
          const SizedBox(height: 10),
          AppButton(
            label: 'Open decision algorithm', icon: Icons.account_tree_rounded, size: AppButtonSize.small,
            variant: AppButtonVariant.secondary, accent: const Color(0xFF8C9EFF),
            onPressed: () => context.push(Routes.algorithm(m.algorithmId!)),
          ),
        ],
      ]),
    );
  }

  Widget _relatedRail(BuildContext context, ContentRepository repo, Disease d) {
    final chips = <RelatedChip>[
      for (final dx in d.differentials)
        if (repo.disease(dx) != null)
          RelatedChip(label: repo.disease(dx)!.name, icon: Icons.compare_arrows_rounded, accent: _accent, onTap: () => context.push(Routes.disease(dx))),
    ];
    return RelatedRail(title: 'Differentials', icon: Icons.compare_arrows_rounded, chips: chips);
  }
}

/// Side-by-side differential comparison on wide layouts (prompt 45 §3).
class DiseaseCompareScreen extends ConsumerWidget {
  const DiseaseCompareScreen({super.key, required this.ids});
  final List<String> ids;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final repo = ref.watch(repositoryProvider);
    final diseases = ids.map(repo.disease).whereType<Disease>().toList();
    if (diseases.isEmpty) {
      return ModuleScaffold(title: 'Compare', accent: _accent, body: const EmptyState(icon: Icons.compare_arrows_rounded, title: 'Nothing to compare'));
    }

    Widget cell(String label, String? value) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: t.textFaint, fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(value?.isNotEmpty == true ? value! : '—', style: TextStyle(color: t.text, fontSize: 12.5, height: 1.35)),
          ]),
        );

    return ModuleScaffold(
      title: 'Compare',
      subtitle: diseases.map((d) => d.name).join(' vs '),
      accent: _accent,
      showDisclaimer: true,
      scrollable: true,
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final d in diseases)
              Container(
                width: 280,
                margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                child: AppCard(
                  accent: _accent,
                  onTap: () => context.push(Routes.disease(d.id)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d.name, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    cell('Summary', d.summary),
                    cell('Key symptoms', d.presentation.symptoms.take(4).join(', ')),
                    cell('Key signs', d.presentation.signs.take(4).join(', ')),
                    cell('Red flags', d.redFlags.join(', ')),
                    cell('First-line workup', [...d.workup.labs, ...d.workup.imaging].take(4).join(', ')),
                    cell('Management', d.management.medical.take(3).join('; ')),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

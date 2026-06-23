import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_engines/synapse_engines.dart';
import 'package:synapse_services/synapse_services.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../../router/routes.dart';
import '../../state/app_providers.dart';
import '../../state/game_provider.dart';
import 'reference_sections.dart';

const _accent = Color(0xFFC3E88D);

class DrugsListScreen extends ConsumerStatefulWidget {
  const DrugsListScreen({super.key});
  @override
  ConsumerState<DrugsListScreen> createState() => _DrugsListScreenState();
}

class _DrugsListScreenState extends ConsumerState<DrugsListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final repo = ref.watch(repositoryProvider);
    var list = repo.drugs;
    if (_query.isNotEmpty) list = list.where((d) => d.matches(_query)).toList();
    list = [...list]..sort((a, b) => a.genericName.compareTo(b.genericName));

    return ModuleScaffold(
      title: 'Drugs',
      subtitle: '${repo.drugs.length} medications · ${repo.drugClasses.length} classes',
      accent: _accent,
      showDisclaimer: true,
      onCopilot: () => context.push(Routes.copilot),
      actions: [
        AppIconButton(icon: Icons.warning_amber_rounded, tooltip: 'Interaction checker', onPressed: () => context.push(Routes.drugInteractions)),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          SearchField(hint: 'Search drugs & brands…', onChanged: (v) => setState(() => _query = v)),
          const SizedBox(height: 12),
          if (_query.isEmpty) ...[
            SizedBox(
              height: 34,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final c in repo.drugClasses)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AppChip(label: c.name, accent: _accent, onTap: () => context.push(Routes.drugClassRoute(c.id))),
                  ),
              ]),
            ),
            const SizedBox(height: 12),
          ],
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final d = list[i];
                return AppCard(
                  onTap: () => context.push(Routes.drug(d.id)),
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: _accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.medication_rounded, color: _accent, size: 21),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d.genericName, style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 2),
                        Text(d.brandNames.isNotEmpty ? d.brandNames.join(', ') : d.mechanism,
                            style: TextStyle(color: t.textMuted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                    if (d.hasBlackBox) Icon(Icons.report_rounded, color: t.danger, size: 18),
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

class DrugDetailScreen extends ConsumerWidget {
  const DrugDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final repo = ref.watch(repositoryProvider);
    final d = repo.drug(id);
    if (d == null) {
      return ModuleScaffold(title: 'Not found', accent: _accent, body: const EmptyState(icon: Icons.error_outline_rounded, title: 'Drug not found'));
    }
    final mastery = ref.watch(gameProvider).mastery[d.conceptId];

    return ModuleScaffold(
      title: d.genericName,
      subtitle: d.brandNames.isNotEmpty ? d.brandNames.join(' · ') : 'Medication',
      accent: _accent,
      showDisclaimer: true,
      scrollable: true,
      onCopilot: () => context.push(Routes.copilot),
      actions: [AppIconButton(icon: Icons.psychology_rounded, tooltip: 'See concept', onPressed: () => context.goConcept(d.conceptId))],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          AppCard(
            accent: _accent,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(d.mechanism, style: TextStyle(color: t.text, height: 1.5))),
                const SizedBox(width: 12),
                ConceptMasteryRing(value: mastery?.mastery ?? 0, accent: _accent),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final cid in d.classIds)
                  if (repo.drugClass(cid) != null)
                    GestureDetector(
                      onTap: () => context.push(Routes.drugClassRoute(cid)),
                      child: AppBadge(label: repo.drugClass(cid)!.name, color: _accent, subtle: true),
                    ),
                if (d.pregnancyCategory != null) AppBadge(label: 'Pregnancy ${d.pregnancyCategory}', color: t.textMuted, subtle: true),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          if (d.hasBlackBox)
            AppCard(
              color: t.danger.withValues(alpha: 0.08), accent: t.danger,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.report_rounded, color: t.danger),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Black-box warning', style: TextStyle(color: t.danger, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(d.blackBoxWarning!, style: TextStyle(color: t.text, height: 1.4)),
                ])),
              ]),
            ),
          if (d.hasBlackBox) const SizedBox(height: 12),
          if (d.indications.isNotEmpty) _indicationsSection(context, repo, d),
          if (_dosingRows(d).isNotEmpty) RefSection.custom(title: 'Dosing (educational)', child: Column(children: _dosingRows(d))),
          if (d.routes.isNotEmpty) RefBulletSection(title: 'Routes', items: d.routes),
          if (!d.pk.isEmpty) RefSection.custom(title: 'Pharmacokinetics', child: Column(children: [
            if (d.pk.absorption != null) _kv(context, 'Absorption', d.pk.absorption!),
            if (d.pk.distribution != null) _kv(context, 'Distribution', d.pk.distribution!),
            if (d.pk.metabolism != null) _kv(context, 'Metabolism', d.pk.metabolism!),
            if (d.pk.excretion != null) _kv(context, 'Excretion', d.pk.excretion!),
            if (d.pk.halfLife != null) _kv(context, 'Half-life', d.pk.halfLife!),
          ])),
          if (d.contraindications.isNotEmpty) RefBulletSection(title: 'Contraindications', items: d.contraindications),
          if (d.cautions.isNotEmpty) RefBulletSection(title: 'Cautions', items: d.cautions),
          if (d.adverse.common.isNotEmpty || d.adverse.serious.isNotEmpty)
            RefSection.custom(title: 'Adverse effects', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (d.adverse.common.isNotEmpty) RefMiniList(label: 'Common', items: d.adverse.common),
              if (d.adverse.serious.isNotEmpty) RefMiniList(label: 'Serious', items: d.adverse.serious),
            ])),
          if (d.monitoring.isNotEmpty) _monitoringSection(context, repo, d),
          if (d.interactions.isNotEmpty) _interactionsSection(context, repo, d),
          if (d.antidote != null) RefSection(title: 'Antidote / reversal', body: d.antidote!),
          if (d.counseling.isNotEmpty) RefBulletSection(title: 'Patient counseling', items: d.counseling),
          if (d.highYield.isNotEmpty) HighYieldCard(points: d.highYield, accent: _accent),
          const SizedBox(height: 16),
          SourcesFooter(evidence: d.evidence, review: d.review, onReport: () => showReportSheet(context, d.genericName)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _indicationsSection(BuildContext context, ContentRepository repo, Drug d) {
    return RefSection.custom(
      title: 'Indications',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final i in d.indications)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(top: 6, right: 8), child: Icon(Icons.circle, size: 5, color: context.tokens.textFaint)),
              Expanded(child: Text(i, style: TextStyle(color: context.tokens.text, height: 1.4))),
            ]),
          ),
        if (d.indicationDiseaseIds.isNotEmpty) ...[
          const SizedBox(height: 8),
          RelatedRail(
            title: 'Linked diseases', icon: Icons.coronavirus_rounded,
            chips: [
              for (final did in d.indicationDiseaseIds)
                if (repo.disease(did) != null)
                  RelatedChip(label: repo.disease(did)!.name, icon: Icons.coronavirus_rounded, accent: const Color(0xFFFF8A8A), onTap: () => context.push(Routes.disease(did))),
            ],
          ),
        ],
      ]),
    );
  }

  Widget _monitoringSection(BuildContext context, ContentRepository repo, Drug d) {
    return RefSection.custom(
      title: 'Monitoring',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        RefMiniList(label: 'Parameters', items: d.monitoring),
        RelatedRail(
          title: 'Related labs', icon: Icons.science_rounded,
          chips: [RelatedChip(label: 'Open Labs', icon: Icons.science_rounded, accent: const Color(0xFFC3E88D), onTap: () => context.push(Routes.labs))],
        ),
      ]),
    );
  }

  Widget _interactionsSection(BuildContext context, ContentRepository repo, Drug d) {
    final t = context.tokens;
    return RefSection.custom(
      title: 'Interactions',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final ix in d.interactions)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sevDot(t, ix.severity),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_ixLabel(repo, ix), style: TextStyle(color: t.text, fontWeight: FontWeight.w600, fontSize: 13)),
                Text('${ix.severity.label} · ${ix.effect}', style: TextStyle(color: t.textMuted, fontSize: 12)),
              ])),
            ]),
          ),
        const SizedBox(height: 8),
        AppButton(label: 'Open interaction checker', icon: Icons.warning_amber_rounded, size: AppButtonSize.small, variant: AppButtonVariant.secondary, accent: _accent, onPressed: () => context.push(Routes.drugInteractions)),
      ]),
    );
  }

  String _ixLabel(ContentRepository repo, DrugInteraction ix) {
    if (ix.withDrugId != null) return repo.drug(ix.withDrugId!)?.genericName ?? ix.withDrugId!;
    if (ix.withClassId != null) return repo.drugClass(ix.withClassId!)?.name ?? ix.withClassId!;
    return 'Interaction';
  }

  Widget _sevDot(SynapseTokens t, InteractionSeverity s) {
    final c = switch (s) {
      InteractionSeverity.minor => t.success,
      InteractionSeverity.moderate => t.warning,
      InteractionSeverity.major => t.danger,
      InteractionSeverity.contraindicated => t.danger,
    };
    return Padding(padding: const EdgeInsets.only(top: 5), child: Icon(Icons.circle, size: 10, color: c));
  }

  List<Widget> _dosingRows(Drug d) {
    return [
      if (d.dosing.adult != null) _kvStatic('Adult', d.dosing.adult!),
      if (d.dosing.pediatric != null) _kvStatic('Pediatric', d.dosing.pediatric!),
      if (d.dosing.renal != null) _kvStatic('Renal', d.dosing.renal!),
      if (d.dosing.hepatic != null) _kvStatic('Hepatic', d.dosing.hepatic!),
    ];
  }

  Widget _kv(BuildContext context, String k, String v) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 96, child: Text(k, style: TextStyle(color: t.textMuted, fontSize: 12.5, fontWeight: FontWeight.w600))),
        Expanded(child: Text(v, style: TextStyle(color: t.text, fontSize: 13, height: 1.4))),
      ]),
    );
  }

  Widget _kvStatic(String k, String v) => Builder(builder: (context) => _kv(context, k, v));
}

class DrugClassScreen extends ConsumerWidget {
  const DrugClassScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final repo = ref.watch(repositoryProvider);
    final c = repo.drugClass(id);
    if (c == null) {
      return ModuleScaffold(title: 'Not found', accent: _accent, body: const EmptyState(icon: Icons.error_outline_rounded, title: 'Class not found'));
    }
    final members = repo.drugsInClass(id);
    return ModuleScaffold(
      title: c.name,
      subtitle: 'Drug class · ${members.length} members',
      accent: _accent,
      showDisclaimer: true,
      scrollable: true,
      onCopilot: () => context.push(Routes.copilot),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        if (c.summary != null) AppCard(accent: _accent, child: Text(c.summary!, style: TextStyle(color: t.text, height: 1.5))),
        const SizedBox(height: 12),
        if (c.classEffects.isNotEmpty) RefBulletSection(title: 'Class effects', items: c.classEffects),
        const SizedBox(height: 4),
        Text('Members', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final d in members)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ListRow(
              title: d.genericName,
              subtitle: d.brandNames.isNotEmpty ? d.brandNames.join(', ') : null,
              leadingIcon: Icons.medication_rounded,
              accent: _accent,
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(Routes.drug(d.id)),
            ),
          ),
        const SizedBox(height: 24),
      ]),
    );
  }
}

/// The interaction checker (prompt 46 §2): add drugs → severity-ranked results.
class InteractionCheckerScreen extends ConsumerStatefulWidget {
  const InteractionCheckerScreen({super.key});
  @override
  ConsumerState<InteractionCheckerScreen> createState() => _InteractionCheckerScreenState();
}

class _InteractionCheckerScreenState extends ConsumerState<InteractionCheckerScreen> {
  final List<String> _selected = [];
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final repo = ref.watch(repositoryProvider);
    final selectedDrugs = _selected.map(repo.drug).whereType<Drug>().toList();
    final results = InteractionEngine.check(selectedDrugs);
    final candidates = repo.drugs.where((d) => !_selected.contains(d.id) && (_query.isEmpty || d.matches(_query))).toList();

    return ModuleScaffold(
      title: 'Interaction checker',
      subtitle: 'Educational — not prescribing advice',
      accent: const Color(0xFFFFB07A),
      showDisclaimer: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          if (selectedDrugs.isNotEmpty)
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final d in selectedDrugs)
                Chip(
                  label: Text(d.genericName),
                  backgroundColor: t.surfaceAlt,
                  onDeleted: () => setState(() => _selected.remove(d.id)),
                ),
            ]),
          const SizedBox(height: 12),
          if (selectedDrugs.length >= 2) ...[
            Text(results.isEmpty ? 'No known interactions in this set' : '${results.length} interaction${results.length == 1 ? '' : 's'} found',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final r in results)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  accent: _sevColor(t, r.severity),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.warning_amber_rounded, color: _sevColor(t, r.severity), size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${r.a.genericName} + ${r.b.genericName}', style: Theme.of(context).textTheme.titleSmall)),
                      AppBadge(label: r.severity.label, color: _sevColor(t, r.severity), subtle: true),
                    ]),
                    const SizedBox(height: 6),
                    Text(r.effect, style: TextStyle(color: t.text, height: 1.4)),
                    if (r.mechanism != null) ...[
                      const SizedBox(height: 2),
                      Text('Mechanism: ${r.mechanism}', style: TextStyle(color: t.textMuted, fontSize: 12)),
                    ],
                  ]),
                ),
              ),
            const Divider(height: 28),
          ],
          SearchField(hint: 'Add a drug…', onChanged: (v) => setState(() => _query = v)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: candidates.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, i) {
                final d = candidates[i];
                return ListRow(
                  title: d.genericName,
                  subtitle: d.classIds.map((c) => repo.drugClass(c)?.name).whereType<String>().join(', '),
                  leadingIcon: Icons.add_circle_outline_rounded,
                  accent: const Color(0xFFFFB07A),
                  onTap: () => setState(() { _selected.add(d.id); _query = ''; }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _sevColor(SynapseTokens t, InteractionSeverity s) => switch (s) {
        InteractionSeverity.minor => t.success,
        InteractionSeverity.moderate => t.warning,
        InteractionSeverity.major => t.danger,
        InteractionSeverity.contraindicated => t.danger,
      };
}

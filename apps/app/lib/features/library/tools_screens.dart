import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_engines/synapse_engines.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../../router/routes.dart';
import '../../state/app_providers.dart';
import '../../state/game_provider.dart';
import 'reference_sections.dart';

const _accent = Color(0xFF8C9EFF);

class ToolsListScreen extends ConsumerStatefulWidget {
  const ToolsListScreen({super.key});
  @override
  ConsumerState<ToolsListScreen> createState() => _ToolsListScreenState();
}

class _ToolsListScreenState extends ConsumerState<ToolsListScreen> {
  String _query = '';
  ToolCategory? _cat;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final repo = ref.watch(repositoryProvider);
    var list = repo.tools;
    if (_cat != null) list = list.where((x) => x.category == _cat).toList();
    if (_query.isNotEmpty) list = list.where((x) => x.matches(_query)).toList();
    list = [...list]..sort((a, b) => a.name.compareTo(b.name));

    return ModuleScaffold(
      title: 'Calculators',
      subtitle: '${repo.tools.length} scores, formulas & converters',
      accent: _accent,
      showDisclaimer: true,
      onCopilot: () => context.push(Routes.copilot),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          SearchField(hint: 'Search tools…', onChanged: (v) => setState(() => _query = v)),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              Padding(padding: const EdgeInsets.only(right: 8), child: AppChip(label: 'All', selected: _cat == null, accent: _accent, onTap: () => setState(() => _cat = null))),
              for (final c in ToolCategory.values)
                Padding(padding: const EdgeInsets.only(right: 8), child: AppChip(label: c.label, selected: _cat == c, accent: _accent, onTap: () => setState(() => _cat = c))),
            ]),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final tool = list[i];
                return AppCard(
                  onTap: () => context.push(Routes.tool(tool.id)),
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: _accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
                      child: Icon(_iconFor(tool.category), color: _accent, size: 21),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tool.name, style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(tool.description ?? tool.category.label, style: TextStyle(color: t.textMuted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ])),
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

  IconData _iconFor(ToolCategory c) => switch (c) {
        ToolCategory.score => Icons.scoreboard_rounded,
        ToolCategory.formula => Icons.functions_rounded,
        ToolCategory.converter => Icons.swap_horiz_rounded,
        ToolCategory.decision => Icons.account_tree_rounded,
      };
}

/// A data-driven calculator with live result + interpretation band (prompt 47).
class ToolDetailScreen extends ConsumerStatefulWidget {
  const ToolDetailScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<ToolDetailScreen> createState() => _ToolDetailScreenState();
}

class _ToolDetailScreenState extends ConsumerState<ToolDetailScreen> {
  final Map<String, dynamic> _inputs = {};
  bool _scored = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final repo = ref.watch(repositoryProvider);
    final tool = repo.tool(widget.id);
    if (tool == null) {
      return ModuleScaffold(title: 'Not found', accent: _accent, body: const EmptyState(icon: Icons.error_outline_rounded, title: 'Tool not found'));
    }

    // Defaults.
    for (final input in tool.inputs) {
      _inputs.putIfAbsent(input.key, () {
        if (input.type == ToolInputType.boolean) return false;
        if (input.type == ToolInputType.select) return input.defaultValue ?? input.options.first.value;
        return input.defaultValue;
      });
    }

    final result = CalculatorEngine.evaluate(tool, _inputs);

    return ModuleScaffold(
      title: tool.name,
      subtitle: tool.category.label,
      accent: _accent,
      showDisclaimer: true,
      scrollable: true,
      onCopilot: () => context.push(Routes.copilot),
      actions: [
        if (tool.conceptIds.isNotEmpty)
          AppIconButton(icon: Icons.psychology_rounded, tooltip: 'See concept', onPressed: () => context.goConcept(tool.conceptIds.first)),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          if (tool.description != null) Text(tool.description!, style: TextStyle(color: t.textMuted, height: 1.4)),
          const SizedBox(height: 16),
          // Result banner.
          _ResultBanner(tool: tool, result: result),
          const SizedBox(height: 16),
          for (final input in tool.inputs) _buildInput(context, input),
          const SizedBox(height: 12),
          if (tool.references.isNotEmpty)
            SourcesFooter(
              evidence: Evidence(citations: tool.references, levelOfEvidence: tool.evidence.levelOfEvidence),
              review: tool.review,
              onReport: () => showReportSheet(context, tool.name),
            ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Quiz me on this score', icon: Icons.quiz_rounded, variant: AppButtonVariant.secondary, accent: _accent, expand: true,
            onPressed: () {
              if (tool.conceptIds.isNotEmpty) {
                ref.read(gameProvider.notifier).report(source: ModuleKey.labs, kind: RewardKind.review, correct: true, concepts: tool.conceptIds, xp: 6);
              }
              setState(() => _scored = true);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nice — interpretation logged to your plan'), behavior: SnackBarBehavior.floating));
            },
          ),
          if (_scored) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Mastery updated for this concept.', style: TextStyle(color: t.success, fontSize: 12))),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildInput(BuildContext context, ToolInput input) {
    switch (input.type) {
      case ToolInputType.boolean:
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: AppSwitchTile(
            title: input.label,
            subtitle: input.help,
            value: _inputs[input.key] == true,
            onChanged: (v) => setState(() => _inputs[input.key] = v),
          ),
        );
      case ToolInputType.select:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(input.label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final o in input.options)
                AppChip(label: o.label, selected: _inputs[input.key] == o.value, accent: _accent, onTap: () => setState(() => _inputs[input.key] = o.value)),
            ]),
          ]),
        );
      case ToolInputType.number:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: AppTextField(
            label: input.unit != null ? '${input.label} (${input.unit})' : input.label,
            hint: input.help ?? (input.min != null ? '${input.min}–${input.max}' : null),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            accent: _accent,
            onChanged: (v) => setState(() => _inputs[input.key] = double.tryParse(v)),
          ),
        );
    }
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.tool, required this.result});
  final ClinicalTool tool;
  final ToolResult result;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bandColor = result.band != null ? Color(result.band!.colorHex) : _accent;
    return AppCard(
      accent: result.hasError ? t.border : bandColor,
      color: result.hasError ? t.surface : bandColor.withValues(alpha: 0.10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tool.outputLabel, style: TextStyle(color: t.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        if (result.hasError)
          Text(result.error!, style: TextStyle(color: t.textMuted, fontSize: 16))
        else ...[
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(result.display, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
            if (result.band != null) ...[
              const SizedBox(width: 12),
              Flexible(child: AppBadge(label: result.band!.label, color: bandColor)),
            ],
          ]),
          if (result.band != null) ...[
            const SizedBox(height: 6),
            Text(result.band!.interpretation, style: TextStyle(color: t.text, height: 1.4)),
          ],
          if (result.breakdown.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final b in result.breakdown)
              Text('· $b', style: TextStyle(color: t.textFaint, fontSize: 11.5)),
          ],
        ],
      ]),
    );
  }
}

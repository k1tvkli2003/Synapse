import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_engines/synapse_engines.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../../router/routes.dart';
import '../../state/game_provider.dart';

final _accent = Color(ModuleKey.labs.accentHex);

class LabsHomeScreen extends StatelessWidget {
  const LabsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ModuleScaffold(
      title: 'Labs',
      subtitle: ModuleKey.labs.tagline,
      accent: _accent,
      showDisclaimer: true,
      onCopilot: () => context.push(Routes.copilot),
      actions: [
        AppIconButton(icon: Icons.rule_rounded, tooltip: 'Ruleset & ranges', onPressed: () => context.push('/clinical/labs/ruleset')),
      ],
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text('Choose a panel to interpret', style: TextStyle(color: t.textMuted)),
          const SizedBox(height: 16),
          for (final p in LabPanelType.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                accent: _accent,
                onTap: () => context.push(Routes.labPanel(p.name)),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: _accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                      child: Icon(Icons.science_rounded, color: _accent),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.label, style: Theme.of(context).textTheme.titleLarge),
                          Text(p.fullName, style: TextStyle(color: t.textMuted, fontSize: 13)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'A deterministic, versioned rule engine produces pattern-based '
            'interpretations with an audit trail (${LabRuleEngine.version}).',
            style: TextStyle(color: t.textFaint, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class LabPanelScreen extends ConsumerStatefulWidget {
  const LabPanelScreen({super.key, required this.panel});
  final LabPanelType panel;
  @override
  ConsumerState<LabPanelScreen> createState() => _LabPanelScreenState();
}

class _LabPanelScreenState extends ConsumerState<LabPanelScreen> {
  final Map<String, TextEditingController> _controllers = {};
  RuleResult? _result;

  @override
  void initState() {
    super.initState();
    for (final a in LabReference.analytes(widget.panel)) {
      _controllers[a.id] = TextEditingController(text: _normalValue(a).toString());
    }
  }

  double _normalValue(LabAnalyte a) =>
      double.parse((((a.refLow + a.refHigh) / 2)).toStringAsFixed(1));

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _loadExample() {
    // Push an illustrative abnormal pattern per panel.
    final ex = switch (widget.panel) {
      LabPanelType.cbc => {'wbc': '14.5', 'hgb': '9.2', 'plt': '90', 'mcv': '72'},
      LabPanelType.bmp => {'na': '131', 'k': '6.8', 'cl': '99', 'hco3': '16', 'bun': '48', 'cr': '3.1', 'glu': '290', 'ca': '8.9'},
      LabPanelType.lft => {'ast': '180', 'alt': '70', 'alp': '110', 'tbili': '3.4', 'alb': '2.9'},
    };
    setState(() {
      ex.forEach((k, v) => _controllers[k]?.text = v);
      _result = null;
    });
  }

  void _interpret() {
    final values = <String, double>{};
    for (final entry in _controllers.entries) {
      final v = double.tryParse(entry.value.text.trim());
      if (v != null) values[entry.key] = v;
    }
    final result = LabRuleEngine.evaluate(widget.panel, values);
    setState(() => _result = result);

    // Feed the game: each non-baseline interpretation touches concepts.
    final concepts = result.interpretations.expand((i) => i.conceptIds).toSet().toList();
    ref.read(gameProvider.notifier).report(
          source: ModuleKey.labs,
          kind: RewardKind.correct,
          correct: true,
          concepts: concepts,
          xp: 10,
          achievementMetric: 'labs.eval',
        );
  }

  @override
  Widget build(BuildContext context) {
    final analytes = LabReference.analytes(widget.panel);
    return ModuleScaffold(
      title: '${widget.panel.label} interpreter',
      subtitle: widget.panel.fullName,
      accent: _accent,
      showDisclaimer: true,
      actions: [
        AppIconButton(icon: Icons.auto_fix_high_rounded, tooltip: 'Load example', onPressed: _loadExample),
      ],
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          AppCard(
            child: Column(
              children: [
                for (final a in analytes) _AnalyteRow(analyte: a, controller: _controllers[a.id]!),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppButton(label: 'Interpret panel', expand: true, accent: _accent, icon: Icons.biotech_rounded, onPressed: _interpret),
          if (_result != null) ...[
            const SizedBox(height: 20),
            _ResultView(result: _result!),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _AnalyteRow extends StatelessWidget {
  const _AnalyteRow({required this.analyte, required this.controller});
  final LabAnalyte analyte;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(analyte.name, style: Theme.of(context).textTheme.titleSmall),
                Text('${analyte.refLow}–${analyte.refHigh} ${analyte.unit}',
                    style: TextStyle(color: t.textFaint, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: t.surfaceAlt,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result});
  final RuleResult result;

  Color _sevColor(SynapseTokens t, InterpretationSeverity s) => switch (s) {
        InterpretationSeverity.critical => t.danger,
        InterpretationSeverity.concern => t.warning,
        InterpretationSeverity.watch => t.info,
        InterpretationSeverity.info => t.success,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Interpretation', subtitle: 'Ruleset ${result.rulesetVersion}'),
        if (result.derivedIndices.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: result.derivedIndices.entries
                  .map((e) => AppChip(label: '${e.key}: ${e.value}', accent: _accent))
                  .toList(),
            ),
          ),
        ...result.interpretations.map((i) {
          final c = _sevColor(t, i.severity);
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(i.severity == InterpretationSeverity.critical
                        ? Icons.warning_rounded
                        : Icons.info_outline_rounded, color: c, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(i.title, style: TextStyle(color: c, fontWeight: FontWeight.w800))),
                  ],
                ),
                const SizedBox(height: 6),
                Text(i.detail, style: TextStyle(color: t.text, height: 1.45, fontSize: 13.5)),
                if (i.nextSteps.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...i.nextSteps.map((s) => Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.arrow_right_rounded, size: 16, color: t.textMuted),
                            Expanded(child: Text(s, style: TextStyle(color: t.textMuted, fontSize: 12.5))),
                          ],
                        ),
                      )),
                ],
                if (i.conceptIds.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: i.conceptIds
                        .map((cid) => AppChip(
                              label: 'Concept',
                              icon: Icons.hub_rounded,
                              onTap: () => context.push(Routes.concept(cid)),
                            ))
                        .toList(),
                  ),
                ],
                if (i.firedRuleId != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('rule: ${i.firedRuleId}', style: TextStyle(color: t.textFaint, fontSize: 10)),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

/// The ruleset & reference viewer (prompt 16 §3): the deterministic, versioned
/// rules and reference ranges behind every interpretation — the audit surface.
class LabRulesetScreen extends ConsumerWidget {
  const LabRulesetScreen({super.key});

  static const _rules = {
    LabPanelType.cbc: [
      ('cbc.anemia', 'Low hemoglobin → anemia, classified by MCV'),
      ('cbc.leukocytosis', 'High WBC → consider infection/inflammation'),
      ('cbc.leukopenia', 'Low WBC → immunosuppression risk'),
      ('cbc.thrombocytopenia', 'Low platelets → bleeding risk'),
    ],
    LabPanelType.bmp: [
      ('bmp.hagma', 'High anion gap → metabolic acidosis (MUDPILES)'),
      ('bmp.hyperkalemia', 'High potassium → ECG changes / critical value'),
      ('bmp.hypokalemia', 'Low potassium → weakness, arrhythmia'),
      ('bmp.hyponatremia', 'Low sodium → correct slowly'),
      ('bmp.hypernatremia', 'High sodium → free-water deficit'),
      ('bmp.aki', 'Elevated creatinine → acute kidney injury'),
      ('bmp.hyperglycemia', 'High glucose → evaluate for DKA/HHS'),
    ],
    LabPanelType.lft: [
      ('lft.hepatocellular', 'AST/ALT-predominant → hepatocyte injury'),
      ('lft.ast_alt_ratio', 'AST:ALT ≥ 2 → alcoholic pattern'),
      ('lft.cholestatic', 'ALP-predominant → cholestasis/obstruction'),
      ('lft.bilirubin', 'High bilirubin → jaundice'),
      ('lft.albumin', 'Low albumin → impaired synthetic function'),
    ],
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    return ModuleScaffold(
      title: 'Lab ruleset',
      subtitle: 'Deterministic · ${LabRuleEngine.version}',
      accent: _accent,
      showDisclaimer: true,
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          AppCard(accent: _accent, child: Row(children: [
            Icon(Icons.verified_rounded, color: _accent),
            const SizedBox(width: 12),
            Expanded(child: Text('Same input → same output. Every interpretation records the rule that fired and the ruleset version (${LabRuleEngine.version}).', style: TextStyle(color: t.text, height: 1.4))),
          ])),
          for (final panel in LabPanelType.values) ...[
            const SizedBox(height: 16),
            Text('${panel.label} — reference ranges', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            AppCard(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), child: Column(
              children: [
                for (final a in LabReference.analytes(panel))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Expanded(flex: 3, child: Text(a.name, style: TextStyle(color: t.text, fontSize: 13, fontWeight: FontWeight.w600))),
                      Expanded(flex: 3, child: Text('${a.refLow}–${a.refHigh} ${a.unit}', style: TextStyle(color: t.textMuted, fontSize: 12.5))),
                      Expanded(flex: 2, child: Text(a.criticalHigh != null ? '⚠ ${a.criticalHigh}' : '', textAlign: TextAlign.right, style: TextStyle(color: t.danger, fontSize: 12))),
                    ]),
                  ),
              ],
            )),
            const SizedBox(height: 8),
            Text('Rules', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            for (final (id, desc) in _rules[panel]!)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: t.surfaceAlt, borderRadius: BorderRadius.circular(6)),
                    child: Text(id, style: TextStyle(color: t.textMuted, fontSize: 11, fontFamily: 'monospace')),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(desc, style: TextStyle(color: t.text, fontSize: 13, height: 1.35))),
                ]),
              ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

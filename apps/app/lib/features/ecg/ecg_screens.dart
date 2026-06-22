import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_engines/synapse_engines.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../../router/routes.dart';
import '../../state/app_providers.dart';
import '../../state/game_provider.dart';
import 'ecg_view.dart';

final _accent = Color(ModuleKey.ecg.accentHex);

class EcgHomeScreen extends ConsumerWidget {
  const EcgHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final cases = ref.watch(repositoryProvider).ecgCases;
    return ModuleScaffold(
      title: 'ECG',
      subtitle: ModuleKey.ecg.tagline,
      accent: _accent,
      showDisclaimer: true,
      onCopilot: () => context.push(Routes.copilot),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
            child: Row(
              children: [
                HeartsRow(hearts: ref.watch(heartsProvider)),
                const Spacer(),
                AppButton(
                  label: 'Start drill',
                  icon: Icons.bolt_rounded,
                  size: AppButtonSize.small,
                  accent: _accent,
                  onPressed: () => context.push(Routes.ecgDrill),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: cases.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final c = cases[i];
                return AppCard(
                  onTap: () => context.push(Routes.ecgCase(c.id)),
                  accent: _accent,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: _accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.monitor_heart_rounded, color: _accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.title, style: Theme.of(context).textTheme.titleSmall),
                            Text('Difficulty ${'★' * c.difficulty}', style: TextStyle(color: t.textMuted, fontSize: 12)),
                          ],
                        ),
                      ),
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

/// Endless ECG drill — the [DrillShell] reads identical to Terms/Sounds.
class EcgDrillScreen extends ConsumerStatefulWidget {
  const EcgDrillScreen({super.key, this.singleCaseId});
  final String? singleCaseId;
  @override
  ConsumerState<EcgDrillScreen> createState() => _EcgDrillScreenState();
}

class _EcgDrillScreenState extends ConsumerState<EcgDrillScreen> {
  late List<EcgCase> _cases;
  int _index = 0;
  int? _selected;
  bool _answered = false;

  @override
  void initState() {
    super.initState();
    final all = ref.read(repositoryProvider).ecgCases;
    if (widget.singleCaseId != null) {
      _cases = all.where((c) => c.id == widget.singleCaseId).toList();
    } else {
      _cases = [...all]..shuffle();
    }
  }

  void _check() {
    if (_answered) {
      _next();
      return;
    }
    if (_selected == null) return;
    final c = _cases[_index];
    final correct = c.isCorrect(_selected!);
    setState(() => _answered = true);
    ref.read(gameProvider.notifier).report(
          source: ModuleKey.ecg,
          kind: RewardKind.correct,
          correct: correct,
          concepts: [if (c.conceptId != null) c.conceptId!],
          xp: correct ? 8 : 0,
          firstTry: correct,
          hearted: true,
          achievementMetric: correct ? 'ecg.correct' : '',
        );
  }

  void _next() {
    if (_index < _cases.length - 1) {
      setState(() {
        _index++;
        _selected = null;
        _answered = false;
      });
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (_cases.isEmpty) {
      return const Scaffold(body: Center(child: Text('No cases')));
    }
    final c = _cases[_index];
    final params = EcgGenerator.paramsForRhythm(c.rhythm);
    return DrillShell(
      accent: _accent,
      progress: _index / _cases.length,
      headerTrailing: HeartsRow(hearts: ref.watch(heartsProvider), size: 16),
      continueEnabled: _selected != null,
      continueLabel: _answered ? (_index < _cases.length - 1 ? 'Next' : 'Finish') : 'Check',
      onContinue: _check,
      feedback: _answered
          ? QuizFeedbackBanner(
              correct: c.isCorrect(_selected!),
              title: c.isCorrect(_selected!) ? 'Correct — ${c.diagnosis}' : 'It was ${c.diagnosis}',
              explanation: c.teaching,
              onSeeConcept: c.conceptId != null ? () => context.push(Routes.concept(c.conceptId!)) : null,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(c.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          EcgStrip(params: params),
          if (_answered && c.findings.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: c.findings.map((f) => AppChip(label: f, accent: _accent)).toList(),
            ),
          ],
          const SizedBox(height: 16),
          Text('What is the diagnosis?', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          ...List.generate(c.options.length, (i) {
            final selected = _selected == i;
            final isAnswer = i == c.correctIndex;
            Color border = t.border;
            Color? fill;
            if (_answered && isAnswer) {
              border = t.success;
              fill = t.success.withValues(alpha: 0.12);
            } else if (_answered && selected && !isAnswer) {
              border = t.danger;
              fill = t.danger.withValues(alpha: 0.12);
            } else if (selected) {
              border = _accent;
              fill = _accent.withValues(alpha: 0.12);
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: _answered ? null : () => setState(() => _selected = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: fill ?? t.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border, width: selected || (_answered && isAnswer) ? 2 : 1),
                  ),
                  child: Text(c.options[i], style: Theme.of(context).textTheme.titleMedium),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

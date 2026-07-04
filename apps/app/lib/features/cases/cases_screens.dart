import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_engines/synapse_engines.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../../router/routes.dart';
import '../../state/app_providers.dart';
import '../../state/game_provider.dart';
import '../ecg/ecg_view.dart';

const _accent = Color(0xFFB794F6);

class CasesListScreen extends ConsumerWidget {
  const CasesListScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final cases = ref.watch(repositoryProvider).cases;
    return ModuleScaffold(
      title: 'Cases',
      subtitle: 'Virtual patients across modules',
      accent: _accent,
      showDisclaimer: true,
      onCopilot: () => context.push(Routes.copilot),
      body: ListView.separated(
        padding: const EdgeInsets.only(top: 8, bottom: 100),
        itemCount: cases.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final c = cases[i];
          final modules = c.stages.map((s) => s.module).toSet();
          return AppCard(
            accent: _accent,
            onTap: () => context.push(Routes.caseDetail(c.id)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(color: _accent.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(13)),
                      child: const Icon(Icons.personal_injury_rounded, color: _accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.title, style: Theme.of(context).textTheme.titleMedium),
                          if (c.demographics != null) Text(c.demographics!, style: TextStyle(color: t.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    Text('${c.stageCount} steps', style: TextStyle(color: t.textMuted, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: modules
                      .map((m) => AppChip(label: m.title, icon: ModuleVisuals.icon(m), accent: Color(m.accentHex)))
                      .toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class CasePlayerScreen extends ConsumerStatefulWidget {
  const CasePlayerScreen({super.key, required this.caseId});
  final String caseId;
  @override
  ConsumerState<CasePlayerScreen> createState() => _CasePlayerScreenState();
}

class _CasePlayerScreenState extends ConsumerState<CasePlayerScreen> {
  VirtualPatientCase? _case;
  int _stage = -1; // -1 = presentation
  int? _selected;
  bool _answered = false;
  int _correct = 0;

  @override
  void initState() {
    super.initState();
    _case = ref.read(repositoryProvider).cases.firstWhere(
          (c) => c.id == widget.caseId,
          orElse: () => const VirtualPatientCase(id: 'x', title: '?', presentation: '', stages: []),
        );
  }

  void _start() => setState(() => _stage = 0);

  void _check() {
    if (_answered) {
      _next();
      return;
    }
    if (_selected == null) return;
    final st = _case!.stages[_stage];
    final correct = st.isCorrect(_selected!);
    setState(() => _answered = true);
    if (correct) _correct++;
    ref.read(gameProvider.notifier).report(
          source: st.module,
          kind: RewardKind.correct,
          correct: correct,
          concepts: st.conceptIds,
          xp: correct ? 10 : 0,
          hearted: false,
        );
  }

  void _next() {
    if (_stage < _case!.stages.length - 1) {
      setState(() {
        _stage++;
        _selected = null;
        _answered = false;
      });
    } else {
      _finish();
    }
  }

  void _finish() {
    final c = _case!;
    ref.read(eventBusProvider).publish(CaseCompleted(caseId: c.id, conceptIds: c.conceptIds));
    ref.read(gameProvider.notifier).report(
          source: ModuleKey.copilot,
          kind: RewardKind.lesson,
          correct: true,
          concepts: c.conceptIds,
          xp: 25,
          gems: 10,
          achievementMetric: 'cases.completed',
        );
    setState(() => _stage = c.stages.length); // done
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = _case;
    if (c == null || c.stages.isEmpty) {
      return const Scaffold(body: Center(child: Text('Case not found')));
    }

    if (_stage == -1) {
      return ModuleScaffold(
        title: c.title,
        subtitle: c.demographics,
        accent: _accent,
        showDisclaimer: true,
        scrollable: true,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            AppCard(
              feature: true,
              accent: _accent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Presentation', style: TextStyle(color: t.textFaint, fontSize: 12, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Text(c.presentation, style: Theme.of(context).textTheme.titleMedium?.copyWith(height: 1.5)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            AppButton(label: 'Begin encounter', expand: true, accent: _accent, icon: Icons.play_arrow_rounded, onPressed: _start),
            const SizedBox(height: 40),
          ],
        ),
      );
    }

    if (_stage >= c.stages.length) {
      return Scaffold(
        body: SafeArea(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.verified_rounded, size: 64, color: _accent),
                    const SizedBox(height: 16),
                    Text('Case complete', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text('$_correct / ${c.stageCount} stages correct',
                        style: TextStyle(color: t.textMuted)),
                    if (c.finalDiagnosis != null) ...[
                      const SizedBox(height: 12),
                      AppCard(
                        accent: t.success,
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_rounded, color: t.success),
                            const SizedBox(width: 10),
                            Expanded(child: Text('Diagnosis: ${c.finalDiagnosis}', style: Theme.of(context).textTheme.titleMedium)),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text('Mastery distributed to ${c.conceptIds.length} concepts across modules.',
                        textAlign: TextAlign.center, style: TextStyle(color: t.textFaint, fontSize: 12)),
                    const SizedBox(height: 24),
                    AppButton(label: 'Done', accent: _accent, onPressed: () => Navigator.of(context).maybePop()),
                  ],
                ),
              ),
              const Positioned.fill(child: ConfettiOverlay(play: true)),
            ],
          ),
        ),
      );
    }

    final st = c.stages[_stage];
    final accent = Color(st.module.accentHex);
    return DrillShell(
      accent: accent,
      progress: _stage / c.stages.length,
      headerTrailing: AppBadge(label: st.module.title, color: accent, subtle: true),
      continueEnabled: _selected != null,
      continueLabel: _answered ? (_stage < c.stages.length - 1 ? 'Next' : 'Finish case') : 'Submit',
      onContinue: _check,
      feedback: _answered
          ? QuizFeedbackBanner(
              correct: st.isCorrect(_selected!),
              explanation: st.rationale,
              onSeeConcept: st.conceptIds.isNotEmpty ? () => context.push(Routes.concept(st.conceptIds.first)) : null,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(st.title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: accent)),
          const SizedBox(height: 8),
          Text(st.prompt, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          if (st.payload['rhythm'] != null) ...[
            EcgStrip(params: EcgGenerator.paramsForRhythm(_rhythm(st.payload['rhythm']!)), height: 150),
            const SizedBox(height: 16),
          ],
          ...List.generate(st.options.length, (i) {
            final selected = _selected == i;
            final isAnswer = i == st.correctIndex;
            Color border = t.border;
            Color? fill;
            if (_answered && isAnswer) {
              border = t.success;
              fill = t.success.withValues(alpha: 0.12);
            } else if (_answered && selected && !isAnswer) {
              border = t.danger;
              fill = t.danger.withValues(alpha: 0.12);
            } else if (selected) {
              border = accent;
              fill = accent.withValues(alpha: 0.12);
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
                  child: Text(st.options[i], style: Theme.of(context).textTheme.titleMedium),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  EcgRhythm _rhythm(String name) =>
      EcgRhythm.values.firstWhere((r) => r.name == name, orElse: () => EcgRhythm.sinus);
}

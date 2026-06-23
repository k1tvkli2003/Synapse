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
                  label: 'Generative',
                  icon: Icons.auto_graph_rounded,
                  size: AppButtonSize.small,
                  variant: AppButtonVariant.secondary,
                  accent: _accent,
                  onPressed: () => context.push('/clinical/ecg/generative'),
                ),
                const SizedBox(width: 8),
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

String ecgRhythmLabel(EcgRhythm r) => switch (r) {
      EcgRhythm.sinus => 'Sinus rhythm',
      EcgRhythm.tachycardia => 'Sinus tachycardia',
      EcgRhythm.bradycardia => 'Sinus bradycardia',
      EcgRhythm.afib => 'Atrial fibrillation',
      EcgRhythm.flutter => 'Atrial flutter',
      EcgRhythm.vtach => 'Ventricular tachycardia',
      EcgRhythm.vfib => 'Ventricular fibrillation',
      EcgRhythm.stemi => 'STEMI',
      EcgRhythm.hyperkalemia => 'Hyperkalemia',
      EcgRhythm.heartBlock => 'Complete heart block',
      EcgRhythm.asystole => 'Asystole',
    };

String ecgRhythmTeaching(EcgRhythm r) => switch (r) {
      EcgRhythm.sinus => 'Normal P-QRS-T at a regular rate; every P is followed by a QRS.',
      EcgRhythm.tachycardia => 'Rate > 100 with preserved morphology — look for an underlying driver.',
      EcgRhythm.bradycardia => 'Rate < 60; symptomatic bradycardia may need atropine or pacing.',
      EcgRhythm.afib => 'Irregularly irregular with no discernible P waves and a fibrillatory baseline.',
      EcgRhythm.flutter => 'Sawtooth flutter waves, often ~150 bpm with 2:1 conduction.',
      EcgRhythm.vtach => 'Wide-complex tachycardia from below the AV node; can be pulseless.',
      EcgRhythm.vfib => 'Chaotic, disorganized waveform — a shockable arrest rhythm.',
      EcgRhythm.stemi => 'ST elevation in contiguous leads — acute coronary occlusion.',
      EcgRhythm.hyperkalemia => 'Peaked T waves; as K⁺ rises the QRS widens toward a sine wave.',
      EcgRhythm.heartBlock => 'P waves and QRS march out independently (AV dissociation).',
      EcgRhythm.asystole => 'A near-flat line — confirm in two leads; not a shockable rhythm.',
    };

/// The generative ECG lab (prompt 14): synthesise any rhythm from parameters and
/// see the tracing update live. Powered by the pure-Dart [EcgGenerator].
class GenerativeEcgScreen extends ConsumerStatefulWidget {
  const GenerativeEcgScreen({super.key});
  @override
  ConsumerState<GenerativeEcgScreen> createState() => _GenerativeEcgScreenState();
}

class _GenerativeEcgScreenState extends ConsumerState<GenerativeEcgScreen> {
  EcgGenParams _p = const EcgGenParams();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ModuleScaffold(
      title: 'Generative ECG',
      subtitle: 'Synthesise any rhythm, live',
      accent: _accent,
      showDisclaimer: true,
      scrollable: true,
      onCopilot: () => context.push(Routes.copilot),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          AppCard(padding: const EdgeInsets.all(8), child: EcgStrip(params: _p, height: 200)),
          const SizedBox(height: 8),
          Text(ecgRhythmLabel(_p.rhythm), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(ecgRhythmTeaching(_p.rhythm), style: TextStyle(color: t.textMuted, height: 1.4)),
          const SizedBox(height: 16),
          Text('Rhythm', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final r in EcgRhythm.values)
              AppChip(
                label: ecgRhythmLabel(r),
                selected: _p.rhythm == r,
                accent: _accent,
                onTap: () => setState(() => _p = EcgGenerator.paramsForRhythm(r)),
              ),
          ]),
          const SizedBox(height: 16),
          _slider('Rate', '${_p.rateBpm} bpm', _p.rateBpm.toDouble(), 20, 300, (v) => setState(() => _p = _p.copyWith(rateBpm: v.round()))),
          if (_p.rhythm == EcgRhythm.hyperkalemia)
            _slider('Potassium', '${_p.potassium.toStringAsFixed(1)} mmol/L', _p.potassium, 4, 9, (v) => setState(() => _p = _p.copyWith(potassium: v))),
          if (_p.rhythm == EcgRhythm.stemi)
            _slider('ST elevation', '+${(_p.stElevation * 10).toStringAsFixed(1)} mm', _p.stElevation, 0, 0.6, (v) => setState(() => _p = _p.copyWith(stElevation: v))),
          const SizedBox(height: 16),
          AppButton(
            label: 'Quiz me on this tracing', icon: Icons.quiz_rounded, accent: _accent, variant: AppButtonVariant.secondary, expand: true,
            onPressed: () {
              ref.read(gameProvider.notifier).report(source: ModuleKey.ecg, kind: RewardKind.review, correct: true, xp: 6);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logged — generative practice counts toward mastery'), behavior: SnackBarBehavior.floating));
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _slider(String label, String value, double v, double min, double max, ValueChanged<double> onChanged) {
    final t = context.tokens;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const Spacer(),
        Text(value, style: TextStyle(color: _accent, fontWeight: FontWeight.w700)),
      ]),
      Slider(value: v.clamp(min, max), min: min, max: max, activeColor: _accent, onChanged: onChanged),
      SizedBox(height: 4, child: Container(color: t.bg)),
    ]);
  }
}

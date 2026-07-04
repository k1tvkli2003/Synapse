import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../../router/routes.dart';
import '../../state/app_providers.dart';
import '../../state/game_provider.dart';

const _accent = Color(0xFF5FD9C4);

/// The OSCE station library (prompt 52 §5).
class OsceListScreen extends ConsumerWidget {
  const OsceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final repo = ref.watch(repositoryProvider);
    final stations = repo.osceStations;

    return ModuleScaffold(
      title: 'OSCE Simulator',
      subtitle: 'Practise communication & reasoning',
      accent: _accent,
      showDisclaimer: true,
      onCopilot: () => context.push(Routes.copilot),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          AppCard(accent: _accent, child: Row(children: [
            const Icon(Icons.record_voice_over_rounded, color: _accent),
            const SizedBox(width: 12),
            Expanded(child: Text('Interview an AI standardized patient, then give your differential and plan — scored against a clinical rubric.', style: TextStyle(color: t.text, height: 1.4))),
          ])),
          const SizedBox(height: 16),
          for (final s in stations)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                onTap: () => context.push(Routes.osceStation(s.id)),
                child: Row(children: [
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(color: _accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.person_rounded, color: _accent),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.title, style: Theme.of(context).textTheme.titleSmall),
                    Text('${s.type.label} · ${s.patientName} · ${s.minutes} min', style: TextStyle(color: t.textMuted, fontSize: 12.5)),
                  ])),
                  const Icon(Icons.chevron_right_rounded),
                ]),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// The "door sign" briefing before entering a station (prompt 52 §1).
class OsceStationScreen extends ConsumerWidget {
  const OsceStationScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final s = ref.watch(repositoryProvider).osceStation(id);
    if (s == null) {
      return ModuleScaffold(title: 'Not found', accent: _accent, body: const EmptyState(icon: Icons.error_outline_rounded, title: 'Station not found'));
    }
    return ModuleScaffold(
      title: s.title,
      subtitle: s.type.label,
      accent: _accent,
      showDisclaimer: true,
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          AppCard(
            accent: _accent,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.assignment_rounded, color: _accent, size: 18),
                const SizedBox(width: 8),
                Text('Candidate instructions', style: Theme.of(context).textTheme.titleSmall),
              ]),
              const SizedBox(height: 8),
              Text(s.doorSign, style: TextStyle(color: t.text, height: 1.5)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                AppBadge(label: s.patientName, color: _accent, subtle: true),
                if (s.affect != null) AppBadge(label: 'Affect: ${s.affect}', color: t.textMuted, subtle: true),
                AppBadge(label: '${s.minutes} min', color: t.textMuted, subtle: true),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          Text('You will be scored on:', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final d in OsceDomain.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Icon(Icons.check_circle_outline_rounded, size: 16, color: _accent),
                const SizedBox(width: 8),
                Text(d.label, style: TextStyle(color: t.text)),
              ]),
            ),
          const SizedBox(height: 20),
          AppButton(label: 'Enter the room', icon: Icons.meeting_room_rounded, accent: _accent, expand: true, onPressed: () => context.push(Routes.oscePlay(s.id))),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

enum _Phase { interview, reasoning, debrief }

class OscePlayScreen extends ConsumerStatefulWidget {
  const OscePlayScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<OscePlayScreen> createState() => _OscePlayScreenState();
}

class _OscePlayScreenState extends ConsumerState<OscePlayScreen> {
  _Phase _phase = _Phase.interview;
  final List<(bool, String)> _transcript = []; // (isLearner, text)
  final Set<String> _asked = {};
  final TextEditingController _input = TextEditingController();
  final Set<String> _dx = {};
  final Set<String> _plan = {};
  OsceScore? _score;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(repositoryProvider).osceStation(widget.id);
    if (s == null) {
      return ModuleScaffold(title: 'Not found', accent: _accent, body: const EmptyState(icon: Icons.error_outline_rounded, title: 'Station not found'));
    }
    if (_transcript.isEmpty) {
      _transcript.add((false, s.openingLine));
    }
    return ModuleScaffold(
      title: s.patientName,
      subtitle: switch (_phase) { _Phase.interview => 'Interview', _Phase.reasoning => 'Differential & plan', _Phase.debrief => 'Debrief' },
      accent: _accent,
      showDisclaimer: true,
      body: switch (_phase) {
        _Phase.interview => _buildInterview(context, s),
        _Phase.reasoning => _buildReasoning(context, s),
        _Phase.debrief => _buildDebrief(context, s),
      },
    );
  }

  Widget _buildInterview(BuildContext context, OsceStation s) {
    final t = context.tokens;
    final remaining = s.beats.where((b) => !_asked.contains(b.topic)).toList();
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 12, bottom: 12),
            itemCount: _transcript.length,
            itemBuilder: (context, i) {
              final (isLearner, text) = _transcript[i];
              return Align(
                alignment: isLearner ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.74),
                  decoration: BoxDecoration(
                    color: isLearner ? _accent.withValues(alpha: 0.18) : t.surfaceAlt,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(text, style: TextStyle(color: t.text, height: 1.35)),
                ),
              );
            },
          ),
        ),
        if (remaining.isNotEmpty)
          SizedBox(
            height: 38,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final b in remaining.take(6))
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: AppChip(label: 'Ask: ${b.topic}', accent: _accent, onTap: () => _ask(b.topic, s)),
                ),
            ]),
          ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: AppTextField(controller: _input, hint: 'Ask the patient a question…', accent: _accent, onSubmitted: (v) => _askFree(v, s))),
          const SizedBox(width: 8),
          AppIconButton(icon: Icons.send_rounded, color: _accent, onPressed: () => _askFree(_input.text, s)),
        ]),
        const SizedBox(height: 10),
        AppButton(label: 'Finish interview → differential', icon: Icons.arrow_forward_rounded, accent: _accent, expand: true, onPressed: () => setState(() => _phase = _Phase.reasoning)),
        const SizedBox(height: 12),
      ],
    );
  }

  void _ask(String topic, OsceStation s) {
    final beat = s.beats.firstWhere((b) => b.topic == topic);
    setState(() {
      _asked.add(beat.topic);
      _transcript.add((true, 'About your ${beat.topic.toLowerCase()}?'));
      _transcript.add((false, beat.response));
    });
  }

  void _askFree(String text, OsceStation s) {
    final q = text.trim();
    if (q.isEmpty) return;
    final lower = q.toLowerCase();
    OsceBeat? match;
    for (final b in s.beats) {
      if (_asked.contains(b.topic)) continue;
      if (b.keywords.any((k) => lower.contains(k))) { match = b; break; }
    }
    setState(() {
      _transcript.add((true, q));
      if (match != null) {
        _asked.add(match.topic);
        _transcript.add((false, match.response));
      } else {
        _transcript.add((false, "I'm not sure what you mean — could you ask another way?"));
      }
      _input.clear();
    });
  }

  Widget _buildReasoning(BuildContext context, OsceStation s) {
    final t = context.tokens;
    final isCounseling = s.type == OsceType.counseling;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(isCounseling ? 'What did you cover?' : 'Your differential diagnosis', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text('Select all that apply.', style: TextStyle(color: t.textMuted)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final d in s.differentialOptions)
            AppChip(label: d, selected: _dx.contains(d), accent: _accent, onTap: () => setState(() => _dx.contains(d) ? _dx.remove(d) : _dx.add(d))),
        ]),
        const SizedBox(height: 20),
        Text(isCounseling ? 'Safety-netting / next steps' : 'Initial plan', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in s.planOptions)
            AppChip(label: p, selected: _plan.contains(p), accent: _accent, onTap: () => setState(() => _plan.contains(p) ? _plan.remove(p) : _plan.add(p))),
        ]),
        const SizedBox(height: 24),
        AppButton(label: 'Submit & get scored', icon: Icons.grading_rounded, accent: _accent, expand: true, onPressed: () => _submit(s)),
      ]),
    );
  }

  void _submit(OsceStation s) {
    final score = OsceScorer.score(station: s, asked: _asked, dx: _dx, plan: _plan);
    // Distribute mastery + rewards through the game hub (prompt 52 §3).
    ref.read(gameProvider.notifier).report(
          source: ModuleKey.copilot,
          kind: RewardKind.lesson,
          correct: score.overall >= 60,
          concepts: s.conceptIds,
          xp: (score.overall / 4).round(),
          achievementMetric: 'osce.count',
        );
    setState(() { _score = score; _phase = _Phase.debrief; });
  }

  Widget _buildDebrief(BuildContext context, OsceStation s) {
    final t = context.tokens;
    final score = _score!;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AppCard(
          accent: score.overall >= 60 ? t.success : t.warning,
          child: Row(children: [
            ProgressRing(value: score.overall / 100, size: 64, color: score.overall >= 60 ? t.success : t.warning, child: Text('${score.overall}', style: const TextStyle(fontWeight: FontWeight.w800))),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(score.overall >= 75 ? 'Strong performance' : score.overall >= 60 ? 'Pass' : 'Needs work', style: Theme.of(context).textTheme.titleLarge),
              Text('Overall station score', style: TextStyle(color: t.textMuted)),
            ])),
          ]),
        ),
        const SizedBox(height: 16),
        Text('Rubric breakdown', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final entry in score.byDomain.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(entry.key.label, style: TextStyle(color: t.text, fontWeight: FontWeight.w600))),
                Text('${entry.value}%', style: TextStyle(color: t.textMuted, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 4),
              AppProgressBar(value: entry.value / 100, color: entry.value >= 60 ? t.success : t.warning),
            ]),
          ),
        const SizedBox(height: 16),
        if (score.missed.isNotEmpty) ...[
          Text('Questions you missed', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          for (final m in score.missed)
            Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.remove_circle_outline_rounded, size: 15, color: t.warning),
              const SizedBox(width: 8),
              Expanded(child: Text(m, style: TextStyle(color: t.text))),
            ])),
          const SizedBox(height: 16),
        ],
        AppCard(
          color: t.surfaceAlt,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Model answer', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Text('Most likely: ${s.correctDifferential.join(', ')}', style: TextStyle(color: t.text, height: 1.4)),
            const SizedBox(height: 4),
            Text('Key steps: ${s.correctPlan.join('; ')}', style: TextStyle(color: t.textMuted, height: 1.4)),
          ]),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final cid in s.conceptIds)
            if (ref.read(repositoryProvider).concept(cid) != null)
              AppChip(label: ref.read(repositoryProvider).concept(cid)!.name, icon: Icons.psychology_rounded, accent: _accent, onTap: () => context.goConcept(cid)),
        ]),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: AppButton(label: 'Back to OSCE', variant: AppButtonVariant.secondary, accent: _accent, onPressed: () => context.go(Routes.osce))),
          const SizedBox(width: 10),
          Expanded(child: AppButton(label: 'See my plan', accent: _accent, onPressed: () => context.go(Routes.plan))),
        ]),
      ]),
    );
  }
}

/// Pure rubric scorer for an OSCE encounter (prompt 52 §2).
class OsceScore {
  const OsceScore({required this.overall, required this.byDomain, required this.missed});
  final int overall;
  final Map<OsceDomain, int> byDomain;
  final List<String> missed;
}

class OsceScorer {
  const OsceScorer._();

  static OsceScore score({
    required OsceStation station,
    required Set<String> asked,
    required Set<String> dx,
    required Set<String> plan,
  }) {
    final essential = station.essentialBeats;
    final askedEssential = essential.where((b) => asked.contains(b.topic)).length;
    final dataGathering = essential.isEmpty ? 100 : ((askedEssential / essential.length) * 100).round();

    final totalQ = station.beats.length;
    final communication = totalQ == 0 ? 100 : ((asked.length / totalQ).clamp(0, 1) * 100).round();

    final empathyBeats = station.beats.where((b) => b.domain == OsceDomain.empathy).map((b) => b.topic).toSet();
    final empathy = empathyBeats.isEmpty ? 80 : (asked.intersection(empathyBeats).isNotEmpty ? 100 : 40);

    final correctDx = station.correctDifferential.toSet();
    final dxHits = dx.intersection(correctDx).length;
    final dxWrong = dx.difference(correctDx).length;
    final diagnosis = correctDx.isEmpty ? 100 : ((dxHits / correctDx.length) * 100 - dxWrong * 15).clamp(0, 100).round();

    final correctPlan = station.correctPlan.toSet();
    final planHits = plan.intersection(correctPlan).length;
    final dangerous = plan.where((p) => p.toLowerCase().contains('discharge')).isNotEmpty;
    var safety = correctPlan.isEmpty ? 100 : ((planHits / correctPlan.length) * 100).round();
    if (dangerous) safety = (safety - 40).clamp(0, 100);

    final byDomain = {
      OsceDomain.dataGathering: dataGathering,
      OsceDomain.communication: communication,
      OsceDomain.empathy: empathy,
      OsceDomain.diagnosis: diagnosis,
      OsceDomain.safety: safety,
    };
    final overall = (byDomain.values.reduce((a, b) => a + b) / byDomain.length).round();

    final missed = [
      for (final b in essential)
        if (!asked.contains(b.topic)) 'Ask about: ${b.topic}',
      for (final d in correctDx)
        if (!dx.contains(d)) 'Consider: $d',
    ];

    return OsceScore(overall: overall, byDomain: byDomain, missed: missed);
  }
}

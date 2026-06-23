import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../../router/routes.dart';
import '../../state/study_plan_provider.dart';

const _accent = Color(0xFF8E9BFF);

/// Long-horizon curriculum tracks (prompt 35 §3).
class CurriculumTrack {
  const CurriculumTrack(this.id, this.title, this.subtitle, this.milestones, this.weeks);
  final String id;
  final String title;
  final String subtitle;
  final List<String> milestones;
  final int weeks;
}

const kTracks = [
  CurriculumTrack('usmle1', 'USMLE Step 1', 'Foundational sciences across every system', [
    'Cardiovascular physiology & pathology',
    'Pharmacology core',
    'Renal & acid-base',
    'Microbiology & antimicrobials',
    'Endocrine & metabolism',
  ], 12),
  CurriculumTrack('cards', 'Cardiology rotation', 'Be ward-ready for the heart', [
    'ECG mastery (rhythms & ischemia)',
    'Heart failure management',
    'ACS pathways',
    'Antiarrhythmics & anticoagulation',
  ], 6),
  CurriculumTrack('nclex', 'NCLEX-RN', 'Safe, effective nursing care', [
    'Pharmacology & safe administration',
    'Fluids & electrolytes',
    'Cardiac & respiratory care',
    'Prioritization & delegation',
  ], 8),
];

/// The full Study Plan screen: today's checklist, the week and tracks.
class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final plan = ref.watch(studyPlanProvider);

    return ModuleScaffold(
      title: 'Study Plan',
      subtitle: 'One plan across every module',
      accent: _accent,
      scrollable: true,
      onCopilot: () => context.push(Routes.copilot),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          AppCard(
            accent: _accent,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                ProgressRing(value: plan.progress, size: 56, color: _accent, child: Text('${plan.doneCount}/${plan.total}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("Today's plan", style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(plan.doneCount == plan.total ? 'Done for today — great work!' : '~${plan.minutesLeft} min left · ${plan.total - plan.doneCount} tasks',
                      style: TextStyle(color: t.textMuted)),
                ])),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          for (final task in plan.tasks) _PlanTaskRow(task: task, done: plan.isDone(task.id)),
          const SizedBox(height: 24),
          Text('Curriculum tracks', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Long-horizon paths that sequence content from every module toward a goal.',
              style: TextStyle(color: t.textMuted, fontSize: 13)),
          const SizedBox(height: 12),
          for (final track in kTracks)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                onTap: () => context.push(Routes.planTrack(track.id)),
                child: Row(children: [
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(color: _accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.timeline_rounded, color: _accent),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(track.title, style: Theme.of(context).textTheme.titleSmall),
                    Text('${track.subtitle} · ${track.weeks} weeks', style: TextStyle(color: t.textMuted, fontSize: 12.5)),
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

class _PlanTaskRow extends ConsumerWidget {
  const _PlanTaskRow({required this.task, required this.done});
  final StudyTask task;
  final bool done;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        accent: done ? t.success : null,
        onTap: () {
          ref.read(studyPlanProvider.notifier).markDone(task.id);
          context.push(task.route);
        },
        child: Row(children: [
          GestureDetector(
            onTap: () => ref.read(studyPlanProvider.notifier).toggle(task.id),
            child: Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: done ? t.success : task.accent),
          ),
          const SizedBox(width: 12),
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: task.accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
            child: Icon(task.icon, color: task.accent, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(task.title, style: TextStyle(
              fontWeight: FontWeight.w700,
              decoration: done ? TextDecoration.lineThrough : null,
              color: done ? t.textMuted : t.text,
            )),
            Text(task.subtitle, style: TextStyle(color: t.textMuted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${task.minutes}m', style: TextStyle(color: t.textFaint, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => ref.read(studyPlanProvider.notifier).swap(task.id),
              child: Icon(Icons.swap_vert_rounded, size: 16, color: t.textFaint),
            ),
          ]),
        ]),
      ),
    );
  }
}

/// A track view with milestones over the concept graph (prompt 35 §3).
class TrackScreen extends ConsumerWidget {
  const TrackScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final track = kTracks.firstWhere((x) => x.id == id, orElse: () => kTracks.first);

    return ModuleScaffold(
      title: track.title,
      subtitle: track.subtitle,
      accent: _accent,
      scrollable: true,
      onCopilot: () => context.push(Routes.copilot),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          AppCard(accent: _accent, child: Row(children: [
            const Icon(Icons.flag_rounded, color: _accent),
            const SizedBox(width: 12),
            Expanded(child: Text('${track.weeks}-week track · ${track.milestones.length} milestones', style: TextStyle(color: t.text))),
          ])),
          const SizedBox(height: 16),
          for (var i = 0; i < track.milestones.length; i++)
            _MilestoneRow(index: i, label: track.milestones[i], last: i == track.milestones.length - 1),
          const SizedBox(height: 20),
          AppButton(label: 'Start this track', icon: Icons.play_arrow_rounded, accent: _accent, expand: true, onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${track.title} added to your plan'), behavior: SnackBarBehavior.floating),
            );
            context.push(Routes.plan);
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({required this.index, required this.label, required this.last});
  final int index;
  final String label;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(color: _accent.withValues(alpha: 0.16), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('${index + 1}', style: const TextStyle(color: _accent, fontWeight: FontWeight.w800, fontSize: 13)),
          ),
          if (!last) Expanded(child: Container(width: 2, color: t.border)),
        ]),
        const SizedBox(width: 14),
        Expanded(child: Padding(
          padding: const EdgeInsets.only(bottom: 18, top: 4),
          child: Text(label, style: Theme.of(context).textTheme.titleSmall),
        )),
      ]),
    );
  }
}

/// The compact "Today" panel embedded on the Hub (prompt 35 §4 / 07).
class TodayPanel extends ConsumerWidget {
  const TodayPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final plan = ref.watch(studyPlanProvider);
    final next = plan.remaining.isNotEmpty ? plan.remaining.first : null;

    return AppCard(
      feature: true,
      accent: _accent,
      onTap: () => context.push(Routes.plan),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ProgressRing(value: plan.progress, size: 46, color: _accent, child: Text('${plan.doneCount}/${plan.total}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Today's plan", style: Theme.of(context).textTheme.titleLarge),
            Text(plan.doneCount == plan.total ? 'All done — nice!' : '~${plan.minutesLeft} min · tap to open',
                style: TextStyle(color: t.textMuted, fontSize: 13)),
          ])),
          Icon(Icons.arrow_forward_rounded, color: _accent),
        ]),
        if (next != null) ...[
          const Divider(height: 22),
          Row(children: [
            Icon(next.icon, color: next.accent, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text('Next: ${next.title}', style: TextStyle(color: t.text, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
            TextButton(
              onPressed: () { ref.read(studyPlanProvider.notifier).markDone(next.id); context.push(next.route); },
              child: Text('Start', style: TextStyle(color: _accent, fontWeight: FontWeight.w700)),
            ),
          ]),
        ],
      ]),
    );
  }
}

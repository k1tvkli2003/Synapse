import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../../router/routes.dart';
import '../../state/app_providers.dart';

const _accent = Color(0xFF7FB5FF);

/// Student "Classes" space (prompt 55 §3) — assignments + class progress, folded
/// into the same plan and hub.
class ClassesScreen extends ConsumerWidget {
  const ClassesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final assignments = [
      ('Read: Heart failure', 'Due in 2 days', Routes.disease('d_chf'), Icons.menu_book_rounded),
      ('Case: Chest pain', 'Due Friday', Routes.cases, Icons.local_hospital_rounded),
      ('OSCE: Warfarin counseling', 'Due next week', Routes.osce, Icons.record_voice_over_rounded),
    ];
    return ModuleScaffold(
      title: 'My Classes',
      subtitle: 'Assignments & class progress',
      accent: _accent,
      scrollable: true,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        AppCard(accent: _accent, child: Row(children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: _accent.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.school_rounded, color: _accent)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Year 3 — Medicine', style: Theme.of(context).textTheme.titleMedium),
            Text('St. Mary\'s School of Medicine', style: TextStyle(color: t.textMuted, fontSize: 12.5)),
          ])),
        ])),
        const SizedBox(height: 16),
        Text('Assignments', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final (title, due, route, icon) in assignments)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: AppCard(onTap: () => context.push(route), child: Row(children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(color: _accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: _accent, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              Text(due, style: TextStyle(color: t.textMuted, fontSize: 12.5)),
            ])),
            const Icon(Icons.chevron_right_rounded),
          ]))),
        const SizedBox(height: 12),
        AppCard(color: t.surfaceAlt, child: Row(children: [
          Icon(Icons.lightbulb_rounded, color: t.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text('Assignments appear in your daily plan and reminders automatically.', style: TextStyle(color: t.textMuted, fontSize: 12.5, height: 1.4))),
        ])),
        const SizedBox(height: 16),
        AppButton(label: 'Educator console', icon: Icons.dashboard_rounded, variant: AppButtonVariant.secondary, accent: _accent, expand: true, onPressed: () => context.push(Routes.org)),
        const SizedBox(height: 24),
      ]),
    );
  }
}

/// Educator console (prompt 55 §2) — cohort analytics + assignment authoring.
class OrgScreen extends ConsumerWidget {
  const OrgScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final repo = ref.watch(repositoryProvider);
    final cohortSize = repo.buddies.length + 24;

    return ModuleScaffold(
      title: 'Educator Console',
      subtitle: 'Cohort mode · privacy-respecting',
      accent: _accent,
      scrollable: true,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: StatTile(value: '$cohortSize', label: 'Students', icon: Icons.people_rounded, accent: _accent)),
          const SizedBox(width: 10),
          Expanded(child: StatTile(value: '72%', label: 'Avg. engagement', icon: Icons.bolt_rounded, accent: t.success, delta: '+6%')),
        ]),
        const SizedBox(height: 12),
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Cohort mastery (aggregate)', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text('Privacy-respecting — no individual data exposed beyond policy.', style: TextStyle(color: t.textMuted, fontSize: 12)),
          const SizedBox(height: 12),
          for (final (label, value) in const [('Cardiology', 0.78), ('Pharmacology', 0.61), ('Renal', 0.45), ('Microbiology', 0.69)])
            Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(label, style: TextStyle(color: t.text, fontSize: 13))), Text('${(value * 100).round()}%', style: TextStyle(color: t.textMuted, fontSize: 12, fontWeight: FontWeight.w700))]),
              const SizedBox(height: 4),
              AppProgressBar(value: value, color: value < 0.5 ? t.warning : t.success),
            ])),
        ])),
        const SizedBox(height: 16),
        const SectionHeader(title: 'Tools'),
        AppCard(child: Column(children: [
          _row(context, Icons.assignment_add, 'Create assignment', () => context.push(Routes.create)),
          _row(context, Icons.insights_rounded, 'Cohort analytics', () => context.push(Routes.insights)),
          _row(context, Icons.video_call_rounded, 'Run a class session', () => context.push(Routes.rooms)),
          _row(context, Icons.upload_file_rounded, 'Import roster (CSV / SSO)', () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Roster import — choose a CSV or connect SSO'), behavior: SnackBarBehavior.floating))),
        ])),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _row(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: t.radii.cardR,
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12), child: Row(children: [
        Icon(icon, color: t.textMuted, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: Theme.of(context).textTheme.titleSmall)),
        Icon(Icons.chevron_right_rounded, color: t.textFaint, size: 20),
      ])),
    );
  }
}

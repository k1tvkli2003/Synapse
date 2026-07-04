import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../../router/routes.dart';
import '../../state/app_providers.dart';

const _accent = Color(0xFF8C9EFF);

/// The role-gated admin / CMS console (prompt 41 §3). Coverage analytics over
/// the concept graph, a review queue, users and feature flags.
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final repo = ref.watch(repositoryProvider);

    // Coverage: concepts with at least one learn item vs total.
    final total = repo.concepts.length;
    final covered = repo.concepts.where((c) => repo.itemsForConcept(c.id).isNotEmpty).length;
    final gaps = repo.concepts.where((c) => repo.itemsForConcept(c.id).isEmpty).toList();

    return ModuleScaffold(
      title: 'Admin Console',
      subtitle: 'Content supply chain · role-gated',
      accent: _accent,
      scrollable: true,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: StatTile(value: '$covered/$total', label: 'Concepts covered', icon: Icons.hub_rounded, accent: t.success)),
          const SizedBox(width: 10),
          Expanded(child: StatTile(value: '${repo.learnItems.length}', label: 'Content items', icon: Icons.inventory_2_rounded, accent: _accent)),
        ]),
        const SizedBox(height: 12),
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Concept-graph coverage', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          AppProgressBar(value: total == 0 ? 0 : covered / total, color: t.success, height: 10),
          const SizedBox(height: 6),
          Text('${gaps.length} concepts have no content yet', style: TextStyle(color: t.textMuted, fontSize: 12.5)),
        ])),
        const SizedBox(height: 16),
        const SectionHeader(title: 'Manage'),
        AppCard(child: Column(children: [
          _row(context, Icons.edit_document, 'Content library', '${repo.learnItems.length} items', () => context.push('/admin/content')),
          _row(context, Icons.rate_review_rounded, 'Review queue', '3 pending', () => context.push('/admin/review')),
          _row(context, Icons.people_rounded, 'Users & roles', null, () => context.push('/admin/users')),
          _row(context, Icons.flag_rounded, 'Feature flags', null, () => context.push('/admin/flags')),
          _row(context, Icons.add_circle_rounded, 'Author new content', null, () => context.push(Routes.create)),
        ])),
        const SizedBox(height: 16),
        if (gaps.isNotEmpty) ...[
          const SectionHeader(title: 'Coverage gaps'),
          AppCard(child: Column(children: [
            for (final c in gaps.take(8))
              ListRow(title: c.name, subtitle: c.domain.label, leadingIcon: Icons.warning_amber_rounded, accent: t.warning, trailing: TextButton(onPressed: () => context.push(Routes.create), child: const Text('Author'))),
          ])),
        ],
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _row(BuildContext context, IconData icon, String label, String? value, VoidCallback onTap) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: t.radii.cardR,
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12), child: Row(children: [
        Icon(icon, color: t.textMuted, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: Theme.of(context).textTheme.titleSmall)),
        if (value != null) Text(value, style: TextStyle(color: t.textMuted, fontSize: 13)),
        const SizedBox(width: 6),
        Icon(Icons.chevron_right_rounded, color: t.textFaint, size: 20),
      ])),
    );
  }
}

/// A simple list surface reused for content / review / users / flags.
class AdminListScreen extends ConsumerWidget {
  const AdminListScreen({super.key, required this.section});
  final String section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final repo = ref.watch(repositoryProvider);

    return ModuleScaffold(
      title: switch (section) {
        'content' => 'Content library',
        'review' => 'Review queue',
        'users' => 'Users & roles',
        'flags' => 'Feature flags',
        _ => 'Admin',
      },
      accent: _accent,
      scrollable: true,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        if (section == 'content')
          for (final item in repo.learnItems.take(40))
            Padding(padding: const EdgeInsets.only(bottom: 6), child: ListRow(
              title: item.title, subtitle: '${item.module.title}${item.subtitle != null ? ' · ${item.subtitle}' : ''}',
              leadingIcon: Icons.description_rounded, accent: Color(item.module.accentHex),
              trailing: const Icon(Icons.chevron_right_rounded), onTap: () => context.push(item.route),
            ))
        else if (section == 'review')
          for (final r in const [
            ('Mnemonic: SOAP note order', 'Community submission', ReviewStatus.inReview),
            ('Drug: cefepime entry', 'Dosing update', ReviewStatus.inReview),
            ('Disease: myocarditis', 'New draft', ReviewStatus.draft),
          ])
            Padding(padding: const EdgeInsets.only(bottom: 8), child: AppCard(child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.$1, style: Theme.of(context).textTheme.titleSmall),
                Text(r.$2, style: TextStyle(color: t.textMuted, fontSize: 12.5)),
              ])),
              ReviewBadge(review: ReviewState(status: r.$3)),
              const SizedBox(width: 8),
              AppButton(label: 'Approve', size: AppButtonSize.small, accent: t.success, onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Approved: ${r.$1}'), behavior: SnackBarBehavior.floating))),
            ])))
        else if (section == 'users')
          for (final b in repo.buddies)
            Padding(padding: const EdgeInsets.only(bottom: 6), child: ListRow(
              title: b.name, subtitle: '${b.role.name}${b.specialty != null ? ' · ${b.specialty}' : ''}',
              leading: AppAvatar(name: b.name, radius: 18), trailing: AppBadge(label: b.role == UserRole.clinician ? 'Reviewer' : 'Member', color: _accent, subtle: true),
            ))
        else
          for (final flag in const ['Generative ECG', 'Sound simulator', 'OR visual mode', 'Live study rooms', 'On-device AI'])
            AppSwitchTile(title: flag, value: flag == 'Live study rooms', onChanged: (_) {}),
        const SizedBox(height: 24),
      ]),
    );
  }
}

/// Unified authoring surface (prompt 41 §1) — author any content type into the
/// unified model, with mandatory concept links, references and disclaimer.
class CreateScreen extends ConsumerStatefulWidget {
  const CreateScreen({super.key});
  @override
  ConsumerState<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends ConsumerState<CreateScreen> {
  String _type = 'Mnemonic';
  static const _types = ['Mnemonic', 'Flashcard', 'Term', 'ECG case', 'Algorithm', 'Disease', 'Drug', 'Case'];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ModuleScaffold(
      title: 'Author content',
      subtitle: 'One pipeline, one taxonomy',
      accent: const Color(0xFF7BE0A3),
      scrollable: true,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        Text('Content type', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final ty in _types) AppChip(label: ty, selected: _type == ty, accent: const Color(0xFF7BE0A3), onTap: () => setState(() => _type = ty)),
        ]),
        const SizedBox(height: 16),
        const AppTextField(label: 'Title', hint: 'e.g. APGAR score components'),
        const SizedBox(height: 12),
        const AppTextField(label: 'Body / content', hint: 'The teaching content…', maxLines: 4),
        const SizedBox(height: 12),
        const AppTextField(label: 'Linked concepts (required)', hint: 'Search and tag concepts…', icon: Icons.psychology_rounded),
        const SizedBox(height: 12),
        const AppTextField(label: 'References / sources (required)', hint: 'Citation, source, year', icon: Icons.menu_book_rounded),
        const SizedBox(height: 12),
        AppCard(color: t.warning.withValues(alpha: 0.08), child: Row(children: [
          Icon(Icons.info_outline_rounded, size: 16, color: t.warning),
          const SizedBox(width: 8),
          Expanded(child: Text('Submissions enter the review queue — AI-assisted drafts are never auto-published.', style: TextStyle(color: t.warning, fontSize: 12.5, height: 1.4))),
        ])),
        const SizedBox(height: 16),
        AppButton(label: 'Submit for review', icon: Icons.send_rounded, accent: const Color(0xFF7BE0A3), expand: true, onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$_type submitted to the review queue'), behavior: SnackBarBehavior.floating));
          context.pop();
        }),
        const SizedBox(height: 24),
      ]),
    );
  }
}

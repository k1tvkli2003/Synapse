import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../../router/routes.dart';
import '../../state/app_providers.dart';

/// The signature accent for the reference Library.
const libraryAccent = Color(0xFF7DD3FC);

/// One reference bank tile on the Library hub (prompt 48 §6).
class _Bank {
  const _Bank(this.title, this.subtitle, this.icon, this.route, this.color);
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final Color color;
}

/// The unified Library home: one hub joining Diseases, Drugs, Tools and the five
/// reference banks under a single search (prompt 48 §6).
class LibraryHubScreen extends ConsumerWidget {
  const LibraryHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final repo = ref.watch(repositoryProvider);

    final banks = <_Bank>[
      _Bank('Diseases', '${repo.diseases.length} conditions', Icons.coronavirus_rounded, Routes.diseases, const Color(0xFFFF8A8A)),
      _Bank('Drugs', '${repo.drugs.length} medications', Icons.medication_rounded, Routes.drugs, const Color(0xFFC3E88D)),
      _Bank('Calculators', '${repo.tools.length} scores & tools', Icons.calculate_rounded, Routes.tools, const Color(0xFF8C9EFF)),
      _Bank('Interactions', 'Drug interaction checker', Icons.warning_amber_rounded, Routes.drugInteractions, const Color(0xFFFFB07A)),
      _Bank('Anatomy Atlas', '${repo.libraryOfKind(LibraryKind.atlas).length} plates', Icons.accessibility_new_rounded, LibraryKind.atlas.route, const Color(0xFFF7A8C4)),
      _Bank('Imaging', '${repo.libraryOfKind(LibraryKind.imaging).length} teaching cases', Icons.broken_image_rounded, LibraryKind.imaging.route, const Color(0xFF6FD3E8)),
      _Bank('Procedures', '${repo.libraryOfKind(LibraryKind.procedure).length} skills', Icons.healing_rounded, LibraryKind.procedure.route, const Color(0xFFA6B6CC)),
      _Bank('Guidelines', '${repo.libraryOfKind(LibraryKind.guideline).length} protocols', Icons.fact_check_rounded, LibraryKind.guideline.route, const Color(0xFF7BE0A3)),
      _Bank('Journal Club', '${repo.libraryOfKind(LibraryKind.journal).length} landmark trials', Icons.article_rounded, LibraryKind.journal.route, const Color(0xFFFFC773)),
    ];

    final cross = const Responsive(compact: 2, medium: 3, expanded: 3, large: 4, xlarge: 4).resolve(context);

    return ModuleScaffold(
      title: 'Library',
      subtitle: 'Reference, anchored to your concepts',
      accent: libraryAccent,
      showDisclaimer: true,
      onCopilot: () => context.push(Routes.copilot),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          SearchField(
            hint: 'Search diseases, drugs, tools, guidelines…',
            readOnly: true,
            onTap: () => context.push(Routes.search),
          ),
          const SizedBox(height: 20),
          Text('Reference banks', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cross,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
            ),
            itemCount: banks.length,
            itemBuilder: (context, i) {
              final b = banks[i];
              return AppCard(
                accent: b.color,
                onTap: () => context.push(b.route),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: b.color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
                      child: Icon(b.icon, color: b.color, size: 21),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.title, style: Theme.of(context).textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(b.subtitle, style: TextStyle(color: t.textMuted, fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Text('Everything in the Library is Concept-anchored — it appears on the '
              'concept hub and feeds the same mastery as your practice.',
              style: TextStyle(color: t.textFaint, fontSize: 12, height: 1.4)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

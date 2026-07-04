import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../../router/routes.dart';
import '../../state/srs_provider.dart';

/// A branch sub-hub (Learn / Clinical / Social) listing its modules with the
/// same ModuleTile language as the Hub (prompt 07 §1).
class SubHubScreen extends ConsumerWidget {
  const SubHubScreen({super.key, required this.branch, required this.title});
  final ShellBranch branch;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modules = ModuleKey.inBranch(branch);
    final cols = context.bp.isCompact ? 2 : 3;
    final due = ref.watch(dueCountProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ContentBounds(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
                ),
              ),
              if (branch == ShellBranch.learn)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                    child: AppCard(
                      accent: context.tokens.primary,
                      onTap: () => context.push(Routes.review),
                      child: Row(
                        children: [
                          Icon(Icons.replay_rounded, color: context.tokens.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text('Daily Review${due > 0 ? '  ·  $due due' : ''}',
                                style: Theme.of(context).textTheme.titleMedium),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.05,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final m = modules[i];
                      return ModuleTile(module: m, onTap: () => context.push(_routeFor(m)));
                    },
                    childCount: modules.length,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingCopilotButton(onPressed: () => context.push(Routes.copilot)),
    );
  }

  String _routeFor(ModuleKey m) => switch (m) {
        ModuleKey.copilot => Routes.copilot,
        ModuleKey.terms => Routes.terms,
        ModuleKey.cards => Routes.cards,
        ModuleKey.mnemonics => Routes.mnemonics,
        ModuleKey.ecg => Routes.ecg,
        ModuleKey.sounds => Routes.sounds,
        ModuleKey.labs => Routes.labs,
        ModuleKey.algorithms => Routes.algorithms,
        ModuleKey.orLab => Routes.orLab,
        ModuleKey.rounds => Routes.rounds,
        ModuleKey.buddies => Routes.buddies,
        ModuleKey.arena => Routes.arena,
      };
}

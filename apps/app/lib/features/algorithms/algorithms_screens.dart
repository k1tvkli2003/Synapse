import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../../router/routes.dart';
import '../../state/app_providers.dart';
import '../../state/game_provider.dart';

final _accent = Color(ModuleKey.algorithms.accentHex);

class AlgorithmsHomeScreen extends ConsumerWidget {
  const AlgorithmsHomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final algos = ref.watch(repositoryProvider).algorithms;
    return ModuleScaffold(
      title: 'Algorithms',
      subtitle: ModuleKey.algorithms.tagline,
      accent: _accent,
      showDisclaimer: true,
      onCopilot: () => context.push(Routes.copilot),
      body: ListView.separated(
        padding: const EdgeInsets.only(top: 8, bottom: 100),
        itemCount: algos.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final a = algos[i];
          return AppCard(
            accent: _accent,
            onTap: () => context.push(Routes.algorithmPlay(a.id)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: _accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.account_tree_rounded, color: _accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.title, style: Theme.of(context).textTheme.titleMedium),
                          if (a.specialty != null) Text(a.specialty!, style: TextStyle(color: t.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.play_circle_fill_rounded, color: _accent),
                  ],
                ),
                if (a.description != null) ...[
                  const SizedBox(height: 10),
                  Text(a.description!, style: TextStyle(color: t.textMuted, fontSize: 13, height: 1.4)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class AlgorithmPlayerScreen extends ConsumerStatefulWidget {
  const AlgorithmPlayerScreen({super.key, required this.algorithmId});
  final String algorithmId;
  @override
  ConsumerState<AlgorithmPlayerScreen> createState() => _AlgorithmPlayerScreenState();
}

class _AlgorithmPlayerScreenState extends ConsumerState<AlgorithmPlayerScreen> {
  DiagnosticAlgorithm? _algo;
  late String _nodeId;
  final List<String> _path = [];
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    _algo = ref.read(repositoryProvider).algorithms.firstWhere(
          (a) => a.id == widget.algorithmId,
          orElse: () => const DiagnosticAlgorithm(id: 'x', title: '?', startNodeId: 's', nodes: {}),
        );
    _nodeId = _algo!.startNodeId;
    _path.add(_nodeId);
  }

  void _choose(AlgoOption opt) {
    setState(() {
      _nodeId = opt.next;
      _path.add(_nodeId);
    });
    final node = _algo!.node(_nodeId);
    if (node != null && node.isOutcome && !_reported) {
      _reported = true;
      ref.read(gameProvider.notifier).report(
            source: ModuleKey.algorithms,
            kind: RewardKind.correct,
            correct: true,
            concepts: _algo!.conceptIds,
            xp: 12,
            achievementMetric: 'algorithms.completed',
          );
    }
  }

  void _restart() {
    setState(() {
      _nodeId = _algo!.startNodeId;
      _path
        ..clear()
        ..add(_nodeId);
      _reported = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final algo = _algo;
    if (algo == null || algo.nodes.isEmpty) {
      return const Scaffold(body: Center(child: Text('Algorithm not found')));
    }
    final node = algo.node(_nodeId)!;
    final progress = _path.length / (algo.nodeCount).clamp(1, 99);

    return ModuleScaffold(
      title: algo.title,
      subtitle: algo.specialty,
      accent: _accent,
      showDisclaimer: true,
      scrollable: true,
      actions: [AppIconButton(icon: Icons.restart_alt_rounded, tooltip: 'Restart', onPressed: _restart)],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 8,
              backgroundColor: t.surfaceHigh,
              valueColor: AlwaysStoppedAnimation(_accent),
            ),
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: t.motion.base,
            child: node.isOutcome ? _outcome(node) : _decision(node),
          ),
          const SizedBox(height: 24),
          if (_path.length > 1) ...[
            Text('Your path', style: TextStyle(color: t.textFaint, fontSize: 12, letterSpacing: 1)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _path.map((id) {
                final n = algo.node(id);
                return AppChip(label: n?.text.split('?').first.trim() ?? id, accent: _accent);
              }).toList(),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _decision(AlgoNode node) {
    return Column(
      key: ValueKey(node.id),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          feature: true,
          accent: _accent,
          child: Row(
            children: [
              Icon(Icons.help_outline_rounded, color: _accent),
              const SizedBox(width: 12),
              Expanded(child: Text(node.text, style: Theme.of(context).textTheme.titleLarge)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...node.options.map((o) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppButton(
                label: o.label,
                expand: true,
                variant: AppButtonVariant.secondary,
                accent: _accent,
                onPressed: () => _choose(o),
              ),
            )),
      ],
    );
  }

  Widget _outcome(AlgoNode node) {
    final t = context.tokens;
    return Column(
      key: ValueKey(node.id),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          feature: true,
          color: t.success.withValues(alpha: 0.12),
          accent: t.success,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.flag_rounded, color: t.success),
                  const SizedBox(width: 10),
                  Expanded(child: Text(node.text, style: Theme.of(context).textTheme.titleLarge)),
                ],
              ),
              if (node.detail != null) ...[
                const SizedBox(height: 10),
                Text(node.detail!, style: TextStyle(color: t.text, height: 1.5)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            if (_algo!.conceptIds.isNotEmpty)
              Expanded(
                child: AppButton(
                  label: 'See concept',
                  variant: AppButtonVariant.ghost,
                  accent: _accent,
                  onPressed: () => context.push(Routes.concept(_algo!.conceptIds.first)),
                ),
              ),
            Expanded(
              child: AppButton(label: 'Restart', accent: _accent, onPressed: _restart),
            ),
          ],
        ),
      ],
    );
  }
}

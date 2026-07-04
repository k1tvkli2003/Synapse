import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../../router/routes.dart';
import '../../state/app_providers.dart';
import '../../state/game_provider.dart';

const _accent = Color(0xFF6FD3E8);

/// The knowledge graph (prompt 12): concepts as nodes, links as edges, colored
/// by mastery. Pan/zoom; tap a node to open its cross-module hub. Drawn with a
/// CustomPainter over the real Concept graph — no assets.
class KnowledgeGraphScreen extends ConsumerWidget {
  const KnowledgeGraphScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final repo = ref.watch(repositoryProvider);
    final mastery = ref.watch(masteryMapProvider);
    final concepts = repo.concepts;

    // Deterministic radial layout, grouped so related nodes cluster.
    const canvas = 1400.0;
    final center = const Offset(canvas / 2, canvas / 2);
    final positions = <ConceptId, Offset>{};
    for (var i = 0; i < concepts.length; i++) {
      final angle = (i / concepts.length) * 2 * math.pi;
      // Two rings to reduce overlap.
      final radius = canvas * (i.isEven ? 0.40 : 0.28);
      positions[concepts[i].id] = center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
    }

    final edges = <(Offset, Offset)>[];
    for (final c in concepts) {
      final from = positions[c.id];
      if (from == null) continue;
      for (final link in c.links) {
        final to = positions[link.to];
        if (to != null) edges.add((from, to));
      }
    }

    return ModuleScaffold(
      title: 'Knowledge graph',
      subtitle: '${concepts.length} concepts · tap to explore',
      accent: _accent,
      padded: false,
      onCopilot: () => context.push(Routes.copilot),
      body: InteractiveViewer(
        constrained: false,
        minScale: 0.3,
        maxScale: 2.5,
        boundaryMargin: const EdgeInsets.all(200),
        child: SizedBox(
          width: canvas,
          height: canvas,
          child: Stack(
            children: [
              // Edges.
              Positioned.fill(child: CustomPaint(painter: _EdgePainter(edges, t.border))),
              // Nodes.
              for (final c in concepts)
                if (positions[c.id] != null)
                  Positioned(
                    left: positions[c.id]!.dx - 60,
                    top: positions[c.id]!.dy - 18,
                    width: 120,
                    child: _Node(
                      label: c.name,
                      mastery: mastery[c.id]?.mastery ?? 0,
                      hasData: mastery.containsKey(c.id),
                      onTap: () => context.push(Routes.concept(c.id)),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Node extends StatelessWidget {
  const _Node({required this.label, required this.mastery, required this.hasData, required this.onTap});
  final String label;
  final double mastery;
  final bool hasData;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = hasData ? Color.lerp(t.danger, t.success, mastery)! : t.textFaint;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.6), width: 1.4),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: t.text, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter(this.edges, this.color);
  final List<(Offset, Offset)> edges;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (final (a, b) in edges) {
      canvas.drawLine(a, b, paint);
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) => old.edges != edges;
}

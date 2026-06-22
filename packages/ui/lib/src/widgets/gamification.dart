import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:synapse_core/synapse_core.dart';

import '../theme/tokens.dart';

/// The global streak indicator — flame + day count (prompt 09).
class StreakFlame extends StatelessWidget {
  const StreakFlame({super.key, required this.days, this.compact = false});
  final int days;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final active = days > 0;
    final color = active ? const Color(0xFFFF8A3D) : t.textFaint;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.local_fire_department_rounded, color: color, size: compact ? 18 : 22),
        const SizedBox(width: 4),
        Text('$days',
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: compact ? 14 : 16,
                fontFeatures: const [FontFeature.tabularFigures()])),
      ],
    );
  }
}

/// Hearts row (lives) — full + empty (prompt 09).
class HeartsRow extends StatelessWidget {
  const HeartsRow({super.key, required this.hearts, this.size = 18});
  final Hearts hearts;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < hearts.max; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Icon(
              i < hearts.current ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: i < hearts.current ? t.danger : t.textFaint,
              size: size,
            ),
          ),
      ],
    );
  }
}

/// A gem counter pill.
class GemCounter extends StatelessWidget {
  const GemCounter({super.key, required this.gems});
  final int gems;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.diamond_rounded, color: t.info, size: 18),
        const SizedBox(width: 4),
        Text('$gems',
            style: TextStyle(
                color: t.info,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()])),
      ],
    );
  }
}

/// XP/level bar with current level and progress to the next (prompt 09).
class XpBar extends StatelessWidget {
  const XpBar({super.key, required this.xp, this.showLabel = true});
  final XPState xp;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: [
                Text('Level ${xp.level}',
                    style: TextStyle(fontWeight: FontWeight.w700, color: t.text, fontSize: 13)),
                const Spacer(),
                Text('${xp.intoLevel} / ${xp.toNext} XP',
                    style: TextStyle(color: t.textMuted, fontSize: 12)),
              ],
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: xp.levelProgress,
            minHeight: 8,
            backgroundColor: t.surfaceHigh,
            valueColor: AlwaysStoppedAnimation(t.primary),
          ),
        ),
      ],
    );
  }
}

/// A league tier badge with its signature colour.
class LeagueBadge extends StatelessWidget {
  const LeagueBadge({super.key, required this.league, this.size = 28});
  final League league;
  final double size;

  static Color colorOf(League l) => switch (l) {
        League.bronze => const Color(0xFFCD7F32),
        League.silver => const Color(0xFFBFC7D5),
        League.gold => const Color(0xFFFFCB57),
        League.sapphire => const Color(0xFF4FA8FF),
        League.ruby => const Color(0xFFFF5B7F),
        League.emerald => const Color(0xFF49D6A0),
        League.diamond => const Color(0xFF8AE6FF),
      };

  @override
  Widget build(BuildContext context) {
    final c = colorOf(league);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [c, c.withValues(alpha: 0.6)]),
        boxShadow: [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 10)],
      ),
      child: Icon(Icons.shield_rounded, color: Colors.white.withValues(alpha: 0.9), size: size * 0.55),
    );
  }
}

/// A circular progress ring (used on module tiles, mastery, stats).
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 44,
    this.stroke = 5,
    this.color,
    this.child,
  });

  final double value;
  final double size;
  final double stroke;
  final Color? color;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          value: value.clamp(0.0, 1.0),
          color: color ?? t.primary,
          track: t.surfaceHigh,
          stroke: stroke,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.color, required this.track, required this.stroke});
  final double value;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.width - stroke) / 2;
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * value,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color;
}

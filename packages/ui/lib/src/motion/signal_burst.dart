import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:synapse_motion/synapse_motion.dart';

import 'motion_scope.dart';

class SignalBurstOverlay extends StatefulWidget {
  const SignalBurstOverlay({
    super.key,
    required this.receiptId,
    required this.play,
    this.tier = MotionTier.standard,
    this.color,
    this.semanticLabel,
  });

  final String receiptId;
  final bool play;
  final MotionTier tier;
  final Color? color;
  final String? semanticLabel;

  @override
  State<SignalBurstOverlay> createState() => _SignalBurstOverlayState();
}

class _SignalBurstOverlayState extends State<SignalBurstOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  String? _lastPlayedReceipt;
  String? _lastDecisionSignature;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final decision = context.motionDecision(widget.tier, celebratory: true);
    final signature = _decisionSignature(decision);
    if (widget.play &&
        (_lastPlayedReceipt != widget.receiptId ||
            _lastDecisionSignature != signature)) {
      _start(decision);
    }
  }

  @override
  void didUpdateWidget(SignalBurstOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.play &&
        (!oldWidget.play ||
            oldWidget.receiptId != widget.receiptId ||
            oldWidget.tier != widget.tier)) {
      _start(context.motionDecision(widget.tier, celebratory: true));
    }
  }

  void _start(MotionDecision decision) {
    _lastPlayedReceipt = widget.receiptId;
    _lastDecisionSignature = _decisionSignature(decision);
    if (decision.disposition == MotionDisposition.deferred ||
        decision.disposition == MotionDisposition.still) {
      _controller.value = 1;
      return;
    }
    final base = switch (widget.tier) {
      MotionTier.micro => const Duration(milliseconds: 300),
      MotionTier.standard => const Duration(milliseconds: 620),
      MotionTier.milestone => const Duration(milliseconds: 1400),
      MotionTier.showpiece => const Duration(milliseconds: 3000),
      MotionTier.functional => const Duration(milliseconds: 260),
    };
    _controller.duration = Duration(
      microseconds: (base.inMicroseconds * decision.durationScale)
          .round()
          .clamp(1, base.inMicroseconds),
    );
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final decision = context.motionDecision(widget.tier, celebratory: true);
    if (decision.disposition == MotionDisposition.deferred ||
        decision.disposition == MotionDisposition.still) {
      return _SemanticReceipt(label: widget.semanticLabel);
    }
    final particles = _particles(widget.receiptId, decision.maxParticles);
    return IgnorePointer(
      child: Semantics(
        liveRegion: widget.semanticLabel != null,
        label: widget.semanticLabel,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            if (_controller.isDismissed) return const SizedBox.shrink();
            return CustomPaint(
              key: const ValueKey('synapse-signal-burst-canvas'),
              size: Size.infinite,
              painter: _SignalBurstPainter(
                particles: particles,
                progress: _controller.value,
                color: widget.color ?? Theme.of(context).colorScheme.primary,
                reduced: decision.disposition == MotionDisposition.reduced,
              ),
            );
          },
        ),
      ),
    );
  }
}

String _decisionSignature(MotionDecision decision) =>
    '${decision.disposition.name}|${decision.durationScale}|${decision.maxParticles}';

class _SemanticReceipt extends StatelessWidget {
  const _SemanticReceipt({required this.label});

  final String? label;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: label != null,
    label: label,
    child: const SizedBox.shrink(),
  );
}

final class _SignalParticle {
  const _SignalParticle({
    required this.angle,
    required this.reach,
    required this.delay,
    required this.size,
    required this.bend,
    required this.luma,
  });

  final double angle;
  final double reach;
  final double delay;
  final double size;
  final double bend;
  final double luma;
}

List<_SignalParticle> _particles(String seed, int count) {
  var state = _fnv1a(seed);
  double next() {
    state = (1664525 * state + 1013904223) & 0xFFFFFFFF;
    return state / 0xFFFFFFFF;
  }

  return List.generate(count, (_) {
    final side = next() < 0.5 ? -1.0 : 1.0;
    return _SignalParticle(
      angle:
          (next() * math.pi * 0.9 - math.pi * 0.45) + (side < 0 ? math.pi : 0),
      reach: 0.34 + next() * 0.62,
      delay: next() * 0.28,
      size: 1.5 + next() * 3.5,
      bend: (next() - 0.5) * 0.8,
      luma: 0.68 + next() * 0.32,
    );
  });
}

int _fnv1a(String value) {
  var hash = 0x811C9DC5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

class _SignalBurstPainter extends CustomPainter {
  const _SignalBurstPainter({
    required this.particles,
    required this.progress,
    required this.color,
    required this.reduced,
  });

  final List<_SignalParticle> particles;
  final double progress;
  final Color color;
  final bool reduced;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final shortest = math.min(size.width, size.height);
    final eased = Curves.easeOutCubic.transform(progress);
    final settle = Curves.easeInCubic.transform(progress);
    final ringAlpha = math.sin(math.pi * progress).clamp(0.0, 1.0);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = reduced ? 2 : 1.5
      ..color = color.withValues(alpha: ringAlpha * 0.72);
    canvas.drawCircle(
      center,
      shortest * (0.05 + eased * (reduced ? 0.16 : 0.24)),
      ringPaint,
    );
    if (reduced) return;

    for (final particle in particles) {
      final local = ((progress - particle.delay) / (1 - particle.delay)).clamp(
        0.0,
        1.0,
      );
      if (local <= 0 || local >= 1) continue;
      final travel = Curves.easeOutCubic.transform(local);
      final alpha = math.sin(math.pi * local) * (1 - settle * 0.28);
      final radius = shortest * particle.reach * travel * 0.52;
      final tangent = Offset(
        math.cos(particle.angle + particle.bend * travel),
        math.sin(particle.angle + particle.bend * travel),
      );
      final point = center + tangent * radius;
      final previous = center + tangent * math.max(0, radius - 10);
      final particleColor = Color.lerp(
        color,
        const Color(0xFFF6C760),
        1 - particle.luma,
      )!.withValues(alpha: alpha * 0.82);
      canvas.drawLine(
        previous,
        point,
        Paint()
          ..strokeWidth = 1
          ..strokeCap = StrokeCap.round
          ..color = particleColor.withValues(alpha: alpha * 0.32),
      );
      canvas.drawCircle(
        point,
        particle.size * (1 - local * 0.32),
        Paint()..color = particleColor,
      );
    }
  }

  @override
  bool shouldRepaint(_SignalBurstPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.reduced != reduced ||
      oldDelegate.particles != particles;
}

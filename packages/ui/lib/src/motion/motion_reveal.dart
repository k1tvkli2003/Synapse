import 'dart:async';

import 'package:flutter/material.dart';
import 'package:synapse_motion/synapse_motion.dart';

import 'motion_scope.dart';

class MotionReveal extends StatefulWidget {
  const MotionReveal({
    super.key,
    required this.child,
    this.tier = MotionTier.standard,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 360),
    this.offset = const Offset(0, 12),
    this.scaleFrom = 0.98,
    this.celebratory = false,
  });

  final Widget child;
  final MotionTier tier;
  final Duration delay;
  final Duration duration;
  final Offset offset;
  final double scaleFrom;
  final bool celebratory;

  @override
  State<MotionReveal> createState() => _MotionRevealState();
}

class _MotionRevealState extends State<MotionReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  Timer? _timer;
  MotionDecision? _decision;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _configure();
  }

  @override
  void didUpdateWidget(MotionReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tier != widget.tier ||
        oldWidget.celebratory != widget.celebratory ||
        oldWidget.duration != widget.duration ||
        oldWidget.delay != widget.delay) {
      _configure(force: true);
    }
  }

  void _configure({bool force = false}) {
    final next = context.motionDecision(
      widget.tier,
      celebratory: widget.celebratory,
    );
    if (!force && _sameDecision(_decision, next)) return;
    _decision = next;
    _timer?.cancel();
    if (next.disposition == MotionDisposition.deferred ||
        next.disposition == MotionDisposition.still) {
      _controller.value = 1;
      return;
    }
    _controller.duration = Duration(
      microseconds: (widget.duration.inMicroseconds * next.durationScale)
          .round()
          .clamp(1, widget.duration.inMicroseconds),
    );
    _controller.value = 0;
    final scaledDelay = Duration(
      microseconds: (widget.delay.inMicroseconds * next.durationScale).round(),
    );
    _timer = Timer(scaledDelay, () {
      if (mounted) unawaited(_controller.forward());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final decision = _decision;
    if (decision?.disposition == MotionDisposition.deferred) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final value = Curves.easeOutCubic.transform(_controller.value);
        final reduced = decision?.disposition == MotionDisposition.reduced;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: reduced ? Offset.zero : widget.offset * (1 - value),
            child: Transform.scale(
              scale: reduced
                  ? 1
                  : widget.scaleFrom + (1 - widget.scaleFrom) * value,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

bool _sameDecision(MotionDecision? left, MotionDecision right) =>
    left?.disposition == right.disposition &&
    left?.durationScale == right.durationScale &&
    left?.maxParticles == right.maxParticles;

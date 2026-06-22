import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'atoms.dart';

/// A celebratory toast fired when the gamification engine grants a reward
/// (prompt 03 §5 / 09). Mounted by the app-level ToastHost.
class RewardToast extends StatelessWidget {
  const RewardToast({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.bolt_rounded,
    this.color,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = color ?? t.primary;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: t.surfaceHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.withValues(alpha: 0.45)),
          boxShadow: t.glow(c, opacity: 0.25, blur: 24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: c.withValues(alpha: 0.18), shape: BoxShape.circle),
              child: Icon(icon, color: c, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                if (subtitle != null)
                  Text(subtitle!, style: TextStyle(color: t.textMuted, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A confirm dialog with the standard radius + a destructive variant.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final t = context.tokens;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(title),
      content: Text(message, style: TextStyle(color: t.textMuted, height: 1.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel, style: TextStyle(color: t.textMuted)),
        ),
        AppButton(
          label: confirmLabel,
          size: AppButtonSize.small,
          variant: destructive ? AppButtonVariant.danger : AppButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Shows a rounded bottom sheet with the standard chrome.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool scrollable = true,
}) {
  final t = context.tokens;
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: t.surface,
    isScrollControlled: scrollable,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: builder,
  );
}

/// A one-shot confetti burst (style §6.6). Drop into a Stack and toggle [play].
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({super.key, required this.play, this.colors});
  final bool play;
  final List<Color>? colors;

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  final List<_Particle> _particles = [];
  final _rand = math.Random();

  @override
  void didUpdateWidget(ConfettiOverlay old) {
    super.didUpdateWidget(old);
    if (widget.play && !old.play) _burst();
  }

  void _burst() {
    final palette = widget.colors ??
        [const Color(0xFF8E9BFF), const Color(0xFF5FD9A4), const Color(0xFFFFC773), const Color(0xFFFF7A8A)];
    _particles
      ..clear()
      ..addAll(List.generate(60, (_) {
        return _Particle(
          x: _rand.nextDouble(),
          vx: _rand.nextDouble() * 0.6 - 0.3,
          vy: _rand.nextDouble() * 0.7 + 0.4,
          color: palette[_rand.nextInt(palette.length)],
          size: _rand.nextDouble() * 7 + 4,
          rot: _rand.nextDouble() * math.pi,
        );
      }));
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          if (_c.isDismissed) return const SizedBox.shrink();
          return CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(_particles, _c.value),
          );
        },
      ),
    );
  }
}

class _Particle {
  _Particle({
    required this.x,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    required this.rot,
  });
  final double x, vx, vy, size, rot;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.particles, this.t);
  final List<_Particle> particles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final dx = (p.x + p.vx * t) * size.width;
      final dy = (p.vy * t) * size.height * 1.4;
      final paint = Paint()..color = p.color.withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(p.rot + t * 6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

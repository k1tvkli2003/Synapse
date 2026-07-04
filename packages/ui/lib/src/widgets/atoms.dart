import 'package:flutter/material.dart';

import '../theme/tokens.dart';

enum AppButtonVariant { primary, secondary, ghost, danger }

enum AppButtonSize { small, medium, large }

/// The one button used everywhere (style §8). Variants, sizes, loading state and
/// a 0.96 press-scale spring. Accent-aware so module screens tint their CTA.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.large,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.accent,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final bool loading;
  final bool expand;
  final Color? accent;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final enabled = widget.onPressed != null && !widget.loading;
    final accent = widget.accent ?? t.primary;
    final height = switch (widget.size) {
      AppButtonSize.small => 40.0,
      AppButtonSize.medium => 48.0,
      AppButtonSize.large => 54.0,
    };

    late final Color bg;
    late final Color fg;
    late final Border? border;
    switch (widget.variant) {
      case AppButtonVariant.primary:
        bg = accent;
        fg = t.isDark ? const Color(0xFF080B1C) : Colors.white;
        border = null;
      case AppButtonVariant.danger:
        bg = t.danger;
        fg = Colors.white;
        border = null;
      case AppButtonVariant.secondary:
        bg = Colors.transparent;
        fg = accent;
        border = Border.all(color: accent.withValues(alpha: 0.6), width: 1.5);
      case AppButtonVariant.ghost:
        bg = Colors.transparent;
        fg = t.text;
        border = null;
    }

    final child = widget.loading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 18, color: fg),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w600,
                    fontSize: widget.size == AppButtonSize.small ? 14 : 15.5,
                  ),
                ),
              ),
            ],
          );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: _down ? 0.96 : 1.0,
          duration: t.motion.fast,
          curve: t.motion.emphasized,
          child: AnimatedOpacity(
            opacity: enabled ? 1 : 0.45,
            duration: t.motion.fast,
            child: Container(
              height: height,
              width: widget.expand ? double.infinity : null,
              constraints: const BoxConstraints(minWidth: 88),
              padding: EdgeInsets.symmetric(
                  horizontal: widget.size == AppButtonSize.small ? 16 : 24),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: t.radii.buttonR,
                border: border,
                boxShadow: widget.variant == AppButtonVariant.primary && enabled
                    ? t.glow(accent, opacity: 0.30)
                    : null,
              ),
              alignment: Alignment.center,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// A round, tappable icon button with a hover/press surface.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.color,
    this.size = 22,
    this.filled = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final btn = Material(
      color: filled ? t.surfaceAlt : Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: size, color: color ?? t.textMuted),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

/// A pill chip (filled / outlined / selected) — style §8.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
    this.accent,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final a = accent ?? t.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: t.motion.base,
        curve: t.motion.standard,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? a : t.surfaceAlt,
          borderRadius: t.radii.pillR,
          border: Border.all(
            color: selected ? a : t.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 15,
                  color: selected ? (t.isDark ? Colors.black : Colors.white) : t.textMuted),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected
                    ? (t.isDark ? const Color(0xFF080B1C) : Colors.white)
                    : t.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small status/count badge.
class AppBadge extends StatelessWidget {
  const AppBadge({super.key, required this.label, this.color, this.subtle = false});
  final String label;
  final Color? color;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = color ?? t.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: subtle ? c.withValues(alpha: 0.16) : c,
        borderRadius: t.radii.pillR,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: subtle ? c : (t.isDark ? const Color(0xFF080B1C) : Colors.white),
        ),
      ),
    );
  }
}

/// Circular avatar with initials fallback.
class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, required this.name, this.radius = 20, this.color});
  final String name;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = color ?? t.primary;
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join();
    return CircleAvatar(
      radius: radius,
      backgroundColor: c.withValues(alpha: 0.22),
      child: Text(
        initials,
        style: TextStyle(
          color: c,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}

/// A thin rounded progress bar.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.height = 8,
    this.color,
    this.background,
  });

  final double value;
  final double height;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Stack(
        children: [
          Container(height: height, color: background ?? t.surfaceHigh),
          AnimatedFractionallySizedBox(
            duration: t.motion.slow,
            curve: t.motion.emphasized,
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: color ?? t.primary,
                borderRadius: BorderRadius.circular(height),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated fractional width helper used by [AppProgressBar].
class AnimatedFractionallySizedBox extends ImplicitlyAnimatedWidget {
  const AnimatedFractionallySizedBox({
    super.key,
    required this.widthFactor,
    required this.child,
    required super.duration,
    super.curve,
  });

  final double widthFactor;
  final Widget child;

  @override
  ImplicitlyAnimatedWidgetState<AnimatedFractionallySizedBox> createState() =>
      _AFSBState();
}

class _AFSBState extends AnimatedWidgetBaseState<AnimatedFractionallySizedBox> {
  Tween<double>? _factor;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _factor = visitor(_factor, widget.widthFactor, (v) => Tween<double>(begin: v as double))
        as Tween<double>?;
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: (_factor?.evaluate(animation) ?? widget.widthFactor).clamp(0.0, 1.0),
      child: widget.child,
    );
  }
}

/// A shimmering skeleton placeholder (style §6.5). Mirror the real content's
/// shape so loading feels like the content is materialising.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, this.width, this.height = 16, this.radius = 8});
  final double? width;
  final double height;
  final double radius;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 + _c.value * 2, 0),
              end: Alignment(1 + _c.value * 2, 0),
              colors: [t.surfaceAlt, t.surfaceHigh, t.surfaceAlt],
            ),
          ),
        );
      },
    );
  }
}

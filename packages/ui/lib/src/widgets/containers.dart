import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The standard surface (style §7). 20px radius, generous padding, dark-mode
/// 1px border instead of a shadow. Optional tap with a press-scale.
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.accent,
    this.feature = false,
    this.border = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? color;
  final Color? accent;
  final bool feature;
  final bool border;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radius = widget.feature ? t.radii.featureR : t.radii.cardR;
    final card = AnimatedContainer(
      duration: t.motion.base,
      curve: t.motion.standard,
      padding: widget.padding,
      transform: Matrix4.translationValues(0, _hover && widget.onTap != null ? -3 : 0, 0),
      decoration: BoxDecoration(
        color: widget.color ?? t.surface,
        borderRadius: radius,
        border: widget.border
            ? Border.all(
                color: widget.accent != null
                    ? widget.accent!.withValues(alpha: 0.30)
                    : t.border,
                width: 1,
              )
            : null,
        boxShadow: _hover && widget.onTap != null
            ? t.glow(widget.accent ?? Colors.black, opacity: t.isDark ? 0.18 : 0.10, blur: 20)
            : t.cardShadow,
      ),
      child: widget.child,
    );

    if (widget.onTap == null) return card;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.985 : 1,
          duration: t.motion.fast,
          child: card,
        ),
      ),
    );
  }
}

/// A section title with an optional trailing action (style §7).
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.onAction,
    this.actionLabel,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final VoidCallback? onAction;
  final String? actionLabel;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: t.textMuted),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!,
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
              ],
            ),
          ),
          if (action != null)
            action!
          else if (onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel ?? 'See all',
                  style: TextStyle(color: t.primary, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

/// A compact metric card (style §7 metric pattern).
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.accent,
    this.delta,
  });

  final String value;
  final String label;
  final IconData? icon;
  final Color? accent;
  final String? delta;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final a = accent ?? t.primary;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: a),
                const SizedBox(width: 6),
              ],
              if (delta != null) ...[
                const Spacer(),
                Text(delta!,
                    style: TextStyle(
                        color: t.success, fontWeight: FontWeight.w700, fontSize: 12)),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
                fontSize: 26, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()]),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// A standard tappable list row with leading icon, title/subtitle, trailing.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.leading,
    this.trailing,
    this.onTap,
    this.accent,
  });

  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final a = accent ?? t.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: t.radii.cardR,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              if (leading != null)
                leading!
              else if (leadingIcon != null)
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: a.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(leadingIcon, color: a, size: 20),
                ),
              if (leading != null || leadingIcon != null) const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(subtitle!,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

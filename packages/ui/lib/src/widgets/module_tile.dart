import 'package:flutter/material.dart';
import 'package:synapse_core/synapse_core.dart';

import '../theme/module_visuals.dart';
import '../theme/tokens.dart';
import 'containers.dart';

/// The single entry point to a module on the Hub grid (prompt 07 §2). Accent
/// colour + icon + a live stat. One consistent tile so learning one module
/// teaches you them all (prompt 30 §1).
class ModuleTile extends StatelessWidget {
  const ModuleTile({
    super.key,
    required this.module,
    required this.onTap,
    this.stat,
    this.badge,
  });

  final ModuleKey module;
  final VoidCallback onTap;

  /// A live one-liner, e.g. "12 due", "3 new".
  final String? stat;

  /// Optional small count badge (e.g. unread).
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final accent = t.accentOf(module);
    return AppCard(
      onTap: onTap,
      accent: accent,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent.withValues(alpha: 0.30), accent.withValues(alpha: 0.12)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(ModuleVisuals.icon(module), color: accent, size: 24),
              ),
              const Spacer(),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(99)),
                  child: Text(badge!,
                      style: TextStyle(
                          color: t.isDark ? const Color(0xFF080B1C) : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(module.title,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(
                stat ?? module.tagline,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: stat != null ? accent : t.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synapse_motion/synapse_motion.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../state/toast_provider.dart';

/// Root overlay for short operational notices. Rewards, quests, achievements,
/// and other durable outcomes must use presentation receipts instead.
class ToastHost extends ConsumerWidget {
  const ToastHost({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toasts = ref.watch(toastProvider);
    return Stack(
      children: [
        child,
        Positioned(
          top: MediaQuery.paddingOf(context).top + 8,
          left: 0,
          right: 0,
          child: Column(
            children: toasts
                .map(
                  (m) => Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 16,
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: MotionReveal(
                        key: ValueKey(m.id),
                        duration: const Duration(milliseconds: 320),
                        offset: const Offset(0, -16),
                        scaleFrom: 0.96,
                        tier: MotionTier.functional,
                        child: RewardToast(
                          title: m.title,
                          subtitle: m.subtitle,
                          icon: m.icon,
                          color: m.color,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

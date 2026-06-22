import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../state/toast_provider.dart';

/// Root overlay that renders reward/achievement toasts from anywhere (prompt
/// 07 §3). Mounted above the router so it survives navigation.
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
                .map((m) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: RewardToast(
                          title: m.title,
                          subtitle: m.subtitle,
                          icon: m.icon,
                          color: m.color,
                        )
                            .animate()
                            .fadeIn(duration: 220.ms)
                            .moveY(begin: -16, end: 0, curve: Curves.easeOutBack),
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

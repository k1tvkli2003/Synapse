import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../state/audio_provider.dart';
import '../state/network_banner.dart';

/// The adaptive navigation shell (prompt 07 §1 / 03 §3): NavigationBar on
/// compact, NavigationRail on medium/expanded, extended rail on large/desktop.
/// Same five routes, adaptive chrome. Hosts the persistent audio bar.
class AdaptiveShell extends ConsumerWidget {
  const AdaptiveShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    (ShellBranch.home, 'Home', Icons.home_rounded, Icons.home_outlined),
    (ShellBranch.learn, 'Learn', Icons.school_rounded, Icons.school_outlined),
    (ShellBranch.clinical, 'Clinical', Icons.health_and_safety_rounded, Icons.health_and_safety_outlined),
    (ShellBranch.social, 'Social', Icons.forum_rounded, Icons.forum_outlined),
    (ShellBranch.profile, 'Profile', Icons.person_rounded, Icons.person_outline_rounded),
  ];

  void _go(int index) => navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bp = context.bp;
    final useRail = bp.usesRail;

    final body = Column(
      children: [
        const NetworkBanner(),
        Expanded(child: navigationShell),
        const _AudioDock(),
      ],
    );

    if (!useRail) {
      return Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _go,
          destinations: _destinations
              .map((d) => NavigationDestination(
                    icon: Icon(d.$4),
                    selectedIcon: Icon(d.$3),
                    label: d.$2,
                  ))
              .toList(),
        ),
      );
    }

    final extended = bp.usesDrawer;
    return Scaffold(
      body: Row(
        children: [
          _Rail(
            index: navigationShell.currentIndex,
            extended: extended,
            onSelected: _go,
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.index, required this.extended, required this.onSelected});
  final int index;
  final bool extended;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return NavigationRail(
      selectedIndex: index,
      onDestinationSelected: onSelected,
      extended: extended,
      minExtendedWidth: 200,
      backgroundColor: t.surface,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [t.primary, t.info]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.hub_rounded, color: Colors.white, size: 22),
            ),
            if (extended) ...[
              const SizedBox(width: 10),
              Text('Synapse', style: Theme.of(context).textTheme.titleLarge),
            ],
          ],
        ),
      ),
      destinations: AdaptiveShell._destinations
          .map((d) => NavigationRailDestination(
                icon: Icon(d.$4),
                selectedIcon: Icon(d.$3),
                label: Text(d.$2),
              ))
          .toList(),
    );
  }
}

/// Persistent mini audio bar across navigation (prompt 30 §2).
class _AudioDock extends ConsumerWidget {
  const _AudioDock();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioProvider);
    if (!audio.hasMedia) return const SizedBox.shrink();
    final notifier = ref.read(audioProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: AudioPlayerBar(
        title: audio.title!,
        subtitle: audio.subtitle,
        isPlaying: audio.isPlaying,
        position: audio.position,
        duration: audio.duration,
        accent: audio.accentHex != null ? Color(audio.accentHex!) : null,
        dense: true,
        onPlayPause: notifier.toggle,
        onSeek: notifier.seek,
        onClose: notifier.stop,
      ),
    );
  }
}

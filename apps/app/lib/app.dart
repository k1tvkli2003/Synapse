import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synapse_ui/synapse_ui.dart';

import 'router/router.dart';
import 'shell/toast_host.dart';
import 'state/settings_provider.dart';

/// The Synapse application root. One Material 3 app, dark by default, with the
/// reward/notification ToastHost mounted above the router (prompt 07 §3).
class SynapseApp extends ConsumerWidget {
  const SynapseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final reduceMotion = ref.watch(settingsProvider).reduceMotion;

    return MaterialApp.router(
      title: 'Synapse',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: SynapseTheme.light(),
      darkTheme: SynapseTheme.dark(),
      themeMode: themeMode,
      builder: (context, child) {
        final app = ToastHost(child: child ?? const SizedBox.shrink());
        if (reduceMotion) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: app,
          );
        }
        return app;
      },
    );
  }
}

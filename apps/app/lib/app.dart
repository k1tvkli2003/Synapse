import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_motion/synapse_motion.dart';
import 'package:synapse_ui/synapse_ui.dart';

import 'router/router.dart';
import 'shell/presentation_host.dart';
import 'shell/toast_host.dart';
import 'state/personal_sync_provider.dart';
import 'state/settings_provider.dart';

/// The Synapse application root. One Material 3 app, dark by default, with the
/// reward/notification ToastHost mounted above the router (prompt 07 §3).
class SynapseApp extends ConsumerWidget {
  const SynapseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final settings = ref.watch(settingsProvider);
    // Activates the local-first personal-sync recovery loop only when the
    // private gateway is configured. It performs no work for unpaired installs
    // and never delays router construction or Academy rendering.
    ref.watch(personalSyncDispatcherProvider);
    // Independently refreshes verified chapter packages only when a public
    // internal-channel keyring is configured. Existing local learning remains
    // immediately available while it runs or retries in the foreground.
    ref.watch(personalContentDispatcherProvider);
    final motionMode = settings.motionMode;
    final locale = settings.locale.toLowerCase().startsWith('fa')
        ? const Locale('fa')
        : const Locale('en');

    return MaterialApp.router(
      title: 'Synapse',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: SynapseTheme.light(),
      darkTheme: SynapseTheme.dark(),
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('en'), Locale('fa')],
      builder: (context, child) {
        final app = PresentationHost(
          child: ToastHost(child: child ?? const SizedBox.shrink()),
        );
        final media = MediaQuery.of(context);
        final disableAnimations =
            media.disableAnimations || motionMode != MotionModePref.full;
        return ListenableBuilder(
          listenable: router.routeInformationProvider,
          builder: (context, _) {
            final path = router.routeInformationProvider.value.uri.path;
            final surface = path.startsWith('/clinical')
                ? MotionSurface.clinical
                : path.startsWith('/library')
                ? MotionSurface.evidence
                : MotionSurface.study;
            return MediaQuery(
              data: media.copyWith(disableAnimations: disableAnimations),
              child: SynapseMotionScope(
                preference: switch (motionMode) {
                  MotionModePref.full => MotionPreference.full,
                  MotionModePref.reduced => MotionPreference.reduced,
                  MotionModePref.off => MotionPreference.off,
                },
                surface: surface,
                child: app,
              ),
            );
          },
        );
      },
    );
  }
}

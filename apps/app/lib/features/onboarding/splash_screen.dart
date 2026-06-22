import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../../router/routes.dart';
import '../../state/settings_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      final onboarded = ref.read(settingsProvider.notifier).onboarded;
      context.go(onboarded ? Routes.home : Routes.onboarding);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [t.primary, t.info]),
                borderRadius: BorderRadius.circular(26),
                boxShadow: t.glow(t.primary, opacity: 0.4, blur: 30),
              ),
              child: const Icon(Icons.hub_rounded, color: Colors.white, size: 48),
            )
                .animate()
                .scale(duration: 500.ms, curve: Curves.easeOutBack)
                .fadeIn(),
            const SizedBox(height: 20),
            Text('Synapse', style: Theme.of(context).textTheme.displaySmall)
                .animate()
                .fadeIn(delay: 200.ms),
            const SizedBox(height: 6),
            Text('Learn. Drill. Decide. Together.',
                    style: TextStyle(color: t.textMuted))
                .animate()
                .fadeIn(delay: 350.ms),
          ],
        ),
      ),
    );
  }
}

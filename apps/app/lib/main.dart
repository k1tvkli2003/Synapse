import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:synapse_config/synapse_config.dart';
import 'package:synapse_observability/synapse_observability.dart';

import 'app.dart';
import 'bootstrap/app_bootstrap.dart';
import 'state/app_providers.dart';
import 'state/observability_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  pdfrxFlutterInitialize();
  try {
    final runtime = await AppBootstrapper(
      config: AppConfig.fromEnvironment(),
    ).run();
    _installGlobalErrorHandlers(runtime.crashReporter);
    runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(runtime.store),
          appConfigProvider.overrideWithValue(runtime.config),
          structuredLoggerProvider.overrideWithValue(runtime.logger),
          analyticsProvider.overrideWithValue(runtime.analytics),
          crashReporterProvider.overrideWithValue(runtime.crashReporter),
        ],
        child: const SynapseApp(),
      ),
    );
  } catch (error) {
    runApp(_BootstrapFailureApp(errorType: error.runtimeType.toString()));
  }
}

void _installGlobalErrorHandlers(CrashReporter reporter) {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(
      reporter.capture(
        details.exception,
        details.stack ?? StackTrace.current,
        fatal: false,
      ),
    );
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    unawaited(reporter.capture(error, stackTrace, fatal: true));
    return true;
  };
}

final class _BootstrapFailureApp extends StatelessWidget {
  const _BootstrapFailureApp({required this.errorType});

  final String errorType;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.health_and_safety_outlined, size: 48),
                  const SizedBox(height: 20),
                  const Text(
                    'Synapse could not start safely',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your local learning data was not changed. Restart the app '
                    'or verify this build\'s environment configuration.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text('Diagnostic: $errorType'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

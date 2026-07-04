import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synapse_config/synapse_config.dart';

import 'app.dart';
import 'cloud/supabase_bootstrap.dart';
import 'state/app_providers.dart';
import 'state/persistence.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final store = PersistedStore(prefs);

  // Offline-first: a cloud hiccup at boot must never block the app.
  try {
    await bootstrapSupabase(AppConfig.fromEnvironment());
  } catch (_) {
    // Falls back to local-only; CloudSyncController stays in offline phase.
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(store),
      ],
      child: const SynapseApp(),
    ),
  );
}

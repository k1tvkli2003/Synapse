import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:synapse_config/synapse_config.dart';

/// Initializes the Supabase client when a backend is configured. A no-op when
/// running fully offline (prompt 23) — the app must boot even if this fails,
/// so callers should not let a thrown error here block `runApp`.
Future<void> bootstrapSupabase(AppConfig config) async {
  if (!config.hasLegacySupabaseBackend) return;
  await Supabase.initialize(
    url: config.supabaseUrl,
    publishableKey: config.supabasePublishableKey,
  );
}

/// The live client. Only touch this when [AppConfig.hasLegacySupabaseBackend] is true (i.e.
/// after a successful [bootstrapSupabase]) — otherwise Supabase throws.
SupabaseClient get cloud => Supabase.instance.client;

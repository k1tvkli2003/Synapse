import 'package:meta/meta.dart';

/// Immutable application configuration, populated from `--dart-define` values at
/// launch. Everything has a safe default so the app boots fully offline with no
/// backend credentials — Synapse is offline-first (see prompt 23).
@immutable
class AppConfig {
  const AppConfig({
    this.supabaseUrl = '',
    this.supabaseAnonKey = '',
    this.aiGatewayUrl = '',
    this.posthogKey = '',
    this.sentryDsn = '',
    this.environment = AppEnvironment.local,
  });

  /// Reads configuration from compile-time environment values.
  factory AppConfig.fromEnvironment() {
    const envName = String.fromEnvironment('SYNAPSE_ENV', defaultValue: 'local');
    return AppConfig(
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
      aiGatewayUrl: const String.fromEnvironment('AI_GATEWAY_URL'),
      posthogKey: const String.fromEnvironment('POSTHOG_KEY'),
      sentryDsn: const String.fromEnvironment('SENTRY_DSN'),
      environment: AppEnvironment.values.firstWhere(
        (e) => e.name == envName,
        orElse: () => AppEnvironment.local,
      ),
    );
  }

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String aiGatewayUrl;
  final String posthogKey;
  final String sentryDsn;
  final AppEnvironment environment;

  /// Whether a real Supabase backend is configured. When false the app runs on
  /// the bundled local repositories + seed data (full offline experience).
  bool get hasBackend => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Whether the server-side AI gateway is configured. When false Copilot runs
  /// in grounded "demo" mode using the local knowledge base.
  bool get hasAi => aiGatewayUrl.isNotEmpty;

  bool get isProd => environment == AppEnvironment.prod;
}

enum AppEnvironment { local, dev, staging, prod }

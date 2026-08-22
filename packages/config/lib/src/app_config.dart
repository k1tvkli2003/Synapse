import 'package:meta/meta.dart';

/// Immutable compile-time configuration for one Synapse deployment tier.
@immutable
class AppConfig {
  const AppConfig({
    this.supabaseUrl = '',
    this.supabaseAnonKey = '',
    this.personalSyncGatewayUrl = '',
    this.personalContentTrustAnchorsJson = '',
    this.aiGatewayUrl = '',
    this.posthogKey = '',
    this.sentryDsn = '',
    this.environment = AppEnvironment.local,
  });

  /// Reads values embedded with `--dart-define` and validates the selected tier.
  factory AppConfig.fromEnvironment({bool validate = true}) {
    const values = <String, String>{
      'SYNAPSE_ENV': String.fromEnvironment(
        'SYNAPSE_ENV',
        defaultValue: 'local',
      ),
      'SUPABASE_URL': String.fromEnvironment('SUPABASE_URL'),
      'SUPABASE_PUBLISHABLE_KEY': String.fromEnvironment(
        'SUPABASE_PUBLISHABLE_KEY',
      ),
      // Compatibility input. New environments should use the publishable name.
      'SUPABASE_ANON_KEY': String.fromEnvironment('SUPABASE_ANON_KEY'),
      'SYNAPSE_SYNC_GATEWAY_URL': String.fromEnvironment(
        'SYNAPSE_SYNC_GATEWAY_URL',
      ),
      // Public Ed25519 keyring only. It is not a credential and scopes the
      // private gateway's immutable internal curriculum channel.
      'SYNAPSE_CONTENT_TRUST_ANCHORS_JSON': String.fromEnvironment(
        'SYNAPSE_CONTENT_TRUST_ANCHORS_JSON',
      ),
      'AI_GATEWAY_URL': String.fromEnvironment('AI_GATEWAY_URL'),
      'POSTHOG_KEY': String.fromEnvironment('POSTHOG_KEY'),
      'SENTRY_DSN': String.fromEnvironment('SENTRY_DSN'),
    };
    return AppConfig.fromMap(values, validate: validate);
  }

  /// Builds configuration from a non-secret map for deterministic tests/tools.
  factory AppConfig.fromMap(
    Map<String, String> values, {
    bool validate = true,
  }) {
    final environment = AppEnvironment.parse(values['SYNAPSE_ENV'] ?? 'local');
    final publishableKey = _firstNonEmpty(
      values['SUPABASE_PUBLISHABLE_KEY'],
      values['SUPABASE_ANON_KEY'],
    );
    final config = AppConfig(
      supabaseUrl: (values['SUPABASE_URL'] ?? '').trim(),
      supabaseAnonKey: publishableKey,
      personalSyncGatewayUrl: (values['SYNAPSE_SYNC_GATEWAY_URL'] ?? '').trim(),
      personalContentTrustAnchorsJson:
          (values['SYNAPSE_CONTENT_TRUST_ANCHORS_JSON'] ?? '').trim(),
      aiGatewayUrl: (values['AI_GATEWAY_URL'] ?? '').trim(),
      posthogKey: (values['POSTHOG_KEY'] ?? '').trim(),
      sentryDsn: (values['SENTRY_DSN'] ?? '').trim(),
      environment: environment,
    );
    if (validate) config.validateOrThrow();
    return config;
  }

  final String supabaseUrl;

  /// Legacy source-compatible name for the client-safe Supabase key.
  ///
  /// Supabase publishable/anon keys are public client identifiers governed by
  /// RLS; service-role or secret keys are forbidden in every client build.
  final String supabaseAnonKey;

  /// Client-safe base URL of the private Go device-sync gateway. No database
  /// or storage credential is ever embedded in Flutter.
  final String personalSyncGatewayUrl;

  /// Public JSON keyring for the signed personal curriculum channel. Private
  /// signing material is never accepted here or embedded in Flutter.
  final String personalContentTrustAnchorsJson;
  final String aiGatewayUrl;
  final String posthogKey;
  final String sentryDsn;
  final AppEnvironment environment;

  String get supabasePublishableKey => supabaseAnonKey;
  bool get hasLegacySupabaseBackend =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
  bool get hasPersonalSyncGateway => personalSyncGatewayUrl.isNotEmpty;
  bool get hasPersonalContentTrustAnchors =>
      personalContentTrustAnchorsJson.isNotEmpty;

  /// Compatibility status for older local-only screens. New personal sync
  /// must use [hasPersonalSyncGateway] and never direct Supabase access.
  bool get hasBackend => hasLegacySupabaseBackend || hasPersonalSyncGateway;
  bool get hasAi => aiGatewayUrl.isNotEmpty;
  bool get hasAnalytics => posthogKey.isNotEmpty;
  bool get hasCrashReporting => sentryDsn.isNotEmpty;
  bool get isProd => environment == AppEnvironment.production;

  List<ConfigIssue> validate() {
    final issues = <ConfigIssue>[];
    if (environment == AppEnvironment.test &&
        (hasBackend || hasAi || hasAnalytics || hasCrashReporting)) {
      issues.add(
        const ConfigIssue(
          code: ConfigIssueCode.externalServiceInTest,
          field: 'SYNAPSE_ENV',
          message: 'The test tier cannot target external services.',
        ),
      );
    }
    if (environment.requiresBackend && !hasBackend) {
      issues.add(
        const ConfigIssue(
          code: ConfigIssueCode.missingBackend,
          field: 'SUPABASE_URL',
          message: 'This deployment tier requires a complete backend pair.',
        ),
      );
    }
    if (supabaseUrl.isNotEmpty) {
      issues.addAll(
        _validateUrl(
          field: 'SUPABASE_URL',
          value: supabaseUrl,
          requireHttps: environment.requiresSecureRemote,
        ),
      );
    }
    if (personalSyncGatewayUrl.isNotEmpty) {
      issues.addAll(
        _validateUrl(
          field: 'SYNAPSE_SYNC_GATEWAY_URL',
          value: personalSyncGatewayUrl,
          requireHttps: environment.requiresSecureRemote,
        ),
      );
    }
    if (aiGatewayUrl.isNotEmpty) {
      issues.addAll(
        _validateUrl(
          field: 'AI_GATEWAY_URL',
          value: aiGatewayUrl,
          requireHttps: environment.requiresSecureRemote,
        ),
      );
    }
    if (sentryDsn.isNotEmpty) {
      issues.addAll(
        _validateUrl(
          field: 'SENTRY_DSN',
          value: sentryDsn,
          requireHttps: environment.requiresSecureRemote,
        ),
      );
    }
    if (supabasePublishableKey.isNotEmpty &&
        supabasePublishableKey.length < 20) {
      issues.add(
        const ConfigIssue(
          code: ConfigIssueCode.invalidPublishableKey,
          field: 'SUPABASE_PUBLISHABLE_KEY',
          message: 'The publishable key is structurally invalid.',
        ),
      );
    }
    return List.unmodifiable(issues);
  }

  void validateOrThrow() {
    final issues = validate();
    if (issues.isNotEmpty) throw AppConfigException(issues);
  }

  /// Safe diagnostic metadata. Credential-like values are never returned.
  Map<String, Object> toSafeDiagnostics() => {
    'environment': environment.wireName,
    'backendConfigured': hasBackend,
    'personalSyncGatewayConfigured': hasPersonalSyncGateway,
    'personalContentTrustAnchorsConfigured': hasPersonalContentTrustAnchors,
    'legacySupabaseConfigured': hasLegacySupabaseBackend,
    'aiConfigured': hasAi,
    'analyticsConfigured': hasAnalytics,
    'crashReportingConfigured': hasCrashReporting,
  };
}

enum AppEnvironment {
  local,
  test,
  preview,
  staging,
  production;

  static AppEnvironment parse(String raw) {
    return switch (raw.trim().toLowerCase()) {
      '' || 'local' || 'dev' || 'development' => local,
      'test' => test,
      'preview' => preview,
      'staging' || 'stage' => staging,
      'production' || 'prod' => production,
      final value => throw AppConfigException([
        ConfigIssue(
          code: ConfigIssueCode.unknownEnvironment,
          field: 'SYNAPSE_ENV',
          message: 'Unknown deployment tier: $value',
        ),
      ]),
    };
  }

  String get wireName => name;
  bool get requiresBackend => this == staging || this == production;
  bool get requiresSecureRemote => this == staging || this == production;
  bool get allowsTelemetry =>
      this == preview || this == staging || this == production;
}

enum ConfigIssueCode {
  unknownEnvironment,
  missingBackend,
  invalidUrl,
  insecureUrl,
  loopbackRemote,
  invalidPublishableKey,
  externalServiceInTest,
}

@immutable
class ConfigIssue {
  const ConfigIssue({
    required this.code,
    required this.field,
    required this.message,
  });

  final ConfigIssueCode code;
  final String field;
  final String message;

  @override
  String toString() => '${code.name}($field): $message';
}

final class AppConfigException implements Exception {
  AppConfigException(List<ConfigIssue> issues)
    : issues = List.unmodifiable(issues);

  final List<ConfigIssue> issues;

  @override
  String toString() => 'AppConfigException(${issues.join(', ')})';
}

List<ConfigIssue> _validateUrl({
  required String field,
  required String value,
  required bool requireHttps,
}) {
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return [
      ConfigIssue(
        code: ConfigIssueCode.invalidUrl,
        field: field,
        message: 'A complete absolute URL is required.',
      ),
    ];
  }
  final issues = <ConfigIssue>[];
  if (requireHttps && uri.scheme != 'https') {
    issues.add(
      ConfigIssue(
        code: ConfigIssueCode.insecureUrl,
        field: field,
        message: 'Remote staging/production endpoints must use HTTPS.',
      ),
    );
  }
  if (requireHttps && _isLoopback(uri.host)) {
    issues.add(
      ConfigIssue(
        code: ConfigIssueCode.loopbackRemote,
        field: field,
        message: 'Remote staging/production endpoints cannot be loopback.',
      ),
    );
  }
  return issues;
}

bool _isLoopback(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'localhost' ||
      normalized == '127.0.0.1' ||
      normalized == '::1';
}

String _firstNonEmpty(String? primary, String? fallback) {
  final first = (primary ?? '').trim();
  return first.isNotEmpty ? first : (fallback ?? '').trim();
}

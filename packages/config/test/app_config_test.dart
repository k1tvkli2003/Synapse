import 'package:synapse_config/synapse_config.dart';
import 'package:test/test.dart';

void main() {
  group('AppEnvironment', () {
    test('supports canonical tiers and legacy aliases', () {
      expect(AppEnvironment.parse('local'), AppEnvironment.local);
      expect(AppEnvironment.parse('dev'), AppEnvironment.local);
      expect(AppEnvironment.parse('test'), AppEnvironment.test);
      expect(AppEnvironment.parse('preview'), AppEnvironment.preview);
      expect(AppEnvironment.parse('stage'), AppEnvironment.staging);
      expect(AppEnvironment.parse('prod'), AppEnvironment.production);
    });

    test('rejects unknown tiers instead of silently using local', () {
      expect(
        () => AppEnvironment.parse('mystery'),
        throwsA(
          isA<AppConfigException>().having(
            (error) => error.issues.single.code,
            'code',
            ConfigIssueCode.unknownEnvironment,
          ),
        ),
      );
    });
  });

  group('AppConfig validation', () {
    test('local defaults are a valid offline-first configuration', () {
      final config = AppConfig.fromMap(const {'SYNAPSE_ENV': 'local'});

      expect(config.environment, AppEnvironment.local);
      expect(config.hasBackend, isFalse);
      expect(config.validate(), isEmpty);
    });

    test('production rejects a missing backend pair', () {
      expect(
        () => AppConfig.fromMap(const {'SYNAPSE_ENV': 'production'}),
        throwsA(
          isA<AppConfigException>().having(
            (error) => error.issues.map((issue) => issue.code),
            'codes',
            contains(ConfigIssueCode.missingBackend),
          ),
        ),
      );
    });

    test('production rejects insecure and loopback endpoints', () {
      expect(
        () => AppConfig.fromMap(const {
          'SYNAPSE_ENV': 'prod',
          'SUPABASE_URL': 'http://localhost:54321',
          'SUPABASE_PUBLISHABLE_KEY': 'sb_publishable_fixture_123456789',
        }),
        throwsA(
          isA<AppConfigException>().having(
            (error) => error.issues.map((issue) => issue.code),
            'codes',
            containsAll({
              ConfigIssueCode.insecureUrl,
              ConfigIssueCode.loopbackRemote,
            }),
          ),
        ),
      );
    });

    test('test tier cannot accidentally call external services', () {
      expect(
        () => AppConfig.fromMap(const {
          'SYNAPSE_ENV': 'test',
          'AI_GATEWAY_URL': 'https://ai.example.test',
        }),
        throwsA(
          isA<AppConfigException>().having(
            (error) => error.issues.single.code,
            'code',
            ConfigIssueCode.externalServiceInTest,
          ),
        ),
      );
    });

    test('valid production config accepts the legacy publishable-key name', () {
      final config = AppConfig.fromMap(const {
        'SYNAPSE_ENV': 'production',
        'SUPABASE_URL': 'https://synapse.example.com',
        'SUPABASE_ANON_KEY': 'fixture_public_key_1234567890',
        'AI_GATEWAY_URL': 'https://ai.example.com',
        'POSTHOG_KEY': 'public_project_key',
        'SENTRY_DSN': 'https://public@example.ingest.sentry.io/1',
      });

      expect(config.isProd, isTrue);
      expect(config.hasBackend, isTrue);
      expect(config.supabasePublishableKey, 'fixture_public_key_1234567890');
      expect(config.toSafeDiagnostics(), {
        'environment': 'production',
        'backendConfigured': true,
        'aiConfigured': true,
        'analyticsConfigured': true,
        'crashReportingConfigured': true,
        'personalSyncGatewayConfigured': false,
        'personalContentTrustAnchorsConfigured': false,
        'legacySupabaseConfigured': true,
      });
      expect(
        config.toSafeDiagnostics().toString(),
        isNot(contains('fixture_public_key')),
      );
    });
  });
}

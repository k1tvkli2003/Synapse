import 'package:synapse_config/synapse_config.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 7, 17, 12);

  test('defaults preserve existing ECG generative capability', () {
    expect(FeatureFlags.defaults.featureEcgGenerative, isTrue);
    expect(FeatureFlags.defaults.featureLiveRooms, isFalse);
  });

  test('typed local overrides apply in local builds', () {
    final resolution = FeatureFlags.resolve(
      environment: AppEnvironment.local,
      now: now,
      online: true,
      localOverrides: const {FeatureFlagKey.featureEcgGenerative: false},
    );

    expect(resolution.flags.featureEcgGenerative, isFalse);
    expect(resolution.localOverridesApplied, isTrue);
  });

  test('unsigned local overrides are ignored in production', () {
    final resolution = FeatureFlags.resolve(
      environment: AppEnvironment.production,
      now: now,
      online: true,
      localOverrides: const {FeatureFlagKey.moduleEcg: false},
    );

    expect(resolution.flags.moduleEcg, isTrue);
    expect(resolution.localOverridesApplied, isFalse);
  });

  test('fresh online remote snapshot applies', () {
    final resolution = FeatureFlags.resolve(
      environment: AppEnvironment.production,
      now: now,
      online: true,
      remote: RemoteFeatureFlags(
        values: const {FeatureFlagKey.featureLiveRooms: true},
        fetchedAt: now.subtract(const Duration(minutes: 10)),
      ),
    );

    expect(resolution.flags.featureLiveRooms, isTrue);
    expect(resolution.remoteState, RemoteFeatureFlagState.applied);
  });

  test('offline remote snapshot is ignored', () {
    final resolution = FeatureFlags.resolve(
      environment: AppEnvironment.production,
      now: now,
      online: false,
      remote: RemoteFeatureFlags(
        values: const {FeatureFlagKey.moduleEcg: false},
        fetchedAt: now,
      ),
    );

    expect(resolution.flags.moduleEcg, isTrue);
    expect(resolution.remoteState, RemoteFeatureFlagState.offlineIgnored);
  });

  test('stale remote snapshot is ignored', () {
    final resolution = FeatureFlags.resolve(
      environment: AppEnvironment.production,
      now: now,
      online: true,
      remote: RemoteFeatureFlags(
        values: const {FeatureFlagKey.moduleEcg: false},
        fetchedAt: now.subtract(const Duration(hours: 2)),
      ),
    );

    expect(resolution.flags.moduleEcg, isTrue);
    expect(resolution.remoteState, RemoteFeatureFlagState.staleIgnored);
  });

  test('override parser rejects unknown keys and malformed values', () {
    expect(
      () => FeatureFlags.parseOverrides('unknown=true'),
      throwsA(isA<FeatureFlagFormatException>()),
    );
    expect(
      () => FeatureFlags.parseOverrides('moduleEcg=maybe'),
      throwsA(isA<FeatureFlagFormatException>()),
    );
  });
}

import 'package:meta/meta.dart';

import 'app_config.dart';

enum FeatureFlagKey {
  moduleCopilot,
  moduleTerms,
  moduleCards,
  moduleMnemonics,
  moduleEcg,
  moduleSounds,
  moduleLabs,
  moduleAlgorithms,
  moduleOrLab,
  moduleRounds,
  moduleBuddies,
  moduleArena,
  moduleCases,
  featureEcgGenerative,
  featureSoundSimulator,
  featureOrVisual,
  featureLiveRooms;

  static FeatureFlagKey parse(String value) {
    return values.firstWhere(
      (key) => key.name == value.trim(),
      orElse: () => throw FeatureFlagFormatException(
        'Unknown feature flag: ${value.trim()}',
      ),
    );
  }
}

/// Stable feature snapshot. Existing reachable capabilities default on;
/// unfinished capabilities default off and keep their routes resolvable.
@immutable
class FeatureFlags {
  const FeatureFlags({
    this.moduleCopilot = true,
    this.moduleTerms = true,
    this.moduleCards = true,
    this.moduleMnemonics = true,
    this.moduleEcg = true,
    this.moduleSounds = true,
    this.moduleLabs = true,
    this.moduleAlgorithms = true,
    this.moduleOrLab = true,
    this.moduleRounds = true,
    this.moduleBuddies = true,
    this.moduleArena = true,
    this.moduleCases = true,
    // This route is already implemented and therefore remains on by default.
    this.featureEcgGenerative = true,
    this.featureSoundSimulator = false,
    this.featureOrVisual = false,
    this.featureLiveRooms = false,
  });

  factory FeatureFlags.fromEnvironment(AppEnvironment environment) {
    const raw = String.fromEnvironment('SYNAPSE_FEATURE_FLAGS');
    return FeatureFlags.resolve(
      environment: environment,
      localOverrides: parseOverrides(raw),
      now: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      online: true,
    ).flags;
  }

  final bool moduleCopilot;
  final bool moduleTerms;
  final bool moduleCards;
  final bool moduleMnemonics;
  final bool moduleEcg;
  final bool moduleSounds;
  final bool moduleLabs;
  final bool moduleAlgorithms;
  final bool moduleOrLab;
  final bool moduleRounds;
  final bool moduleBuddies;
  final bool moduleArena;
  final bool moduleCases;
  final bool featureEcgGenerative;
  final bool featureSoundSimulator;
  final bool featureOrVisual;
  final bool featureLiveRooms;

  static const FeatureFlags defaults = FeatureFlags();

  bool operator [](FeatureFlagKey key) => switch (key) {
    FeatureFlagKey.moduleCopilot => moduleCopilot,
    FeatureFlagKey.moduleTerms => moduleTerms,
    FeatureFlagKey.moduleCards => moduleCards,
    FeatureFlagKey.moduleMnemonics => moduleMnemonics,
    FeatureFlagKey.moduleEcg => moduleEcg,
    FeatureFlagKey.moduleSounds => moduleSounds,
    FeatureFlagKey.moduleLabs => moduleLabs,
    FeatureFlagKey.moduleAlgorithms => moduleAlgorithms,
    FeatureFlagKey.moduleOrLab => moduleOrLab,
    FeatureFlagKey.moduleRounds => moduleRounds,
    FeatureFlagKey.moduleBuddies => moduleBuddies,
    FeatureFlagKey.moduleArena => moduleArena,
    FeatureFlagKey.moduleCases => moduleCases,
    FeatureFlagKey.featureEcgGenerative => featureEcgGenerative,
    FeatureFlagKey.featureSoundSimulator => featureSoundSimulator,
    FeatureFlagKey.featureOrVisual => featureOrVisual,
    FeatureFlagKey.featureLiveRooms => featureLiveRooms,
  };

  Map<FeatureFlagKey, bool> get values => Map.unmodifiable({
    for (final key in FeatureFlagKey.values) key: this[key],
  });

  FeatureFlags withValues(Map<FeatureFlagKey, bool> overrides) {
    final merged = {...values, ...overrides};
    return FeatureFlags(
      moduleCopilot: merged[FeatureFlagKey.moduleCopilot]!,
      moduleTerms: merged[FeatureFlagKey.moduleTerms]!,
      moduleCards: merged[FeatureFlagKey.moduleCards]!,
      moduleMnemonics: merged[FeatureFlagKey.moduleMnemonics]!,
      moduleEcg: merged[FeatureFlagKey.moduleEcg]!,
      moduleSounds: merged[FeatureFlagKey.moduleSounds]!,
      moduleLabs: merged[FeatureFlagKey.moduleLabs]!,
      moduleAlgorithms: merged[FeatureFlagKey.moduleAlgorithms]!,
      moduleOrLab: merged[FeatureFlagKey.moduleOrLab]!,
      moduleRounds: merged[FeatureFlagKey.moduleRounds]!,
      moduleBuddies: merged[FeatureFlagKey.moduleBuddies]!,
      moduleArena: merged[FeatureFlagKey.moduleArena]!,
      moduleCases: merged[FeatureFlagKey.moduleCases]!,
      featureEcgGenerative: merged[FeatureFlagKey.featureEcgGenerative]!,
      featureSoundSimulator: merged[FeatureFlagKey.featureSoundSimulator]!,
      featureOrVisual: merged[FeatureFlagKey.featureOrVisual]!,
      featureLiveRooms: merged[FeatureFlagKey.featureLiveRooms]!,
    );
  }

  static Map<FeatureFlagKey, bool> parseOverrides(String raw) {
    if (raw.trim().isEmpty) return const {};
    final result = <FeatureFlagKey, bool>{};
    for (final assignment in raw.split(',')) {
      final parts = assignment.split('=');
      if (parts.length != 2) {
        throw FeatureFlagFormatException(
          'Expected key=true|false, got: ${assignment.trim()}',
        );
      }
      final key = FeatureFlagKey.parse(parts[0]);
      final value = switch (parts[1].trim().toLowerCase()) {
        'true' || '1' => true,
        'false' || '0' => false,
        final invalid => throw FeatureFlagFormatException(
          'Invalid value for ${key.name}: $invalid',
        ),
      };
      result[key] = value;
    }
    return Map.unmodifiable(result);
  }

  static FeatureFlagResolution resolve({
    required AppEnvironment environment,
    required DateTime now,
    required bool online,
    FeatureFlags defaults = FeatureFlags.defaults,
    RemoteFeatureFlags? remote,
    Map<FeatureFlagKey, bool> localOverrides = const {},
  }) {
    var flags = defaults;
    var remoteState = RemoteFeatureFlagState.absent;
    if (remote != null) {
      if (!online) {
        remoteState = RemoteFeatureFlagState.offlineIgnored;
      } else if (remote.schemaVersion != 1) {
        remoteState = RemoteFeatureFlagState.incompatibleIgnored;
      } else if (!remote.isFreshAt(now)) {
        remoteState = RemoteFeatureFlagState.staleIgnored;
      } else {
        flags = flags.withValues(remote.values);
        remoteState = RemoteFeatureFlagState.applied;
      }
    }

    final localOverridesAllowed =
        environment == AppEnvironment.local ||
        environment == AppEnvironment.test ||
        environment == AppEnvironment.preview;
    if (localOverridesAllowed) flags = flags.withValues(localOverrides);
    return FeatureFlagResolution(
      flags: flags,
      remoteState: remoteState,
      localOverridesApplied: localOverridesAllowed && localOverrides.isNotEmpty,
    );
  }
}

@immutable
class RemoteFeatureFlags {
  RemoteFeatureFlags({
    required Map<FeatureFlagKey, bool> values,
    required this.fetchedAt,
    this.validFor = const Duration(hours: 1),
    this.schemaVersion = 1,
  }) : values = Map.unmodifiable(values);

  final Map<FeatureFlagKey, bool> values;
  final DateTime fetchedAt;
  final Duration validFor;
  final int schemaVersion;

  bool isFreshAt(DateTime now) =>
      !now.isBefore(fetchedAt) && now.difference(fetchedAt) <= validFor;
}

enum RemoteFeatureFlagState {
  absent,
  applied,
  offlineIgnored,
  staleIgnored,
  incompatibleIgnored,
}

@immutable
class FeatureFlagResolution {
  const FeatureFlagResolution({
    required this.flags,
    required this.remoteState,
    required this.localOverridesApplied,
  });

  final FeatureFlags flags;
  final RemoteFeatureFlagState remoteState;
  final bool localOverridesApplied;
}

final class FeatureFlagFormatException implements FormatException {
  const FeatureFlagFormatException(this.message);

  @override
  final String message;

  @override
  int? get offset => null;

  @override
  Object? get source => null;

  @override
  String toString() => 'FeatureFlagFormatException: $message';
}

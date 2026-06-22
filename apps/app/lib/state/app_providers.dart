import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synapse_config/synapse_config.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_services/synapse_services.dart';

import 'persistence.dart';

/// Overridden in `main()` with the resolved instance.
final sharedPreferencesProvider = Provider<PersistedStore>(
  (ref) => throw UnimplementedError('PersistedStore must be provided in main()'),
);

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.fromEnvironment());

final featureFlagsProvider = Provider<FeatureFlags>((ref) => FeatureFlags.defaults);

/// The offline-first content repository + seed data (prompt 05/23).
final repositoryProvider = Provider<ContentRepository>((ref) => ContentRepository());

/// The typed in-app event bus — the integration backbone (prompt 32).
final eventBusProvider = Provider<EventBus>((ref) {
  final bus = EventBus();
  ref.onDispose(bus.dispose);
  return bus;
});

/// A live feed of recent events (for the integration/debug surface).
final eventFeedProvider = StreamProvider<SynapseEvent>((ref) {
  return ref.watch(eventBusProvider).stream;
});

/// Online/offline status (prompt 23). Local-only here; defaults to online.
final networkOnlineProvider = StateProvider<bool>((ref) => true);

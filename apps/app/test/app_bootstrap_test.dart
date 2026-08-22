import 'package:shared_preferences/shared_preferences.dart';
import 'package:synapse_app/bootstrap/app_bootstrap.dart';
import 'package:synapse_app/state/persistence.dart';
import 'package:synapse_config/synapse_config.dart';
import 'package:synapse_foundation/synapse_foundation.dart';
import 'package:synapse_observability/synapse_observability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<PersistedStore> storeWithAnalytics(bool optedIn) async {
    SharedPreferences.setMockInitialValues({
      'settings': '{"analyticsOptIn":$optedIn}',
    });
    return PersistedStore(await SharedPreferences.getInstance());
  }

  test('offline bootstrap skips cloud and still produces a runtime', () async {
    var cloudCalls = 0;
    final logs = MemoryStructuredLogSink();
    final runtime = await AppBootstrapper(
      config: const AppConfig(),
      online: false,
      loadStore: () => storeWithAnalytics(false),
      initializeCloud: (_) async => cloudCalls += 1,
      clock: MutableClock(DateTime.utc(2026, 7, 17, 12)),
      correlationIds: TimeOrderedIdSource(
        clock: MutableClock(DateTime.utc(2026, 7, 17, 12)),
        random: SeededRandomSource(1),
      ),
      logSink: logs,
    ).run();

    expect(runtime.bootstrap.outcome, BootstrapOutcome.degraded);
    expect(cloudCalls, 0);
    expect(logs.records.last.name, 'app.bootstrap.complete');
  });

  test('cloud failure is degraded and never blocks local startup', () async {
    final runtime = await AppBootstrapper(
      config: const AppConfig(),
      loadStore: () => storeWithAnalytics(false),
      initializeCloud: (_) async => throw StateError('offline fixture'),
    ).run();

    expect(runtime.bootstrap.outcome, BootstrapOutcome.degraded);
    expect(
      runtime.bootstrap.statusOf(BootstrapStage.sync),
      BootstrapStageStatus.degraded,
    );
  });

  test(
    'persisted consent controls the first anonymous app-open event',
    () async {
      final analytics = MemoryAnalyticsSink();
      await AppBootstrapper(
        config: const AppConfig(),
        loadStore: () => storeWithAnalytics(true),
        initializeCloud: (_) async {},
        analyticsSink: analytics,
      ).run();

      expect(analytics.events, hasLength(1));
      expect(analytics.events.single.event.name, AnalyticsEventName.appOpened);
    },
  );
}

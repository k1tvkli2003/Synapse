import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synapse_config/synapse_config.dart';
import 'package:synapse_foundation/synapse_foundation.dart';
import 'package:synapse_observability/synapse_observability.dart';

import '../cloud/supabase_bootstrap.dart';
import '../state/persistence.dart';

typedef StoreLoader = Future<PersistedStore> Function();
typedef CloudInitializer = Future<void> Function(AppConfig config);

final class AppRuntime {
  const AppRuntime({
    required this.config,
    required this.store,
    required this.bootstrap,
    required this.logger,
    required this.analytics,
    required this.crashReporter,
  });

  final AppConfig config;
  final PersistedStore store;
  final BootstrapSnapshot bootstrap;
  final StructuredLogger logger;
  final PrivacyAwareAnalytics analytics;
  final CrashReporter crashReporter;
}

final class AppBootstrapException implements Exception {
  const AppBootstrapException(this.snapshot);

  final BootstrapSnapshot snapshot;

  @override
  String toString() =>
      'AppBootstrapException(${snapshot.failure?.errorType ?? 'unknown'})';
}

final class AppBootstrapper {
  AppBootstrapper({
    required this.config,
    this.online = true,
    StoreLoader? loadStore,
    CloudInitializer? initializeCloud,
    Clock? clock,
    IdSource? correlationIds,
    StructuredLogSink? logSink,
    AnalyticsSink? analyticsSink,
    CrashSink? crashSink,
  }) : loadStore = loadStore ?? _loadSharedPreferences,
       initializeCloud = initializeCloud ?? bootstrapSupabase,
       clock = clock ?? const SystemClock(),
       correlationIds =
           correlationIds ??
           TimeOrderedIdSource(
             clock: clock ?? const SystemClock(),
             random: SecureRandomSource(),
             prefix: 'cor',
           ),
       logSink = logSink ?? _defaultLogSink(config.environment),
       analyticsSink = analyticsSink ?? const NoopAnalyticsSink(),
       crashSink = crashSink ?? const NoopCrashSink();

  final AppConfig config;
  final bool online;
  final StoreLoader loadStore;
  final CloudInitializer initializeCloud;
  final Clock clock;
  final IdSource correlationIds;
  final StructuredLogSink logSink;
  final AnalyticsSink analyticsSink;
  final CrashSink crashSink;

  Future<AppRuntime> run() async {
    late PersistedStore store;
    final redaction = RedactionPolicy(
      allowedKeys: const {'stage', 'status', 'outcome', 'errorType', 'online'},
    );
    final logger = StructuredLogger(
      clock: clock,
      correlationIds: correlationIds,
      redaction: redaction,
      sink: logSink,
    );
    final crashReporter = SafeCrashReporter(
      clock: clock,
      correlationIds: correlationIds,
      redaction: redaction,
      sink: crashSink,
    );

    final coordinator = BootstrapCoordinator(
      operations: [
        BootstrapOperation(
          stage: BootstrapStage.config,
          action: () async => config.validateOrThrow(),
        ),
        BootstrapOperation(
          stage: BootstrapStage.localStore,
          action: () async => store = await loadStore(),
        ),
        BootstrapOperation(stage: BootstrapStage.auth, action: () async {}),
        BootstrapOperation(
          stage: BootstrapStage.sync,
          critical: false,
          requiresNetwork: true,
          action: () => initializeCloud(config),
        ),
        BootstrapOperation(
          stage: BootstrapStage.locale,
          critical: false,
          action: () async {},
        ),
        BootstrapOperation(stage: BootstrapStage.router, action: () async {}),
      ],
      onTransition: (snapshot) {
        unawaited(
          logger.emit(
            name: 'app.bootstrap.transition',
            severity: snapshot.outcome == BootstrapOutcome.failed
                ? LogSeverity.error
                : LogSeverity.info,
            attributes: [
              if (snapshot.currentStage case final stage?)
                ObservabilityAttribute(key: 'stage', value: stage.name),
              ObservabilityAttribute(
                key: 'outcome',
                value: snapshot.outcome.name,
              ),
              ObservabilityAttribute(key: 'online', value: online),
              if (snapshot.failure case final failure?)
                ObservabilityAttribute(
                  key: 'errorType',
                  value: failure.errorType,
                ),
            ],
          ),
        );
      },
    );

    final bootstrap = await coordinator.start(online: online);
    if (bootstrap.outcome == BootstrapOutcome.failed) {
      throw AppBootstrapException(bootstrap);
    }

    final analyticsOptIn =
        store.readJson('settings')?['analyticsOptIn'] == true;
    final consent = MemoryAnalyticsConsentStore(
      analyticsOptIn ? AnalyticsConsent.granted : AnalyticsConsent.denied,
    );
    final analytics = PrivacyAwareAnalytics(
      clock: clock,
      correlationIds: correlationIds,
      consent: consent,
      sink: analyticsSink,
    );
    await analytics.track(
      AnalyticsEvent(
        name: AnalyticsEventName.appOpened,
        properties: {
          AnalyticsPropertyKey.networkState: online ? 'online' : 'offline',
        },
      ),
    );
    await logger.emit(
      name: 'app.bootstrap.complete',
      attributes: [
        ObservabilityAttribute(key: 'outcome', value: bootstrap.outcome.name),
        ObservabilityAttribute(key: 'online', value: online),
      ],
    );

    return AppRuntime(
      config: config,
      store: store,
      bootstrap: bootstrap,
      logger: logger,
      analytics: analytics,
      crashReporter: crashReporter,
    );
  }
}

Future<PersistedStore> _loadSharedPreferences() async {
  final preferences = await SharedPreferences.getInstance();
  return PersistedStore(preferences);
}

StructuredLogSink _defaultLogSink(AppEnvironment environment) {
  final local = CallbackStructuredLogSink((payload) async {
    if (kDebugMode) debugPrint(jsonEncode(payload));
  });
  return EnvironmentStructuredLogSink(
    tier: switch (environment) {
      AppEnvironment.local => RuntimeTier.local,
      AppEnvironment.test => RuntimeTier.test,
      AppEnvironment.preview => RuntimeTier.preview,
      AppEnvironment.staging => RuntimeTier.staging,
      AppEnvironment.production => RuntimeTier.production,
    },
    local: local,
    test: const NoopStructuredLogSink(),
    remote: const NoopStructuredLogSink(),
  );
}

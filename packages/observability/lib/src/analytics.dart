import 'package:synapse_foundation/synapse_foundation.dart';

enum AnalyticsConsent { unknown, denied, granted }

enum AnalyticsEventName {
  appOpened,
  navigationCompleted,
  learningSessionStarted,
  lessonCompleted,
  reviewCompleted,
  featureUnavailable,
}

enum AnalyticsPropertyKey {
  surface,
  routeTemplate,
  module,
  lessonKind,
  completionResult,
  durationBucket,
  localeLanguage,
  motionMode,
  networkState,
}

/// Product analytics only. It must never be used as an authoritative learning,
/// reward, streak, assessment, billing, or clinical event.
final class AnalyticsEvent {
  AnalyticsEvent({
    required this.name,
    Map<AnalyticsPropertyKey, Object> properties = const {},
  }) : properties = Map.unmodifiable(properties) {
    _validateAnalyticsProperties(name, this.properties);
  }

  final AnalyticsEventName name;
  final Map<AnalyticsPropertyKey, Object> properties;
}

final class AnalyticsEnvelope {
  AnalyticsEnvelope({
    required this.event,
    required this.occurredAt,
    required this.correlationId,
  });

  final AnalyticsEvent event;
  final DateTime occurredAt;
  final String correlationId;

  Map<String, Object> toJson() => {
    'schemaVersion': 1,
    'name': event.name.name,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'correlationId': correlationId,
    'properties': {
      for (final entry in event.properties.entries) entry.key.name: entry.value,
    },
  };
}

abstract interface class AnalyticsConsentStore {
  AnalyticsConsent get current;

  Future<void> set(AnalyticsConsent value);
}

final class MemoryAnalyticsConsentStore implements AnalyticsConsentStore {
  MemoryAnalyticsConsentStore([this._current = AnalyticsConsent.unknown]);

  AnalyticsConsent _current;

  @override
  AnalyticsConsent get current => _current;

  @override
  Future<void> set(AnalyticsConsent value) async => _current = value;
}

abstract interface class AnalyticsSink {
  Future<void> send(AnalyticsEnvelope envelope);

  /// Deletes queued and vendor-side anonymous telemetry where supported.
  Future<void> purge();
}

final class NoopAnalyticsSink implements AnalyticsSink {
  const NoopAnalyticsSink();

  @override
  Future<void> send(AnalyticsEnvelope envelope) async {}

  @override
  Future<void> purge() async {}
}

final class MemoryAnalyticsSink implements AnalyticsSink {
  final List<AnalyticsEnvelope> _events = [];
  int purgeCount = 0;

  List<AnalyticsEnvelope> get events => List.unmodifiable(_events);

  @override
  Future<void> send(AnalyticsEnvelope envelope) async => _events.add(envelope);

  @override
  Future<void> purge() async {
    purgeCount += 1;
    _events.clear();
  }
}

/// Vendor adapter boundary; receives only schema-validated minimized payloads.
final class CallbackAnalyticsSink implements AnalyticsSink {
  const CallbackAnalyticsSink({
    required this.sendPayload,
    required this.purgeData,
  });

  final Future<void> Function(Map<String, Object> payload) sendPayload;
  final Future<void> Function() purgeData;

  @override
  Future<void> send(AnalyticsEnvelope envelope) =>
      sendPayload(envelope.toJson());

  @override
  Future<void> purge() => purgeData();
}

enum AnalyticsDelivery { delivered, suppressedNoConsent }

final class PrivacyAwareAnalytics {
  const PrivacyAwareAnalytics({
    required this.clock,
    required this.correlationIds,
    required this.consent,
    required this.sink,
  });

  final Clock clock;
  final IdSource correlationIds;
  final AnalyticsConsentStore consent;
  final AnalyticsSink sink;

  Future<AnalyticsDelivery> track(
    AnalyticsEvent event, {
    String? correlationId,
  }) async {
    if (consent.current != AnalyticsConsent.granted) {
      return AnalyticsDelivery.suppressedNoConsent;
    }
    await sink.send(
      AnalyticsEnvelope(
        event: event,
        occurredAt: clock.nowUtc(),
        correlationId: correlationId ?? correlationIds.nextId(),
      ),
    );
    return AnalyticsDelivery.delivered;
  }

  Future<void> grantConsent() => consent.set(AnalyticsConsent.granted);

  Future<void> revokeConsentAndDelete() async {
    await consent.set(AnalyticsConsent.denied);
    await sink.purge();
  }
}

void _validateAnalyticsProperties(
  AnalyticsEventName name,
  Map<AnalyticsPropertyKey, Object> properties,
) {
  const common = {
    AnalyticsPropertyKey.surface,
    AnalyticsPropertyKey.localeLanguage,
    AnalyticsPropertyKey.motionMode,
    AnalyticsPropertyKey.networkState,
  };
  final eventSpecific = switch (name) {
    AnalyticsEventName.appOpened => const <AnalyticsPropertyKey>{},
    AnalyticsEventName.navigationCompleted => const {
      AnalyticsPropertyKey.routeTemplate,
    },
    AnalyticsEventName.learningSessionStarted => const {
      AnalyticsPropertyKey.module,
      AnalyticsPropertyKey.lessonKind,
    },
    AnalyticsEventName.lessonCompleted ||
    AnalyticsEventName.reviewCompleted => const {
      AnalyticsPropertyKey.module,
      AnalyticsPropertyKey.lessonKind,
      AnalyticsPropertyKey.completionResult,
      AnalyticsPropertyKey.durationBucket,
    },
    AnalyticsEventName.featureUnavailable => const {
      AnalyticsPropertyKey.module,
    },
  };
  final allowed = {...common, ...eventSpecific};
  for (final entry in properties.entries) {
    if (!allowed.contains(entry.key)) {
      throw ArgumentError('${entry.key.name} is not allowed for ${name.name}.');
    }
    if (entry.value is! String && entry.value is! bool && entry.value is! num) {
      throw ArgumentError.value(
        entry.value,
        entry.key.name,
        'Analytics properties must be scalar.',
      );
    }
    if (entry.value case final String value when value.length > 64) {
      throw ArgumentError.value(value, entry.key.name, 'Value is too long.');
    }
  }
}

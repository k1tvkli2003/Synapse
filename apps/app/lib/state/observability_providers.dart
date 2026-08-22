import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synapse_foundation/synapse_foundation.dart';
import 'package:synapse_observability/synapse_observability.dart';

final structuredLoggerProvider = Provider<StructuredLogger>((ref) {
  return StructuredLogger(
    clock: const SystemClock(),
    correlationIds: SequenceIdSource(const ['fallback-log']),
    redaction: RedactionPolicy(allowedKeys: const {}),
    sink: const NoopStructuredLogSink(),
  );
});

final analyticsProvider = Provider<PrivacyAwareAnalytics>((ref) {
  return PrivacyAwareAnalytics(
    clock: const SystemClock(),
    correlationIds: SequenceIdSource(const ['fallback-analytics']),
    consent: MemoryAnalyticsConsentStore(AnalyticsConsent.denied),
    sink: const NoopAnalyticsSink(),
  );
});

final crashReporterProvider = Provider<CrashReporter>((ref) {
  return SafeCrashReporter(
    clock: const SystemClock(),
    correlationIds: SequenceIdSource(const ['fallback-crash']),
    redaction: RedactionPolicy(allowedKeys: const {}),
    sink: const NoopCrashSink(),
  );
});

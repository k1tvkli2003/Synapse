import 'package:synapse_foundation/synapse_foundation.dart';

import 'redaction.dart';

enum LogSeverity { trace, debug, info, warning, error, critical }

enum RuntimeTier { local, test, preview, staging, production }

final class StructuredLogRecord {
  StructuredLogRecord({
    required this.name,
    required this.severity,
    required this.occurredAt,
    required this.correlationId,
    required Map<String, Object> attributes,
  }) : attributes = Map.unmodifiable(attributes) {
    _validateEventName(name);
  }

  final String name;
  final LogSeverity severity;
  final DateTime occurredAt;
  final String correlationId;
  final Map<String, Object> attributes;

  Map<String, Object> toJson() => {
    'schemaVersion': 1,
    'name': name,
    'severity': severity.name,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'correlationId': correlationId,
    'attributes': attributes,
  };
}

abstract interface class StructuredLogSink {
  Future<void> write(StructuredLogRecord record);
}

final class NoopStructuredLogSink implements StructuredLogSink {
  const NoopStructuredLogSink();

  @override
  Future<void> write(StructuredLogRecord record) async {}
}

final class MemoryStructuredLogSink implements StructuredLogSink {
  final List<StructuredLogRecord> _records = [];

  List<StructuredLogRecord> get records => List.unmodifiable(_records);

  @override
  Future<void> write(StructuredLogRecord record) async => _records.add(record);

  void clear() => _records.clear();
}

/// Boundary used by Sentry, OpenTelemetry, or another future adapter.
final class CallbackStructuredLogSink implements StructuredLogSink {
  const CallbackStructuredLogSink(this.callback);

  final Future<void> Function(Map<String, Object> payload) callback;

  @override
  Future<void> write(StructuredLogRecord record) => callback(record.toJson());
}

/// Selects a sink by deployment tier without importing app configuration.
final class EnvironmentStructuredLogSink implements StructuredLogSink {
  const EnvironmentStructuredLogSink({
    required this.tier,
    this.local = const NoopStructuredLogSink(),
    this.test = const NoopStructuredLogSink(),
    this.remote = const NoopStructuredLogSink(),
  });

  final RuntimeTier tier;
  final StructuredLogSink local;
  final StructuredLogSink test;
  final StructuredLogSink remote;

  StructuredLogSink get _selected => switch (tier) {
    RuntimeTier.local || RuntimeTier.preview => local,
    RuntimeTier.test => test,
    RuntimeTier.staging || RuntimeTier.production => remote,
  };

  @override
  Future<void> write(StructuredLogRecord record) => _selected.write(record);
}

final class StructuredLogger {
  const StructuredLogger({
    required this.clock,
    required this.correlationIds,
    required this.redaction,
    required this.sink,
  });

  final Clock clock;
  final IdSource correlationIds;
  final RedactionPolicy redaction;
  final StructuredLogSink sink;

  Future<StructuredLogRecord> emit({
    required String name,
    LogSeverity severity = LogSeverity.info,
    String? correlationId,
    Iterable<ObservabilityAttribute> attributes = const [],
  }) async {
    final record = StructuredLogRecord(
      name: name,
      severity: severity,
      occurredAt: clock.nowUtc(),
      correlationId: correlationId ?? correlationIds.nextId(),
      attributes: redaction.sanitize(attributes),
    );
    await sink.write(record);
    return record;
  }
}

void _validateEventName(String value) {
  if (!RegExp(r'^[a-z][a-z0-9]*(\.[a-z0-9]+)+$').hasMatch(value)) {
    throw FormatException(
      'Structured event names must use lowercase dotted notation.',
      value,
    );
  }
}

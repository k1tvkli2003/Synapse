import 'package:synapse_foundation/synapse_foundation.dart';

import 'redaction.dart';

final class CrashIncident {
  CrashIncident({
    required this.errorType,
    required this.fatal,
    required this.occurredAt,
    required this.correlationId,
    required this.normalizedStack,
    required Map<String, Object> attributes,
  }) : attributes = Map.unmodifiable(attributes);

  final String errorType;
  final bool fatal;
  final DateTime occurredAt;
  final String correlationId;
  final String normalizedStack;
  final Map<String, Object> attributes;

  Map<String, Object> toJson() => {
    'schemaVersion': 1,
    'errorType': errorType,
    'fatal': fatal,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'correlationId': correlationId,
    'normalizedStack': normalizedStack,
    'attributes': attributes,
  };
}

abstract interface class CrashSink {
  Future<void> send(CrashIncident incident);
}

final class NoopCrashSink implements CrashSink {
  const NoopCrashSink();

  @override
  Future<void> send(CrashIncident incident) async {}
}

final class MemoryCrashSink implements CrashSink {
  final List<CrashIncident> _incidents = [];

  List<CrashIncident> get incidents => List.unmodifiable(_incidents);

  @override
  Future<void> send(CrashIncident incident) async => _incidents.add(incident);
}

/// Production adapter boundary. Vendor SDK types never enter this package.
final class CallbackCrashSink implements CrashSink {
  const CallbackCrashSink(this.callback);

  final Future<void> Function(Map<String, Object> payload) callback;

  @override
  Future<void> send(CrashIncident incident) => callback(incident.toJson());
}

abstract interface class CrashReporter {
  Future<CrashIncident> capture(
    Object error,
    StackTrace stackTrace, {
    bool fatal = false,
    String? correlationId,
    Iterable<ObservabilityAttribute> attributes = const [],
  });
}

final class SafeCrashReporter implements CrashReporter {
  const SafeCrashReporter({
    required this.clock,
    required this.correlationIds,
    required this.redaction,
    required this.sink,
  });

  final Clock clock;
  final IdSource correlationIds;
  final RedactionPolicy redaction;
  final CrashSink sink;

  @override
  Future<CrashIncident> capture(
    Object error,
    StackTrace stackTrace, {
    bool fatal = false,
    String? correlationId,
    Iterable<ObservabilityAttribute> attributes = const [],
  }) async {
    // Never serialize error.toString(): exception messages may contain notes,
    // prompts, identifiers, credentials, or other sensitive user input.
    final incident = CrashIncident(
      errorType: error.runtimeType.toString(),
      fatal: fatal,
      occurredAt: clock.nowUtc(),
      correlationId: correlationId ?? correlationIds.nextId(),
      normalizedStack: normalizeStackTrace(stackTrace),
      attributes: redaction.sanitize(attributes),
    );
    await sink.send(incident);
    return incident;
  }
}

String normalizeStackTrace(StackTrace stackTrace, {int maximumFrames = 40}) {
  final frames = stackTrace.toString().split('\n').take(maximumFrames).map((
    line,
  ) {
    var safe = line.replaceAll(
      RegExp(r'[A-Za-z]:\\[^\s:)]+(?:\\[^\s:)]+)*'),
      '[LOCAL_PATH]',
    );
    safe = safe.replaceAll(RegExp(r'file://[^\s:)]+'), 'file://[LOCAL_PATH]');
    return sanitizeText(safe, maximumLength: 240);
  });
  return frames.join('\n');
}

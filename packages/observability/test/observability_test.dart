import 'package:synapse_foundation/synapse_foundation.dart';
import 'package:synapse_observability/synapse_observability.dart';
import 'package:test/test.dart';

void main() {
  final timestamp = DateTime.utc(2026, 7, 17, 12);

  group('structured logging', () {
    test(
      'allowlists fields and redacts classified or credential-like values',
      () async {
        final sink = MemoryStructuredLogSink();
        final logger = StructuredLogger(
          clock: MutableClock(timestamp),
          correlationIds: SequenceIdSource(const ['cor-1']),
          redaction: RedactionPolicy(
            allowedKeys: const {'phase', 'detail', 'note'},
          ),
          sink: sink,
        );
        final token = ['Bearer', 'opaque', 'value'].join(' ');

        final record = await logger.emit(
          name: 'bootstrap.config.ready',
          attributes: [
            const ObservabilityAttribute(key: 'phase', value: 'config'),
            ObservabilityAttribute(key: 'detail', value: token),
            const ObservabilityAttribute(
              key: 'note',
              value: 'private note',
              classification: DataClassification.sensitive,
            ),
            const ObservabilityAttribute(key: 'unknown', value: 'dropped'),
          ],
        );

        expect(record.correlationId, 'cor-1');
        expect(record.attributes['phase'], 'config');
        expect(record.attributes['detail'], contains('[REDACTED_TOKEN]'));
        expect(record.attributes['note'], '[REDACTED]');
        expect(record.attributes, isNot(contains('unknown')));
        expect(sink.records, hasLength(1));
      },
    );

    test(
      'environment router never sends production records to local sink',
      () async {
        final local = MemoryStructuredLogSink();
        final remote = MemoryStructuredLogSink();
        final sink = EnvironmentStructuredLogSink(
          tier: RuntimeTier.production,
          local: local,
          remote: remote,
        );
        final record = StructuredLogRecord(
          name: 'app.boot.ready',
          severity: LogSeverity.info,
          occurredAt: timestamp,
          correlationId: 'cor-2',
          attributes: const {},
        );

        await sink.write(record);
        expect(local.records, isEmpty);
        expect(remote.records, [record]);
      },
    );
  });

  group('analytics privacy', () {
    test('suppresses events until explicit consent', () async {
      final consent = MemoryAnalyticsConsentStore();
      final sink = MemoryAnalyticsSink();
      final analytics = PrivacyAwareAnalytics(
        clock: MutableClock(timestamp),
        correlationIds: SequenceIdSource(const ['analytics-1']),
        consent: consent,
        sink: sink,
      );
      final event = AnalyticsEvent(name: AnalyticsEventName.appOpened);

      expect(
        await analytics.track(event),
        AnalyticsDelivery.suppressedNoConsent,
      );
      await analytics.grantConsent();
      expect(await analytics.track(event), AnalyticsDelivery.delivered);
      expect(sink.events, hasLength(1));
    });

    test(
      'revocation deletes queued analytics and changes consent first',
      () async {
        final consent = MemoryAnalyticsConsentStore(AnalyticsConsent.granted);
        final sink = MemoryAnalyticsSink();
        final analytics = PrivacyAwareAnalytics(
          clock: MutableClock(timestamp),
          correlationIds: SequenceIdSource(const ['analytics-2']),
          consent: consent,
          sink: sink,
        );
        await analytics.track(
          AnalyticsEvent(name: AnalyticsEventName.appOpened),
        );

        await analytics.revokeConsentAndDelete();

        expect(consent.current, AnalyticsConsent.denied);
        expect(sink.events, isEmpty);
        expect(sink.purgeCount, 1);
      },
    );

    test('rejects properties that are not minimized for an event', () {
      expect(
        () => AnalyticsEvent(
          name: AnalyticsEventName.appOpened,
          properties: const {AnalyticsPropertyKey.lessonKind: 'private-title'},
        ),
        throwsArgumentError,
      );
    });
  });

  group('crash reporting', () {
    test('never serializes exception messages and redacts context', () async {
      final sink = MemoryCrashSink();
      final reporter = SafeCrashReporter(
        clock: MutableClock(timestamp),
        correlationIds: SequenceIdSource(const ['crash-1']),
        redaction: RedactionPolicy(allowedKeys: const {'phase', 'content'}),
        sink: sink,
      );
      const error = _PrivateMessageError('patient note must not leave process');

      final incident = await reporter.capture(
        error,
        StackTrace.fromString(
          '#0 main (file:///private/project/main.dart:10:2)',
        ),
        attributes: const [
          ObservabilityAttribute(key: 'phase', value: 'bootstrap'),
          ObservabilityAttribute(
            key: 'content',
            value: 'sensitive text',
            classification: DataClassification.prohibited,
          ),
        ],
      );

      final payload = incident.toJson().toString();
      expect(payload, isNot(contains('patient note')));
      expect(payload, isNot(contains('/private/project')));
      expect(incident.errorType, '_PrivateMessageError');
      expect(incident.attributes['content'], '[REDACTED]');
      expect(sink.incidents, [incident]);
    });
  });
}

final class _PrivateMessageError implements Exception {
  const _PrivateMessageError(this.message);

  final String message;

  @override
  String toString() => message;
}

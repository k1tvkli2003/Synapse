import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synapse_app/state/app_providers.dart';
import 'package:synapse_app/state/persistence.dart';
import 'package:synapse_app/state/presentation_provider.dart';
import 'package:synapse_foundation/synapse_foundation.dart';
import 'package:synapse_motion/synapse_motion.dart';

void main() {
  Future<(ProviderContainer, SharedPreferences)> containerWith(
    Map<String, Object> values,
  ) async {
    SharedPreferences.setMockInitialValues(values);
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          PersistedStore(preferences),
        ),
        clockProvider.overrideWithValue(
          MutableClock(DateTime.utc(2026, 7, 17, 12)),
        ),
      ],
    );
    addTearDown(container.dispose);
    return (container, preferences);
  }

  test(
    'invalid presentation snapshot recovers without blocking startup',
    () async {
      final (container, preferences) = await containerWith({
        'motion_presentation_queue_v1': '{"schemaVersion":999,"records":[]}',
      });

      final state = container.read(presentationQueueProvider);
      await Future<void>.delayed(Duration.zero);

      expect(state.records, isEmpty);
      expect(preferences.getString('motion_presentation_queue_v1'), isNull);
    },
  );

  test(
    'rapid queue transitions persist their newest terminal snapshot',
    () async {
      final (container, preferences) = await containerWith({});
      final controller = container.read(presentationQueueProvider.notifier);
      controller.enqueue(
        PresentationReceipt(
          receiptId: 'receipt-1',
          sourceEventId: 'event-1',
          sequenceKey: 'reward.standard',
          tier: MotionTier.standard,
          occurredAtUtc: DateTime.utc(2026, 7, 17, 12),
        ),
      );
      controller.start('receipt-1');
      controller.acknowledge('receipt-1', PresentationStatus.played);

      await controller.flushForTest();

      final restored = PresentationQueue.fromJson(
        clock: MutableClock(DateTime.utc(2026, 7, 17, 12, 1)),
        json: PersistedStore(
          preferences,
        ).readJson('motion_presentation_queue_v1')!,
      );
      expect(restored.records.single.status, PresentationStatus.played);
    },
  );
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synapse_app/state/app_providers.dart';
import 'package:synapse_app/state/game_provider.dart';
import 'package:synapse_app/state/persistence.dart';
import 'package:synapse_app/state/presentation_provider.dart';
import 'package:synapse_app/state/toast_provider.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_foundation/synapse_foundation.dart';
import 'package:synapse_motion/synapse_motion.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('one report produces one durable receipt and no reward toast', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final clock = MutableClock(DateTime.utc(2026, 7, 17, 12));
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          PersistedStore(preferences),
        ),
        clockProvider.overrideWithValue(clock),
        operationalIdSourceProvider.overrideWithValue(
          SequenceIdSource(const ['source-event-1', 'receipt-1']),
        ),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(gameProvider.notifier)
        .report(
          source: ModuleKey.terms,
          kind: RewardKind.correct,
          correct: true,
          xp: 12,
        );

    final records = container.read(presentationQueueProvider).records;
    expect(records, hasLength(1));
    expect(records.single.status, PresentationStatus.queued);
    expect(records.single.receipt.sourceEventId, 'source-event-1');
    expect(records.single.receipt.payload['reasonKey'], 'reward.correct');
    expect(records.single.receipt.payload['xpDelta'], 12);
    expect(container.read(toastProvider), isEmpty);
  });
}

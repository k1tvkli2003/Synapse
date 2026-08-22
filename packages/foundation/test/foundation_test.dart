import 'package:synapse_foundation/synapse_foundation.dart';
import 'package:test/test.dart';

void main() {
  test('clock and IDs replay deterministically', () {
    final clock = MutableClock(DateTime.utc(2026, 7, 17, 12));
    final first = TimeOrderedIdSource(
      clock: clock,
      random: SeededRandomSource(42),
      prefix: 'cor',
    );
    final second = TimeOrderedIdSource(
      clock: MutableClock(DateTime.utc(2026, 7, 17, 12)),
      random: SeededRandomSource(42),
      prefix: 'cor',
    );

    expect(first.nextId(), second.nextId());
    expect(first.nextId(), second.nextId());
    clock.advance(const Duration(seconds: 1));
    expect(first.nextId(), isNot(second.nextId()));
  });

  test('finite ID sequence fails rather than reusing an ID', () {
    final ids = SequenceIdSource(const ['a']);
    expect(ids.nextId(), 'a');
    expect(ids.nextId, throwsStateError);
  });

  test('network monitor can model a deterministic offline boot', () async {
    const monitor = StaticNetworkMonitor(NetworkState.offline);
    expect(await monitor.current(), NetworkState.offline);
    expect(await monitor.changes.first, NetworkState.offline);
  });

  test('memory store copies structured values and clears exactly', () async {
    final source = <Object?>['one'];
    final store = MemoryKeyValueStore();
    await store.write('items', source);
    source.add('mutated');

    expect(await store.read('items'), const ['one']);
    await store.clear();
    expect(store.snapshot, isEmpty);
  });

  test('memory store rejects non-JSON-safe values', () async {
    expect(
      () => MemoryKeyValueStore().write('bad', DateTime.now()),
      throwsArgumentError,
    );
  });

  group('bootstrap state machine', () {
    test('runs the canonical stages in order', () async {
      final order = <BootstrapStage>[];
      final coordinator = BootstrapCoordinator(
        operations: [
          for (final stage in BootstrapStage.values)
            BootstrapOperation(
              stage: stage,
              action: () async => order.add(stage),
            ),
        ],
      );

      final result = await coordinator.start(online: true);

      expect(result.outcome, BootstrapOutcome.ready);
      expect(order, BootstrapStage.values);
      expect(result.stages.values, everyElement(BootstrapStageStatus.ready));
    });

    test('offline sync degrades without blocking locale and router', () async {
      final coordinator = BootstrapCoordinator(
        operations: [
          BootstrapOperation(stage: BootstrapStage.config, action: () async {}),
          BootstrapOperation(
            stage: BootstrapStage.sync,
            requiresNetwork: true,
            action: () async => fail('offline sync must not run'),
          ),
          BootstrapOperation(stage: BootstrapStage.locale, action: () async {}),
          BootstrapOperation(stage: BootstrapStage.router, action: () async {}),
        ],
      );

      final result = await coordinator.start(online: false);

      expect(result.outcome, BootstrapOutcome.degraded);
      expect(
        result.statusOf(BootstrapStage.sync),
        BootstrapStageStatus.skippedOffline,
      );
      expect(
        result.statusOf(BootstrapStage.router),
        BootstrapStageStatus.ready,
      );
    });

    test(
      'critical failure stops downstream and retry resumes at boundary',
      () async {
        var shouldFail = true;
        var configRuns = 0;
        var routerRuns = 0;
        final coordinator = BootstrapCoordinator(
          operations: [
            BootstrapOperation(
              stage: BootstrapStage.config,
              action: () async => configRuns += 1,
            ),
            BootstrapOperation(
              stage: BootstrapStage.localStore,
              action: () async {
                if (shouldFail) throw StateError('fixture failure');
              },
            ),
            BootstrapOperation(
              stage: BootstrapStage.router,
              action: () async => routerRuns += 1,
            ),
          ],
        );

        final failed = await coordinator.start(online: true);
        expect(failed.outcome, BootstrapOutcome.failed);
        expect(routerRuns, 0);
        expect(failed.failure?.errorType, 'StateError');

        shouldFail = false;
        final recovered = await coordinator.retry(online: true);
        expect(recovered.outcome, BootstrapOutcome.ready);
        expect(configRuns, 1);
        expect(routerRuns, 1);
      },
    );

    test(
      'optional failure degrades and still completes later stages',
      () async {
        var routerReady = false;
        final coordinator = BootstrapCoordinator(
          operations: [
            BootstrapOperation(
              stage: BootstrapStage.auth,
              critical: false,
              action: () async => throw StateError('optional failure'),
            ),
            BootstrapOperation(
              stage: BootstrapStage.router,
              action: () async => routerReady = true,
            ),
          ],
        );

        final result = await coordinator.start(online: true);

        expect(result.outcome, BootstrapOutcome.degraded);
        expect(
          result.statusOf(BootstrapStage.auth),
          BootstrapStageStatus.degraded,
        );
        expect(routerReady, isTrue);
      },
    );
  });
}

import 'package:synapse_foundation/synapse_foundation.dart';
import 'package:synapse_motion/synapse_motion.dart';
import 'package:test/test.dart';

void main() {
  late MutableClock clock;

  setUp(() {
    clock = MutableClock(DateTime.utc(2026, 7, 17, 12));
  });

  PresentationReceipt receipt({
    String id = 'receipt-1',
    String event = 'event-1',
    String sequence = 'reward.standard',
    MotionTier tier = MotionTier.standard,
    PresentationPriority priority = PresentationPriority.normal,
    bool celebratory = true,
    DateTime? expires,
  }) => PresentationReceipt(
    receiptId: id,
    sourceEventId: event,
    sequenceKey: sequence,
    tier: tier,
    priority: priority,
    celebratory: celebratory,
    occurredAtUtc: clock.nowUtc(),
    expiresAtUtc: expires,
    payload: const {'masteryDelta': 8, 'reasonKey': 'lesson.correct_first_try'},
  );

  test('duplicate source event and sequence cannot enqueue twice', () {
    final queue = PresentationQueue(clock: clock);
    final first = queue.enqueue(receipt());
    final duplicate = queue.enqueue(receipt(id: 'receipt-2'));

    expect(first.disposition, EnqueueDisposition.accepted);
    expect(duplicate.disposition, EnqueueDisposition.duplicate);
    expect(duplicate.record.receipt.receiptId, 'receipt-1');
    expect(queue.records, hasLength(1));
  });

  test('priority wins while equal priority preserves occurrence order', () {
    final queue = PresentationQueue(clock: clock);
    queue.enqueue(receipt(id: 'normal', event: 'normal'));
    clock.advance(const Duration(milliseconds: 1));
    queue.enqueue(
      receipt(
        id: 'critical',
        event: 'critical',
        priority: PresentationPriority.critical,
      ),
    );

    expect(queue.pending.first.receipt.receiptId, 'critical');
  });

  test('system reduced motion overrides a full preference', () {
    final decision = MotionPolicy.resolve(
      environment: const MotionEnvironment(systemReducedMotion: true),
      tier: MotionTier.showpiece,
      celebratory: true,
    );

    expect(decision.disposition, MotionDisposition.reduced);
    expect(decision.maxParticles, 0);
    expect(decision.allowShader, isFalse);
  });

  test('quiet clinical defers reward theater without consuming receipt', () {
    final queue = PresentationQueue(clock: clock);
    queue.enqueue(receipt());

    final clinical = queue.nextFor(
      const MotionEnvironment(surface: MotionSurface.clinical),
    );
    final study = queue.nextFor(const MotionEnvironment());

    expect(clinical, isNull);
    expect(study?.record.receipt.receiptId, 'receipt-1');
    expect(queue.pending, hasLength(1));
  });

  test(
    'off mode presents the final semantic state and acknowledges skipped',
    () {
      final queue = PresentationQueue(clock: clock)..enqueue(receipt());
      final selection = queue.nextFor(
        const MotionEnvironment(preference: MotionPreference.off),
      )!;

      expect(selection.decision.disposition, MotionDisposition.still);
      final terminal = queue.acknowledgeSelection(selection);
      expect(terminal.status, PresentationStatus.skipped);
      expect(terminal.receipt.payload['masteryDelta'], 8);
    },
  );

  test('interruption changes presentation status but never payload', () {
    final queue = PresentationQueue(clock: clock)..enqueue(receipt());
    queue.start('receipt-1');
    final terminal = queue.acknowledge(
      'receipt-1',
      PresentationStatus.interrupted,
    );

    expect(terminal.status, PresentationStatus.interrupted);
    expect(terminal.receipt.payload, {
      'masteryDelta': 8,
      'reasonKey': 'lesson.correct_first_try',
    });
  });

  test('expired receipts remain deduplicated and never present', () {
    final queue = PresentationQueue(clock: clock);
    final expired = receipt(
      expires: clock.nowUtc().add(const Duration(seconds: 1)),
    );
    clock.advance(const Duration(seconds: 1));

    expect(queue.enqueue(expired).disposition, EnqueueDisposition.expired);
    expect(queue.nextFor(const MotionEnvironment()), isNull);
    expect(
      queue.enqueue(receipt(id: 'later')).disposition,
      EnqueueDisposition.duplicate,
    );
  });

  test(
    'queue persists and restores terminal and pending receipts exactly',
    () async {
      final store = MemoryKeyValueStore();
      final repository = PresentationQueueRepository(store: store);
      final queue = PresentationQueue(clock: clock);
      queue.enqueue(receipt());
      queue.enqueue(receipt(id: 'receipt-2', event: 'event-2'));
      queue.acknowledge('receipt-1', PresentationStatus.reduced);
      await repository.save(queue);

      final restored = await repository.load(clock);

      expect(restored.records, hasLength(2));
      expect(
        restored.records
            .singleWhere((item) => item.receipt.receiptId == 'receipt-1')
            .status,
        PresentationStatus.reduced,
      );
      expect(restored.pending, hasLength(1));
      expect(restored.toJson(), queue.toJson());
    },
  );

  test(
    'a crash while playing restores as interrupted instead of replaying',
    () async {
      final store = MemoryKeyValueStore();
      final repository = PresentationQueueRepository(store: store);
      final queue = PresentationQueue(clock: clock)..enqueue(receipt());
      queue.start('receipt-1');
      await repository.save(queue);

      final restored = await repository.load(clock);

      expect(restored.records.single.status, PresentationStatus.interrupted);
      expect(restored.nextFor(const MotionEnvironment()), isNull);
    },
  );

  test('wire format uses stable names and rejects unknown schema versions', () {
    final encoded = receipt().toJson();

    expect(encoded['tier'], 'standard');
    expect(encoded['priority'], 'normal');
    expect(PresentationReceipt.fromJson(encoded).toJson(), encoded);
    expect(
      () => PresentationReceipt.fromJson({...encoded, 'schemaVersion': 2}),
      throwsFormatException,
    );
  });
}

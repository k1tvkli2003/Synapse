import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synapse_motion/synapse_motion.dart';
import 'package:synapse_observability/synapse_observability.dart';

import 'app_providers.dart';
import 'observability_providers.dart';

final class PresentationQueueState {
  const PresentationQueueState({required this.revision, required this.records});

  final int revision;
  final List<PresentationRecord> records;
}

class PresentationQueueController extends Notifier<PresentationQueueState> {
  static const _storageKey = 'motion_presentation_queue_v1';

  late PresentationQueue _queue;
  Future<void> _persistTail = Future<void>.value();

  @override
  PresentationQueueState build() {
    final store = ref.watch(sharedPreferencesProvider);
    final saved = store.readJson(_storageKey);
    try {
      _queue = saved == null
          ? PresentationQueue(clock: ref.read(clockProvider))
          : PresentationQueue.fromJson(
              clock: ref.read(clockProvider),
              json: saved,
            );
    } catch (error, stackTrace) {
      // Presentation state is optional. A corrupt or future snapshot must
      // never prevent access to medical learning or clinical references.
      _queue = PresentationQueue(clock: ref.read(clockProvider));
      unawaited(store.remove(_storageKey));
      unawaited(
        ref
            .read(structuredLoggerProvider)
            .emit(
              name: 'motion.queue.recovered',
              severity: LogSeverity.warning,
            ),
      );
      unawaited(
        ref
            .read(crashReporterProvider)
            .capture(error, stackTrace, fatal: false),
      );
    }
    return PresentationQueueState(revision: 0, records: _queue.records);
  }

  EnqueueResult enqueue(PresentationReceipt receipt) {
    final result = _queue.enqueue(receipt);
    _publish();
    return result;
  }

  PresentationSelection? nextFor(MotionEnvironment environment) =>
      _queue.nextFor(environment);

  void start(String receiptId) {
    _queue.start(receiptId);
    _publish();
  }

  void acknowledge(String receiptId, PresentationStatus terminalStatus) {
    _queue.acknowledge(receiptId, terminalStatus);
    _publish();
  }

  void acknowledgeSelection(PresentationSelection selection) {
    _queue.acknowledgeSelection(selection);
    _publish();
  }

  void _publish() {
    state = PresentationQueueState(
      revision: state.revision + 1,
      records: _queue.records,
    );
    final store = ref.read(sharedPreferencesProvider);
    final snapshot = _queue.toJson();
    final previous = _persistTail;
    _persistTail = () async {
      try {
        await previous;
      } catch (_) {
        // A failed earlier write is already reported below and must not block
        // a newer authoritative snapshot from replacing it.
      }
      try {
        await store.writeJson(_storageKey, snapshot);
      } catch (error, stackTrace) {
        await ref
            .read(crashReporterProvider)
            .capture(error, stackTrace, fatal: false);
      }
    }();
    unawaited(_persistTail);
  }

  Future<void> flushForTest() => _persistTail;
}

final presentationQueueProvider =
    NotifierProvider<PresentationQueueController, PresentationQueueState>(
      PresentationQueueController.new,
    );

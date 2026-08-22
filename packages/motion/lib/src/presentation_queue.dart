import 'package:synapse_foundation/synapse_foundation.dart';

import 'motion_policy.dart';
import 'presentation_receipt.dart';

enum EnqueueDisposition { accepted, duplicate, expired }

final class EnqueueResult {
  const EnqueueResult({required this.disposition, required this.record});

  final EnqueueDisposition disposition;
  final PresentationRecord record;
}

final class PresentationSelection {
  const PresentationSelection({required this.record, required this.decision});

  final PresentationRecord record;
  final MotionDecision decision;
}

final class PresentationQueue {
  PresentationQueue({required this.clock});

  static const currentSchemaVersion = 1;

  final Clock clock;
  final Map<String, PresentationRecord> _records = {};
  final Map<String, String> _deduplicationIndex = {};

  List<PresentationRecord> get records => List.unmodifiable(_orderedRecords());

  List<PresentationRecord> get pending => List.unmodifiable(
    _orderedRecords().where(
      (record) => record.status == PresentationStatus.queued,
    ),
  );

  EnqueueResult enqueue(PresentationReceipt receipt) {
    final existingId = _deduplicationIndex[receipt.deduplicationKey];
    if (existingId != null) {
      return EnqueueResult(
        disposition: EnqueueDisposition.duplicate,
        record: _records[existingId]!,
      );
    }
    if (_records.containsKey(receipt.receiptId)) {
      throw StateError(
        'Presentation receipt ID already exists: ${receipt.receiptId}',
      );
    }
    final now = clock.nowUtc();
    final status = receipt.isExpiredAt(now)
        ? PresentationStatus.expired
        : PresentationStatus.queued;
    final record = PresentationRecord(
      receipt: receipt,
      status: status,
      statusAtUtc: now,
    );
    _records[receipt.receiptId] = record;
    _deduplicationIndex[receipt.deduplicationKey] = receipt.receiptId;
    return EnqueueResult(
      disposition: status == PresentationStatus.expired
          ? EnqueueDisposition.expired
          : EnqueueDisposition.accepted,
      record: record,
    );
  }

  PresentationSelection? nextFor(MotionEnvironment environment) {
    _expirePending();
    for (final record in pending) {
      final decision = MotionPolicy.resolve(
        environment: environment,
        tier: record.receipt.tier,
        celebratory: record.receipt.celebratory,
      );
      if (decision.disposition != MotionDisposition.deferred) {
        return PresentationSelection(record: record, decision: decision);
      }
    }
    return null;
  }

  PresentationRecord start(String receiptId) {
    final record = _required(receiptId);
    if (record.status != PresentationStatus.queued) {
      throw StateError('Only a queued receipt can start: $receiptId');
    }
    return _replace(
      record.withStatus(PresentationStatus.playing, clock.nowUtc()),
    );
  }

  PresentationRecord acknowledge(
    String receiptId,
    PresentationStatus terminalStatus,
  ) {
    if (!terminalStatus.isTerminal) {
      throw ArgumentError.value(
        terminalStatus,
        'terminalStatus',
        'Acknowledgement must be terminal.',
      );
    }
    final record = _required(receiptId);
    if (record.status.isTerminal) return record;
    return _replace(record.withStatus(terminalStatus, clock.nowUtc()));
  }

  PresentationRecord acknowledgeSelection(PresentationSelection selection) =>
      acknowledge(
        selection.record.receipt.receiptId,
        MotionPolicy.terminalStatusFor(selection.decision),
      );

  Map<String, Object?> toJson() => {
    'schemaVersion': currentSchemaVersion,
    'records': _orderedRecords().map((record) => record.toJson()).toList(),
  };

  factory PresentationQueue.fromJson({
    required Clock clock,
    required Map<String, Object?> json,
  }) {
    if (json['schemaVersion'] != currentSchemaVersion) {
      throw FormatException(
        'Unsupported presentation queue schema: ${json['schemaVersion']}',
      );
    }
    final queue = PresentationQueue(clock: clock);
    final rawRecords = json['records'];
    if (rawRecords is! List) {
      throw const FormatException('Presentation queue records must be a list.');
    }
    for (final raw in rawRecords) {
      final record = PresentationRecord.fromJson(
        Map<String, Object?>.from(raw! as Map),
      );
      final receipt = record.receipt;
      if (queue._records.containsKey(receipt.receiptId) ||
          queue._deduplicationIndex.containsKey(receipt.deduplicationKey)) {
        throw const FormatException('Duplicate receipt in queue snapshot.');
      }
      final recovered = record.status == PresentationStatus.playing
          ? record.withStatus(PresentationStatus.interrupted, clock.nowUtc())
          : record;
      queue._records[receipt.receiptId] = recovered;
      queue._deduplicationIndex[receipt.deduplicationKey] = receipt.receiptId;
    }
    queue._expirePending();
    return queue;
  }

  List<PresentationRecord> _orderedRecords() {
    final values = _records.values.toList();
    values.sort((left, right) {
      final priority = right.receipt.priority.rank.compareTo(
        left.receipt.priority.rank,
      );
      if (priority != 0) return priority;
      final time = left.receipt.occurredAtUtc.compareTo(
        right.receipt.occurredAtUtc,
      );
      if (time != 0) return time;
      return left.receipt.receiptId.compareTo(right.receipt.receiptId);
    });
    return values;
  }

  void _expirePending() {
    final now = clock.nowUtc();
    for (final record in _records.values.toList()) {
      if (record.status == PresentationStatus.queued &&
          record.receipt.isExpiredAt(now)) {
        _replace(record.withStatus(PresentationStatus.expired, now));
      }
    }
  }

  PresentationRecord _required(String receiptId) {
    final record = _records[receiptId];
    if (record == null) {
      throw StateError('Unknown presentation receipt: $receiptId');
    }
    return record;
  }

  PresentationRecord _replace(PresentationRecord record) {
    _records[record.receipt.receiptId] = record;
    return record;
  }
}

final class PresentationQueueRepository {
  const PresentationQueueRepository({
    required this.store,
    this.storageKey = 'motion.presentation_queue.v1',
  });

  final KeyValueStore store;
  final String storageKey;

  Future<PresentationQueue> load(Clock clock) async {
    final raw = await store.read(storageKey);
    if (raw == null) return PresentationQueue(clock: clock);
    if (raw is! Map) {
      throw const FormatException('Stored presentation queue must be a map.');
    }
    return PresentationQueue.fromJson(
      clock: clock,
      json: Map<String, Object?>.from(raw),
    );
  }

  Future<void> save(PresentationQueue queue) =>
      store.write(storageKey, queue.toJson());

  Future<void> clear() => store.remove(storageKey);
}

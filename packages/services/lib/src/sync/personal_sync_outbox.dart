import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_foundation/synapse_foundation.dart';

import '../data_plane/encrypted_indexed_learner_record_store.dart';
import 'personal_sync_api.dart';
import 'personal_sync_crypto.dart';

final class PersonalSyncRunResult {
  const PersonalSyncRunResult({
    required this.pushed,
    required this.pulled,
    required this.nextSequence,
  });

  final int pushed;
  final int pulled;
  final int nextSequence;
}

abstract interface class PersonalSyncProjectionApplier {
  Future<void> apply(DecryptedPersonalSyncEvent event);
}

final class PersonalSyncOutboxRepository {
  PersonalSyncOutboxRepository({required this._records, required this._clock});

  static const outboxNamespace = 'sync.outbox';
  static const checkpointNamespace = 'sync.checkpoint';
  static const inboxReceiptNamespace = 'sync.inbox-receipt';
  static const checkpointRecordId = 'personal';

  final IndexedLearnerRecordStore _records;
  final Clock _clock;

  Future<EncryptedSyncEvent> enqueue(EncryptedSyncEvent event) async {
    final existing = await _records.read(
      namespace: outboxNamespace,
      recordId: event.id,
    );
    if (existing != null && !existing.tombstone) {
      return EncryptedSyncEvent.fromJson(existing.payload);
    }
    final saved = await _records.put(
      PrivateLearnerRecordDraft(
        namespace: outboxNamespace,
        recordId: event.id,
        scopeId: event.workspaceId,
        kind: personalSyncStorageKind(event.kind),
        updatedAt: event.clientCreatedAt,
        payload: event.toJson(),
      ),
      expectedRevision: existing?.revision,
    );
    return EncryptedSyncEvent.fromJson(saved.payload);
  }

  Future<List<EncryptedSyncEvent>> pending({int limit = 200}) async {
    final records = await _records.query(
      PrivateLearnerRecordQuery(namespace: outboxNamespace, limit: limit),
    );
    return List.unmodifiable(
      records.map((record) => EncryptedSyncEvent.fromJson(record.payload)),
    );
  }

  Future<void> acknowledge(Iterable<EncryptedSyncEvent> events) async {
    final mutations = <PrivateLearnerRecordMutation>[];
    for (final event in events) {
      final existing = await _records.read(
        namespace: outboxNamespace,
        recordId: event.id,
      );
      if (existing == null || existing.tombstone) continue;
      mutations.add(
        PrivateLearnerRecordMutation(
          draft: PrivateLearnerRecordDraft(
            namespace: outboxNamespace,
            recordId: existing.recordId,
            scopeId: existing.scopeId,
            kind: existing.kind,
            updatedAt: _clock.nowUtc(),
            payload: existing.payload,
            tombstone: true,
          ),
          expectedRevision: existing.revision,
        ),
      );
    }
    if (mutations.isNotEmpty) await _records.putBatch(mutations);
  }

  Future<SyncCheckpoint?> readCheckpoint(
    PersonalWorkspaceId workspaceId,
  ) async {
    final record = await _records.read(
      namespace: checkpointNamespace,
      recordId: checkpointRecordId,
    );
    if (record == null || record.tombstone) return null;
    final checkpoint = SyncCheckpoint.fromJson(record.payload);
    if (checkpoint.workspaceId != workspaceId) {
      throw const LearnerDataPlaneException(
        'sync_checkpoint_workspace_mismatch',
        'The personal sync checkpoint belongs to another workspace.',
      );
    }
    return checkpoint;
  }

  Future<void> markApplied({
    required EncryptedSyncEvent event,
    required int nextSequence,
  }) async {
    final sequence = event.serverSequence;
    if (sequence == null || nextSequence < sequence) {
      throw const LearnerDataPlaneException(
        'invalid_sync_checkpoint_sequence',
        'A pulled event requires a valid server sequence.',
      );
    }
    final receiptId = 'server-sequence-$sequence';
    final existingReceipt = await _records.read(
      namespace: inboxReceiptNamespace,
      recordId: receiptId,
    );
    final existingCheckpoint = await _records.read(
      namespace: checkpointNamespace,
      recordId: checkpointRecordId,
    );
    final now = _clock.nowUtc();
    final mutations = <PrivateLearnerRecordMutation>[
      if (existingReceipt == null)
        PrivateLearnerRecordMutation(
          draft: PrivateLearnerRecordDraft(
            namespace: inboxReceiptNamespace,
            recordId: receiptId,
            scopeId: event.workspaceId,
            kind: personalSyncStorageKind(event.kind),
            updatedAt: now,
            payload: {'eventId': event.id, 'serverSequence': sequence},
          ),
          expectedRevision: null,
        ),
      PrivateLearnerRecordMutation(
        draft: PrivateLearnerRecordDraft(
          namespace: checkpointNamespace,
          recordId: checkpointRecordId,
          scopeId: event.workspaceId,
          kind: 'server-sequence',
          updatedAt: now,
          payload: SyncCheckpoint(
            id: checkpointRecordId,
            workspaceId: event.workspaceId,
            serverSequence: nextSequence,
            updatedAt: now,
          ).toJson(),
        ),
        expectedRevision: existingCheckpoint?.revision,
      ),
    ];
    await _records.putBatch(mutations);
  }

  Future<bool> wasApplied(int serverSequence) async {
    final receipt = await _records.read(
      namespace: inboxReceiptNamespace,
      recordId: 'server-sequence-$serverSequence',
    );
    return receipt != null && !receipt.tombstone;
  }
}

/// Data-plane operational columns accept lowercase tokens only. The source
/// enum deliberately preserves readable Dart names such as `studyHistory`;
/// normalize those names at this local encrypted-storage boundary.
String personalSyncStorageKind(PersonalSyncEventKind kind) => kind.name
    .replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '_${match[0]!.toLowerCase()}',
    )
    .toLowerCase();

final class PersonalSyncCoordinator {
  PersonalSyncCoordinator({
    required this._gateway,
    required this._outbox,
    required this._cipher,
    required this._projections,
  });

  final PersonalSyncGateway _gateway;
  final PersonalSyncOutboxRepository _outbox;
  final PersonalSyncEnvelopeCipher _cipher;
  final PersonalSyncProjectionApplier _projections;

  Future<PersonalSyncRunResult> syncOnce({
    required String accessToken,
    required PersonalWorkspaceId workspaceId,
    int batchSize = 200,
  }) async {
    if (batchSize < 1 || batchSize > 500) {
      throw ArgumentError.value(batchSize, 'batchSize');
    }
    var pushed = 0;
    while (true) {
      final pending = await _outbox.pending(limit: batchSize);
      if (pending.isEmpty) break;
      final accepted = await _gateway.pushEvents(
        accessToken: accessToken,
        events: pending,
      );
      final pendingIds = pending.map((event) => event.id).toSet();
      final acceptedIds = accepted.map((event) => event.id).toSet();
      if (accepted.length != acceptedIds.length ||
          acceptedIds.isEmpty ||
          !acceptedIds.every(pendingIds.contains)) {
        throw const LearnerDataPlaneException(
          'invalid_sync_push_receipt',
          'The personal sync gateway returned an invalid push receipt.',
        );
      }
      await _outbox.acknowledge(accepted);
      pushed += accepted.length;
    }

    var checkpoint =
        (await _outbox.readCheckpoint(workspaceId))?.serverSequence ?? 0;
    var pulled = 0;
    while (true) {
      final page = await _gateway.pullEvents(
        accessToken: accessToken,
        afterSequence: checkpoint,
        limit: batchSize,
      );
      if (page.events.isEmpty) {
        checkpoint = page.nextSequence;
        break;
      }
      for (final envelope in page.events) {
        final sequence = envelope.serverSequence;
        if (sequence == null) {
          throw const LearnerDataPlaneException(
            'remote_sync_event_missing_sequence',
            'A remote sync event has no server ordering receipt.',
          );
        }
        if (!await _outbox.wasApplied(sequence)) {
          final clear = await _cipher.decrypt(envelope);
          await _projections.apply(clear);
          pulled += 1;
        }
        await _outbox.markApplied(event: envelope, nextSequence: sequence);
        checkpoint = sequence;
      }
      if (page.events.length < batchSize) break;
    }
    return PersonalSyncRunResult(
      pushed: pushed,
      pulled: pulled,
      nextSequence: checkpoint,
    );
  }
}

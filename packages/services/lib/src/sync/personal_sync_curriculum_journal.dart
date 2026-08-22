import 'dart:convert';

import 'package:crypto/crypto.dart' as hashes;
import 'package:synapse_core/synapse_core.dart';

import 'personal_sync_crypto.dart';
import 'personal_sync_outbox.dart';

/// The minimum identity required to journal a local learning mutation. The
/// journal never obtains an access token and never performs network I/O; it
/// remains safe to call directly in a local Academy checkpoint transaction.
final class PersonalSyncDeviceContext {
  PersonalSyncDeviceContext({required this.workspace, required this.device}) {
    if (workspace.id != device.workspaceId || !device.isActive) {
      throw ArgumentError(
        'A personal sync device must be active in its workspace.',
      );
    }
  }

  final PersonalWorkspace workspace;
  final TrustedDevice device;
}

/// Result of making local curriculum progress durable in the encrypted outbox.
final class PersonalCurriculumJournalReceipt {
  const PersonalCurriculumJournalReceipt({
    required this.progressEventId,
    required this.attemptEventCount,
    required this.historyEventCount,
  });

  final EncryptedSyncEventId progressEventId;
  final int attemptEventCount;
  final int historyEventCount;
}

/// Converts privacy-safe Academy checkpoint material into encrypted outbox
/// envelopes. Free-text teach-back content is deliberately absent: only opaque
/// choice outcomes and structured progress are eligible for multi-device sync.
///
/// It is intentionally additive. The existing local curriculum repository is
/// still authoritative for the active screen; sync subsequently pulls these
/// envelopes into a deterministic projection without blocking the lesson.
final class PersonalSyncCurriculumJournal {
  factory PersonalSyncCurriculumJournal({
    required Future<PersonalSyncDeviceContext?> Function() currentContext,
    required PersonalSyncEnvelopeCipher cipher,
    required PersonalSyncOutboxRepository outbox,
  }) => PersonalSyncCurriculumJournal._(
    currentContext,
    cipher,
    () async => outbox,
  );

  /// Defers creation of the encrypted Data Plane until the device is actually
  /// paired and allowed to sync. This prevents an unpaired Academy session
  /// from opening a database merely to decide that it should remain local.
  factory PersonalSyncCurriculumJournal.lazy({
    required Future<PersonalSyncDeviceContext?> Function() currentContext,
    required PersonalSyncEnvelopeCipher cipher,
    required Future<PersonalSyncOutboxRepository?> Function() outbox,
  }) => PersonalSyncCurriculumJournal._(currentContext, cipher, outbox);

  PersonalSyncCurriculumJournal._(
    this._currentContext,
    this._cipher,
    this._outbox,
  );

  final Future<PersonalSyncDeviceContext?> Function() _currentContext;
  final PersonalSyncEnvelopeCipher _cipher;
  final Future<PersonalSyncOutboxRepository?> Function() _outbox;

  /// Returns null while this device has no paired personal workspace. Local
  /// learning still completes normally; a later migration sweep can journal
  /// pre-pairing checkpoints without ever reopening or changing them.
  Future<PersonalCurriculumJournalReceipt?> recordCheckpoint(
    CurriculumSessionProgress progress,
  ) async {
    final context = await _currentContext();
    if (context == null) return null;
    final outbox = await _outbox();
    if (outbox == null) return null;
    final attempts = progress.choiceResponses.values.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    for (final response in attempts) {
      await _enqueue(
        outbox: outbox,
        context: context,
        eventId: _opaqueId('evt', [
          'academy-attempt-v1',
          context.workspace.id,
          response.id,
        ]),
        idempotencyKey: _opaqueId('idem', [
          'academy-attempt-v1',
          context.workspace.id,
          response.id,
        ]),
        stream: 'academy.attempt',
        entityId: 'attempt:${response.id}',
        kind: PersonalSyncEventKind.attempt,
        mergePolicy: PersonalSyncMergePolicy.appendOnly,
        logicalRevision: 1,
        clientCreatedAt: response.answeredAt,
        payload: {
          'releaseId': progress.key.releaseId,
          'microLessonNodeId': progress.key.microLessonNodeId,
          'sessionId': progress.key.sessionId,
          'responseId': response.id,
          'interactionId': response.interactionId,
          'selectedOptionId': response.selectedOptionId,
          'isCorrect': response.isCorrect,
          'answeredAt': response.answeredAt.toUtc().toIso8601String(),
        },
      );
    }

    var historyEventCount = 0;
    final completionReceiptId = progress.completionReceiptId;
    final completedAt = progress.completedAt;
    if (progress.isCompleted &&
        completionReceiptId != null &&
        completedAt != null) {
      historyEventCount = 1;
      await _enqueue(
        outbox: outbox,
        context: context,
        eventId: _opaqueId('evt', [
          'academy-history-v1',
          context.workspace.id,
          completionReceiptId,
        ]),
        idempotencyKey: _opaqueId('idem', [
          'academy-history-v1',
          context.workspace.id,
          completionReceiptId,
        ]),
        stream: 'academy.history',
        entityId: 'completion:$completionReceiptId',
        kind: PersonalSyncEventKind.studyHistory,
        mergePolicy: PersonalSyncMergePolicy.appendOnly,
        logicalRevision: 1,
        clientCreatedAt: completedAt,
        payload: {
          'releaseId': progress.key.releaseId,
          'microLessonNodeId': progress.key.microLessonNodeId,
          'sessionId': progress.key.sessionId,
          'completedAt': completedAt.toUtc().toIso8601String(),
          'completionReceiptId': completionReceiptId,
        },
      );
    }

    final progressEventId = _opaqueId('evt', [
      'academy-progress-v1',
      context.workspace.id,
      context.device.id,
      progress.key.stableId,
      '${progress.revision}',
    ]);
    await _enqueue(
      outbox: outbox,
      context: context,
      eventId: progressEventId,
      idempotencyKey: _opaqueId('idem', [
        'academy-progress-v1',
        context.workspace.id,
        context.device.id,
        progress.key.stableId,
        '${progress.revision}',
      ]),
      stream: 'academy.progress',
      entityId: 'session:${progress.key.stableId}',
      kind: PersonalSyncEventKind.progress,
      mergePolicy: PersonalSyncMergePolicy.monotonicMaximum,
      logicalRevision: progress.revision,
      clientCreatedAt: progress.updatedAt,
      payload: {
        'releaseId': progress.key.releaseId,
        'microLessonNodeId': progress.key.microLessonNodeId,
        'sessionId': progress.key.sessionId,
        'interactionIndex': progress.interactionIndex,
        'choiceResponseCount': progress.choiceResponses.length,
        'completed': progress.isCompleted,
        'startedAt': progress.startedAt.toUtc().toIso8601String(),
        'completedAt': progress.completedAt?.toUtc().toIso8601String(),
        'completionReceiptId': completionReceiptId,
      },
    );
    return PersonalCurriculumJournalReceipt(
      progressEventId: progressEventId,
      attemptEventCount: attempts.length,
      historyEventCount: historyEventCount,
    );
  }

  Future<void> _enqueue({
    required PersonalSyncOutboxRepository outbox,
    required PersonalSyncDeviceContext context,
    required String eventId,
    required String idempotencyKey,
    required String stream,
    required String entityId,
    required PersonalSyncEventKind kind,
    required PersonalSyncMergePolicy mergePolicy,
    required int logicalRevision,
    required DateTime clientCreatedAt,
    required Map<String, Object?> payload,
  }) async {
    final encrypted = await _cipher.encrypt(
      PersonalSyncClearEvent(
        id: eventId,
        workspaceId: context.workspace.id,
        deviceId: context.device.id,
        stream: stream,
        entityId: entityId,
        kind: kind,
        mergePolicy: mergePolicy,
        logicalRevision: logicalRevision,
        idempotencyKey: idempotencyKey,
        clientCreatedAt: clientCreatedAt,
        payload: payload,
      ),
    );
    await outbox.enqueue(encrypted);
  }
}

String _opaqueId(String prefix, List<String> components) {
  final joined = components.join('\u0000');
  final digest = hashes.sha256.convert(utf8.encode(joined)).toString();
  // Prefixes preserve debugging ergonomics while the semantic IDs remain
  // opaque metadata at the gateway. 48 hex characters provides 192 bits.
  return '${prefix}_${digest.substring(0, 48)}';
}

import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_foundation/synapse_foundation.dart';
import 'package:synapse_services/synapse_services.dart';
import 'package:test/test.dart';

import 'support/curriculum_session_progress_v1_fixture.dart';

void main() {
  late MemoryKeyValueStore store;
  late MutableClock clock;
  late CurriculumSessionProgressKey key;
  late LocalCurriculumSessionProgressRepository repository;

  setUp(() {
    store = MemoryKeyValueStore();
    clock = MutableClock(DateTime.utc(2026, 7, 17, 12));
    key = CurriculumSessionProgressKey(
      releaseId: 'release.preview.001',
      microLessonNodeId: 'node.preview.001',
      sessionId: 'session.preview.001',
    );
    repository = _repository(store, clock, [
      'choice-event.001',
      'complete.001',
    ]);
  });

  test(
    'persists a release-bound choice checkpoint across repository restart',
    () async {
      final opened = await repository.open(key: key, interactionIndex: 0);
      expect(opened.revision, 1);

      final selected = await repository.selectOption(
        key: key,
        interactionIndex: 0,
        selectedOptionId: 'option.preview.a',
        expectedRevision: opened.revision,
      );
      expect(selected.selectedOptionId, 'option.preview.a');
      expect(selected.revision, 2);

      final answered = await repository.recordChoice(
        key: key,
        interactionIndex: 0,
        interactionId: 'interaction.preview.001',
        selectedOptionId: 'option.preview.a',
        isCorrect: true,
        expectedRevision: selected.revision,
      );
      expect(
        answered.responseFor('interaction.preview.001')?.id,
        'choice-event.001',
      );
      expect(answered.isCompleted, isFalse);

      final restarted = _repository(store, clock, ['unused.001']);
      final restored = await restarted.read(key);
      expect(restored, answered);
      expect(restored!.key.releaseId, 'release.preview.001');
      expect(restored.choiceResponses, hasLength(1));
    },
  );

  test(
    'serializes advancing and completion without client-side rewards',
    () async {
      final opened = await repository.open(key: key, interactionIndex: 0);
      final selected = await repository.selectOption(
        key: key,
        interactionIndex: 0,
        selectedOptionId: 'option.preview.a',
        expectedRevision: opened.revision,
      );
      final answered = await repository.recordChoice(
        key: key,
        interactionIndex: 0,
        interactionId: 'interaction.preview.001',
        selectedOptionId: 'option.preview.a',
        isCorrect: true,
        expectedRevision: selected.revision,
      );
      clock.advance(const Duration(seconds: 5));
      final advanced = await repository.advance(
        key: key,
        interactionIndex: 0,
        nextInteractionIndex: 1,
        expectedRevision: answered.revision,
        requiresRecordedChoiceForInteractionId: 'interaction.preview.001',
      );
      expect(advanced.interactionIndex, 1);
      expect(advanced.selectedOptionId, isNull);

      final complete = await repository.complete(
        key: key,
        interactionIndex: 1,
        expectedRevision: advanced.revision,
      );
      expect(complete.isCompleted, isTrue);
      expect(complete.completionReceiptId, 'complete.001');
      expect(complete.choiceResponses, hasLength(1));

      final duplicate = await repository.complete(
        key: key,
        interactionIndex: 1,
        expectedRevision: 1,
      );
      expect(duplicate, complete);
      expect(duplicate.completionReceiptId, 'complete.001');
    },
  );

  test(
    'rejects stale writes and a changed choice after a response is recorded',
    () async {
      final opened = await repository.open(key: key, interactionIndex: 0);
      final selected = await repository.selectOption(
        key: key,
        interactionIndex: 0,
        selectedOptionId: 'option.preview.a',
        expectedRevision: opened.revision,
      );

      await expectLater(
        repository.selectOption(
          key: key,
          interactionIndex: 0,
          selectedOptionId: 'option.preview.b',
          expectedRevision: opened.revision,
        ),
        throwsA(
          isA<CurriculumProgressException>().having(
            (error) => error.code,
            'code',
            'stale_progress_revision',
          ),
        ),
      );

      final answered = await repository.recordChoice(
        key: key,
        interactionIndex: 0,
        interactionId: 'interaction.preview.001',
        selectedOptionId: 'option.preview.a',
        isCorrect: true,
        expectedRevision: selected.revision,
      );
      await expectLater(
        repository.recordChoice(
          key: key,
          interactionIndex: 0,
          interactionId: 'interaction.preview.001',
          selectedOptionId: 'option.preview.a',
          isCorrect: false,
          expectedRevision: answered.revision,
        ),
        throwsA(
          isA<CurriculumProgressException>().having(
            (error) => error.code,
            'code',
            'choice_already_recorded',
          ),
        ),
      );
    },
  );

  test(
    'merges an encrypted-sync replica without overwriting a newer local checkpoint',
    () async {
      final opened = await repository.open(key: key, interactionIndex: 0);
      final selected = await repository.selectOption(
        key: key,
        interactionIndex: 0,
        selectedOptionId: 'option.preview.a',
        expectedRevision: opened.revision,
      );
      final answered = await repository.recordChoice(
        key: key,
        interactionIndex: 0,
        interactionId: 'interaction.preview.001',
        selectedOptionId: 'option.preview.a',
        isCorrect: true,
        expectedRevision: selected.revision,
      );
      final advanced = await repository.advance(
        key: key,
        interactionIndex: 0,
        nextInteractionIndex: 1,
        expectedRevision: answered.revision,
      );
      final replica = CurriculumSessionProgress(
        key: key,
        phase: CurriculumSessionProgressPhase.inProgress,
        interactionIndex: 3,
        revision: 7,
        startedAt: DateTime.utc(2026, 7, 17, 11, 58),
        updatedAt: DateTime.utc(2026, 7, 17, 12, 5),
        choiceResponses: {
          'interaction.preview.002': CurriculumChoiceResponse(
            id: 'choice-event.remote.002',
            interactionId: 'interaction.preview.002',
            selectedOptionId: 'option.preview.b',
            isCorrect: false,
            answeredAt: DateTime.utc(2026, 7, 17, 12, 4),
          ),
        },
      );

      final merged = await repository.mergeExternalReplica(replica);
      final replayed = await repository.mergeExternalReplica(replica);

      expect(merged.interactionIndex, 3);
      expect(merged.revision, 7);
      expect(merged.startedAt, DateTime.utc(2026, 7, 17, 11, 58));
      expect(merged.selectedOptionId, isNull);
      expect(
        merged.choiceResponses.keys,
        containsAll(<String>[
          'interaction.preview.001',
          'interaction.preview.002',
        ]),
      );
      expect(replayed, merged);
    },
  );

  test(
    'converges conflicting replicas and keeps completion monotonic',
    () async {
      final first = _repository(MemoryKeyValueStore(), clock, const []);
      final second = _repository(MemoryKeyValueStore(), clock, const []);
      final earlier = CurriculumSessionProgress(
        key: key,
        phase: CurriculumSessionProgressPhase.completed,
        interactionIndex: 4,
        revision: 8,
        startedAt: DateTime.utc(2026, 7, 17, 11),
        updatedAt: DateTime.utc(2026, 7, 17, 12, 10),
        choiceResponses: {
          'interaction.preview.001': CurriculumChoiceResponse(
            id: 'choice-event.remote.a',
            interactionId: 'interaction.preview.001',
            selectedOptionId: 'option.preview.a',
            isCorrect: true,
            answeredAt: DateTime.utc(2026, 7, 17, 12, 2),
          ),
        },
        completedAt: DateTime.utc(2026, 7, 17, 12, 9),
        completionReceiptId: 'complete.remote.a',
      );
      final laterConflict = CurriculumSessionProgress(
        key: key,
        phase: CurriculumSessionProgressPhase.inProgress,
        interactionIndex: 5,
        revision: 9,
        startedAt: DateTime.utc(2026, 7, 17, 11, 30),
        updatedAt: DateTime.utc(2026, 7, 17, 12, 12),
        choiceResponses: {
          'interaction.preview.001': CurriculumChoiceResponse(
            id: 'choice-event.remote.b',
            interactionId: 'interaction.preview.001',
            selectedOptionId: 'option.preview.c',
            isCorrect: false,
            answeredAt: DateTime.utc(2026, 7, 17, 12, 3),
          ),
        },
      );

      final left = await first.mergeExternalReplica(earlier);
      final leftConverged = await first.mergeExternalReplica(laterConflict);
      final right = await second.mergeExternalReplica(laterConflict);
      final rightConverged = await second.mergeExternalReplica(earlier);

      expect(left.isCompleted, isTrue);
      expect(right.isCompleted, isFalse);
      expect(leftConverged.isCompleted, isTrue);
      expect(rightConverged.isCompleted, isTrue);
      expect(leftConverged, rightConverged);
      expect(leftConverged.interactionIndex, 5);
      expect(
        leftConverged.responseFor('interaction.preview.001')?.id,
        'choice-event.remote.b',
      );
      expect(leftConverged.completionReceiptId, 'complete.remote.a');
    },
  );

  test(
    'rejects a replica that tries to sync a pending option selection',
    () async {
      final unsafeReplica = CurriculumSessionProgress(
        key: key,
        phase: CurriculumSessionProgressPhase.inProgress,
        interactionIndex: 0,
        revision: 1,
        startedAt: DateTime.utc(2026, 7, 17, 12),
        updatedAt: DateTime.utc(2026, 7, 17, 12),
        selectedOptionId: 'option.preview.a',
      );

      await expectLater(
        repository.mergeExternalReplica(unsafeReplica),
        throwsA(
          isA<CurriculumProgressException>().having(
            (error) => error.code,
            'code',
            'invalid_external_progress_replica',
          ),
        ),
      );
    },
  );

  test(
    'round-trips a v1 rollback snapshot through a lossless v2 migration',
    () async {
      final opened = await repository.open(key: key, interactionIndex: 0);
      final selected = await repository.selectOption(
        key: key,
        interactionIndex: 0,
        selectedOptionId: 'option.preview.a',
        expectedRevision: opened.revision,
      );
      final answered = await repository.recordChoice(
        key: key,
        interactionIndex: 0,
        interactionId: 'interaction.preview.001',
        selectedOptionId: 'option.preview.a',
        isCorrect: true,
        expectedRevision: selected.revision,
      );
      final completed = await repository.complete(
        key: key,
        interactionIndex: 0,
        expectedRevision: answered.revision,
        requiresRecordedChoiceForInteractionId: 'interaction.preview.001',
      );

      final rollback = await repository.createRollbackSnapshot(
        targetSchemaVersion:
            LocalCurriculumSessionProgressRepository.rollbackSchemaVersion,
      );
      expect(rollback['schemaVersion'], 1);
      expect(rollback, isNot(contains('integrity')));

      final migratedStore = MemoryKeyValueStore({
        LocalCurriculumSessionProgressRepository.stateKey: rollback,
      });
      final migratedRepository = _repository(migratedStore, clock, [
        'unused.001',
      ]);
      final receipt = await migratedRepository.migrateToCurrentSchema();
      expect(receipt.sourceSchemaVersion, 1);
      expect(receipt.targetSchemaVersion, 2);
      expect(receipt.recordCount, 1);
      expect(receipt.migrated, isTrue);

      final stored = Map<String, Object?>.from(
        migratedStore.snapshot[LocalCurriculumSessionProgressRepository
                .stateKey]
            as Map,
      );
      expect(stored['schemaVersion'], 2);
      expect(Map<String, Object?>.from(stored['integrity']! as Map), {
        'recordCount': 1,
        'choiceReceiptCount': 1,
        'completionReceiptCount': 1,
      });
      expect(await migratedRepository.read(key), completed);

      final noOpReceipt = await migratedRepository.migrateToCurrentSchema();
      expect(noOpReceipt.sourceSchemaVersion, 2);
      expect(noOpReceipt.migrated, isFalse);
    },
  );

  test('migrates the frozen pre-v2 fixture without receipt drift', () async {
    final fixtureKey = CurriculumSessionProgressKey(
      releaseId: 'release.legacy.001',
      microLessonNodeId: 'node.legacy.001',
      sessionId: 'session.legacy.001',
    );
    final fixtureStore = MemoryKeyValueStore({
      LocalCurriculumSessionProgressRepository.stateKey:
          curriculumSessionProgressV1Fixture,
    });
    final fixtureRepository = _repository(fixtureStore, clock, ['unused.001']);

    final receipt = await fixtureRepository.migrateToCurrentSchema();
    final restored = await fixtureRepository.read(fixtureKey);

    expect(receipt.sourceSchemaVersion, 1);
    expect(receipt.targetSchemaVersion, 2);
    expect(receipt.recordCount, 1);
    expect(receipt.migrated, isTrue);
    expect(restored, isNotNull);
    expect(restored!.revision, 4);
    expect(restored.isCompleted, isTrue);
    expect(
      restored.responseFor('interaction.legacy.001')?.id,
      'choice-event.legacy.001',
    );
    expect(restored.completionReceiptId, 'complete.legacy.001');
  });

  test('failed migration leaves the original v1 snapshot untouched', () async {
    final opened = await repository.open(key: key, interactionIndex: 0);
    expect(opened.revision, 1);
    final rollback = await repository.createRollbackSnapshot(
      targetSchemaVersion:
          LocalCurriculumSessionProgressRepository.rollbackSchemaVersion,
    );
    final failingStore = _FailingWriteKeyValueStore({
      LocalCurriculumSessionProgressRepository.stateKey: rollback,
    });
    final failingRepository = LocalCurriculumSessionProgressRepository(
      store: failingStore,
      clock: clock,
      idSource: SequenceIdSource(const ['unused.001']),
    );

    await expectLater(
      failingRepository.migrateToCurrentSchema(),
      throwsA(isA<StateError>()),
    );
    final preserved = Map<String, Object?>.from(
      failingStore.snapshot[LocalCurriculumSessionProgressRepository.stateKey]
          as Map,
    );
    expect(preserved, rollback);
    expect(preserved['schemaVersion'], 1);
  });

  test(
    'rejects a tampered v2 integrity summary without resetting it',
    () async {
      await repository.open(key: key, interactionIndex: 0);
      final stored = Map<String, Object?>.from(
        store.snapshot[LocalCurriculumSessionProgressRepository.stateKey]
            as Map,
      );
      stored['integrity'] = {
        ...Map<String, Object?>.from(stored['integrity']! as Map),
        'recordCount': 99,
      };
      final corruptStore = MemoryKeyValueStore({
        LocalCurriculumSessionProgressRepository.stateKey: stored,
      });
      final corrupt = _repository(corruptStore, clock, ['unused.001']);

      final issues = await corrupt.auditIntegrity();
      expect(issues, hasLength(1));
      expect(issues.single.code, 'corrupt_progress_registry');
      await expectLater(
        corrupt.read(key),
        throwsA(
          isA<CurriculumProgressException>().having(
            (error) => error.code,
            'code',
            'corrupt_progress_registry',
          ),
        ),
      );
      expect(
        corruptStore.snapshot[LocalCurriculumSessionProgressRepository
            .stateKey],
        stored,
      );
    },
  );

  test('rejects globally duplicated receipts during v1 migration', () async {
    final opened = await repository.open(key: key, interactionIndex: 0);
    final selected = await repository.selectOption(
      key: key,
      interactionIndex: 0,
      selectedOptionId: 'option.preview.a',
      expectedRevision: opened.revision,
    );
    final answered = await repository.recordChoice(
      key: key,
      interactionIndex: 0,
      interactionId: 'interaction.preview.001',
      selectedOptionId: 'option.preview.a',
      isCorrect: true,
      expectedRevision: selected.revision,
    );
    await repository.complete(
      key: key,
      interactionIndex: 0,
      expectedRevision: answered.revision,
    );
    final rollback = await repository.createRollbackSnapshot(
      targetSchemaVersion:
          LocalCurriculumSessionProgressRepository.rollbackSchemaVersion,
    );
    final records = Map<String, Object?>.from(rollback['records']! as Map);
    final duplicateKey = CurriculumSessionProgressKey(
      releaseId: key.releaseId,
      microLessonNodeId: 'node.preview.002',
      sessionId: 'session.preview.002',
    );
    final duplicateRecord = Map<String, Object?>.from(
      records[key.stableId]! as Map,
    );
    duplicateRecord['key'] = duplicateKey.toJson();
    records[duplicateKey.stableId] = duplicateRecord;
    final duplicatedV1 = {...rollback, 'records': records};
    final duplicateStore = MemoryKeyValueStore({
      LocalCurriculumSessionProgressRepository.stateKey: duplicatedV1,
    });
    final duplicateRepository = _repository(duplicateStore, clock, [
      'unused.001',
    ]);

    await expectLater(
      duplicateRepository.migrateToCurrentSchema(),
      throwsA(
        isA<CurriculumProgressException>().having(
          (error) => error.code,
          'code',
          'duplicate_progress_receipt',
        ),
      ),
    );
    expect(
      duplicateStore.snapshot[LocalCurriculumSessionProgressRepository
          .stateKey],
      duplicatedV1,
    );
  });

  test('reports corrupt or future registries without resetting them', () async {
    final corruptStore = MemoryKeyValueStore({
      LocalCurriculumSessionProgressRepository.stateKey: {
        'schemaVersion': 99,
        'records': <String, Object?>{},
      },
    });
    final corrupt = _repository(corruptStore, clock, ['unused.001']);

    final issues = await corrupt.auditIntegrity();
    expect(issues, hasLength(1));
    expect(issues.single.code, 'unsupported_progress_schema');
    expect(
      () => corrupt.read(key),
      throwsA(isA<CurriculumProgressException>()),
    );
    expect(
      corruptStore.snapshot[LocalCurriculumSessionProgressRepository.stateKey],
      isNotNull,
    );
  });
}

LocalCurriculumSessionProgressRepository _repository(
  MemoryKeyValueStore store,
  MutableClock clock,
  Iterable<String> ids,
) => LocalCurriculumSessionProgressRepository(
  store: store,
  clock: clock,
  idSource: SequenceIdSource(ids),
);

final class _FailingWriteKeyValueStore implements KeyValueStore {
  _FailingWriteKeyValueStore(Map<String, Object> seed)
    : _delegate = MemoryKeyValueStore(seed);

  final MemoryKeyValueStore _delegate;

  Map<String, Object> get snapshot => _delegate.snapshot;

  @override
  Future<void> clear() => _delegate.clear();

  @override
  Future<Object?> read(String key) => _delegate.read(key);

  @override
  Future<void> remove(String key) => _delegate.remove(key);

  @override
  Future<void> write(String key, Object value) async {
    throw StateError('simulated atomic-write failure');
  }
}

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:synapse_foundation/synapse_foundation.dart';
import 'package:synapse_services/synapse_services.dart';
import 'package:test/test.dart';

void main() {
  late LearnerDataPlaneDatabase database;
  late MutableClock clock;
  late LearnerDataMigrationJournal journal;

  setUp(() {
    database = LearnerDataPlaneDatabase(NativeDatabase.memory());
    clock = MutableClock(DateTime.utc(2026, 7, 22, 20));
    journal = LearnerDataMigrationJournal(database: database, clock: clock);
  });

  tearDown(() => database.close());

  test('checkpoints and completes one crash-resumable migration', () async {
    final digest = LearnerDataMigrationJournal.snapshotDigest({
      'private': 'learner payload',
      'records': 2,
    });
    final started = await journal.begin(
      migrationId: 'resource-workspace-v1-to-indexed-v1',
      sourceKey: '__synapse_resource_workspace_v1',
      sourceSnapshotSha256: digest,
    );
    expect(started.state, LearnerDataMigrationState.running);
    expect(started.cursor, 0);

    clock.advance(const Duration(seconds: 1));
    final checkpoint = await journal.checkpoint(
      migrationId: started.migrationId,
      expectedCursor: 0,
      nextCursor: 2,
      importedCount: 2,
    );
    final restarted = LearnerDataMigrationJournal(
      database: database,
      clock: clock,
    );
    expect(await restarted.read(started.migrationId), checkpoint);

    clock.advance(const Duration(seconds: 1));
    final completed = await restarted.complete(
      migrationId: started.migrationId,
      expectedCursor: 2,
      importedCount: 2,
    );
    expect(completed.state, LearnerDataMigrationState.completed);
    expect(completed.completedAt, isNotNull);
    expect(await restarted.listRecoverable(), isEmpty);
  });

  test('rejects stale workers and monotonic checkpoint regression', () async {
    final started = await _begin(journal);
    await journal.checkpoint(
      migrationId: started.migrationId,
      expectedCursor: 0,
      nextCursor: 3,
      importedCount: 2,
    );

    await expectLater(
      journal.checkpoint(
        migrationId: started.migrationId,
        expectedCursor: 0,
        nextCursor: 4,
        importedCount: 3,
      ),
      throwsA(
        isA<LearnerDataMigrationJournalException>().having(
          (error) => error.code,
          'code',
          'stale_migration_cursor',
        ),
      ),
    );
    await expectLater(
      journal.checkpoint(
        migrationId: started.migrationId,
        expectedCursor: 3,
        nextCursor: 2,
        importedCount: 2,
      ),
      throwsA(
        isA<LearnerDataMigrationJournalException>().having(
          (error) => error.code,
          'code',
          'migration_checkpoint_regression',
        ),
      ),
    );
  });

  test('resumes failed work but refuses a changed source snapshot', () async {
    final started = await _begin(journal);
    final failed = await journal.fail(
      migrationId: started.migrationId,
      expectedCursor: 0,
      errorCode: 'indexed_write_interrupted',
    );
    expect(failed.state, LearnerDataMigrationState.failed);
    expect(await journal.listRecoverable(), [failed]);

    final resumed = await _begin(journal);
    expect(resumed.state, LearnerDataMigrationState.running);
    expect(resumed.errorCode, isNull);
    await expectLater(
      journal.begin(
        migrationId: started.migrationId,
        sourceKey: '__synapse_resource_workspace_v1',
        sourceSnapshotSha256: LearnerDataMigrationJournal.snapshotDigest({
          'changed': true,
        }),
      ),
      throwsA(
        isA<LearnerDataMigrationJournalException>().having(
          (error) => error.code,
          'code',
          'migration_source_snapshot_drift',
        ),
      ),
    );
  });

  test(
    'journal rows never contain source key or private snapshot values',
    () async {
      await journal.begin(
        migrationId: 'resource-reading-state-v1-to-indexed-v1',
        sourceKey: '__synapse_resource_document_reading_state_v1',
        sourceSnapshotSha256: LearnerDataMigrationJournal.snapshotDigest({
          'privateNote': 'never persist this content in the journal',
        }),
      );
      final row = await database
          .select(database.learnerDataMigrations)
          .getSingle();
      final serialized = row.toString();
      expect(
        serialized,
        isNot(contains('__synapse_resource_document_reading_state_v1')),
      );
      expect(serialized, isNot(contains('never persist this content')));
      expect(row.sourceKeyHash, hasLength(64));
      expect(row.sourceSnapshotSha256, hasLength(64));
    },
  );

  test('records rollback only after work has stopped', () async {
    final started = await _begin(journal);
    await expectLater(
      journal.markRolledBack(
        migrationId: started.migrationId,
        expectedCursor: 0,
      ),
      throwsA(
        isA<LearnerDataMigrationJournalException>().having(
          (error) => error.code,
          'code',
          'migration_still_running',
        ),
      ),
    );
    await journal.fail(
      migrationId: started.migrationId,
      expectedCursor: 0,
      errorCode: 'operator_requested_rollback',
    );
    final rolledBack = await journal.markRolledBack(
      migrationId: started.migrationId,
      expectedCursor: 0,
    );
    expect(rolledBack.state, LearnerDataMigrationState.rolledBack);
    expect(rolledBack.errorCode, isNull);
  });

  test('rejects internally inconsistent journal metadata', () async {
    final started = await _begin(journal);
    final row = await database
        .select(database.learnerDataMigrations)
        .getSingle();
    await database
        .update(database.learnerDataMigrations)
        .replace(
          row.copyWith(
            state: LearnerDataMigrationState.completed.name,
            completedAtMicros: const Value(null),
            importedCount: started.cursor + 1,
          ),
        );

    await expectLater(
      journal.read(started.migrationId),
      throwsA(
        isA<LearnerDataMigrationJournalException>().having(
          (error) => error.code,
          'code',
          'corrupt_migration_journal',
        ),
      ),
    );
  });
}

Future<LearnerDataMigrationCheckpoint> _begin(
  LearnerDataMigrationJournal journal,
) => journal.begin(
  migrationId: 'resource-workspace-v1-to-indexed-v1',
  sourceKey: '__synapse_resource_workspace_v1',
  sourceSnapshotSha256: LearnerDataMigrationJournal.snapshotDigest({
    'stable': true,
  }),
);

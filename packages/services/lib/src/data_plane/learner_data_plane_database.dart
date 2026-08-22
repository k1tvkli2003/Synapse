import 'package:drift/drift.dart';

part 'learner_data_plane_database.g.dart';

/// One encrypted learner-owned record.
///
/// Identifiers and scopes are represented only by keyed hashes. The cleartext
/// identifier, scope and JSON payload live inside the authenticated ciphertext.
@DataClassName('EncryptedLearnerRecordRow')
class EncryptedLearnerRecords extends Table {
  TextColumn get namespace => text().withLength(min: 1, max: 80)();

  TextColumn get recordIdHash => text().withLength(min: 64, max: 64)();

  TextColumn get scopeHash => text().withLength(min: 64, max: 64)();

  TextColumn get kind => text().withLength(min: 1, max: 80)();

  IntColumn get keyVersion => integer()();

  IntColumn get revision => integer()();

  BoolColumn get tombstone => boolean()();

  IntColumn get updatedAtMicros => integer()();

  BlobColumn get nonce => blob()();

  BlobColumn get cipherText => blob()();

  BlobColumn get authenticationMac => blob()();

  @override
  Set<Column<Object>> get primaryKey => {namespace, recordIdHash};
}

/// Privacy-safe crash/retry journal for one legacy-to-indexed migration.
///
/// Source values and learner payloads never enter this table. Digests and
/// counts let migration reconcile without exposing the source registry.
@DataClassName('LearnerDataMigrationRow')
class LearnerDataMigrations extends Table {
  TextColumn get migrationId => text().withLength(min: 1, max: 120)();

  TextColumn get sourceKeyHash => text().withLength(min: 64, max: 64)();

  TextColumn get sourceSnapshotSha256 => text().withLength(min: 64, max: 64)();

  TextColumn get state => text().withLength(min: 1, max: 32)();

  IntColumn get cursor => integer().withDefault(const Constant(0))();

  IntColumn get importedCount => integer().withDefault(const Constant(0))();

  IntColumn get startedAtMicros => integer()();

  IntColumn get updatedAtMicros => integer()();

  IntColumn get completedAtMicros => integer().nullable()();

  TextColumn get errorCode => text().withLength(min: 1, max: 80).nullable()();

  @override
  Set<Column<Object>> get primaryKey => {migrationId};
}

@DriftDatabase(tables: [EncryptedLearnerRecords, LearnerDataMigrations])
final class LearnerDataPlaneDatabase extends _$LearnerDataPlaneDatabase {
  LearnerDataPlaneDatabase(super.executor);

  static const currentSchemaVersion = 1;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA busy_timeout = 5000');
    },
    onCreate: (migrator) async {
      await migrator.createAll();
      await customStatement(
        'CREATE INDEX encrypted_learner_records_scope_idx '
        'ON encrypted_learner_records '
        '(namespace, scope_hash, kind, tombstone, updated_at_micros DESC)',
      );
      await customStatement(
        'CREATE INDEX encrypted_learner_records_kind_idx '
        'ON encrypted_learner_records '
        '(namespace, kind, tombstone, updated_at_micros DESC)',
      );
      await customStatement(
        'CREATE INDEX learner_data_migrations_state_idx '
        'ON learner_data_migrations (state, updated_at_micros DESC)',
      );
    },
  );
}

import 'dart:convert';

import 'package:crypto/crypto.dart' as hashes;
import 'package:drift/drift.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_foundation/synapse_foundation.dart';

import 'learner_data_plane_database.dart';

enum LearnerDataMigrationState { running, completed, failed, rolledBack }

final class LearnerDataMigrationCheckpoint {
  const LearnerDataMigrationCheckpoint({
    required this.migrationId,
    required this.sourceKeyHash,
    required this.sourceSnapshotSha256,
    required this.state,
    required this.cursor,
    required this.importedCount,
    required this.startedAt,
    required this.updatedAt,
    this.completedAt,
    this.errorCode,
  });

  final String migrationId;
  final String sourceKeyHash;
  final String sourceSnapshotSha256;
  final LearnerDataMigrationState state;
  final int cursor;
  final int importedCount;
  final DateTime startedAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final String? errorCode;

  bool get isTerminal =>
      state == LearnerDataMigrationState.completed ||
      state == LearnerDataMigrationState.rolledBack;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LearnerDataMigrationCheckpoint &&
          migrationId == other.migrationId &&
          sourceKeyHash == other.sourceKeyHash &&
          sourceSnapshotSha256 == other.sourceSnapshotSha256 &&
          state == other.state &&
          cursor == other.cursor &&
          importedCount == other.importedCount &&
          startedAt == other.startedAt &&
          updatedAt == other.updatedAt &&
          completedAt == other.completedAt &&
          errorCode == other.errorCode;

  @override
  int get hashCode => Object.hash(
    migrationId,
    sourceKeyHash,
    sourceSnapshotSha256,
    state,
    cursor,
    importedCount,
    startedAt,
    updatedAt,
    completedAt,
    errorCode,
  );
}

final class LearnerDataMigrationJournalException implements Exception {
  const LearnerDataMigrationJournalException(
    this.code,
    this.message, [
    this.cause,
  ]);

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'LearnerDataMigrationJournalException($code): $message';
}

/// Privacy-safe, transactional crash journal for legacy-to-indexed imports.
///
/// The journal stores only hashes, counts, cursors, state, and bounded error
/// codes. Source registry values and learner payloads remain outside this
/// metadata table.
final class LearnerDataMigrationJournal {
  LearnerDataMigrationJournal({
    required LearnerDataPlaneDatabase database,
    required Clock clock,
  }) : this._(database, clock);

  LearnerDataMigrationJournal._(this._database, this._clock);

  static final _migrationIdPattern = RegExp(r'^[a-z0-9][a-z0-9._-]{0,119}$');
  static final _errorCodePattern = RegExp(r'^[a-z0-9][a-z0-9._-]{0,79}$');
  static final _digestPattern = RegExp(r'^[0-9a-f]{64}$');

  final LearnerDataPlaneDatabase _database;
  final Clock _clock;

  static String sourceKeyHash(String sourceKey) {
    if (sourceKey.isEmpty) {
      throw const LearnerDataMigrationJournalException(
        'invalid_migration_source_key',
        'Migration source key must not be empty.',
      );
    }
    return hashes.sha256.convert(utf8.encode(sourceKey)).toString();
  }

  static String snapshotDigest(Object? snapshot) => hashes.sha256
      .convert(utf8.encode(CanonicalJson.encode(snapshot)))
      .toString();

  Future<LearnerDataMigrationCheckpoint?> read(String migrationId) async {
    _requireMigrationId(migrationId);
    final row =
        await (_database.select(_database.learnerDataMigrations)
              ..where((table) => table.migrationId.equals(migrationId)))
            .getSingleOrNull();
    return row == null ? null : _checkpoint(row);
  }

  Future<List<LearnerDataMigrationCheckpoint>> listRecoverable() async {
    final rows =
        await (_database.select(_database.learnerDataMigrations)
              ..where(
                (table) => table.state.isIn([
                  LearnerDataMigrationState.running.name,
                  LearnerDataMigrationState.failed.name,
                ]),
              )
              ..orderBy([
                (table) => OrderingTerm.desc(table.updatedAtMicros),
                (table) => OrderingTerm.asc(table.migrationId),
              ]))
            .get();
    return List.unmodifiable(rows.map(_checkpoint));
  }

  Future<LearnerDataMigrationCheckpoint> begin({
    required String migrationId,
    required String sourceKey,
    required String sourceSnapshotSha256,
  }) async {
    _requireMigrationId(migrationId);
    _requireDigest(sourceSnapshotSha256);
    final keyHash = sourceKeyHash(sourceKey);
    return _database.transaction(() async {
      final existing = await _readRow(migrationId);
      if (existing != null) {
        _requireSameSource(
          existing,
          sourceKeyHash: keyHash,
          sourceSnapshotSha256: sourceSnapshotSha256,
        );
        _checkpoint(existing);
        if (existing.state == LearnerDataMigrationState.failed.name) {
          final now = _clock.nowUtc();
          final resumed = existing.copyWith(
            state: LearnerDataMigrationState.running.name,
            updatedAtMicros: now.microsecondsSinceEpoch,
            errorCode: const Value(null),
          );
          await _database
              .update(_database.learnerDataMigrations)
              .replace(resumed);
          return _checkpoint(resumed);
        }
        return _checkpoint(existing);
      }
      final now = _clock.nowUtc();
      final row = LearnerDataMigrationRow(
        migrationId: migrationId,
        sourceKeyHash: keyHash,
        sourceSnapshotSha256: sourceSnapshotSha256,
        state: LearnerDataMigrationState.running.name,
        cursor: 0,
        importedCount: 0,
        startedAtMicros: now.microsecondsSinceEpoch,
        updatedAtMicros: now.microsecondsSinceEpoch,
        completedAtMicros: null,
        errorCode: null,
      );
      await _database.into(_database.learnerDataMigrations).insert(row);
      return _checkpoint(row);
    });
  }

  Future<LearnerDataMigrationCheckpoint> checkpoint({
    required String migrationId,
    required int expectedCursor,
    required int nextCursor,
    required int importedCount,
  }) => _transition(
    migrationId,
    expectedCursor: expectedCursor,
    update: (row, now) {
      if (row.state != LearnerDataMigrationState.running.name) {
        throw const LearnerDataMigrationJournalException(
          'migration_not_running',
          'Only a running migration can advance its checkpoint.',
        );
      }
      if (nextCursor < row.cursor || importedCount < row.importedCount) {
        throw const LearnerDataMigrationJournalException(
          'migration_checkpoint_regression',
          'Migration cursor and imported count must be monotonic.',
        );
      }
      return row.copyWith(
        cursor: nextCursor,
        importedCount: importedCount,
        updatedAtMicros: now.microsecondsSinceEpoch,
      );
    },
  );

  Future<LearnerDataMigrationCheckpoint> complete({
    required String migrationId,
    required int expectedCursor,
    required int importedCount,
  }) => _transition(
    migrationId,
    expectedCursor: expectedCursor,
    update: (row, now) {
      if (row.state == LearnerDataMigrationState.completed.name) return row;
      if (row.state != LearnerDataMigrationState.running.name) {
        throw const LearnerDataMigrationJournalException(
          'migration_not_running',
          'Only a running migration can complete.',
        );
      }
      if (importedCount < row.importedCount) {
        throw const LearnerDataMigrationJournalException(
          'migration_checkpoint_regression',
          'Migration imported count must be monotonic.',
        );
      }
      return row.copyWith(
        importedCount: importedCount,
        state: LearnerDataMigrationState.completed.name,
        updatedAtMicros: now.microsecondsSinceEpoch,
        completedAtMicros: Value(now.microsecondsSinceEpoch),
        errorCode: const Value(null),
      );
    },
  );

  Future<LearnerDataMigrationCheckpoint> fail({
    required String migrationId,
    required int expectedCursor,
    required String errorCode,
  }) {
    if (!_errorCodePattern.hasMatch(errorCode)) {
      throw const LearnerDataMigrationJournalException(
        'invalid_migration_error_code',
        'Migration error code must be a bounded privacy-safe token.',
      );
    }
    return _transition(
      migrationId,
      expectedCursor: expectedCursor,
      update: (row, now) {
        if (row.state != LearnerDataMigrationState.running.name) {
          throw const LearnerDataMigrationJournalException(
            'migration_not_running',
            'Only a running migration can record failure.',
          );
        }
        return row.copyWith(
          state: LearnerDataMigrationState.failed.name,
          updatedAtMicros: now.microsecondsSinceEpoch,
          errorCode: Value(errorCode),
        );
      },
    );
  }

  Future<LearnerDataMigrationCheckpoint> markRolledBack({
    required String migrationId,
    required int expectedCursor,
  }) => _transition(
    migrationId,
    expectedCursor: expectedCursor,
    update: (row, now) {
      if (row.state == LearnerDataMigrationState.rolledBack.name) return row;
      if (row.state == LearnerDataMigrationState.running.name) {
        throw const LearnerDataMigrationJournalException(
          'migration_still_running',
          'A running migration must stop before rollback is recorded.',
        );
      }
      return row.copyWith(
        state: LearnerDataMigrationState.rolledBack.name,
        updatedAtMicros: now.microsecondsSinceEpoch,
        completedAtMicros: Value(now.microsecondsSinceEpoch),
        errorCode: const Value(null),
      );
    },
  );

  Future<LearnerDataMigrationCheckpoint> _transition(
    String migrationId, {
    required int expectedCursor,
    required LearnerDataMigrationRow Function(
      LearnerDataMigrationRow row,
      DateTime now,
    )
    update,
  }) async {
    _requireMigrationId(migrationId);
    if (expectedCursor < 0) {
      throw const LearnerDataMigrationJournalException(
        'invalid_migration_cursor',
        'Migration cursor cannot be negative.',
      );
    }
    return _database.transaction(() async {
      final row = await _readRow(migrationId);
      if (row == null) {
        throw const LearnerDataMigrationJournalException(
          'migration_missing',
          'Migration journal entry does not exist.',
        );
      }
      _checkpoint(row);
      if (row.cursor != expectedCursor) {
        throw const LearnerDataMigrationJournalException(
          'stale_migration_cursor',
          'Migration checkpoint changed after this worker began.',
        );
      }
      final changed = update(row, _clock.nowUtc());
      if (identical(changed, row)) return _checkpoint(row);
      await _database.update(_database.learnerDataMigrations).replace(changed);
      return _checkpoint(changed);
    });
  }

  Future<LearnerDataMigrationRow?> _readRow(String migrationId) =>
      (_database.select(_database.learnerDataMigrations)
            ..where((table) => table.migrationId.equals(migrationId)))
          .getSingleOrNull();

  static void _requireSameSource(
    LearnerDataMigrationRow row, {
    required String sourceKeyHash,
    required String sourceSnapshotSha256,
  }) {
    if (row.sourceKeyHash != sourceKeyHash ||
        row.sourceSnapshotSha256 != sourceSnapshotSha256) {
      throw const LearnerDataMigrationJournalException(
        'migration_source_snapshot_drift',
        'Migration source changed after the journal was created.',
      );
    }
  }

  static void _requireMigrationId(String value) {
    if (!_migrationIdPattern.hasMatch(value)) {
      throw const LearnerDataMigrationJournalException(
        'invalid_migration_id',
        'Migration ID must be a bounded lowercase token.',
      );
    }
  }

  static void _requireDigest(String value) {
    if (!_digestPattern.hasMatch(value)) {
      throw const LearnerDataMigrationJournalException(
        'invalid_migration_snapshot_digest',
        'Migration snapshot digest must be lowercase SHA-256.',
      );
    }
  }
}

LearnerDataMigrationCheckpoint _checkpoint(LearnerDataMigrationRow row) {
  final state = LearnerDataMigrationState.values.where(
    (value) => value.name == row.state,
  );
  final parsedState = state.length == 1 ? state.single : null;
  final completedAtIsRequired =
      parsedState == LearnerDataMigrationState.completed ||
      parsedState == LearnerDataMigrationState.rolledBack;
  final errorIsRequired = parsedState == LearnerDataMigrationState.failed;
  final validErrorCode = row.errorCode == null
      ? !errorIsRequired
      : errorIsRequired &&
            RegExp(r'^[a-z0-9][a-z0-9._-]{0,79}$').hasMatch(row.errorCode!);
  if (parsedState == null ||
      !RegExp(r'^[a-z0-9][a-z0-9._-]{0,119}$').hasMatch(row.migrationId) ||
      !RegExp(r'^[0-9a-f]{64}$').hasMatch(row.sourceKeyHash) ||
      !RegExp(r'^[0-9a-f]{64}$').hasMatch(row.sourceSnapshotSha256) ||
      row.cursor < 0 ||
      row.importedCount < 0 ||
      row.importedCount > row.cursor ||
      row.startedAtMicros <= 0 ||
      row.updatedAtMicros < row.startedAtMicros ||
      (completedAtIsRequired != (row.completedAtMicros != null)) ||
      (row.completedAtMicros != null &&
          (row.completedAtMicros! < row.startedAtMicros ||
              row.completedAtMicros! > row.updatedAtMicros)) ||
      !validErrorCode) {
    throw const LearnerDataMigrationJournalException(
      'corrupt_migration_journal',
      'Migration journal row failed schema validation.',
    );
  }
  return LearnerDataMigrationCheckpoint(
    migrationId: row.migrationId,
    sourceKeyHash: row.sourceKeyHash,
    sourceSnapshotSha256: row.sourceSnapshotSha256,
    state: parsedState,
    cursor: row.cursor,
    importedCount: row.importedCount,
    startedAt: DateTime.fromMicrosecondsSinceEpoch(
      row.startedAtMicros,
      isUtc: true,
    ),
    updatedAt: DateTime.fromMicrosecondsSinceEpoch(
      row.updatedAtMicros,
      isUtc: true,
    ),
    completedAt: row.completedAtMicros == null
        ? null
        : DateTime.fromMicrosecondsSinceEpoch(
            row.completedAtMicros!,
            isUtc: true,
          ),
    errorCode: row.errorCode,
  );
}

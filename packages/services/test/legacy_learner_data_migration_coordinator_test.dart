import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_foundation/synapse_foundation.dart';
import 'package:synapse_services/synapse_services.dart';
import 'package:test/test.dart';

const _documentDigest =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _selectionDigest =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

void main() {
  late LearnerDataPlaneDatabase database;
  late MutableClock clock;
  late MemoryKeyValueStore legacyStore;
  late _MemoryKeyProvider keys;
  late EncryptedIndexedLearnerRecordStore records;

  setUp(() {
    database = LearnerDataPlaneDatabase(NativeDatabase.memory());
    clock = MutableClock(DateTime.utc(2026, 7, 22, 21));
    legacyStore = MemoryKeyValueStore();
    keys = _MemoryKeyProvider(_key(53));
    records = EncryptedIndexedLearnerRecordStore(
      database: database,
      keys: keys,
    );
  });

  tearDown(() => database.close());

  test(
    'migrates the exact workspace graph and retains the legacy rollback key',
    () async {
      final legacy = await _populatedLegacyWorkspace(legacyStore, clock);
      final before = await legacy.exportSnapshot();
      final runtime = _runtime(records, database, clock);

      final receipt = await runtime.coordinator.migrateWorkspace(legacy);
      final after = await runtime.workspace.exportSnapshot();

      expect(
        CanonicalJson.encode(after.toJson()),
        CanonicalJson.encode(before.toJson()),
      );
      expect(receipt.importedCount, before.recordCount);
      expect(receipt.legacySourceRetained, isTrue);
      expect(
        legacyStore.snapshot,
        contains(LocalResourceWorkspaceRepository.stateKey),
      );
      final journal = await runtime.journal.read(receipt.migrationId);
      expect(journal?.state, LearnerDataMigrationState.completed);
      expect(await runtime.workspace.auditIntegrity(), isEmpty);

      final rows = await database
          .select(database.encryptedLearnerRecords)
          .get();
      final serialized = rows.join('\n');
      expect(serialized, isNot(contains('private learner synthesis')));
      expect(serialized, isNot(contains('annotation.migrate.001')));
    },
  );

  test(
    'resumes an exact batch committed immediately before an interruption',
    () async {
      final legacy = await _populatedLegacyWorkspace(legacyStore, clock);
      final interrupting = _CommitThenFailOnceStore(records);
      final firstRuntime = _runtime(
        interrupting,
        database,
        clock,
        chunkSize: 1,
      );

      await expectLater(
        firstRuntime.coordinator.migrateWorkspace(legacy),
        throwsA(
          isA<LegacyLearnerDataMigrationException>().having(
            (error) => error.code,
            'code',
            'legacy_learner_data_migration_failed',
          ),
        ),
      );
      final failed = await firstRuntime.journal.read(
        LegacyLearnerDataMigrationCoordinator.workspaceMigrationId,
      );
      expect(failed?.state, LearnerDataMigrationState.failed);
      expect(failed?.cursor, 0);
      expect(
        await records.exportNamespace(
          IndexedResourceWorkspaceRepository.documentNamespace,
        ),
        hasLength(1),
      );

      final resumedRuntime = _runtime(records, database, clock, chunkSize: 1);
      final receipt = await resumedRuntime.coordinator.migrateWorkspace(legacy);
      expect(receipt.importedCount, 5);
      expect(await resumedRuntime.workspace.auditIntegrity(), isEmpty);
      expect(
        (await resumedRuntime.journal.read(receipt.migrationId))?.state,
        LearnerDataMigrationState.completed,
      );
    },
  );

  test(
    'migrates PDF reading state without rewards or source deletion',
    () async {
      final legacy = LocalResourceDocumentReadingStateRepository(
        store: legacyStore,
        clock: clock,
      );
      final document = _document();
      final saved = await legacy.savePosition(
        document: document,
        pageNumber: 42,
        pagePositionMillionths: 375000,
        expectedRevision: null,
      );
      final runtime = _runtime(records, database, clock);

      final receipt = await runtime.coordinator.migrateReadingState(legacy);

      expect(receipt.importedCount, 1);
      expect(await runtime.readingState.read(document.id), saved);
      expect(
        legacyStore.snapshot,
        contains(LocalResourceDocumentReadingStateRepository.stateKey),
      );
      expect(await runtime.readingState.auditIntegrity(), isEmpty);
    },
  );

  test(
    'a completed migration is idempotent and reconciled on every retry',
    () async {
      final legacy = await _populatedLegacyWorkspace(legacyStore, clock);
      final runtime = _runtime(records, database, clock);
      final first = await runtime.coordinator.migrateWorkspace(legacy);
      final second = await runtime.coordinator.migrateWorkspace(legacy);

      expect(second.migrationId, first.migrationId);
      expect(second.sourceSnapshotSha256, first.sourceSnapshotSha256);
      expect(second.importedCount, first.importedCount);
      expect(await runtime.workspace.auditIntegrity(), isEmpty);
    },
  );

  test(
    'explicit workspace rollback exports post-migration indexed writes',
    () async {
      final legacy = await _populatedLegacyWorkspace(legacyStore, clock);
      final runtime = _runtime(records, database, clock);
      await runtime.coordinator.migrateWorkspace(legacy);
      final postMigrationDocument = ResourceDocument(
        id: 'document.after.migration',
        displayName: 'Post-migration reference.pdf',
        mediaType: 'application/pdf',
        contentSha256:
            'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        byteLength: 16384,
        pageCount: 44,
        origin: ResourceDocumentOrigin.userImport,
        createdAt: clock.nowUtc().add(const Duration(minutes: 1)),
      );
      await runtime.workspace.registerDocument(postMigrationDocument);
      expect(await legacy.readDocument(postMigrationDocument.id), isNull);

      final receipt = await runtime.coordinator.prepareWorkspaceRollback(
        legacy,
      );

      expect(receipt.legacySourceRetained, isTrue);
      expect(
        await legacy.readDocument(postMigrationDocument.id),
        postMigrationDocument,
      );
      expect(
        CanonicalJson.encode((await legacy.exportSnapshot()).toJson()),
        CanonicalJson.encode(
          (await runtime.workspace.exportSnapshot()).toJson(),
        ),
      );
      expect(
        (await runtime.journal.read(receipt.migrationId))?.state,
        LearnerDataMigrationState.rolledBack,
      );
    },
  );

  test(
    'explicit reading rollback exports the latest indexed position',
    () async {
      final legacy = LocalResourceDocumentReadingStateRepository(
        store: legacyStore,
        clock: clock,
      );
      final document = _document();
      final initial = await legacy.savePosition(
        document: document,
        pageNumber: 7,
        pagePositionMillionths: 0,
        expectedRevision: null,
      );
      final runtime = _runtime(records, database, clock);
      await runtime.coordinator.migrateReadingState(legacy);
      clock.advance(const Duration(minutes: 1));
      final latest = await runtime.readingState.savePosition(
        document: document,
        pageNumber: 19,
        pagePositionMillionths: 500000,
        expectedRevision: initial.revision,
      );
      expect(await legacy.read(document.id), initial);

      final receipt = await runtime.coordinator.prepareReadingStateRollback(
        legacy,
      );

      expect(await legacy.read(document.id), latest);
      expect(
        (await runtime.journal.read(receipt.migrationId))?.state,
        LearnerDataMigrationState.rolledBack,
      );
    },
  );
}

Future<LocalResourceWorkspaceRepository> _populatedLegacyWorkspace(
  MemoryKeyValueStore store,
  MutableClock clock,
) async {
  final repository = LocalResourceWorkspaceRepository(
    store: store,
    clock: clock,
    idSource: SequenceIdSource(const ['annotation.migrate.001']),
  );
  final document = await repository.registerDocument(_document());
  final anchor = _textAnchor();
  await repository.addComment(
    anchor: anchor,
    locale: ContentLocale.en,
    body: 'private learner synthesis',
    color: ResourceArtifactColor.cyan,
    tagIds: const ['tag.migrate'],
  );
  await repository.setBookmarked(
    anchor: anchor,
    isBookmarked: true,
    color: ResourceArtifactColor.gold,
    label: 'Resume here',
  );
  await repository.setCrossReference(
    from: ResourceReference.curriculumNode(
      sourceId: 'source.harrison-sim',
      nodeId: 'node.cardiology.001',
    ),
    to: document.reference,
    kind: ResourceCrossReferenceKind.supportingDocument,
    isLinked: true,
  );
  return repository;
}

_MigrationRuntime _runtime(
  IndexedLearnerRecordStore records,
  LearnerDataPlaneDatabase database,
  MutableClock clock, {
  int chunkSize = 100,
}) {
  final journal = LearnerDataMigrationJournal(database: database, clock: clock);
  final workspace = IndexedResourceWorkspaceRepository(
    records: records,
    clock: clock,
    idSource: SequenceIdSource(const ['unused.migration.001']),
  );
  final readingState = IndexedResourceDocumentReadingStateRepository(
    records: records,
    clock: clock,
  );
  return _MigrationRuntime(
    journal: journal,
    workspace: workspace,
    readingState: readingState,
    coordinator: LegacyLearnerDataMigrationCoordinator(
      records: records,
      journal: journal,
      indexedWorkspace: workspace,
      indexedReadingState: readingState,
      chunkSize: chunkSize,
    ),
  );
}

final class _MigrationRuntime {
  const _MigrationRuntime({
    required this.journal,
    required this.workspace,
    required this.readingState,
    required this.coordinator,
  });

  final LearnerDataMigrationJournal journal;
  final IndexedResourceWorkspaceRepository workspace;
  final IndexedResourceDocumentReadingStateRepository readingState;
  final LegacyLearnerDataMigrationCoordinator coordinator;
}

ResourceDocument _document() => ResourceDocument(
  id: 'document.migrate.001',
  displayName: 'Cardiology migration reference.pdf',
  mediaType: 'application/pdf',
  contentSha256: _documentDigest,
  byteLength: 4096,
  pageCount: 120,
  origin: ResourceDocumentOrigin.userImport,
  createdAt: DateTime.utc(2026, 7, 22, 21),
);

DocumentTextRangeResourceAnchor _textAnchor() =>
    DocumentTextRangeResourceAnchor(
      resource: ResourceReference.document('document.migrate.001'),
      pageNumber: 3,
      startOffset: 20,
      endOffset: 48,
      selectedTextSha256: _selectionDigest,
    );

LearnerDataKey _key(int seed) => LearnerDataKey(
  version: 1,
  bytes: Uint8List.fromList(
    List<int>.generate(32, (index) => (seed + index * 17) & 0xff),
  ),
);

final class _MemoryKeyProvider implements LearnerDataKeyProvider {
  _MemoryKeyProvider(this.key);

  LearnerDataKey key;

  @override
  Future<LearnerDataKey> currentKey() async => key;

  @override
  Future<LearnerDataKey?> readKey(int version) async =>
      version == key.version ? key : null;
}

final class _CommitThenFailOnceStore implements IndexedLearnerRecordStore {
  _CommitThenFailOnceStore(this.delegate);

  final IndexedLearnerRecordStore delegate;
  bool _shouldFail = true;

  @override
  Future<int> deleteNamespace(String namespace) =>
      delegate.deleteNamespace(namespace);

  @override
  Future<List<PrivateLearnerRecord>> exportNamespace(String namespace) =>
      delegate.exportNamespace(namespace);

  @override
  Future<List<LearnerDataPlaneIntegrityIssue>> auditIntegrity() =>
      delegate.auditIntegrity();

  @override
  Future<PrivateLearnerRecord> put(
    PrivateLearnerRecordDraft draft, {
    required int? expectedRevision,
  }) => delegate.put(draft, expectedRevision: expectedRevision);

  @override
  Future<List<PrivateLearnerRecord>> putBatch(
    Iterable<PrivateLearnerRecordMutation> mutations,
  ) async {
    final result = await delegate.putBatch(mutations);
    if (_shouldFail) {
      _shouldFail = false;
      throw const LearnerDataPlaneException(
        'simulated_interruption',
        'Synthetic post-commit interruption.',
      );
    }
    return result;
  }

  @override
  Future<List<PrivateLearnerRecord>> query(PrivateLearnerRecordQuery query) =>
      delegate.query(query);

  @override
  Future<PrivateLearnerRecordPage> queryPage(PrivateLearnerRecordQuery query) =>
      delegate.queryPage(query);

  @override
  Future<PrivateLearnerRecord?> read({
    required String namespace,
    required String recordId,
  }) => delegate.read(namespace: namespace, recordId: recordId);
}

import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_foundation/synapse_foundation.dart';
import 'package:synapse_services/synapse_services.dart';
import 'package:test/test.dart';

const _digest =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  late LearnerDataPlaneDatabase database;
  late MutableClock clock;
  late MemoryKeyValueStore legacyStore;
  late EncryptedIndexedLearnerRecordStore records;

  setUp(() {
    database = LearnerDataPlaneDatabase(NativeDatabase.memory());
    clock = MutableClock(DateTime.utc(2026, 7, 22, 22));
    legacyStore = MemoryKeyValueStore();
    records = EncryptedIndexedLearnerRecordStore(
      database: database,
      keys: _MemoryKeyProvider(_key(67)),
    );
  });

  tearDown(() => database.close());

  test(
    'queues callers, migrates once, then writes only to indexed storage',
    () async {
      final legacy = LocalResourceWorkspaceRepository(
        store: legacyStore,
        clock: clock,
        idSource: SequenceIdSource(const ['legacy.annotation.001']),
      );
      final legacyDocument = await legacy.registerDocument(_document('legacy'));
      final indexed = IndexedResourceWorkspaceRepository(
        records: records,
        clock: clock,
        idSource: SequenceIdSource(const ['indexed.annotation.001']),
      );
      final journal = LearnerDataMigrationJournal(
        database: database,
        clock: clock,
      );
      final indexedReading = IndexedResourceDocumentReadingStateRepository(
        records: records,
        clock: clock,
      );
      final coordinator = LegacyLearnerDataMigrationCoordinator(
        records: records,
        journal: journal,
        indexedWorkspace: indexed,
        indexedReadingState: indexedReading,
      );
      var migrations = 0;
      final gateway = MigrationAwareResourceWorkspaceRepository(
        legacy: legacy,
        indexed: indexed,
        migrate: () async {
          migrations += 1;
          await coordinator.migrateWorkspace(legacy);
        },
      );

      final reads = await Future.wait([
        gateway.readDocument(legacyDocument.id),
        gateway.listDocuments().then((value) => value.single),
      ]);
      expect(reads, [legacyDocument, legacyDocument]);
      expect(migrations, 1);
      expect(
        (await gateway.activationStatus).mode,
        LearnerDataPlaneActivationMode.indexed,
      );

      final newDocument = _document('indexed');
      await gateway.registerDocument(newDocument);
      expect(await indexed.readDocument(newDocument.id), newDocument);
      expect(await legacy.readDocument(newDocument.id), isNull);
      expect(
        legacyStore.snapshot,
        contains(LocalResourceWorkspaceRepository.stateKey),
      );
    },
  );

  test(
    'falls back once to legacy without dual-writing when migration fails',
    () async {
      final legacy = LocalResourceWorkspaceRepository(
        store: legacyStore,
        clock: clock,
        idSource: SequenceIdSource(const ['legacy.annotation.001']),
      );
      final indexed = IndexedResourceWorkspaceRepository(
        records: records,
        clock: clock,
        idSource: SequenceIdSource(const ['indexed.annotation.001']),
      );
      var attempts = 0;
      final gateway = MigrationAwareResourceWorkspaceRepository(
        legacy: legacy,
        indexed: indexed,
        migrate: () async {
          attempts += 1;
          throw const LegacyLearnerDataMigrationException(
            'synthetic_migration_failure',
            'Synthetic privacy-safe failure.',
          );
        },
      );
      final document = _document('fallback');

      await gateway.registerDocument(document);
      expect(await gateway.readDocument(document.id), document);
      expect(await legacy.readDocument(document.id), document);
      expect(await indexed.readDocument(document.id), isNull);
      expect(attempts, 1);
      final status = await gateway.activationStatus;
      expect(status.mode, LearnerDataPlaneActivationMode.legacyFallback);
      expect(status.failureCode, 'synthetic_migration_failure');
    },
  );

  test(
    'reading-state gateway also preserves the one-way activation boundary',
    () async {
      final legacy = LocalResourceDocumentReadingStateRepository(
        store: legacyStore,
        clock: clock,
      );
      final indexed = IndexedResourceDocumentReadingStateRepository(
        records: records,
        clock: clock,
      );
      final document = _document('reading');
      final oldPosition = await legacy.savePosition(
        document: document,
        pageNumber: 4,
        pagePositionMillionths: 0,
        expectedRevision: null,
      );
      final gateway = MigrationAwareResourceDocumentReadingStateRepository(
        legacy: legacy,
        indexed: indexed,
        migrate: () async {
          final workspace = IndexedResourceWorkspaceRepository(
            records: records,
            clock: clock,
            idSource: SequenceIdSource(const ['unused.001']),
          );
          await LegacyLearnerDataMigrationCoordinator(
            records: records,
            journal: LearnerDataMigrationJournal(
              database: database,
              clock: clock,
            ),
            indexedWorkspace: workspace,
            indexedReadingState: indexed,
          ).migrateReadingState(legacy);
        },
      );

      expect(await gateway.read(document.id), oldPosition);
      clock.advance(const Duration(minutes: 1));
      final changed = await gateway.savePosition(
        document: document,
        pageNumber: 5,
        pagePositionMillionths: 0,
        expectedRevision: oldPosition.revision,
      );
      expect(await indexed.read(document.id), changed);
      expect(await legacy.read(document.id), oldPosition);
    },
  );
}

ResourceDocument _document(String suffix) => ResourceDocument(
  id: 'document.$suffix',
  displayName: '$suffix.pdf',
  mediaType: 'application/pdf',
  contentSha256: suffix == 'legacy'
      ? _digest
      : _digest.replaceRange(0, 1, suffix.codeUnitAt(0).isEven ? 'b' : 'c'),
  byteLength: 4096,
  pageCount: 12,
  origin: ResourceDocumentOrigin.userImport,
  createdAt: DateTime.utc(2026, 7, 22, 22),
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

import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synapse_app/state/app_providers.dart';
import 'package:synapse_app/state/curriculum_provider.dart';
import 'package:synapse_app/state/persistence.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_services/synapse_services.dart';

const _legacyDigest =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _indexedDigest =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

void main() {
  test(
    'production provider migrates once, retains rollback JSON, and activates indexed writes',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final persisted = PersistedStore(preferences);
      final legacyDocument = _document(
        id: 'document.legacy.provider',
        digest: _legacyDigest,
      );
      final legacySnapshot = ResourceWorkspaceSnapshot.fromRecords(
        documents: [legacyDocument],
        anchors: const [],
        annotations: const [],
        bookmarks: const [],
        crossReferences: const [],
      );
      await persisted.writeJson(
        LocalResourceWorkspaceRepository.stateKey,
        legacySnapshot.toJson(),
      );
      final database = LearnerDataPlaneDatabase(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(persisted),
          learnerDataPlaneDatabaseProvider.overrideWithValue(database),
          learnerDataKeyProvider.overrideWithValue(
            _MemoryKeyProvider(_key(79)),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await database.close();
      });

      final repository = container.read(resourceWorkspaceRepositoryProvider);
      expect(await repository.readDocument(legacyDocument.id), legacyDocument);
      final activation = await container.read(
        resourceWorkspaceDataPlaneStatusProvider.future,
      );
      expect(activation.mode, LearnerDataPlaneActivationMode.indexed);
      expect(activation.failureCode, isNull);

      final indexedDocument = _document(
        id: 'document.indexed.provider',
        digest: _indexedDigest,
      );
      await repository.registerDocument(indexedDocument);
      expect(
        await repository.readDocument(indexedDocument.id),
        indexedDocument,
      );
      final indexed = container.read(
        indexedResourceWorkspaceRepositoryProvider,
      );
      expect(await indexed.readDocument(indexedDocument.id), indexedDocument);

      final retained = preferences.getString(
        LocalResourceWorkspaceRepository.stateKey,
      );
      expect(retained, isNotNull);
      expect(retained, contains(legacyDocument.id));
      expect(retained, isNot(contains(indexedDocument.id)));
      final migration = await container
          .read(learnerDataMigrationJournalProvider)
          .read(LegacyLearnerDataMigrationCoordinator.workspaceMigrationId);
      expect(migration?.state, LearnerDataMigrationState.completed);
    },
  );
}

ResourceDocument _document({required String id, required String digest}) =>
    ResourceDocument(
      id: id,
      displayName: '$id.pdf',
      mediaType: 'application/pdf',
      contentSha256: digest,
      byteLength: 4096,
      pageCount: 12,
      origin: ResourceDocumentOrigin.userImport,
      createdAt: DateTime.utc(2026, 7, 23),
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

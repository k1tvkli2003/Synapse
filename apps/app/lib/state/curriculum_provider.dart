import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_foundation/synapse_foundation.dart';
import 'package:synapse_services/synapse_services.dart';

import '../data/learner_data/learner_data_plane.dart';
import '../data/learner_data/secure_learner_data_key_provider.dart';
import '../data/resource_documents/resource_document_blob_store.dart';
import '../data/resource_documents/resource_document_import_service.dart';
import 'app_providers.dart';
import 'persistence.dart';

/// The app-facing, local-first curriculum registry. It intentionally owns only
/// the curriculum key; clearing or repairing it can never erase user profile,
/// rewards, preferences, notes, or other Synapse data.
final curriculumRegistryStoreProvider = Provider<KeyValueStore>((ref) {
  return _CurriculumRegistryStore(
    ref.watch(sharedPreferencesProvider),
    allowedKey: LocalCurriculumPackageRepository.stateKey,
  );
});

/// Stores only the accepted private content-channel head and safe failure
/// receipts. It cannot read or clear the immutable package registry itself.
final personalContentChannelStoreProvider = Provider<KeyValueStore>((ref) {
  return _CurriculumRegistryStore(
    ref.watch(sharedPreferencesProvider),
    allowedKey: PersonalContentChannelStateRepository.stateKey,
  );
});

/// A public, source-scoped Ed25519 keyring for immutable internal curriculum
/// packages. No signing secret, Supabase credential, or remote policy is ever
/// accepted by Flutter. With no configured keyring, remote package activation
/// stays disabled while every existing local Academy surface remains usable.
final personalContentTrustVerifierProvider =
    Provider<CurriculumReleaseTrustVerifier?>((ref) {
      final raw = ref.watch(appConfigProvider).personalContentTrustAnchorsJson;
      if (raw.isEmpty) return null;
      return PinnedEd25519CurriculumReleaseTrustVerifier(
        anchors: _decodePersonalContentTrustAnchors(raw),
        clock: ref.watch(clockProvider),
      );
    });

/// Separate local-first scope for learner-owned session checkpoints. Package
/// recovery must never erase progress; progress recovery must never erase an
/// immutable reviewed package.
final curriculumProgressStoreProvider = Provider<KeyValueStore>((ref) {
  return _CurriculumRegistryStore(
    ref.watch(sharedPreferencesProvider),
    allowedKey: LocalCurriculumSessionProgressRepository.stateKey,
  );
});

/// Bounded learner-authored study material lives behind its own key and
/// repository. Repairing packages or session checkpoints can never erase
/// notes, bookmarks, or private focus totals.
final curriculumStudyWorkspaceStoreProvider = Provider<KeyValueStore>((ref) {
  return _CurriculumRegistryStore(
    ref.watch(sharedPreferencesProvider),
    allowedKey: LocalCurriculumStudyWorkspaceRepository.stateKey,
  );
});

/// Semantic Deep Study resume anchors own a separate additive key. An older
/// app can ignore this registry without rewriting Workspace v1 notes or
/// release-bound Session checkpoints.
final curriculumReadingStateStoreProvider = Provider<KeyValueStore>((ref) {
  return _CurriculumRegistryStore(
    ref.watch(sharedPreferencesProvider),
    allowedKey: LocalCurriculumReadingStateRepository.stateKey,
  );
});

/// Universal resource metadata, anchors, annotations, and bookmark tombstones
/// own an additive scope. Binary document bytes are intentionally outside this
/// adapter and will use the cross-platform content-addressed blob store.
final resourceWorkspaceStoreProvider = Provider<KeyValueStore>((ref) {
  return _CurriculumRegistryStore(
    ref.watch(sharedPreferencesProvider),
    allowedKey: LocalResourceWorkspaceRepository.stateKey,
  );
});

/// Reward-neutral PDF resume positions use a separate additive rollback key.
/// Clearing this scope cannot erase document bytes, metadata, annotations,
/// curriculum progress, notes, or any legacy Synapse capability.
final resourceDocumentReadingStateStoreProvider = Provider<KeyValueStore>((
  ref,
) {
  return _CurriculumRegistryStore(
    ref.watch(sharedPreferencesProvider),
    allowedKey: LocalResourceDocumentReadingStateRepository.stateKey,
  );
});

/// Indexed, encrypted learner-data foundation. The rollback-safe JSON keys are
/// retained; migration-aware gateways below activate this store only after a
/// journaled import and full reconciliation succeeds.
final learnerDataPlaneDatabaseProvider = Provider<LearnerDataPlaneDatabase>((
  ref,
) {
  final database = createLearnerDataPlaneDatabase();
  ref.onDispose(() => unawaited(database.close()));
  return database;
});

final learnerDataKeyProvider = Provider<LearnerDataKeyProvider>((ref) {
  return SecureLearnerDataKeyProvider(
    secureStore: const FlutterSecureStringStore(),
  );
});

final indexedLearnerRecordStoreProvider = Provider<IndexedLearnerRecordStore>((
  ref,
) {
  return EncryptedIndexedLearnerRecordStore(
    database: ref.watch(learnerDataPlaneDatabaseProvider),
    keys: ref.watch(learnerDataKeyProvider),
  );
});

final learnerDataMigrationJournalProvider =
    Provider<LearnerDataMigrationJournal>((ref) {
      return LearnerDataMigrationJournal(
        database: ref.watch(learnerDataPlaneDatabaseProvider),
        clock: ref.watch(clockProvider),
      );
    });

/// Immutable package authority for learner-visible curriculum releases.
final curriculumPackageRepositoryProvider =
    Provider<CurriculumPackageRepository>((ref) {
      return LocalCurriculumPackageRepository(
        store: ref.watch(curriculumRegistryStoreProvider),
        clock: ref.watch(clockProvider),
        idSource: ref.watch(operationalIdSourceProvider),
        releaseTrustVerifier: ref.watch(personalContentTrustVerifierProvider),
      );
    });

/// Rebuildable indexes over the immutable local package registry.
final curriculumCatalogRepositoryProvider =
    Provider<CurriculumCatalogRepository>((ref) {
      return PackageCurriculumCatalogRepository(
        packages: ref.watch(curriculumPackageRepositoryProvider),
      );
    });

/// Release-bound learner resume state. It owns no rewards, XP, or remote sync;
/// those remain separate authoritative systems behind a later outbox.
final curriculumSessionProgressRepositoryProvider =
    Provider<CurriculumSessionProgressRepository>((ref) {
      return LocalCurriculumSessionProgressRepository(
        store: ref.watch(curriculumProgressStoreProvider),
        clock: ref.watch(clockProvider),
        idSource: ref.watch(operationalIdSourceProvider),
      );
    });

final curriculumStudyWorkspaceRepositoryProvider =
    Provider<CurriculumStudyWorkspaceRepository>((ref) {
      return LocalCurriculumStudyWorkspaceRepository(
        store: ref.watch(curriculumStudyWorkspaceStoreProvider),
        clock: ref.watch(clockProvider),
        idSource: ref.watch(operationalIdSourceProvider),
      );
    });

final curriculumReadingStateRepositoryProvider =
    Provider<CurriculumReadingStateRepository>((ref) {
      return LocalCurriculumReadingStateRepository(
        store: ref.watch(curriculumReadingStateStoreProvider),
        clock: ref.watch(clockProvider),
      );
    });

final legacyResourceWorkspaceRepositoryProvider =
    Provider<LocalResourceWorkspaceRepository>((ref) {
      return LocalResourceWorkspaceRepository(
        store: ref.watch(resourceWorkspaceStoreProvider),
        clock: ref.watch(clockProvider),
        idSource: ref.watch(operationalIdSourceProvider),
      );
    });

final indexedResourceWorkspaceRepositoryProvider =
    Provider<IndexedResourceWorkspaceRepository>((ref) {
      return IndexedResourceWorkspaceRepository(
        records: ref.watch(indexedLearnerRecordStoreProvider),
        clock: ref.watch(clockProvider),
        idSource: ref.watch(operationalIdSourceProvider),
      );
    });

final legacyResourceDocumentReadingStateRepositoryProvider =
    Provider<LocalResourceDocumentReadingStateRepository>((ref) {
      return LocalResourceDocumentReadingStateRepository(
        store: ref.watch(resourceDocumentReadingStateStoreProvider),
        clock: ref.watch(clockProvider),
      );
    });

final indexedResourceDocumentReadingStateRepositoryProvider =
    Provider<IndexedResourceDocumentReadingStateRepository>((ref) {
      return IndexedResourceDocumentReadingStateRepository(
        records: ref.watch(indexedLearnerRecordStoreProvider),
        clock: ref.watch(clockProvider),
      );
    });

final legacyLearnerDataMigrationCoordinatorProvider =
    Provider<LegacyLearnerDataMigrationCoordinator>((ref) {
      return LegacyLearnerDataMigrationCoordinator(
        records: ref.watch(indexedLearnerRecordStoreProvider),
        journal: ref.watch(learnerDataMigrationJournalProvider),
        indexedWorkspace: ref.watch(indexedResourceWorkspaceRepositoryProvider),
        indexedReadingState: ref.watch(
          indexedResourceDocumentReadingStateRepositoryProvider,
        ),
      );
    });

/// Every call waits behind one migration attempt. Success activates only the
/// indexed repository; failure keeps the intact legacy authority for this app
/// process. There is no dual-write window and no legacy key deletion.
final resourceWorkspaceRepositoryProvider =
    Provider<ResourceWorkspaceRepository>((ref) {
      final legacy = ref.watch(legacyResourceWorkspaceRepositoryProvider);
      return MigrationAwareResourceWorkspaceRepository(
        legacy: legacy,
        indexed: ref.watch(indexedResourceWorkspaceRepositoryProvider),
        migrate: () async {
          await ref
              .read(legacyLearnerDataMigrationCoordinatorProvider)
              .migrateWorkspace(legacy);
        },
      );
    });

final resourceDocumentReadingStateRepositoryProvider =
    Provider<ResourceDocumentReadingStateRepository>((ref) {
      final legacy = ref.watch(
        legacyResourceDocumentReadingStateRepositoryProvider,
      );
      return MigrationAwareResourceDocumentReadingStateRepository(
        legacy: legacy,
        indexed: ref.watch(
          indexedResourceDocumentReadingStateRepositoryProvider,
        ),
        migrate: () async {
          await ref
              .read(legacyLearnerDataMigrationCoordinatorProvider)
              .migrateReadingState(legacy);
        },
      );
    });

final resourceWorkspaceDataPlaneStatusProvider = FutureProvider((ref) async {
  final repository = ref.watch(resourceWorkspaceRepositoryProvider);
  if (repository is MigrationAwareResourceWorkspaceRepository) {
    return repository.activationStatus;
  }
  return const LearnerDataPlaneActivationStatus(
    mode: LearnerDataPlaneActivationMode.legacyFallback,
    failureCode: 'non_migration_repository_override',
  );
});

final resourceReadingStateDataPlaneStatusProvider = FutureProvider((ref) async {
  final repository = ref.watch(resourceDocumentReadingStateRepositoryProvider);
  if (repository is MigrationAwareResourceDocumentReadingStateRepository) {
    return repository.activationStatus;
  }
  return const LearnerDataPlaneActivationStatus(
    mode: LearnerDataPlaneActivationMode.legacyFallback,
    failureCode: 'non_migration_repository_override',
  );
});

final resourceDocumentReadingPositionProvider = FutureProvider.autoDispose
    .family<ResourceDocumentReadingPosition?, ResourceDocumentId>((
      ref,
      documentId,
    ) {
      return ref
          .watch(resourceDocumentReadingStateRepositoryProvider)
          .read(documentId);
    });

/// One content-addressed PDF byte authority for this app process. The provider
/// resolves to native application-support storage or browser IndexedDB through
/// a conditional export; absolute native paths never enter app state.
final resourceDocumentBlobStoreProvider = Provider<ResourceDocumentBlobStore>((
  ref,
) {
  final store = createResourceDocumentBlobStore();
  ref.onDispose(() => unawaited(store.close()));
  return store;
});

final resourceDocumentImportServiceProvider =
    Provider<ResourceDocumentImportService>((ref) {
      return ResourceDocumentImportService(
        blobs: ref.watch(resourceDocumentBlobStoreProvider),
        metadata: ref.watch(resourceWorkspaceRepositoryProvider),
        clock: ref.watch(clockProvider),
        ids: ref.watch(operationalIdSourceProvider),
      );
    });

/// Immutable metadata projection. Missing metadata remains distinguishable
/// from a missing/corrupt blob and is handled truthfully by the reader.
final resourceDocumentProvider = FutureProvider.autoDispose
    .family<ResourceDocument?, ResourceDocumentId>((ref, documentId) {
      return ref
          .watch(resourceWorkspaceRepositoryProvider)
          .readDocument(documentId);
    });

/// Resolve only the PDFs explicitly attached to one resource context. This is
/// deliberately not `listDocuments()`: importing a cardiology reference must
/// never make it appear as evidence for every other lesson.
final contextualResourceDocumentsProvider = FutureProvider.autoDispose
    .family<List<ResourceDocument>, ResourceReference>((ref, context) async {
      final repository = ref.watch(resourceWorkspaceRepositoryProvider);
      final links = await repository.listCrossReferencesFrom(
        context,
        kind: ResourceCrossReferenceKind.supportingDocument,
      );
      final documents = <ResourceDocument>[];
      for (final link in links) {
        if (link.to.kind != ResourceReferenceKind.document) continue;
        final document = await repository.readDocument(link.to.resourceId);
        if (document != null) documents.add(document);
      }
      documents.sort((left, right) {
        final byTime = right.createdAt.compareTo(left.createdAt);
        return byTime != 0 ? byTime : right.id.compareTo(left.id);
      });
      return List.unmodifiable(documents);
    });

/// Ephemeral viewer source. A native path or browser byte array exists only
/// for the reader lifetime and is never copied into persisted provider state.
final resourceDocumentSourceProvider = FutureProvider.autoDispose
    .family<ResourceDocumentSource?, ResourceDocument>((ref, document) {
      return ref.watch(resourceDocumentBlobStoreProvider).resolve(document);
    });

/// Read-only bookmark projection; opening a lesson never creates an artifact.
final resourceBookmarkProvider = FutureProvider.autoDispose
    .family<ResourceBookmark?, ResourceAnchorId>((ref, anchorId) {
      return ref
          .watch(resourceWorkspaceRepositoryProvider)
          .readBookmark(anchorId);
    });

final resourceBookmarksForResourceProvider = FutureProvider.autoDispose
    .family<List<ResourceBookmark>, ResourceReference>((ref, resource) {
      return ref
          .watch(resourceWorkspaceRepositoryProvider)
          .listBookmarksForResource(resource);
    });

final resourceAnnotationsForResourceProvider = FutureProvider.autoDispose
    .family<List<ResourceAnnotation>, ResourceReference>((ref, resource) {
      return ref
          .watch(resourceWorkspaceRepositoryProvider)
          .listAnnotationsForResource(resource);
    });

final resourceAnchorsForResourceProvider = FutureProvider.autoDispose
    .family<List<ResourceAnchor>, ResourceReference>((ref, resource) {
      return ref
          .watch(resourceWorkspaceRepositoryProvider)
          .listAnchorsForResource(resource);
    });

/// Read-only projection; viewing a document never manufactures a saved place.
final curriculumReadingPositionProvider = FutureProvider.autoDispose
    .family<CurriculumReadingPosition?, CurriculumReadingPositionKey>((
      ref,
      key,
    ) {
      return ref.watch(curriculumReadingStateRepositoryProvider).read(key);
    });

typedef CurriculumStudyWorkspaceRequest = ({
  CurriculumStudyWorkspaceKey key,
  CurriculumReleaseId releaseId,
});

/// Opens the stable node workspace and records the active reviewed release as
/// provenance without binding learner notes to that release forever.
final curriculumStudyWorkspaceProvider =
    FutureProvider.family<
      CurriculumStudyWorkspace,
      CurriculumStudyWorkspaceRequest
    >((ref, request) {
      return ref
          .watch(curriculumStudyWorkspaceRepositoryProvider)
          .open(key: request.key, releaseId: request.releaseId);
    });

/// Opens a session checkpoint lazily and restores it on every later read.
/// The key contains the immutable package release, preventing a new release
/// from silently treating an old learner response as current content.
final curriculumSessionProgressProvider =
    FutureProvider.family<
      CurriculumSessionProgress,
      CurriculumSessionProgressKey
    >((ref, key) async {
      return ref
          .watch(curriculumSessionProgressRepositoryProvider)
          .open(key: key, interactionIndex: 0);
    });

/// Read-only release-bound checkpoint projection for contextual study gates.
///
/// Unlike [curriculumSessionProgressProvider], this never opens a Session or
/// creates learner progress merely because a reading surface was viewed.
final curriculumSessionProgressSnapshotProvider = FutureProvider.autoDispose
    .family<CurriculumSessionProgress?, CurriculumSessionProgressKey>((
      ref,
      key,
    ) {
      return ref.watch(curriculumSessionProgressRepositoryProvider).read(key);
    });

/// The only learner-facing bootstrap state. Screens render this result
/// truthfully instead of inferring that a missing/corrupt curriculum is a
/// network failure or silently substituting placeholder medical content.
final curriculumRuntimeProvider =
    FutureProvider<CurriculumRuntimeBootstrapResult>((ref) async {
      final packages = ref.watch(curriculumPackageRepositoryProvider);
      final catalogs = ref.watch(curriculumCatalogRepositoryProvider);
      return CurriculumRuntimeBootCoordinator(
        packages: packages,
        catalogs: catalogs,
      ).boot(CurriculumActivationTarget.learner);
    });

/// Scoped `KeyValueStore` adapter for the curriculum registry.
///
/// [KeyValueStore.clear] is deliberately narrowed to the one curriculum
/// registry key. The generic interface is shared with test stores, but this
/// production adapter must never clear unrelated learner data.
final class _CurriculumRegistryStore implements KeyValueStore {
  const _CurriculumRegistryStore(this._store, {required this.allowedKey});

  final PersistedStore _store;
  final String allowedKey;

  @override
  Future<Object?> read(String key) async {
    _requireAllowedKey(key);
    return _store.readJsonStrict(key);
  }

  @override
  Future<void> write(String key, Object value) async {
    _requireAllowedKey(key);
    if (value is! Map) {
      throw ArgumentError.value(value, 'value', 'Expected a JSON object.');
    }
    await _store.writeJson(key, Map<String, dynamic>.from(value));
  }

  @override
  Future<void> remove(String key) {
    _requireAllowedKey(key);
    return _store.remove(key);
  }

  @override
  Future<void> clear() => _store.remove(allowedKey);

  void _requireAllowedKey(String key) {
    if (key != allowedKey) {
      throw ArgumentError.value(
        key,
        'key',
        'This adapter may access only its declared curriculum key.',
      );
    }
  }
}

List<CurriculumReleaseTrustAnchor> _decodePersonalContentTrustAnchors(
  String raw,
) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List || decoded.isEmpty) {
      throw const FormatException('Expected a non-empty JSON anchor array.');
    }
    final keyIds = <String>{};
    return List<CurriculumReleaseTrustAnchor>.unmodifiable([
      for (final entry in decoded)
        _decodePersonalContentTrustAnchor(entry, knownKeyIds: keyIds),
    ]);
  } on FormatException {
    rethrow;
  } on Object catch (error) {
    throw FormatException('Invalid SYNAPSE_CONTENT_TRUST_ANCHORS_JSON: $error');
  }
}

CurriculumReleaseTrustAnchor _decodePersonalContentTrustAnchor(
  Object? value, {
  required Set<String> knownKeyIds,
}) {
  if (value is! Map) {
    throw const FormatException('Each content trust anchor must be an object.');
  }
  final map = Map<String, Object?>.from(value);
  final keyId = _anchorString(map, 'keyId');
  if (!knownKeyIds.add(keyId)) {
    throw FormatException('Duplicate content trust keyId $keyId.');
  }
  final sourceIds = map['allowedSourceIds'];
  if (sourceIds is! List || sourceIds.isEmpty) {
    throw const FormatException(
      'A content trust anchor requires allowedSourceIds.',
    );
  }
  final validFrom = _anchorDate(map, 'validFrom');
  final validUntilRaw = map['validUntil'];
  final validUntil = validUntilRaw == null
      ? null
      : _parseAnchorDate(validUntilRaw, 'validUntil');
  final revoked = map['revoked'] ?? false;
  if (revoked is! bool) {
    throw const FormatException('Content trust revoked must be boolean.');
  }
  return CurriculumReleaseTrustAnchor(
    keyId: keyId,
    publicKeyBytes: _decodePublicEd25519Key(_anchorString(map, 'publicKey')),
    allowedSourceIds: [
      for (final source in sourceIds)
        if (source is String &&
            source.trim().isNotEmpty &&
            source == source.trim())
          source
        else
          throw const FormatException(
            'Content trust allowedSourceIds must contain stable strings.',
          ),
    ],
    // Personal mode recognizes only the non-public internal channel. Future
    // beta/stable support must be an explicit signed-policy design change.
    allowedChannels: const [CurriculumReleaseChannel.internal],
    validFrom: validFrom,
    validUntil: validUntil,
    revoked: revoked,
  );
}

String _anchorString(Map<String, Object?> map, String field) {
  final value = map[field];
  if (value is! String || value.trim().isEmpty || value != value.trim()) {
    throw FormatException('Content trust $field must be a non-empty string.');
  }
  return value;
}

DateTime _anchorDate(Map<String, Object?> map, String field) =>
    _parseAnchorDate(map[field], field);

DateTime _parseAnchorDate(Object? value, String field) {
  if (value is! String || !value.endsWith('Z')) {
    throw FormatException('Content trust $field must be a UTC timestamp.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('Content trust $field is invalid.');
  }
  return parsed.toUtc();
}

List<int> _decodePublicEd25519Key(String raw) {
  if (raw.contains('=') || !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(raw)) {
    throw const FormatException(
      'Content trust publicKey must be canonical unpadded base64url.',
    );
  }
  try {
    final padded = raw.padRight((raw.length + 3) ~/ 4 * 4, '=');
    final bytes = base64Url.decode(padded);
    if (bytes.length != 32 ||
        base64Url.encode(bytes).replaceAll('=', '') != raw) {
      throw const FormatException('Content trust publicKey is not canonical.');
    }
    return List<int>.unmodifiable(bytes);
  } on FormatException {
    rethrow;
  } on Object catch (error) {
    throw FormatException('Content trust publicKey is invalid: $error');
  }
}

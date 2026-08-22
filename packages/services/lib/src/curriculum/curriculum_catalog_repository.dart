import 'dart:async';

import 'package:synapse_core/synapse_core.dart';

import 'curriculum_catalog_models.dart';
import 'curriculum_package_models.dart';
import 'curriculum_package_repository.dart';

abstract interface class CurriculumCatalogRepository {
  Future<CurriculumCatalogSnapshot?> activeCatalog(
    CurriculumActivationTarget target,
  );

  Future<CurriculumCatalogSnapshot> catalogForRelease(
    CurriculumReleaseId releaseId,
  );

  CurriculumCatalogCacheStatus get cacheStatus;

  bool evictRelease(CurriculumReleaseId releaseId);

  void clearMemoryCache();
}

/// Rebuildable, bounded in-memory indexes over immutable installed manifests.
///
/// The package repository remains the offline authority. Cache eviction never
/// removes packages, progress, activation receipts, or user data.
final class PackageCurriculumCatalogRepository
    implements CurriculumCatalogRepository {
  factory PackageCurriculumCatalogRepository({
    required CurriculumPackageRepository packages,
    int maxCachedReleases = 3,
    int maxCachedNodes = 50000,
  }) {
    if (maxCachedReleases < 1) {
      throw ArgumentError.value(maxCachedReleases, 'maxCachedReleases');
    }
    if (maxCachedNodes < 1) {
      throw ArgumentError.value(maxCachedNodes, 'maxCachedNodes');
    }
    return PackageCurriculumCatalogRepository._(
      packages,
      maxCachedReleases,
      maxCachedNodes,
    );
  }

  PackageCurriculumCatalogRepository._(
    this._packages,
    this.maxCachedReleases,
    this.maxCachedNodes,
  );

  final CurriculumPackageRepository _packages;
  final int maxCachedReleases;
  final int maxCachedNodes;
  final Map<CurriculumReleaseId, CurriculumCatalogSnapshot> _cache = {};
  final Map<CurriculumReleaseId, Future<CurriculumCatalogSnapshot>> _inFlight =
      {};
  final Map<CurriculumReleaseId, String> _observedCanonicalHashes = {};
  final Map<CurriculumReleaseId, int> _releaseGenerations = {};
  final Map<CurriculumReleaseId, int> _lastEvictionSequence = {};
  int _cachedNodeCount = 0;
  int _hitCount = 0;
  int _missCount = 0;
  int _evictionCount = 0;
  int _oversizedBypassCount = 0;
  int _invalidatedBuildCount = 0;
  int _clearGeneration = 0;
  int _evictionSequence = 0;
  int _activeLookupCount = 0;

  @override
  Future<CurriculumCatalogSnapshot?> activeCatalog(
    CurriculumActivationTarget target,
  ) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final lookupClearGeneration = _clearGeneration;
      final lookupEvictionSequence = _evictionSequence;
      final releaseId = await _trackedActiveReleaseId(target);
      if (releaseId == null) return null;
      final invalidatedDuringLookup =
          lookupClearGeneration != _clearGeneration ||
          (_lastEvictionSequence[releaseId] ?? 0) > lookupEvictionSequence;
      final snapshot = await _catalogForRelease(
        releaseId,
        forceInvalidatedBuild: invalidatedDuringLookup,
      );
      final currentReleaseId = await _trackedActiveReleaseId(target);
      if (currentReleaseId == releaseId) return snapshot;
      if (currentReleaseId == null) return null;
    }
    throw CurriculumCatalogException(
      'active_release_changed_during_load',
      'The active curriculum release changed repeatedly during catalog load.',
    );
  }

  @override
  Future<CurriculumCatalogSnapshot> catalogForRelease(
    CurriculumReleaseId releaseId,
  ) => _catalogForRelease(releaseId);

  Future<CurriculumCatalogSnapshot> _catalogForRelease(
    CurriculumReleaseId releaseId, {
    bool forceInvalidatedBuild = false,
  }) {
    final inFlight = _inFlight[releaseId];
    if (inFlight != null) return inFlight;
    final buildClearGeneration = forceInvalidatedBuild
        ? _clearGeneration - 1
        : _clearGeneration;
    final buildReleaseGeneration = forceInvalidatedBuild
        ? _releaseGeneration(releaseId) - 1
        : _releaseGeneration(releaseId);
    late final Future<CurriculumCatalogSnapshot> pending;
    pending =
        _loadRelease(
          releaseId,
          buildClearGeneration: buildClearGeneration,
          buildReleaseGeneration: buildReleaseGeneration,
        ).whenComplete(() {
          if (identical(_inFlight[releaseId], pending)) {
            _inFlight.remove(releaseId);
          }
        });
    _inFlight[releaseId] = pending;
    return pending;
  }

  Future<CurriculumReleaseId?> _trackedActiveReleaseId(
    CurriculumActivationTarget target,
  ) async {
    _activeLookupCount += 1;
    try {
      return await _packages.activeReleaseId(target);
    } finally {
      _activeLookupCount -= 1;
    }
  }

  Future<CurriculumCatalogSnapshot> _loadRelease(
    CurriculumReleaseId releaseId, {
    required int buildClearGeneration,
    required int buildReleaseGeneration,
  }) async {
    final manifest = await _packages.loadRelease(releaseId);
    if (manifest == null) {
      throw CurriculumCatalogException(
        'release_not_installed',
        'Curriculum release $releaseId is not installed.',
      );
    }
    return _snapshot(
      manifest,
      buildClearGeneration: buildClearGeneration,
      buildReleaseGeneration: buildReleaseGeneration,
    );
  }

  @override
  CurriculumCatalogCacheStatus get cacheStatus => CurriculumCatalogCacheStatus(
    releaseIdsLeastRecentFirst: List.unmodifiable(_cache.keys),
    totalNodeCount: _cachedNodeCount,
    hitCount: _hitCount,
    missCount: _missCount,
    evictionCount: _evictionCount,
    oversizedBypassCount: _oversizedBypassCount,
    invalidatedBuildCount: _invalidatedBuildCount,
    inFlightBuildCount: _inFlight.length,
    activeLookupCount: _activeLookupCount,
  );

  @override
  bool evictRelease(CurriculumReleaseId releaseId) {
    final removed = _cache.remove(releaseId);
    final hadInFlight = _inFlight.containsKey(releaseId);
    final hadPotentialActiveLookup = _activeLookupCount > 0;
    if (removed == null && !hadInFlight && !hadPotentialActiveLookup) {
      return false;
    }
    _releaseGenerations[releaseId] = _releaseGeneration(releaseId) + 1;
    _evictionSequence += 1;
    _lastEvictionSequence[releaseId] = _evictionSequence;
    if (removed != null) _cachedNodeCount -= removed.nodeCount;
    return true;
  }

  @override
  void clearMemoryCache() {
    _clearGeneration += 1;
    _cache.clear();
    _cachedNodeCount = 0;
  }

  CurriculumCatalogSnapshot _snapshot(
    CurriculumManifest manifest, {
    required int buildClearGeneration,
    required int buildReleaseGeneration,
  }) {
    final releaseId = manifest.release.id;
    final canonicalSha256 = manifest.canonicalSha256;
    final observedSha256 = _observedCanonicalHashes[releaseId];
    if (observedSha256 != null && observedSha256 != canonicalSha256) {
      throw CurriculumCatalogException(
        'immutable_release_drift',
        'Curriculum release $releaseId changed after its identity was observed.',
      );
    }
    _observedCanonicalHashes[releaseId] = canonicalSha256;
    if (buildClearGeneration != _clearGeneration ||
        buildReleaseGeneration != _releaseGeneration(releaseId)) {
      _invalidatedBuildCount += 1;
      return CurriculumCatalogSnapshot.fromManifest(manifest);
    }
    final cached = _cache.remove(releaseId);
    if (cached != null) {
      if (cached.canonicalSha256 != canonicalSha256) {
        throw CurriculumCatalogException(
          'immutable_release_drift',
          'Cached curriculum release $releaseId changed immutable identity.',
        );
      }
      _cache[releaseId] = cached;
      _hitCount += 1;
      return cached;
    }
    _missCount += 1;
    final snapshot = CurriculumCatalogSnapshot.fromManifest(manifest);
    if (snapshot.nodeCount > maxCachedNodes) {
      _oversizedBypassCount += 1;
      return snapshot;
    }
    while (_cache.isNotEmpty &&
        (_cache.length >= maxCachedReleases ||
            _cachedNodeCount + snapshot.nodeCount > maxCachedNodes)) {
      final oldest = _cache.keys.first;
      final removed = _cache.remove(oldest)!;
      _cachedNodeCount -= removed.nodeCount;
      _evictionCount += 1;
    }
    _cache[releaseId] = snapshot;
    _cachedNodeCount += snapshot.nodeCount;
    return snapshot;
  }

  int _releaseGeneration(CurriculumReleaseId releaseId) =>
      _releaseGenerations[releaseId] ?? 0;
}

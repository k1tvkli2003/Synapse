import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_foundation/synapse_foundation.dart';

import 'curriculum_package_models.dart';
import 'curriculum_release_trust.dart';

abstract interface class CurriculumPackageRepository {
  /// Installs bytes that are already part of the signed application artifact.
  /// This is never the remote release-channel entrypoint.
  Future<CurriculumInstallResult> installBundledCandidate({
    required String candidateId,
    required String manifestJson,
    required String expectedCanonicalSha256,
    required String expectedTransportSha256,
  });

  /// Installs an externally delivered candidate only after pinned-key Ed25519
  /// verification of the exact source, release, channel, hashes, and lengths.
  Future<CurriculumInstallResult> installSignedCandidate({
    required String candidateId,
    required String manifestJson,
    required CurriculumSignedReleaseEnvelope envelope,
  });

  /// Installs one independently signed, chapter-sized fragment of an
  /// immutable release. Multiple chapter shards may share a release ID; their
  /// merged manifest is derived only after every stored shard re-validates.
  Future<CurriculumInstallResult> installSignedChapterShard({
    required String candidateId,
    required String manifestJson,
    required CurriculumSignedReleaseEnvelope envelope,
    required CurriculumChapterShard shard,
  });

  /// Replaces a corrupt or drifted installed body only through an explicit,
  /// trusted-hash path and persists a recovery receipt.
  Future<CurriculumPackageRestoreResult> restoreBundledInstalledRelease({
    required String candidateId,
    required String manifestJson,
    required String expectedInstalledCanonicalSha256,
    required String expectedCanonicalSha256,
    required String expectedTransportSha256,
  });

  Future<CurriculumPackageRestoreResult> restoreSignedInstalledRelease({
    required String candidateId,
    required String manifestJson,
    required String expectedInstalledCanonicalSha256,
    required CurriculumSignedReleaseEnvelope envelope,
  });

  /// Restores one corrupt chapter shard through the same signed trust path.
  /// The caller must provide the observed installed hash to make the repair a
  /// compare-and-swap rather than a silent overwrite.
  Future<CurriculumPackageRestoreResult> restoreSignedInstalledChapterShard({
    required String candidateId,
    required String manifestJson,
    required String expectedInstalledCanonicalSha256,
    required CurriculumSignedReleaseEnvelope envelope,
    required CurriculumChapterShard shard,
  });

  Future<List<CurriculumPackageRecord>> inventory();

  Future<List<CurriculumQuarantineRecord>> quarantineHistory();

  Future<List<CurriculumActivationReceipt>> activationHistory();

  Future<List<CurriculumPackageRecoveryReceipt>> recoveryHistory();

  Future<CurriculumManifest?> loadRelease(CurriculumReleaseId releaseId);

  Future<CurriculumManifest?> activeManifest(CurriculumActivationTarget target);

  Future<CurriculumReleaseId?> activeReleaseId(
    CurriculumActivationTarget target,
  );

  Future<CurriculumActivationResult> activate({
    required CurriculumReleaseId releaseId,
    required CurriculumActivationTarget target,
  });

  Future<CurriculumActivationResult> rollback(
    CurriculumActivationTarget target,
  );

  Future<List<CurriculumPackageIntegrityIssue>> auditIntegrity();
}

/// Versioned, local-first curriculum package registry.
///
/// The current persistence port writes the entire registry under one key so an
/// install or channel move has one atomic boundary. Published content bodies
/// can move to content-addressed blob storage later without changing the
/// immutable manifest and activation contracts.
final class LocalCurriculumPackageRepository
    implements CurriculumPackageRepository {
  LocalCurriculumPackageRepository({
    required KeyValueStore store,
    required Clock clock,
    required IdSource idSource,
    CurriculumReleaseTrustVerifier? releaseTrustVerifier,
  }) : this._(store, clock, idSource, releaseTrustVerifier, _queueFor(store));

  LocalCurriculumPackageRepository._(
    this._store,
    this._clock,
    this._idSource,
    this._releaseTrustVerifier,
    this._mutationQueue,
  );

  static const stateKey = '__synapse_curriculum_packages_v1';
  static final _shaPattern = RegExp(r'^[0-9a-f]{64}$');
  static final _candidatePattern = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}$',
  );

  final KeyValueStore _store;
  final Clock _clock;
  final IdSource _idSource;
  final CurriculumReleaseTrustVerifier? _releaseTrustVerifier;
  final _MutationQueue _mutationQueue;
  static final Expando<_MutationQueue> _mutationQueues = Expando();

  @override
  Future<CurriculumInstallResult> installBundledCandidate({
    required String candidateId,
    required String manifestJson,
    required String expectedCanonicalSha256,
    required String expectedTransportSha256,
  }) => _installCandidate(
    candidateId: candidateId,
    manifestJson: manifestJson,
    expectedCanonicalSha256: expectedCanonicalSha256,
    expectedTransportSha256: expectedTransportSha256,
  );

  @override
  Future<CurriculumInstallResult> installSignedCandidate({
    required String candidateId,
    required String manifestJson,
    required CurriculumSignedReleaseEnvelope envelope,
  }) => _installCandidate(
    candidateId: candidateId,
    manifestJson: manifestJson,
    expectedCanonicalSha256: envelope.canonicalSha256,
    expectedTransportSha256: envelope.transportSha256,
    envelope: envelope,
  );

  @override
  Future<CurriculumPackageRestoreResult> restoreSignedInstalledChapterShard({
    required String candidateId,
    required String manifestJson,
    required String expectedInstalledCanonicalSha256,
    required CurriculumSignedReleaseEnvelope envelope,
    required CurriculumChapterShard shard,
  }) => _restoreInstalledChapterShard(
    candidateId: candidateId,
    manifestJson: manifestJson,
    expectedInstalledCanonicalSha256: expectedInstalledCanonicalSha256,
    envelope: envelope,
    shard: shard,
  );

  @override
  Future<CurriculumInstallResult> installSignedChapterShard({
    required String candidateId,
    required String manifestJson,
    required CurriculumSignedReleaseEnvelope envelope,
    required CurriculumChapterShard shard,
  }) => _installCandidate(
    candidateId: candidateId,
    manifestJson: manifestJson,
    expectedCanonicalSha256: envelope.canonicalSha256,
    expectedTransportSha256: envelope.transportSha256,
    envelope: envelope,
    shard: shard,
  );

  Future<CurriculumInstallResult> _installCandidate({
    required String candidateId,
    required String manifestJson,
    required String expectedCanonicalSha256,
    required String expectedTransportSha256,
    CurriculumSignedReleaseEnvelope? envelope,
    CurriculumChapterShard? shard,
  }) => _mutate(() async {
    _requireCandidateId(candidateId);
    _requireSha(expectedCanonicalSha256, 'expectedCanonicalSha256');
    _requireSha(expectedTransportSha256, 'expectedTransportSha256');
    final state = await _readState();
    final candidate = await _validateCandidate(
      state: state,
      candidateId: candidateId,
      manifestJson: manifestJson,
      expectedCanonicalSha256: expectedCanonicalSha256,
      expectedTransportSha256: expectedTransportSha256,
    );
    await _verifySignedCandidate(
      state: state,
      candidateId: candidateId,
      candidate: candidate,
      envelope: envelope,
    );
    if (shard != null) {
      _validateChapterShard(candidate.manifest, shard);
      return _installChapterShard(
        state: state,
        candidateId: candidateId,
        candidate: candidate,
        envelope: envelope!,
        shard: shard,
      );
    }
    final manifest = candidate.manifest;
    final canonicalSha = candidate.canonicalSha256;

    final existing = state.packages[manifest.release.id];
    if (existing != null) {
      if (existing.record.canonicalSha256 == canonicalSha) {
        final existingManifest = _decodeStored(manifest.release.id, existing);
        await _verifyStoredTrust(existingManifest, existing);
        if (envelope != null) {
          final upgradedRecord = _recordForCandidate(
            candidateId: candidateId,
            candidate: candidate,
            installedAt: existing.record.installedAt,
            trustKind: CurriculumPackageTrustKind.signedRelease,
            envelope: envelope,
          );
          final upgraded = _StoredPackage(
            record: upgradedRecord,
            manifestJson: candidate.canonicalJson,
            trustEnvelope: envelope,
          );
          state.packages[manifest.release.id] = upgraded;
          await _writeState(state);
          return CurriculumInstallResult(
            record: upgradedRecord,
            alreadyInstalled: true,
          );
        }
        return CurriculumInstallResult(
          record: existing.record,
          alreadyInstalled: true,
        );
      }
      return _quarantineAndThrow(
        state: state,
        candidateId: candidateId,
        transportSha: candidate.transportSha256,
        transportByteLength: candidate.transportByteLength,
        code: 'immutable_release_collision',
        message:
            'Release ${manifest.release.id} is already installed with different bytes.',
        observedCanonicalSha256: canonicalSha,
      );
    }

    final record = _recordForCandidate(
      candidateId: candidateId,
      candidate: candidate,
      installedAt: _clock.nowUtc(),
      trustKind: envelope == null
          ? CurriculumPackageTrustKind.bundledArtifact
          : CurriculumPackageTrustKind.signedRelease,
      envelope: envelope,
    );
    state.packages[record.releaseId] = _StoredPackage(
      record: record,
      manifestJson: candidate.canonicalJson,
      trustEnvelope: envelope,
    );
    await _writeState(state);
    return CurriculumInstallResult(record: record, alreadyInstalled: false);
  });

  Future<CurriculumInstallResult> _installChapterShard({
    required _RegistryState state,
    required String candidateId,
    required _ValidatedCandidate candidate,
    required CurriculumSignedReleaseEnvelope envelope,
    required CurriculumChapterShard shard,
  }) async {
    final existing = state.chapterShards[candidateId];
    if (existing != null) {
      if (existing.record.canonicalSha256 != candidate.canonicalSha256 ||
          existing.record.chapterShard == null ||
          !_sameChapterShard(existing.record.chapterShard!, shard)) {
        return _quarantineAndThrow(
          state: state,
          candidateId: candidateId,
          transportSha: candidate.transportSha256,
          transportByteLength: candidate.transportByteLength,
          code: 'immutable_chapter_shard_collision',
          message:
              'Chapter shard $candidateId is already installed with different immutable content.',
          observedCanonicalSha256: candidate.canonicalSha256,
        );
      }
      final existingManifest = _decodeStored(
        candidate.manifest.release.id,
        existing,
      );
      await _verifyStoredTrust(existingManifest, existing);
      return CurriculumInstallResult(
        record: existing.record,
        alreadyInstalled: true,
      );
    }

    final duplicateChapter = state.chapterShards.values.any((stored) {
      final installedShard = stored.record.chapterShard;
      return stored.record.releaseId == candidate.manifest.release.id &&
          installedShard != null &&
          installedShard.chapterSourceKey == shard.chapterSourceKey;
    });
    if (duplicateChapter) {
      return _quarantineAndThrow(
        state: state,
        candidateId: candidateId,
        transportSha: candidate.transportSha256,
        transportByteLength: candidate.transportByteLength,
        code: 'duplicate_chapter_shard',
        message:
            'Release ${candidate.manifest.release.id} already contains ${shard.chapterSourceKey}.',
        observedCanonicalSha256: candidate.canonicalSha256,
      );
    }

    final record = _recordForCandidate(
      candidateId: candidateId,
      candidate: candidate,
      installedAt: _clock.nowUtc(),
      trustKind: CurriculumPackageTrustKind.signedRelease,
      envelope: envelope,
      shard: shard,
    );
    state.chapterShards[candidateId] = _StoredPackage(
      record: record,
      manifestJson: candidate.canonicalJson,
      trustEnvelope: envelope,
    );
    await _writeState(state);
    return CurriculumInstallResult(record: record, alreadyInstalled: false);
  }

  @override
  Future<CurriculumPackageRestoreResult> restoreBundledInstalledRelease({
    required String candidateId,
    required String manifestJson,
    required String expectedInstalledCanonicalSha256,
    required String expectedCanonicalSha256,
    required String expectedTransportSha256,
  }) => _restoreInstalledRelease(
    candidateId: candidateId,
    manifestJson: manifestJson,
    expectedInstalledCanonicalSha256: expectedInstalledCanonicalSha256,
    expectedCanonicalSha256: expectedCanonicalSha256,
    expectedTransportSha256: expectedTransportSha256,
  );

  @override
  Future<CurriculumPackageRestoreResult> restoreSignedInstalledRelease({
    required String candidateId,
    required String manifestJson,
    required String expectedInstalledCanonicalSha256,
    required CurriculumSignedReleaseEnvelope envelope,
  }) => _restoreInstalledRelease(
    candidateId: candidateId,
    manifestJson: manifestJson,
    expectedInstalledCanonicalSha256: expectedInstalledCanonicalSha256,
    expectedCanonicalSha256: envelope.canonicalSha256,
    expectedTransportSha256: envelope.transportSha256,
    envelope: envelope,
  );

  Future<CurriculumPackageRestoreResult> _restoreInstalledRelease({
    required String candidateId,
    required String manifestJson,
    required String expectedInstalledCanonicalSha256,
    required String expectedCanonicalSha256,
    required String expectedTransportSha256,
    CurriculumSignedReleaseEnvelope? envelope,
  }) => _mutate(() async {
    _requireCandidateId(candidateId);
    _requireSha(
      expectedInstalledCanonicalSha256,
      'expectedInstalledCanonicalSha256',
    );
    _requireSha(expectedCanonicalSha256, 'expectedCanonicalSha256');
    _requireSha(expectedTransportSha256, 'expectedTransportSha256');
    final state = await _readState();
    final candidate = await _validateCandidate(
      state: state,
      candidateId: candidateId,
      manifestJson: manifestJson,
      expectedCanonicalSha256: expectedCanonicalSha256,
      expectedTransportSha256: expectedTransportSha256,
    );
    await _verifySignedCandidate(
      state: state,
      candidateId: candidateId,
      candidate: candidate,
      envelope: envelope,
    );
    final releaseId = candidate.manifest.release.id;
    final existing = state.packages[releaseId];
    if (existing == null) {
      throw CurriculumPackageException(
        'release_not_installed',
        'Curriculum release $releaseId is not installed and cannot be restored.',
      );
    }
    if (existing.record.canonicalSha256 != expectedInstalledCanonicalSha256) {
      throw CurriculumPackageException(
        'restore_precondition_failed',
        'Curriculum release $releaseId changed after recovery was prepared.',
      );
    }
    if (existing.record.trustKind == CurriculumPackageTrustKind.signedRelease &&
        envelope == null) {
      throw const CurriculumPackageException(
        'signed_release_requires_signed_restore',
        'A signed curriculum release requires a signed recovery candidate.',
      );
    }
    var installedBodyIsCorrupt = false;
    try {
      _decodeStored(releaseId, existing);
    } on CurriculumPackageException catch (error) {
      if (error.code != 'corrupt_installed_package') rethrow;
      installedBodyIsCorrupt = true;
    }
    if (!installedBodyIsCorrupt &&
        existing.record.canonicalSha256 == candidate.canonicalSha256) {
      throw CurriculumPackageException(
        'release_not_corrupt',
        'Curriculum release $releaseId passed integrity validation.',
      );
    }
    final record = _recordForCandidate(
      candidateId: candidateId,
      candidate: candidate,
      installedAt: existing.record.installedAt,
      trustKind: envelope == null
          ? CurriculumPackageTrustKind.bundledArtifact
          : CurriculumPackageTrustKind.signedRelease,
      envelope: envelope,
    );
    final receipt = CurriculumPackageRecoveryReceipt(
      id: _idSource.nextId(),
      candidateId: candidateId,
      releaseId: releaseId,
      previousCanonicalSha256: existing.record.canonicalSha256,
      restoredCanonicalSha256: record.canonicalSha256,
      previousTransportSha256: existing.record.transportSha256,
      restoredTransportSha256: record.transportSha256,
      restoredAt: _clock.nowUtc(),
    );
    state.packages[releaseId] = _StoredPackage(
      record: record,
      manifestJson: candidate.canonicalJson,
      trustEnvelope: envelope,
    );
    state.recoveries.add(receipt);
    await _writeState(state);
    return CurriculumPackageRestoreResult(record: record, receipt: receipt);
  });

  Future<CurriculumPackageRestoreResult> _restoreInstalledChapterShard({
    required String candidateId,
    required String manifestJson,
    required String expectedInstalledCanonicalSha256,
    required CurriculumSignedReleaseEnvelope envelope,
    required CurriculumChapterShard shard,
  }) => _mutate(() async {
    _requireCandidateId(candidateId);
    _requireSha(
      expectedInstalledCanonicalSha256,
      'expectedInstalledCanonicalSha256',
    );
    final state = await _readState();
    final candidate = await _validateCandidate(
      state: state,
      candidateId: candidateId,
      manifestJson: manifestJson,
      expectedCanonicalSha256: envelope.canonicalSha256,
      expectedTransportSha256: envelope.transportSha256,
    );
    await _verifySignedCandidate(
      state: state,
      candidateId: candidateId,
      candidate: candidate,
      envelope: envelope,
    );
    _validateChapterShard(candidate.manifest, shard);
    final existing = state.chapterShards[candidateId];
    final releaseId = candidate.manifest.release.id;
    if (existing == null ||
        existing.record.releaseId != releaseId ||
        existing.record.chapterShard == null ||
        !_sameChapterShard(existing.record.chapterShard!, shard)) {
      throw CurriculumPackageException(
        'chapter_shard_not_installed',
        'Curriculum chapter shard $candidateId is not installed and cannot be restored.',
      );
    }
    if (existing.record.canonicalSha256 != expectedInstalledCanonicalSha256) {
      throw CurriculumPackageException(
        'restore_precondition_failed',
        'Curriculum chapter shard $candidateId changed after recovery was prepared.',
      );
    }
    var installedBodyIsCorrupt = false;
    try {
      _decodeStored(releaseId, existing);
    } on CurriculumPackageException catch (error) {
      if (error.code != 'corrupt_installed_package') rethrow;
      installedBodyIsCorrupt = true;
    }
    if (!installedBodyIsCorrupt &&
        existing.record.canonicalSha256 == candidate.canonicalSha256) {
      throw CurriculumPackageException(
        'release_not_corrupt',
        'Curriculum chapter shard $candidateId passed integrity validation.',
      );
    }
    final record = _recordForCandidate(
      candidateId: candidateId,
      candidate: candidate,
      installedAt: existing.record.installedAt,
      trustKind: CurriculumPackageTrustKind.signedRelease,
      envelope: envelope,
      shard: shard,
    );
    final receipt = CurriculumPackageRecoveryReceipt(
      id: _idSource.nextId(),
      candidateId: candidateId,
      releaseId: releaseId,
      previousCanonicalSha256: existing.record.canonicalSha256,
      restoredCanonicalSha256: record.canonicalSha256,
      previousTransportSha256: existing.record.transportSha256,
      restoredTransportSha256: record.transportSha256,
      restoredAt: _clock.nowUtc(),
    );
    state.chapterShards[candidateId] = _StoredPackage(
      record: record,
      manifestJson: candidate.canonicalJson,
      trustEnvelope: envelope,
    );
    state.recoveries.add(receipt);
    await _writeState(state);
    return CurriculumPackageRestoreResult(record: record, receipt: receipt);
  });

  @override
  Future<List<CurriculumPackageRecord>> inventory() async {
    final state = await _readState();
    final result =
        [
          ...state.packages.values.map((value) => value.record),
          ...state.chapterShards.values.map((value) => value.record),
        ]..sort((left, right) {
          final release = left.releaseId.compareTo(right.releaseId);
          return release != 0
              ? release
              : left.candidateId.compareTo(right.candidateId);
        });
    return List.unmodifiable(result);
  }

  @override
  Future<List<CurriculumQuarantineRecord>> quarantineHistory() async =>
      List.unmodifiable((await _readState()).quarantine);

  @override
  Future<List<CurriculumActivationReceipt>> activationHistory() async =>
      List.unmodifiable((await _readState()).receipts);

  @override
  Future<List<CurriculumPackageRecoveryReceipt>> recoveryHistory() async =>
      List.unmodifiable((await _readState()).recoveries);

  @override
  Future<CurriculumManifest?> loadRelease(CurriculumReleaseId releaseId) async {
    final state = await _readState();
    if (!_hasRelease(state, releaseId)) return null;
    return _manifestForRelease(state, releaseId);
  }

  @override
  Future<CurriculumManifest?> activeManifest(
    CurriculumActivationTarget target,
  ) async {
    final state = await _readState();
    final releaseId = state.active[encodeCurriculumActivationTarget(target)];
    if (releaseId == null) return null;
    if (!_hasRelease(state, releaseId)) {
      throw CurriculumPackageException(
        'missing_active_release',
        'Active $target release $releaseId is not installed.',
      );
    }
    final manifest = await _manifestForRelease(state, releaseId);
    _requireActivationEligibility(
      manifest,
      _storedForRelease(state, releaseId).map((stored) => stored.record),
      target,
    );
    return manifest;
  }

  @override
  Future<CurriculumReleaseId?> activeReleaseId(
    CurriculumActivationTarget target,
  ) async {
    final state = await _readState();
    final releaseId = state.active[encodeCurriculumActivationTarget(target)];
    if (releaseId != null && !_hasRelease(state, releaseId)) {
      throw CurriculumPackageException(
        'missing_active_release',
        'Active $target release $releaseId is not installed.',
      );
    }
    return releaseId;
  }

  @override
  Future<CurriculumActivationResult> activate({
    required CurriculumReleaseId releaseId,
    required CurriculumActivationTarget target,
  }) => _mutate(() async {
    final state = await _readState();
    final manifest = await _manifestForRelease(state, releaseId);
    _requireActivationEligibility(
      manifest,
      _storedForRelease(state, releaseId).map((stored) => stored.record),
      target,
    );
    final targetKey = encodeCurriculumActivationTarget(target);
    final latestReceipt = _verifiedLatestReceiptForTarget(state, target);
    if (state.active[targetKey] == releaseId) {
      return CurriculumActivationResult(
        receipt: latestReceipt!,
        changed: false,
      );
    }
    final receipt = _activateState(
      state: state,
      target: target,
      releaseId: releaseId,
    );
    await _writeState(state);
    return CurriculumActivationResult(receipt: receipt, changed: true);
  });

  @override
  Future<CurriculumActivationResult> rollback(
    CurriculumActivationTarget target,
  ) => _mutate(() async {
    final state = await _readState();
    final targetKey = encodeCurriculumActivationTarget(target);
    final current = state.active[targetKey];
    if (current == null) {
      throw const CurriculumPackageException(
        'nothing_to_rollback',
        'No active curriculum release can be rolled back.',
      );
    }
    final sourceReceipt = _verifiedLatestReceiptForTarget(state, target)!;
    if (sourceReceipt.previousReleaseId == null) {
      throw const CurriculumPackageException(
        'nothing_to_rollback',
        'The active release has no previous release receipt.',
      );
    }
    final previous = sourceReceipt.previousReleaseId!;
    final manifest = await _manifestForRelease(state, previous);
    _requireActivationEligibility(
      manifest,
      _storedForRelease(state, previous).map((stored) => stored.record),
      target,
    );
    final receipt = _activateState(
      state: state,
      target: target,
      releaseId: previous,
      rollbackOfReceiptId: sourceReceipt.id,
    );
    await _writeState(state);
    return CurriculumActivationResult(receipt: receipt, changed: true);
  });

  @override
  Future<List<CurriculumPackageIntegrityIssue>> auditIntegrity() async {
    final state = await _readState();
    final issues = <CurriculumPackageIntegrityIssue>[];
    final installed = <_StoredPackage>[
      ...state.packages.values,
      ...state.chapterShards.values,
    ];
    for (final stored in installed) {
      try {
        final manifest = _decodeStored(stored.record.releaseId, stored);
        await _verifyStoredTrust(manifest, stored);
      } on CurriculumPackageException catch (error) {
        issues.add(
          CurriculumPackageIntegrityIssue(
            code: error.code,
            message: error.message,
            releaseId: stored.record.releaseId,
          ),
        );
      } on Object catch (error) {
        issues.add(
          CurriculumPackageIntegrityIssue(
            code: 'corrupt_installed_package',
            message: error.toString(),
            releaseId: stored.record.releaseId,
          ),
        );
      }
    }
    final receiptIdCounts = <String, int>{};
    final receiptIndexes = <String, int>{};
    final receiptsById = <String, CurriculumActivationReceipt>{};
    for (var index = 0; index < state.receipts.length; index++) {
      final receipt = state.receipts[index];
      receiptIdCounts.update(
        receipt.id,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      receiptIndexes.putIfAbsent(receipt.id, () => index);
      receiptsById.putIfAbsent(receipt.id, () => receipt);
    }
    final latestReceiptByTarget =
        <CurriculumActivationTarget, CurriculumActivationReceipt>{};
    final lastReleaseByTarget =
        <CurriculumActivationTarget, CurriculumReleaseId?>{};
    final lastActivationAtByTarget = <CurriculumActivationTarget, DateTime>{};
    for (var index = 0; index < state.receipts.length; index++) {
      final receipt = state.receipts[index];
      if (receiptIdCounts[receipt.id]! > 1) {
        issues.add(
          CurriculumPackageIntegrityIssue(
            code: 'duplicate_activation_receipt_id',
            message: 'Activation receipt ${receipt.id} is not unique.',
            releaseId: receipt.releaseId,
            target: receipt.target,
          ),
        );
      }
      if (!_hasRelease(state, receipt.releaseId)) {
        issues.add(
          CurriculumPackageIntegrityIssue(
            code: 'receipt_release_missing',
            message: '${receipt.id} points to missing ${receipt.releaseId}.',
            releaseId: receipt.releaseId,
            target: receipt.target,
          ),
        );
      }
      final previousReleaseId = receipt.previousReleaseId;
      if (previousReleaseId != null && !_hasRelease(state, previousReleaseId)) {
        issues.add(
          CurriculumPackageIntegrityIssue(
            code: 'receipt_previous_release_missing',
            message: '${receipt.id} points back to missing $previousReleaseId.',
            releaseId: previousReleaseId,
            target: receipt.target,
          ),
        );
      }
      if (previousReleaseId != lastReleaseByTarget[receipt.target]) {
        issues.add(
          CurriculumPackageIntegrityIssue(
            code: 'activation_receipt_chain_broken',
            message: '${receipt.id} does not continue its target history.',
            releaseId: receipt.releaseId,
            target: receipt.target,
          ),
        );
      }
      final lastActivatedAt = lastActivationAtByTarget[receipt.target];
      if (lastActivatedAt != null &&
          receipt.activatedAt.isBefore(lastActivatedAt)) {
        issues.add(
          CurriculumPackageIntegrityIssue(
            code: 'activation_receipt_time_regressed',
            message: '${receipt.id} predates the prior target receipt.',
            releaseId: receipt.releaseId,
            target: receipt.target,
          ),
        );
      }
      final rollbackOfReceiptId = receipt.rollbackOfReceiptId;
      if (rollbackOfReceiptId != null) {
        final source = receiptsById[rollbackOfReceiptId];
        final sourceIndex = receiptIndexes[rollbackOfReceiptId];
        if (source == null || sourceIndex == null || sourceIndex >= index) {
          issues.add(
            CurriculumPackageIntegrityIssue(
              code: 'rollback_receipt_missing',
              message: '${receipt.id} references no prior rollback source.',
              releaseId: receipt.releaseId,
              target: receipt.target,
            ),
          );
        } else if (source.target != receipt.target ||
            source.releaseId != receipt.previousReleaseId ||
            source.previousReleaseId != receipt.releaseId) {
          issues.add(
            CurriculumPackageIntegrityIssue(
              code: 'rollback_receipt_chain_broken',
              message: '${receipt.id} does not invert its source receipt.',
              releaseId: receipt.releaseId,
              target: receipt.target,
            ),
          );
        }
      }
      lastReleaseByTarget[receipt.target] = receipt.releaseId;
      lastActivationAtByTarget[receipt.target] = receipt.activatedAt;
      latestReceiptByTarget[receipt.target] = receipt;
    }
    for (final active in state.active.entries) {
      final target = decodeCurriculumActivationTarget(active.key);
      final activeReleaseId = active.value;
      if (activeReleaseId != null && !_hasRelease(state, activeReleaseId)) {
        issues.add(
          CurriculumPackageIntegrityIssue(
            code: 'missing_active_release',
            message: '${active.key} points to missing $activeReleaseId.',
            releaseId: activeReleaseId,
            target: target,
          ),
        );
      }
      final latestReceipt = latestReceiptByTarget[target];
      if (activeReleaseId != null && latestReceipt == null) {
        issues.add(
          CurriculumPackageIntegrityIssue(
            code: 'missing_activation_receipt',
            message: '${active.key} has no activation receipt.',
            releaseId: activeReleaseId,
            target: target,
          ),
        );
      } else if (latestReceipt?.releaseId != activeReleaseId) {
        issues.add(
          CurriculumPackageIntegrityIssue(
            code: 'active_receipt_mismatch',
            message: '${active.key} disagrees with its latest receipt.',
            releaseId: activeReleaseId ?? latestReceipt?.releaseId,
            target: target,
          ),
        );
      }
    }
    final recoveryIdCounts = <String, int>{};
    final latestRecoveryByCandidate =
        <String, CurriculumPackageRecoveryReceipt>{};
    for (final recovery in state.recoveries) {
      recoveryIdCounts.update(
        recovery.id,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      latestRecoveryByCandidate[recovery.candidateId] = recovery;
      if (!_hasRelease(state, recovery.releaseId)) {
        issues.add(
          CurriculumPackageIntegrityIssue(
            code: 'recovery_release_missing',
            message: '${recovery.id} points to missing ${recovery.releaseId}.',
            releaseId: recovery.releaseId,
          ),
        );
      }
    }
    for (final recovery in state.recoveries) {
      if (recoveryIdCounts[recovery.id]! > 1) {
        issues.add(
          CurriculumPackageIntegrityIssue(
            code: 'duplicate_recovery_receipt_id',
            message: 'Recovery receipt ${recovery.id} is not unique.',
            releaseId: recovery.releaseId,
          ),
        );
      }
    }
    for (final entry in latestRecoveryByCandidate.entries) {
      final recovered = _storedForCandidate(state, entry.key);
      if (recovered != null &&
          (recovered.record.canonicalSha256 !=
                  entry.value.restoredCanonicalSha256 ||
              recovered.record.transportSha256 !=
                  entry.value.restoredTransportSha256)) {
        issues.add(
          CurriculumPackageIntegrityIssue(
            code: 'recovery_receipt_drift',
            message: '${entry.value.id} disagrees with the installed record.',
            releaseId: entry.value.releaseId,
          ),
        );
      }
    }
    return List.unmodifiable(issues);
  }

  CurriculumActivationReceipt _activateState({
    required _RegistryState state,
    required CurriculumActivationTarget target,
    required CurriculumReleaseId releaseId,
    String? rollbackOfReceiptId,
  }) {
    final targetKey = encodeCurriculumActivationTarget(target);
    final receipt = CurriculumActivationReceipt(
      id: _idSource.nextId(),
      target: target,
      releaseId: releaseId,
      previousReleaseId: state.active[targetKey],
      rollbackOfReceiptId: rollbackOfReceiptId,
      activatedAt: _clock.nowUtc(),
    );
    state.active[targetKey] = releaseId;
    state.receipts.add(receipt);
    return receipt;
  }

  CurriculumActivationReceipt? _verifiedLatestReceiptForTarget(
    _RegistryState state,
    CurriculumActivationTarget target,
  ) {
    final activeReleaseId =
        state.active[encodeCurriculumActivationTarget(target)];
    CurriculumActivationReceipt? latestReceipt;
    for (final receipt in state.receipts.reversed) {
      if (receipt.target == target) {
        latestReceipt = receipt;
        break;
      }
    }
    if (activeReleaseId == null && latestReceipt == null) return null;
    if (activeReleaseId == null ||
        latestReceipt == null ||
        latestReceipt.releaseId != activeReleaseId) {
      throw CurriculumPackageException(
        'activation_control_plane_corrupt',
        'The $target active pointer disagrees with its latest receipt.',
      );
    }
    return latestReceipt;
  }

  Future<CurriculumManifest> _manifestForRelease(
    _RegistryState state,
    CurriculumReleaseId releaseId,
  ) async {
    final stored = _storedForRelease(state, releaseId);
    if (stored.isEmpty) {
      throw CurriculumPackageException(
        'release_not_installed',
        'Curriculum release $releaseId is not installed.',
      );
    }
    final manifests = <CurriculumManifest>[];
    for (final value in stored) {
      final manifest = _decodeStored(releaseId, value);
      await _verifyStoredTrust(manifest, value);
      manifests.add(manifest);
    }
    if (manifests.length == 1) return manifests.single;
    return _composeChapterShards(releaseId, manifests);
  }

  List<_StoredPackage> _storedForRelease(
    _RegistryState state,
    CurriculumReleaseId releaseId,
  ) {
    final result = <_StoredPackage>[
      ?state.packages[releaseId],
      ...state.chapterShards.values.where(
        (stored) => stored.record.releaseId == releaseId,
      ),
    ];
    result.sort((left, right) {
      final leftShard = left.record.chapterShard;
      final rightShard = right.record.chapterShard;
      final ordinal = (leftShard?.ordinal ?? 0).compareTo(
        rightShard?.ordinal ?? 0,
      );
      return ordinal != 0
          ? ordinal
          : left.record.candidateId.compareTo(right.record.candidateId);
    });
    return List.unmodifiable(result);
  }

  _StoredPackage? _storedForCandidate(
    _RegistryState state,
    String candidateId,
  ) {
    final shard = state.chapterShards[candidateId];
    if (shard != null) return shard;
    for (final stored in state.packages.values) {
      if (stored.record.candidateId == candidateId) return stored;
    }
    return null;
  }

  bool _hasRelease(_RegistryState state, CurriculumReleaseId releaseId) =>
      state.packages.containsKey(releaseId) ||
      state.chapterShards.values.any(
        (stored) => stored.record.releaseId == releaseId,
      );

  CurriculumManifest _composeChapterShards(
    CurriculumReleaseId releaseId,
    List<CurriculumManifest> manifests,
  ) {
    final first = manifests.first;
    final sourceJson = CanonicalJson.encode(first.source.toJson());
    final releaseJson = CanonicalJson.encode(first.release.toJson());
    for (final manifest in manifests) {
      if (manifest.release.id != releaseId ||
          CanonicalJson.encode(manifest.source.toJson()) != sourceJson ||
          CanonicalJson.encode(manifest.release.toJson()) != releaseJson) {
        throw const CurriculumPackageException(
          'chapter_shard_release_mismatch',
          'Chapter shards must share the exact immutable source and release metadata.',
        );
      }
    }
    try {
      return CurriculumManifest(
        manifestSchemaVersion: first.manifestSchemaVersion,
        source: first.source,
        release: first.release,
        nodes: _mergeShardEntities(
          manifests.expand((manifest) => manifest.nodes),
          (value) => value.id,
          (value) => value.toJson(),
        )..sort((left, right) => left.sourceKey.compareTo(right.sourceKey)),
        localizationUnits: _mergeShardEntities(
          manifests.expand((manifest) => manifest.localizationUnits),
          (value) => value.id,
          (value) => value.toJson(),
        )..sort((left, right) => left.id.compareTo(right.id)),
        microLessons: _mergeShardEntities(
          manifests.expand((manifest) => manifest.microLessons),
          (value) => value.id,
          (value) => value.toJson(),
        )..sort((left, right) => left.id.compareTo(right.id)),
        sessions: _mergeShardEntities(
          manifests.expand((manifest) => manifest.sessions),
          (value) => value.id,
          (value) => value.toJson(),
        )..sort((left, right) => left.id.compareTo(right.id)),
        interactions: _mergeShardEntities(
          manifests.expand((manifest) => manifest.interactions),
          (value) => value.id,
          (value) => value.toJson(),
        )..sort((left, right) => left.id.compareTo(right.id)),
        studyDocuments: _mergeShardEntities(
          manifests.expand((manifest) => manifest.studyDocuments),
          (value) => value.id,
          (value) => value.toJson(),
        )..sort((left, right) => left.id.compareTo(right.id)),
        studyBlocks: _mergeShardEntities(
          manifests.expand((manifest) => manifest.studyBlocks),
          (value) => value.id,
          (value) => value.toJson(),
        )..sort((left, right) => left.id.compareTo(right.id)),
      );
    } on CurriculumPackageException {
      rethrow;
    } on Object catch (error) {
      throw CurriculumPackageException(
        'chapter_shard_composition_failed',
        'Installed chapter shards cannot form a valid curriculum release.',
        error,
      );
    }
  }

  void _validateChapterShard(
    CurriculumManifest manifest,
    CurriculumChapterShard shard,
  ) {
    final courses = manifest.nodes
        .where((node) => node.kind == CurriculumNodeKind.course)
        .toList(growable: false);
    final chapters = manifest.nodes
        .where((node) => node.kind == CurriculumNodeKind.chapter)
        .toList(growable: false);
    if (courses.length != 1 || chapters.length != 1) {
      throw const CurriculumPackageException(
        'invalid_chapter_shard_structure',
        'A chapter shard must contain exactly one Course and one Chapter root.',
      );
    }
    final course = courses.single;
    final chapter = chapters.single;
    if (course.sourceKey != shard.courseSourceKey ||
        chapter.sourceKey != shard.chapterSourceKey ||
        chapter.ordinal != shard.ordinal ||
        chapter.parentId != course.id) {
      throw const CurriculumPackageException(
        'chapter_shard_metadata_mismatch',
        'The signed shard metadata does not match the immutable curriculum hierarchy.',
      );
    }
  }

  bool _sameChapterShard(
    CurriculumChapterShard left,
    CurriculumChapterShard right,
  ) =>
      left.courseSourceKey == right.courseSourceKey &&
      left.chapterSourceKey == right.chapterSourceKey &&
      left.ordinal == right.ordinal;

  CurriculumManifest _decodeStored(
    CurriculumReleaseId releaseId,
    _StoredPackage stored,
  ) {
    try {
      final decoded = jsonDecode(stored.manifestJson);
      if (decoded is! Map) {
        throw const FormatException('Stored manifest root is not an object.');
      }
      final manifest = CurriculumManifest.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      final canonicalJson = CanonicalJson.encode(manifest.toJson());
      final canonicalByteLength = utf8.encode(canonicalJson).length;
      if (manifest.release.id != releaseId ||
          stored.record.releaseId != releaseId ||
          manifest.source.id != stored.record.sourceId ||
          manifest.canonicalSha256 != stored.record.canonicalSha256 ||
          stored.manifestJson != canonicalJson ||
          stored.record.canonicalByteLength != canonicalByteLength ||
          stored.record.releaseChannel !=
              _releaseChannelWire(manifest.release.channel) ||
          stored.record.contentState !=
              _contentStateWire(manifest.release.contentState) ||
          stored.record.isScaffold != manifest.isScaffold) {
        throw const FormatException(
          'Stored manifest bytes or registry metadata drifted.',
        );
      }
      final envelope = stored.trustEnvelope;
      switch (stored.record.trustKind) {
        case CurriculumPackageTrustKind.signedRelease:
          if (envelope == null ||
              stored.record.trustKeyId != envelope.keyId ||
              stored.record.trustEnvelopeSha256 != envelope.envelopeSha256 ||
              stored.record.trustSignedAt != envelope.signedAt ||
              envelope.sourceId != manifest.source.id ||
              envelope.releaseId != manifest.release.id ||
              envelope.releaseChannel != manifest.release.channel ||
              envelope.canonicalSha256 != stored.record.canonicalSha256 ||
              envelope.canonicalByteLength !=
                  stored.record.canonicalByteLength ||
              envelope.transportSha256 != stored.record.transportSha256 ||
              envelope.transportByteLength !=
                  stored.record.transportByteLength) {
            throw const FormatException(
              'Stored signed-release provenance drifted.',
            );
          }
        case CurriculumPackageTrustKind.legacyCallerHashes ||
            CurriculumPackageTrustKind.bundledArtifact:
          if (envelope != null) {
            throw const FormatException(
              'A non-signed package carries a release envelope.',
            );
          }
      }
      return manifest;
    } on CurriculumPackageException {
      rethrow;
    } on Object catch (error) {
      throw CurriculumPackageException(
        'corrupt_installed_package',
        'Installed curriculum release $releaseId failed integrity validation.',
        error,
      );
    }
  }

  Future<void> _verifyStoredTrust(
    CurriculumManifest manifest,
    _StoredPackage stored,
  ) async {
    if (stored.record.trustKind != CurriculumPackageTrustKind.signedRelease) {
      return;
    }
    final verifier = _releaseTrustVerifier;
    if (verifier == null) {
      throw const CurriculumPackageException(
        'release_trust_not_configured',
        'No pinned curriculum release trust policy is configured.',
      );
    }
    await verifier.verifyCandidate(
      manifest: manifest,
      canonicalSha256: stored.record.canonicalSha256,
      canonicalByteLength: stored.record.canonicalByteLength,
      transportSha256: stored.record.transportSha256,
      transportByteLength: stored.record.transportByteLength,
      envelope: stored.trustEnvelope!,
    );
  }

  void _requireActivationEligibility(
    CurriculumManifest manifest,
    Iterable<CurriculumPackageRecord> records,
    CurriculumActivationTarget target,
  ) {
    final resolvedRecords = List<CurriculumPackageRecord>.unmodifiable(records);
    if (resolvedRecords.isEmpty) {
      throw const CurriculumPackageException(
        'release_not_installed',
        'No package records are available for this curriculum release.',
      );
    }
    switch (target) {
      case CurriculumActivationTarget.preview:
        if (manifest.release.contentState != ContentLifecycleState.validated &&
            manifest.release.contentState != ContentLifecycleState.published) {
          throw const CurriculumPackageException(
            'release_not_previewable',
            'Preview activation requires a validated or published release.',
          );
        }
      case CurriculumActivationTarget.learner:
        if (resolvedRecords.any(
          (record) =>
              record.trustKind == CurriculumPackageTrustKind.legacyCallerHashes,
        )) {
          throw const CurriculumPackageException(
            'legacy_release_trust_blocked',
            'Legacy caller-hash packages cannot be learner activated.',
          );
        }
        if (!manifest.release.isLearnerVisible || manifest.isScaffold) {
          throw const CurriculumPackageException(
            'release_not_learner_visible',
            'Learner activation requires a published non-scaffold release.',
          );
        }
    }
  }

  Future<_ValidatedCandidate> _validateCandidate({
    required _RegistryState state,
    required String candidateId,
    required String manifestJson,
    required String expectedCanonicalSha256,
    required String expectedTransportSha256,
  }) async {
    final transportBytes = utf8.encode(manifestJson);
    final transportSha256 = sha256.convert(transportBytes).toString();
    if (transportSha256 != expectedTransportSha256) {
      return _quarantineAndThrow(
        state: state,
        candidateId: candidateId,
        transportSha: transportSha256,
        transportByteLength: transportBytes.length,
        code: 'transport_hash_mismatch',
        message: 'Expected transport hash does not match the candidate bytes.',
      );
    }

    CurriculumManifest manifest;
    try {
      final decoded = jsonDecode(manifestJson);
      if (decoded is! Map) {
        throw const CurriculumPackageException(
          'invalid_manifest_root',
          'A curriculum manifest must be a JSON object.',
        );
      }
      manifest = CurriculumManifest.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } on CurriculumPackageException catch (error) {
      return _quarantineAndThrow(
        state: state,
        candidateId: candidateId,
        transportSha: transportSha256,
        transportByteLength: transportBytes.length,
        code: error.code,
        message: error.message,
        cause: error,
      );
    } on Object catch (error) {
      return _quarantineAndThrow(
        state: state,
        candidateId: candidateId,
        transportSha: transportSha256,
        transportByteLength: transportBytes.length,
        code: 'invalid_manifest',
        message: 'The candidate failed curriculum manifest validation.',
        cause: error,
      );
    }

    final canonicalSha256 = manifest.canonicalSha256;
    if (canonicalSha256 != expectedCanonicalSha256) {
      return _quarantineAndThrow(
        state: state,
        candidateId: candidateId,
        transportSha: transportSha256,
        transportByteLength: transportBytes.length,
        code: 'canonical_hash_mismatch',
        message:
            'Expected canonical hash does not match the validated manifest.',
        observedCanonicalSha256: canonicalSha256,
      );
    }
    final canonicalJson = CanonicalJson.encode(manifest.toJson());
    return _ValidatedCandidate(
      manifest: manifest,
      canonicalJson: canonicalJson,
      canonicalSha256: canonicalSha256,
      canonicalByteLength: utf8.encode(canonicalJson).length,
      transportSha256: transportSha256,
      transportByteLength: transportBytes.length,
    );
  }

  Future<void> _verifySignedCandidate({
    required _RegistryState state,
    required String candidateId,
    required _ValidatedCandidate candidate,
    required CurriculumSignedReleaseEnvelope? envelope,
  }) async {
    if (envelope == null) return;
    final verifier = _releaseTrustVerifier;
    if (verifier == null) {
      await _quarantineAndThrow(
        state: state,
        candidateId: candidateId,
        transportSha: candidate.transportSha256,
        transportByteLength: candidate.transportByteLength,
        code: 'release_trust_not_configured',
        message: 'No pinned curriculum release trust policy is configured.',
        observedCanonicalSha256: candidate.canonicalSha256,
      );
    }
    try {
      await verifier.verifyCandidate(
        manifest: candidate.manifest,
        canonicalSha256: candidate.canonicalSha256,
        canonicalByteLength: candidate.canonicalByteLength,
        transportSha256: candidate.transportSha256,
        transportByteLength: candidate.transportByteLength,
        envelope: envelope,
      );
    } on CurriculumPackageException catch (error) {
      await _quarantineAndThrow(
        state: state,
        candidateId: candidateId,
        transportSha: candidate.transportSha256,
        transportByteLength: candidate.transportByteLength,
        code: error.code,
        message: error.message,
        observedCanonicalSha256: candidate.canonicalSha256,
        cause: error,
      );
    }
  }

  CurriculumPackageRecord _recordForCandidate({
    required String candidateId,
    required _ValidatedCandidate candidate,
    required DateTime installedAt,
    required CurriculumPackageTrustKind trustKind,
    required CurriculumSignedReleaseEnvelope? envelope,
    CurriculumChapterShard? shard,
  }) => CurriculumPackageRecord(
    candidateId: candidateId,
    releaseId: candidate.manifest.release.id,
    sourceId: candidate.manifest.source.id,
    canonicalSha256: candidate.canonicalSha256,
    transportSha256: candidate.transportSha256,
    transportByteLength: candidate.transportByteLength,
    canonicalByteLength: candidate.canonicalByteLength,
    releaseChannel: _releaseChannelWire(candidate.manifest.release.channel),
    contentState: _contentStateWire(candidate.manifest.release.contentState),
    isScaffold: candidate.manifest.isScaffold,
    trustKind: trustKind,
    trustKeyId: envelope?.keyId,
    trustEnvelopeSha256: envelope?.envelopeSha256,
    trustSignedAt: envelope?.signedAt,
    chapterShard: shard,
    installedAt: installedAt,
  );

  Future<Never> _quarantineAndThrow({
    required _RegistryState state,
    required String candidateId,
    required String transportSha,
    required int transportByteLength,
    required String code,
    required String message,
    String? observedCanonicalSha256,
    Object? cause,
  }) async {
    final existing = state.quarantine.any(
      (value) =>
          value.candidateId == candidateId &&
          value.transportSha256 == transportSha &&
          value.code == code,
    );
    if (!existing) {
      state.quarantine.add(
        CurriculumQuarantineRecord(
          candidateId: candidateId,
          transportSha256: transportSha,
          transportByteLength: transportByteLength,
          code: code,
          message: message,
          observedCanonicalSha256: observedCanonicalSha256,
          failedAt: _clock.nowUtc(),
        ),
      );
      await _writeState(state);
    }
    throw CurriculumPackageException(code, message, cause);
  }

  Future<_RegistryState> _readState() async {
    final raw = await _store.read(stateKey);
    if (raw == null) return _RegistryState.empty();
    if (raw is! Map) {
      throw const CurriculumPackageException(
        'corrupt_registry',
        'Curriculum package registry is not a JSON object.',
      );
    }
    try {
      return _RegistryState.fromJson(Map<String, Object?>.from(raw));
    } on CurriculumPackageException {
      rethrow;
    } on Object catch (error) {
      throw CurriculumPackageException(
        'corrupt_registry',
        'Curriculum package registry failed schema validation.',
        error,
      );
    }
  }

  Future<void> _writeState(_RegistryState state) =>
      _store.write(stateKey, state.toJson());

  Future<T> _mutate<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _mutationQueue.tail = _mutationQueue.tail.then((_) async {
      try {
        completer.complete(await action());
      } on Object catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  static _MutationQueue _queueFor(KeyValueStore store) =>
      _mutationQueues[store] ??= _MutationQueue();

  static void _requireCandidateId(String value) {
    if (!_candidatePattern.hasMatch(value)) {
      throw ArgumentError.value(
        value,
        'candidateId',
        'Invalid stable candidate ID.',
      );
    }
  }

  static void _requireSha(String value, String field) {
    if (!_shaPattern.hasMatch(value)) {
      throw ArgumentError.value(value, field, 'Expected lowercase SHA-256.');
    }
  }
}

final class _MutationQueue {
  Future<void> tail = Future.value();
}

List<T> _mergeShardEntities<T>(
  Iterable<T> values,
  String Function(T value) idOf,
  Object? Function(T value) jsonOf,
) {
  final merged = <String, T>{};
  final canonicalById = <String, String>{};
  for (final value in values) {
    final id = idOf(value);
    final canonical = CanonicalJson.encode(jsonOf(value));
    final existing = canonicalById[id];
    if (existing != null && existing != canonical) {
      throw CurriculumPackageException(
        'chapter_shard_entity_collision',
        'Chapter shards disagree about immutable entity $id.',
      );
    }
    canonicalById[id] = canonical;
    merged[id] = value;
  }
  return merged.values.toList(growable: false);
}

final class _ValidatedCandidate {
  const _ValidatedCandidate({
    required this.manifest,
    required this.canonicalJson,
    required this.canonicalSha256,
    required this.canonicalByteLength,
    required this.transportSha256,
    required this.transportByteLength,
  });

  final CurriculumManifest manifest;
  final String canonicalJson;
  final String canonicalSha256;
  final int canonicalByteLength;
  final String transportSha256;
  final int transportByteLength;
}

final class _StoredPackage {
  const _StoredPackage({
    required this.record,
    required this.manifestJson,
    this.trustEnvelope,
  });

  final CurriculumPackageRecord record;
  final String manifestJson;
  final CurriculumSignedReleaseEnvelope? trustEnvelope;

  Map<String, Object?> toJson() => {
    'record': record.toJson(),
    'manifestJson': manifestJson,
    'trustEnvelope': trustEnvelope?.toJson(),
  };

  factory _StoredPackage.fromJson(Map<String, Object?> json) => _StoredPackage(
    record: CurriculumPackageRecord.fromJson(
      _objectMap(json['record'], 'record'),
    ),
    manifestJson: _requiredString(json['manifestJson'], 'manifestJson'),
    trustEnvelope: json['trustEnvelope'] == null
        ? null
        : CurriculumSignedReleaseEnvelope.fromJson(
            _objectMap(json['trustEnvelope'], 'trustEnvelope'),
          ),
  );
}

final class _RegistryState {
  _RegistryState({
    required this.packages,
    required this.chapterShards,
    required this.active,
    required this.receipts,
    required this.recoveries,
    required this.quarantine,
  });

  static const schemaVersion = 2;
  static const legacySchemaVersion = 1;

  factory _RegistryState.empty() => _RegistryState(
    packages: {},
    chapterShards: {},
    active: {
      encodeCurriculumActivationTarget(CurriculumActivationTarget.preview):
          null,
      encodeCurriculumActivationTarget(CurriculumActivationTarget.learner):
          null,
    },
    receipts: [],
    recoveries: [],
    quarantine: [],
  );

  final Map<CurriculumReleaseId, _StoredPackage> packages;
  final Map<String, _StoredPackage> chapterShards;
  final Map<String, CurriculumReleaseId?> active;
  final List<CurriculumActivationReceipt> receipts;
  final List<CurriculumPackageRecoveryReceipt> recoveries;
  final List<CurriculumQuarantineRecord> quarantine;

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'packages': packages.map(
      (key, value) => MapEntry<String, Object?>(key, value.toJson()),
    ),
    'chapterShards': chapterShards.map(
      (key, value) => MapEntry<String, Object?>(key, value.toJson()),
    ),
    'active': Map<String, Object?>.from(active),
    'receipts': receipts.map((value) => value.toJson()).toList(),
    'recoveries': recoveries.map((value) => value.toJson()).toList(),
    'quarantine': quarantine.map((value) => value.toJson()).toList(),
  };

  factory _RegistryState.fromJson(Map<String, Object?> json) {
    final version = json['schemaVersion'];
    if (version != legacySchemaVersion && version != schemaVersion) {
      throw const CurriculumPackageException(
        'unsupported_registry_schema',
        'Unsupported curriculum package registry schema.',
      );
    }
    final packagesJson = _objectMap(json['packages'], 'packages');
    final activeJson = _objectMap(json['active'], 'active');
    final expectedTargets = {
      encodeCurriculumActivationTarget(CurriculumActivationTarget.preview),
      encodeCurriculumActivationTarget(CurriculumActivationTarget.learner),
    };
    if (activeJson.keys.toSet().difference(expectedTargets).isNotEmpty ||
        expectedTargets.difference(activeJson.keys.toSet()).isNotEmpty) {
      throw const CurriculumPackageException(
        'corrupt_registry',
        'Registry active targets are incomplete or unknown.',
      );
    }
    final packages = packagesJson.map(
      (key, value) => MapEntry(
        key,
        _StoredPackage.fromJson(_objectMap(value, 'packages.$key')),
      ),
    );
    final shardsJson = version == legacySchemaVersion
        ? const <String, Object?>{}
        : _objectMap(json['chapterShards'], 'chapterShards');
    final chapterShards = shardsJson.map(
      (key, value) => MapEntry(
        key,
        _StoredPackage.fromJson(_objectMap(value, 'chapterShards.$key')),
      ),
    );
    for (final entry in packages.entries) {
      if (entry.key != entry.value.record.releaseId ||
          entry.value.record.isChapterShard) {
        throw const CurriculumPackageException(
          'corrupt_registry',
          'A full release registry record has invalid immutable placement.',
        );
      }
    }
    for (final entry in chapterShards.entries) {
      if (entry.key != entry.value.record.candidateId ||
          !entry.value.record.isChapterShard) {
        throw const CurriculumPackageException(
          'corrupt_registry',
          'A chapter shard registry record has invalid immutable placement.',
        );
      }
    }
    return _RegistryState(
      packages: packages,
      chapterShards: chapterShards,
      active: activeJson.map(
        (key, value) => MapEntry(
          key,
          value == null ? null : _requiredString(value, 'active.$key'),
        ),
      ),
      receipts: _objectList(
        json['receipts'],
        'receipts',
      ).map(CurriculumActivationReceipt.fromJson).toList(),
      recoveries: _objectList(
        json['recoveries'] ?? const <Object?>[],
        'recoveries',
      ).map(CurriculumPackageRecoveryReceipt.fromJson).toList(),
      quarantine: _objectList(
        json['quarantine'],
        'quarantine',
      ).map(CurriculumQuarantineRecord.fromJson).toList(),
    );
  }
}

Map<String, Object?> _objectMap(Object? value, String field) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw CurriculumPackageException(
      'corrupt_registry',
      '$field must be a JSON object.',
    );
  }
  return Map<String, Object?>.from(value);
}

List<Map<String, Object?>> _objectList(Object? value, String field) {
  if (value is! List) {
    throw CurriculumPackageException(
      'corrupt_registry',
      '$field must be an array.',
    );
  }
  return [
    for (var index = 0; index < value.length; index++)
      _objectMap(value[index], '$field[$index]'),
  ];
}

String _requiredString(Object? value, String field) {
  if (value is! String || value.trim().isEmpty || value != value.trim()) {
    throw CurriculumPackageException(
      'corrupt_registry',
      '$field must be a non-empty trimmed string.',
    );
  }
  return value;
}

String _releaseChannelWire(CurriculumReleaseChannel value) => switch (value) {
  CurriculumReleaseChannel.internal => 'internal',
  CurriculumReleaseChannel.beta => 'beta',
  CurriculumReleaseChannel.stable => 'stable',
};

String _contentStateWire(ContentLifecycleState value) => switch (value) {
  ContentLifecycleState.raw => 'raw',
  ContentLifecycleState.reviewed => 'reviewed',
  ContentLifecycleState.validated => 'validated',
  ContentLifecycleState.published => 'published',
  ContentLifecycleState.withdrawn => 'withdrawn',
  ContentLifecycleState.superseded => 'superseded',
  ContentLifecycleState.quarantined => 'quarantined',
};

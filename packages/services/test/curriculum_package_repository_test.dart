import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_foundation/synapse_foundation.dart';
import 'package:synapse_services/synapse_services.dart';
import 'package:test/test.dart';

import 'support/curriculum_manifest_fixture.dart';

void main() {
  late MemoryKeyValueStore store;
  late MutableClock clock;
  late LocalCurriculumPackageRepository repository;

  setUp(() {
    store = MemoryKeyValueStore();
    clock = MutableClock(DateTime.utc(2026, 7, 17, 12));
    repository = LocalCurriculumPackageRepository(
      store: store,
      clock: clock,
      idSource: SequenceIdSource([
        for (var index = 1; index <= 20; index++) 'activation.$index',
      ]),
    );
  });

  test(
    'installs and restores a canonical immutable scaffold package',
    () async {
      final manifest = buildScaffoldManifest();
      final result = await _install(
        repository,
        'candidate.scaffold.001',
        manifest,
      );

      expect(result.alreadyInstalled, isFalse);
      expect(result.record.releaseId, manifest.release.id);
      expect(result.record.canonicalSha256, manifest.canonicalSha256);
      expect(result.record.isScaffold, isTrue);
      expect((await repository.inventory()).length, 1);
      expect(await repository.loadRelease(manifest.release.id), manifest);
      expect(await repository.auditIntegrity(), isEmpty);
      expect(
        store.snapshot,
        contains(LocalCurriculumPackageRepository.stateKey),
      );
    },
  );

  test(
    'repeated install and activation are idempotent across restart',
    () async {
      final manifest = buildScaffoldManifest();
      await _install(repository, 'candidate.scaffold.001', manifest);
      final duplicate = await _install(
        repository,
        'candidate.scaffold.retry',
        manifest,
      );
      expect(duplicate.alreadyInstalled, isTrue);
      expect((await repository.inventory()).length, 1);

      final first = await repository.activate(
        releaseId: manifest.release.id,
        target: CurriculumActivationTarget.preview,
      );
      final repeated = await repository.activate(
        releaseId: manifest.release.id,
        target: CurriculumActivationTarget.preview,
      );
      expect(first.changed, isTrue);
      expect(repeated.changed, isFalse);
      expect(repeated.receipt.id, first.receipt.id);
      expect((await repository.activationHistory()).length, 1);

      final restarted = LocalCurriculumPackageRepository(
        store: store,
        clock: clock,
        idSource: SequenceIdSource(const ['activation.after-restart']),
      );
      expect(
        (await restarted.activeManifest(
          CurriculumActivationTarget.preview,
        ))?.release.id,
        manifest.release.id,
      );
    },
  );

  test(
    'quarantines invalid and hash-mismatched candidates without raw body',
    () async {
      await expectLater(
        repository.installBundledCandidate(
          candidateId: 'candidate.invalid.001',
          manifestJson: '{}',
          expectedCanonicalSha256: '0' * 64,
          expectedTransportSha256: _transportSha('{}'),
        ),
        throwsA(
          isA<CurriculumPackageException>().having(
            (error) => error.code,
            'code',
            'invalid_manifest',
          ),
        ),
      );

      final manifest = buildScaffoldManifest();
      final encoded = jsonEncode(manifest.toJson());
      Future<void> mismatch() async {
        await repository.installBundledCandidate(
          candidateId: 'candidate.mismatch.001',
          manifestJson: encoded,
          expectedCanonicalSha256: 'f' * 64,
          expectedTransportSha256: _transportSha(encoded),
        );
      }

      await expectLater(
        mismatch(),
        throwsA(
          isA<CurriculumPackageException>().having(
            (error) => error.code,
            'code',
            'canonical_hash_mismatch',
          ),
        ),
      );
      await expectLater(mismatch(), throwsA(isA<CurriculumPackageException>()));

      final quarantine = await repository.quarantineHistory();
      expect(quarantine.length, 2);
      expect(quarantine.last.observedCanonicalSha256, manifest.canonicalSha256);
      expect(
        quarantine.map((entry) => entry.toJson().keys),
        everyElement(isNot(contains('manifestJson'))),
      );
      expect(await repository.inventory(), isEmpty);
    },
  );

  test('persists zero-byte quarantine metadata across restart', () async {
    await expectLater(
      repository.installBundledCandidate(
        candidateId: 'candidate.empty.001',
        manifestJson: '',
        expectedCanonicalSha256: '0' * 64,
        expectedTransportSha256: _transportSha(''),
      ),
      throwsA(
        isA<CurriculumPackageException>().having(
          (error) => error.code,
          'code',
          'invalid_manifest',
        ),
      ),
    );

    final restarted = LocalCurriculumPackageRepository(
      store: store,
      clock: clock,
      idSource: SequenceIdSource(const ['activation.after-empty']),
    );
    final quarantine = await restarted.quarantineHistory();
    expect(quarantine.single.transportByteLength, 0);
    expect(quarantine.single.candidateId, 'candidate.empty.001');
  });

  test('reads pre-recovery-field v1 registry snapshots losslessly', () async {
    final manifest = buildScaffoldManifest();
    await _install(repository, 'candidate.pre-recovery-field', manifest);
    await _mutateRegistry(store, (registry) {
      registry.remove('recoveries');
    });
    final restarted = LocalCurriculumPackageRepository(
      store: store,
      clock: clock,
      idSource: SequenceIdSource(const ['activation.pre-recovery-field']),
    );

    expect(await restarted.loadRelease(manifest.release.id), manifest);
    expect(await restarted.recoveryHistory(), isEmpty);
    await restarted.activate(
      releaseId: manifest.release.id,
      target: CurriculumActivationTarget.preview,
    );
    final persisted =
        await store.read(LocalCurriculumPackageRepository.stateKey) as Map;
    expect(persisted, contains('recoveries'));
  });

  test(
    'rejects immutable release ID collisions and preserves first bytes',
    () async {
      final first = buildScaffoldManifest(titleSuffix: 'First');
      final collision = buildScaffoldManifest(titleSuffix: 'Changed');
      await _install(repository, 'candidate.first', first);

      await expectLater(
        _install(repository, 'candidate.collision', collision),
        throwsA(
          isA<CurriculumPackageException>().having(
            (error) => error.code,
            'code',
            'immutable_release_collision',
          ),
        ),
      );

      expect(
        (await repository.inventory()).single.canonicalSha256,
        first.canonicalSha256,
      );
      expect(await repository.loadRelease(first.release.id), first);
    },
  );

  test('separates preview scaffolds from learner-visible releases', () async {
    final scaffold = buildScaffoldManifest();
    await _install(repository, 'candidate.scaffold', scaffold);
    await repository.activate(
      releaseId: scaffold.release.id,
      target: CurriculumActivationTarget.preview,
    );
    await expectLater(
      repository.activate(
        releaseId: scaffold.release.id,
        target: CurriculumActivationTarget.learner,
      ),
      throwsA(
        isA<CurriculumPackageException>().having(
          (error) => error.code,
          'code',
          'release_not_learner_visible',
        ),
      ),
    );

    final published = buildPublishedManifest(
      releaseId: 'release.stable.001',
      version: '2026.07.17+10',
    );
    await _install(repository, 'candidate.published', published);
    final activation = await repository.activate(
      releaseId: published.release.id,
      target: CurriculumActivationTarget.learner,
    );

    expect(activation.changed, isTrue);
    expect(
      (await repository.activeManifest(
        CurriculumActivationTarget.learner,
      ))?.release.id,
      published.release.id,
    );
  });

  test('rolls channel pointers back through durable receipts', () async {
    final first = buildPublishedManifest(
      releaseId: 'release.stable.001',
      version: '2026.07.17+10',
      titleSuffix: 'First',
    );
    final second = buildPublishedManifest(
      releaseId: 'release.stable.002',
      version: '2026.07.17+11',
      parentReleaseId: first.release.id,
      titleSuffix: 'Second',
    );
    await Future.wait([
      _install(repository, 'candidate.first', first),
      _install(repository, 'candidate.second', second),
    ]);
    await repository.activate(
      releaseId: first.release.id,
      target: CurriculumActivationTarget.learner,
    );
    final secondActivation = await repository.activate(
      releaseId: second.release.id,
      target: CurriculumActivationTarget.learner,
    );
    clock.advance(const Duration(minutes: 1));
    final rollback = await repository.rollback(
      CurriculumActivationTarget.learner,
    );

    expect(rollback.changed, isTrue);
    expect(rollback.receipt.releaseId, first.release.id);
    expect(rollback.receipt.previousReleaseId, second.release.id);
    expect(rollback.receipt.rollbackOfReceiptId, secondActivation.receipt.id);
    expect((await repository.activationHistory()).length, 3);
    expect(
      (await repository.activeManifest(
        CurriculumActivationTarget.learner,
      ))?.release.id,
      first.release.id,
    );
  });

  test(
    'reports installed-byte corruption instead of silently resetting',
    () async {
      final manifest = buildScaffoldManifest();
      await _install(repository, 'candidate.scaffold', manifest);
      final raw = await store.read(LocalCurriculumPackageRepository.stateKey);
      final mutable = jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
      final packages = mutable['packages'] as Map<String, dynamic>;
      final stored = packages[manifest.release.id] as Map<String, dynamic>;
      stored['manifestJson'] = '{}';
      await store.write(LocalCurriculumPackageRepository.stateKey, mutable);

      final issues = await repository.auditIntegrity();
      expect(issues.single.code, 'corrupt_installed_package');
      expect(issues.single.releaseId, manifest.release.id);
      await expectLater(
        repository.loadRelease(manifest.release.id),
        throwsA(
          isA<CurriculumPackageException>().having(
            (error) => error.code,
            'code',
            'corrupt_installed_package',
          ),
        ),
      );
    },
  );

  test(
    'rejects a candidate whose transport bytes miss the trusted hash',
    () async {
      final manifest = buildScaffoldManifest();
      final manifestJson = jsonEncode(manifest.toJson());

      await expectLater(
        repository.installBundledCandidate(
          candidateId: 'candidate.transport.mismatch',
          manifestJson: manifestJson,
          expectedCanonicalSha256: manifest.canonicalSha256,
          expectedTransportSha256: 'f' * 64,
        ),
        throwsA(
          isA<CurriculumPackageException>().having(
            (error) => error.code,
            'code',
            'transport_hash_mismatch',
          ),
        ),
      );

      expect(await repository.inventory(), isEmpty);
      expect(
        (await repository.quarantineHistory()).single.code,
        'transport_hash_mismatch',
      );
    },
  );

  test(
    'refuses false idempotent success and restores corrupt bytes with a receipt',
    () async {
      final manifest = buildScaffoldManifest();
      await _install(repository, 'candidate.restore.original', manifest);
      await _mutateRegistry(store, (registry) {
        final packages = registry['packages'] as Map<String, dynamic>;
        final stored = packages[manifest.release.id] as Map<String, dynamic>;
        stored['manifestJson'] = '{}';
      });

      await expectLater(
        _install(repository, 'candidate.restore.retry', manifest),
        throwsA(
          isA<CurriculumPackageException>().having(
            (error) => error.code,
            'code',
            'corrupt_installed_package',
          ),
        ),
      );
      expect(await repository.recoveryHistory(), isEmpty);

      final trustedJson = jsonEncode(manifest.toJson());
      await expectLater(
        repository.restoreBundledInstalledRelease(
          candidateId: 'candidate.restore.stale-precondition',
          manifestJson: trustedJson,
          expectedInstalledCanonicalSha256: 'f' * 64,
          expectedCanonicalSha256: manifest.canonicalSha256,
          expectedTransportSha256: _transportSha(trustedJson),
        ),
        throwsA(
          isA<CurriculumPackageException>().having(
            (error) => error.code,
            'code',
            'restore_precondition_failed',
          ),
        ),
      );
      expect(await repository.recoveryHistory(), isEmpty);

      final restored = await _restore(
        repository,
        'candidate.restore.trusted',
        manifest,
      );
      expect(restored.record.canonicalSha256, manifest.canonicalSha256);
      expect(restored.receipt.releaseId, manifest.release.id);
      expect(
        restored.receipt.restoredCanonicalSha256,
        manifest.canonicalSha256,
      );
      expect(await repository.loadRelease(manifest.release.id), manifest);
      expect(await repository.auditIntegrity(), isEmpty);
      expect(
        (await repository.recoveryHistory()).single.id,
        restored.receipt.id,
      );

      await _mutateRegistry(store, (registry) {
        final recoveries = registry['recoveries'] as List<dynamic>;
        final receipt = recoveries.single as Map<String, dynamic>;
        receipt['restoredTransportSha256'] = 'f' * 64;
      });
      expect(
        (await repository.auditIntegrity()).map((issue) => issue.code),
        contains('recovery_receipt_drift'),
      );
    },
  );

  test('rejects non-canonical stored JSON and record metadata drift', () async {
    final manifest = buildScaffoldManifest();
    await _install(repository, 'candidate.canonical.original', manifest);
    await _mutateRegistry(store, (registry) {
      final packages = registry['packages'] as Map<String, dynamic>;
      final stored = packages[manifest.release.id] as Map<String, dynamic>;
      final body =
          jsonDecode(stored['manifestJson'] as String) as Map<String, dynamic>;
      body['ignoredExtraField'] = true;
      stored['manifestJson'] = jsonEncode(body);
    });

    var issues = await repository.auditIntegrity();
    expect(issues.single.code, 'corrupt_installed_package');

    await _restore(repository, 'candidate.canonical.restore', manifest);
    await _mutateRegistry(store, (registry) {
      final packages = registry['packages'] as Map<String, dynamic>;
      final stored = packages[manifest.release.id] as Map<String, dynamic>;
      final record = stored['record'] as Map<String, dynamic>;
      record['sourceId'] = 'source.drifted';
    });
    issues = await repository.auditIntegrity();
    expect(issues.single.code, 'corrupt_installed_package');
  });

  test('audits activation pointer and receipt-chain corruption', () async {
    final first = buildPublishedManifest(
      releaseId: 'release.receipt.first',
      version: '2026.07.17+301',
    );
    final second = buildPublishedManifest(
      releaseId: 'release.receipt.second',
      version: '2026.07.17+302',
      parentReleaseId: first.release.id,
    );
    await _install(repository, 'candidate.receipt.first', first);
    await _install(repository, 'candidate.receipt.second', second);
    await repository.activate(
      releaseId: first.release.id,
      target: CurriculumActivationTarget.learner,
    );
    await repository.activate(
      releaseId: second.release.id,
      target: CurriculumActivationTarget.learner,
    );
    await _mutateRegistry(store, (registry) {
      final receipts = registry['receipts'] as List<dynamic>;
      final secondReceipt = receipts.last as Map<String, dynamic>;
      secondReceipt['previousReleaseId'] = null;
      final active = registry['active'] as Map<String, dynamic>;
      active['learner'] = first.release.id;
    });

    final issues = await repository.auditIntegrity();
    expect(
      issues.map((issue) => issue.code),
      containsAll([
        'activation_receipt_chain_broken',
        'active_receipt_mismatch',
      ]),
    );
    expect(
      issues.where((issue) => issue.target != null),
      everyElement(
        isA<CurriculumPackageIntegrityIssue>().having(
          (issue) => issue.target,
          'target',
          CurriculumActivationTarget.learner,
        ),
      ),
    );
  });

  test('audits duplicate receipts and invalid rollback references', () async {
    final first = buildPublishedManifest(
      releaseId: 'release.rollback-audit.first',
      version: '2026.07.17+303',
    );
    final second = buildPublishedManifest(
      releaseId: 'release.rollback-audit.second',
      version: '2026.07.17+304',
      parentReleaseId: first.release.id,
    );
    await _install(repository, 'candidate.rollback-audit.first', first);
    await _install(repository, 'candidate.rollback-audit.second', second);
    await repository.activate(
      releaseId: first.release.id,
      target: CurriculumActivationTarget.learner,
    );
    await repository.activate(
      releaseId: second.release.id,
      target: CurriculumActivationTarget.learner,
    );
    await repository.rollback(CurriculumActivationTarget.learner);
    await _mutateRegistry(store, (registry) {
      final receipts = registry['receipts'] as List<dynamic>;
      final firstReceipt = receipts.first as Map<String, dynamic>;
      final secondReceipt = receipts[1] as Map<String, dynamic>;
      final rollbackReceipt = receipts.last as Map<String, dynamic>;
      secondReceipt['id'] = firstReceipt['id'];
      rollbackReceipt['rollbackOfReceiptId'] = 'activation.missing';
    });

    final issues = await repository.auditIntegrity();
    expect(
      issues.map((issue) => issue.code),
      containsAll([
        'duplicate_activation_receipt_id',
        'rollback_receipt_missing',
      ]),
    );
  });

  test('trusted restore repairs self-consistent same-release drift', () async {
    final original = buildScaffoldManifest(titleSuffix: 'Original');
    final altered = buildScaffoldManifest(titleSuffix: 'Altered');
    await _install(repository, 'candidate.drift.original', original);
    await _mutateRegistry(store, (registry) {
      final packages = registry['packages'] as Map<String, dynamic>;
      final stored = packages[original.release.id] as Map<String, dynamic>;
      final record = stored['record'] as Map<String, dynamic>;
      final alteredJson = CanonicalJson.encode(altered.toJson());
      stored['manifestJson'] = alteredJson;
      record['canonicalSha256'] = altered.canonicalSha256;
      record['canonicalByteLength'] = utf8.encode(alteredJson).length;
    });

    final restored = await _restore(
      repository,
      'candidate.drift.trusted-original',
      original,
    );

    expect(restored.receipt.previousCanonicalSha256, altered.canonicalSha256);
    expect(restored.receipt.restoredCanonicalSha256, original.canonicalSha256);
    expect(await repository.loadRelease(original.release.id), original);
    expect(await repository.auditIntegrity(), isEmpty);
  });

  test(
    'serializes mutations across repository instances sharing a store',
    () async {
      final restarted = LocalCurriculumPackageRepository(
        store: store,
        clock: clock,
        idSource: SequenceIdSource(const ['activation.shared-store']),
      );
      final first = buildScaffoldManifest(
        releaseId: 'release.shared-store.first',
        version: '2026.07.17+305',
      );
      final second = buildScaffoldManifest(
        releaseId: 'release.shared-store.second',
        version: '2026.07.17+306',
      );

      await Future.wait([
        _install(repository, 'candidate.shared-store.first', first),
        _install(restarted, 'candidate.shared-store.second', second),
      ]);

      expect((await repository.inventory()).map((record) => record.releaseId), [
        first.release.id,
        second.release.id,
      ]);
    },
  );

  test('refuses activation mutations over a corrupt target pointer', () async {
    final first = buildPublishedManifest(
      releaseId: 'release.activation-guard.first',
      version: '2026.07.17+307',
    );
    final second = buildPublishedManifest(
      releaseId: 'release.activation-guard.second',
      version: '2026.07.17+308',
      parentReleaseId: first.release.id,
    );
    await _install(repository, 'candidate.activation-guard.first', first);
    await _install(repository, 'candidate.activation-guard.second', second);
    await repository.activate(
      releaseId: first.release.id,
      target: CurriculumActivationTarget.learner,
    );
    await _mutateRegistry(store, (registry) {
      final active = registry['active'] as Map<String, dynamic>;
      active['learner'] = second.release.id;
    });

    await expectLater(
      repository.activate(
        releaseId: first.release.id,
        target: CurriculumActivationTarget.learner,
      ),
      throwsA(
        isA<CurriculumPackageException>().having(
          (error) => error.code,
          'code',
          'activation_control_plane_corrupt',
        ),
      ),
    );
    await expectLater(
      repository.rollback(CurriculumActivationTarget.learner),
      throwsA(
        isA<CurriculumPackageException>().having(
          (error) => error.code,
          'code',
          'activation_control_plane_corrupt',
        ),
      ),
    );
    expect(await repository.activationHistory(), hasLength(1));
  });
}

Future<CurriculumInstallResult> _install(
  LocalCurriculumPackageRepository repository,
  String candidateId,
  CurriculumManifest manifest,
) {
  final manifestJson = jsonEncode(manifest.toJson());
  return repository.installBundledCandidate(
    candidateId: candidateId,
    manifestJson: manifestJson,
    expectedCanonicalSha256: manifest.canonicalSha256,
    expectedTransportSha256: _transportSha(manifestJson),
  );
}

String _transportSha(String value) =>
    sha256.convert(utf8.encode(value)).toString();

Future<CurriculumPackageRestoreResult> _restore(
  LocalCurriculumPackageRepository repository,
  String candidateId,
  CurriculumManifest manifest, {
  String? expectedInstalledCanonicalSha256,
}) async {
  final manifestJson = jsonEncode(manifest.toJson());
  final installedSha =
      expectedInstalledCanonicalSha256 ??
      (await repository.inventory())
          .singleWhere((record) => record.releaseId == manifest.release.id)
          .canonicalSha256;
  return repository.restoreBundledInstalledRelease(
    candidateId: candidateId,
    manifestJson: manifestJson,
    expectedInstalledCanonicalSha256: installedSha,
    expectedCanonicalSha256: manifest.canonicalSha256,
    expectedTransportSha256: _transportSha(manifestJson),
  );
}

Future<void> _mutateRegistry(
  MemoryKeyValueStore store,
  void Function(Map<String, dynamic> registry) mutate,
) async {
  final raw = await store.read(LocalCurriculumPackageRepository.stateKey);
  final registry = jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
  mutate(registry);
  await store.write(LocalCurriculumPackageRepository.stateKey, registry);
}

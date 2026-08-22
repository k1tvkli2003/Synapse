import 'dart:convert';

import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_foundation/synapse_foundation.dart';
import 'package:synapse_services/synapse_services.dart';
import 'package:test/test.dart';

import 'support/curriculum_manifest_fixture.dart';

void main() {
  late MutableClock clock;
  late Ed25519 algorithm;
  late SimpleKeyPair signingKey;
  late List<int> publicKeyBytes;

  setUp(() async {
    clock = MutableClock(DateTime.utc(2026, 7, 17, 12));
    algorithm = Ed25519();
    signingKey = await algorithm.newKeyPairFromSeed(
      List<int>.generate(32, (index) => index + 1),
    );
    publicKeyBytes = (await signingKey.extractPublicKey()).bytes;
  });

  test(
    'signed envelope round-trips and authorizes learner activation',
    () async {
      final manifest = buildPublishedManifest(
        releaseId: 'release.signed.001',
        version: '2026.07.17+401',
      );
      final manifestJson = jsonEncode(manifest.toJson());
      final envelope = await _signedEnvelope(
        algorithm: algorithm,
        keyPair: signingKey,
        manifest: manifest,
        manifestJson: manifestJson,
        signedAt: clock.nowUtc(),
      );
      final decoded = CurriculumSignedReleaseEnvelope.fromJson(
        Map<String, Object?>.from(
          jsonDecode(jsonEncode(envelope.toJson())) as Map,
        ),
      );
      expect(decoded.toJson(), envelope.toJson());
      expect(decoded.signingBytes, envelope.signingBytes);

      final store = MemoryKeyValueStore();
      final verifier = _verifier(
        clock: clock,
        manifest: manifest,
        publicKeyBytes: publicKeyBytes,
      );
      final repository = _repository(
        store: store,
        clock: clock,
        verifier: verifier,
      );
      final installed = await repository.installSignedCandidate(
        candidateId: 'signed:release.signed.001',
        manifestJson: manifestJson,
        envelope: envelope,
      );

      expect(
        installed.record.trustKind,
        CurriculumPackageTrustKind.signedRelease,
      );
      expect(installed.record.trustKeyId, envelope.keyId);
      expect(installed.record.trustEnvelopeSha256, envelope.envelopeSha256);
      expect(await repository.auditIntegrity(), isEmpty);
      await repository.activate(
        releaseId: manifest.release.id,
        target: CurriculumActivationTarget.learner,
      );
      expect(
        (await repository.activeManifest(
          CurriculumActivationTarget.learner,
        ))?.release.id,
        manifest.release.id,
      );

      final restarted = _repository(
        store: store,
        clock: clock,
        verifier: verifier,
      );
      expect(await restarted.auditIntegrity(), isEmpty);
      expect(await restarted.loadRelease(manifest.release.id), manifest);
    },
  );

  test(
    'merges independently signed chapter shards into one preview release',
    () async {
      final first = buildScaffoldChapterShardManifest(
        releaseId: 'release.internal.shards.001',
        version: '2026.07.27+501',
        chapterOrdinal: 1,
      );
      final second = buildScaffoldChapterShardManifest(
        releaseId: first.release.id,
        version: first.release.version,
        chapterOrdinal: 2,
      );
      final firstJson = jsonEncode(first.toJson());
      final secondJson = jsonEncode(second.toJson());
      final firstEnvelope = await _signedEnvelope(
        algorithm: algorithm,
        keyPair: signingKey,
        manifest: first,
        manifestJson: firstJson,
        signedAt: clock.nowUtc(),
      );
      final secondEnvelope = await _signedEnvelope(
        algorithm: algorithm,
        keyPair: signingKey,
        manifest: second,
        manifestJson: secondJson,
        signedAt: clock.nowUtc(),
      );
      final store = MemoryKeyValueStore();
      final repository = _repository(
        store: store,
        clock: clock,
        verifier: _verifier(
          clock: clock,
          manifest: first,
          publicKeyBytes: publicKeyBytes,
          allowedChannels: const [CurriculumReleaseChannel.internal],
        ),
      );

      await repository.installSignedChapterShard(
        candidateId: 'package.internal.chapter.001',
        manifestJson: firstJson,
        envelope: firstEnvelope,
        shard: CurriculumChapterShard(
          courseSourceKey: 'harrison-sim/course/06',
          chapterSourceKey: 'harrison-sim/course/06/chapter/001',
          ordinal: 1,
        ),
      );
      await repository.installSignedChapterShard(
        candidateId: 'package.internal.chapter.002',
        manifestJson: secondJson,
        envelope: secondEnvelope,
        shard: CurriculumChapterShard(
          courseSourceKey: 'harrison-sim/course/06',
          chapterSourceKey: 'harrison-sim/course/06/chapter/002',
          ordinal: 2,
        ),
      );

      final merged = await repository.loadRelease(first.release.id);
      expect(merged, isNotNull);
      expect(
        merged!.nodes
            .where((node) => node.kind == CurriculumNodeKind.chapter)
            .map((node) => node.sourceKey),
        [
          'harrison-sim/course/06/chapter/001',
          'harrison-sim/course/06/chapter/002',
        ],
      );
      expect(await repository.auditIntegrity(), isEmpty);
      await repository.activate(
        releaseId: first.release.id,
        target: CurriculumActivationTarget.preview,
      );
      expect(
        (await repository.activeManifest(CurriculumActivationTarget.preview))
            ?.nodes
            .where((node) => node.kind == CurriculumNodeKind.chapter)
            .length,
        2,
      );

      final restarted = _repository(
        store: store,
        clock: clock,
        verifier: _verifier(
          clock: clock,
          manifest: first,
          publicKeyBytes: publicKeyBytes,
          allowedChannels: const [CurriculumReleaseChannel.internal],
        ),
      );
      expect(await restarted.auditIntegrity(), isEmpty);
      expect(
        (await restarted.loadRelease(first.release.id))?.nodes
            .where((node) => node.kind == CurriculumNodeKind.chapter)
            .length,
        2,
      );
    },
  );

  test('forged signatures and candidate drift are quarantined', () async {
    final manifest = buildPublishedManifest(
      releaseId: 'release.signed.reject',
      version: '2026.07.17+402',
    );
    final manifestJson = jsonEncode(manifest.toJson());
    final envelope = await _signedEnvelope(
      algorithm: algorithm,
      keyPair: signingKey,
      manifest: manifest,
      manifestJson: manifestJson,
      signedAt: clock.nowUtc(),
    );
    final repository = _repository(
      store: MemoryKeyValueStore(),
      clock: clock,
      verifier: _verifier(
        clock: clock,
        manifest: manifest,
        publicKeyBytes: publicKeyBytes,
      ),
    );
    final forged = CurriculumSignedReleaseEnvelope(
      keyId: envelope.keyId,
      sourceId: envelope.sourceId,
      releaseId: envelope.releaseId,
      releaseChannel: envelope.releaseChannel,
      canonicalSha256: envelope.canonicalSha256,
      canonicalByteLength: envelope.canonicalByteLength,
      transportSha256: envelope.transportSha256,
      transportByteLength: envelope.transportByteLength,
      signedAt: envelope.signedAt,
      signatureBytes: List<int>.filled(64, 7),
    );
    await expectLater(
      repository.installSignedCandidate(
        candidateId: 'signed:forged',
        manifestJson: manifestJson,
        envelope: forged,
      ),
      throwsA(
        isA<CurriculumPackageException>().having(
          (error) => error.code,
          'code',
          'release_signature_invalid',
        ),
      ),
    );
    await expectLater(
      repository.installSignedCandidate(
        candidateId: 'signed:drifted-transport',
        manifestJson: '$manifestJson ',
        envelope: envelope,
      ),
      throwsA(
        isA<CurriculumPackageException>().having(
          (error) => error.code,
          'code',
          'transport_hash_mismatch',
        ),
      ),
    );
    expect(
      (await repository.quarantineHistory()).map((entry) => entry.code),
      containsAll(['release_signature_invalid', 'transport_hash_mismatch']),
    );
    expect(await repository.inventory(), isEmpty);
  });

  test('revoked, out-of-scope, and future signatures fail closed', () async {
    final manifest = buildPublishedManifest(
      releaseId: 'release.signed.policy',
      version: '2026.07.17+403',
    );
    final manifestJson = jsonEncode(manifest.toJson());
    final envelope = await _signedEnvelope(
      algorithm: algorithm,
      keyPair: signingKey,
      manifest: manifest,
      manifestJson: manifestJson,
      signedAt: clock.nowUtc(),
    );

    for (final testCase
        in <
          ({
            String expectedCode,
            CurriculumReleaseTrustAnchor anchor,
            CurriculumSignedReleaseEnvelope envelope,
          })
        >[
          (
            expectedCode: 'revoked_release_signing_key',
            anchor: _anchor(
              manifest: manifest,
              publicKeyBytes: publicKeyBytes,
              revoked: true,
            ),
            envelope: envelope,
          ),
          (
            expectedCode: 'release_signing_scope_mismatch',
            anchor: CurriculumReleaseTrustAnchor(
              keyId: envelope.keyId,
              publicKeyBytes: publicKeyBytes,
              allowedSourceIds: const ['source.not-authorized'],
              allowedChannels: const [CurriculumReleaseChannel.stable],
              validFrom: DateTime.utc(2026, 7, 1),
            ),
            envelope: envelope,
          ),
        ]) {
      final verifier = PinnedEd25519CurriculumReleaseTrustVerifier(
        anchors: [testCase.anchor],
        clock: clock,
      );
      await expectLater(
        _verify(verifier, manifest, manifestJson, testCase.envelope),
        throwsA(
          isA<CurriculumPackageException>().having(
            (error) => error.code,
            'code',
            testCase.expectedCode,
          ),
        ),
      );
    }

    final futureEnvelope = await _signedEnvelope(
      algorithm: algorithm,
      keyPair: signingKey,
      manifest: manifest,
      manifestJson: manifestJson,
      signedAt: clock.nowUtc().add(const Duration(minutes: 6)),
    );
    await expectLater(
      _verify(
        _verifier(
          clock: clock,
          manifest: manifest,
          publicKeyBytes: publicKeyBytes,
        ),
        manifest,
        manifestJson,
        futureEnvelope,
      ),
      throwsA(
        isA<CurriculumPackageException>().having(
          (error) => error.code,
          'code',
          'release_signature_time_invalid',
        ),
      ),
    );
  });

  test(
    'signed trust is re-audited after restart and cannot downgrade',
    () async {
      final manifest = buildPublishedManifest(
        releaseId: 'release.signed.audit',
        version: '2026.07.17+404',
      );
      final manifestJson = jsonEncode(manifest.toJson());
      final envelope = await _signedEnvelope(
        algorithm: algorithm,
        keyPair: signingKey,
        manifest: manifest,
        manifestJson: manifestJson,
        signedAt: clock.nowUtc(),
      );
      final store = MemoryKeyValueStore();
      final repository = _repository(
        store: store,
        clock: clock,
        verifier: _verifier(
          clock: clock,
          manifest: manifest,
          publicKeyBytes: publicKeyBytes,
        ),
      );
      await repository.installSignedCandidate(
        candidateId: 'signed:audit',
        manifestJson: manifestJson,
        envelope: envelope,
      );
      await repository.activate(
        releaseId: manifest.release.id,
        target: CurriculumActivationTarget.learner,
      );

      final noPolicy = _repository(store: store, clock: clock);
      expect(
        (await noPolicy.auditIntegrity()).single.code,
        'release_trust_not_configured',
      );
      await expectLater(
        noPolicy.loadRelease(manifest.release.id),
        throwsA(
          isA<CurriculumPackageException>().having(
            (error) => error.code,
            'code',
            'release_trust_not_configured',
          ),
        ),
      );
      final bootstrap = await CurriculumRuntimeBootCoordinator(
        packages: noPolicy,
        catalogs: PackageCurriculumCatalogRepository(packages: noPolicy),
      ).boot(CurriculumActivationTarget.learner);
      expect(
        bootstrap.status,
        CurriculumRuntimeBootstrapStatus.integrityBlocked,
      );
      expect(bootstrap.errorCode, 'release_trust_not_configured');
      await expectLater(
        noPolicy.restoreBundledInstalledRelease(
          candidateId: 'bundle:attempted-downgrade',
          manifestJson: manifestJson,
          expectedInstalledCanonicalSha256: manifest.canonicalSha256,
          expectedCanonicalSha256: manifest.canonicalSha256,
          expectedTransportSha256: _transportSha(manifestJson),
        ),
        throwsA(
          isA<CurriculumPackageException>().having(
            (error) => error.code,
            'code',
            'signed_release_requires_signed_restore',
          ),
        ),
      );
    },
  );

  test(
    'signed reinstall upgrades identical bundled bytes without duplication',
    () async {
      final manifest = buildPublishedManifest(
        releaseId: 'release.signed.upgrade',
        version: '2026.07.17+405',
      );
      final manifestJson = jsonEncode(manifest.toJson());
      final envelope = await _signedEnvelope(
        algorithm: algorithm,
        keyPair: signingKey,
        manifest: manifest,
        manifestJson: manifestJson,
        signedAt: clock.nowUtc(),
      );
      final repository = _repository(
        store: MemoryKeyValueStore(),
        clock: clock,
        verifier: _verifier(
          clock: clock,
          manifest: manifest,
          publicKeyBytes: publicKeyBytes,
        ),
      );
      await repository.installBundledCandidate(
        candidateId: 'bundle:signed-upgrade',
        manifestJson: manifestJson,
        expectedCanonicalSha256: manifest.canonicalSha256,
        expectedTransportSha256: _transportSha(manifestJson),
      );
      final upgraded = await repository.installSignedCandidate(
        candidateId: 'signed:signed-upgrade',
        manifestJson: manifestJson,
        envelope: envelope,
      );

      expect(upgraded.alreadyInstalled, isTrue);
      expect(
        upgraded.record.trustKind,
        CurriculumPackageTrustKind.signedRelease,
      );
      expect(await repository.inventory(), hasLength(1));
      expect(await repository.auditIntegrity(), isEmpty);
    },
  );

  test('pre-trust registry bodies cannot become learner authority', () async {
    final manifest = buildPublishedManifest(
      releaseId: 'release.legacy.blocked',
      version: '2026.07.17+406',
    );
    final manifestJson = jsonEncode(manifest.toJson());
    final store = MemoryKeyValueStore();
    final repository = _repository(store: store, clock: clock);
    await repository.installBundledCandidate(
      candidateId: 'bundle:legacy-fixture',
      manifestJson: manifestJson,
      expectedCanonicalSha256: manifest.canonicalSha256,
      expectedTransportSha256: _transportSha(manifestJson),
    );
    await _mutateRegistry(store, (registry) {
      final stored =
          (registry['packages'] as Map<String, dynamic>).values.single
              as Map<String, dynamic>;
      final record = stored['record'] as Map<String, dynamic>;
      record.remove('trustKind');
      record.remove('trustKeyId');
      record.remove('trustEnvelopeSha256');
      record.remove('trustSignedAt');
      stored.remove('trustEnvelope');
    });
    final restarted = _repository(store: store, clock: clock);

    expect(
      (await restarted.inventory()).single.trustKind,
      CurriculumPackageTrustKind.legacyCallerHashes,
    );
    await expectLater(
      restarted.activate(
        releaseId: manifest.release.id,
        target: CurriculumActivationTarget.learner,
      ),
      throwsA(
        isA<CurriculumPackageException>().having(
          (error) => error.code,
          'code',
          'legacy_release_trust_blocked',
        ),
      ),
    );
  });
}

LocalCurriculumPackageRepository _repository({
  required MemoryKeyValueStore store,
  required MutableClock clock,
  CurriculumReleaseTrustVerifier? verifier,
}) => LocalCurriculumPackageRepository(
  store: store,
  clock: clock,
  idSource: SequenceIdSource([
    for (var index = 1; index <= 20; index++) 'trust-receipt.$index',
  ]),
  releaseTrustVerifier: verifier,
);

PinnedEd25519CurriculumReleaseTrustVerifier _verifier({
  required MutableClock clock,
  required CurriculumManifest manifest,
  required List<int> publicKeyBytes,
  Iterable<CurriculumReleaseChannel> allowedChannels = const [
    CurriculumReleaseChannel.stable,
  ],
}) => PinnedEd25519CurriculumReleaseTrustVerifier(
  anchors: [
    _anchor(
      manifest: manifest,
      publicKeyBytes: publicKeyBytes,
      allowedChannels: allowedChannels,
    ),
  ],
  clock: clock,
);

CurriculumReleaseTrustAnchor _anchor({
  required CurriculumManifest manifest,
  required List<int> publicKeyBytes,
  Iterable<CurriculumReleaseChannel> allowedChannels = const [
    CurriculumReleaseChannel.stable,
  ],
  bool revoked = false,
}) => CurriculumReleaseTrustAnchor(
  keyId: 'curriculum-publisher-2026-01',
  publicKeyBytes: publicKeyBytes,
  allowedSourceIds: [manifest.source.id],
  allowedChannels: allowedChannels,
  validFrom: DateTime.utc(2026, 7, 1),
  validUntil: DateTime.utc(2027),
  revoked: revoked,
);

Future<CurriculumSignedReleaseEnvelope> _signedEnvelope({
  required Ed25519 algorithm,
  required SimpleKeyPair keyPair,
  required CurriculumManifest manifest,
  required String manifestJson,
  required DateTime signedAt,
}) async {
  final canonicalJson = CanonicalJson.encode(manifest.toJson());
  final unsigned = CurriculumSignedReleaseEnvelope(
    keyId: 'curriculum-publisher-2026-01',
    sourceId: manifest.source.id,
    releaseId: manifest.release.id,
    releaseChannel: manifest.release.channel,
    canonicalSha256: manifest.canonicalSha256,
    canonicalByteLength: utf8.encode(canonicalJson).length,
    transportSha256: _transportSha(manifestJson),
    transportByteLength: utf8.encode(manifestJson).length,
    signedAt: signedAt,
    signatureBytes: List<int>.filled(64, 0),
  );
  final signature = await algorithm.sign(
    unsigned.signingBytes,
    keyPair: keyPair,
  );
  return CurriculumSignedReleaseEnvelope(
    keyId: unsigned.keyId,
    sourceId: unsigned.sourceId,
    releaseId: unsigned.releaseId,
    releaseChannel: unsigned.releaseChannel,
    canonicalSha256: unsigned.canonicalSha256,
    canonicalByteLength: unsigned.canonicalByteLength,
    transportSha256: unsigned.transportSha256,
    transportByteLength: unsigned.transportByteLength,
    signedAt: unsigned.signedAt,
    signatureBytes: signature.bytes,
  );
}

Future<void> _verify(
  CurriculumReleaseTrustVerifier verifier,
  CurriculumManifest manifest,
  String manifestJson,
  CurriculumSignedReleaseEnvelope envelope,
) => verifier.verifyCandidate(
  manifest: manifest,
  canonicalSha256: manifest.canonicalSha256,
  canonicalByteLength: utf8
      .encode(CanonicalJson.encode(manifest.toJson()))
      .length,
  transportSha256: _transportSha(manifestJson),
  transportByteLength: utf8.encode(manifestJson).length,
  envelope: envelope,
);

String _transportSha(String value) =>
    hashes.sha256.convert(utf8.encode(value)).toString();

Future<void> _mutateRegistry(
  MemoryKeyValueStore store,
  void Function(Map<String, dynamic> registry) mutate,
) async {
  final raw = await store.read(LocalCurriculumPackageRepository.stateKey);
  final registry = jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
  mutate(registry);
  await store.write(LocalCurriculumPackageRepository.stateKey, registry);
}

import 'dart:convert';
import 'dart:typed_data';

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
    clock = MutableClock(DateTime.utc(2026, 7, 27, 12, 30));
    algorithm = Ed25519();
    signingKey = await algorithm.newKeyPairFromSeed(
      List<int>.generate(32, (index) => index + 11),
    );
    publicKeyBytes = (await signingKey.extractPublicKey()).bytes;
  });

  test(
    'verifies, installs, composes, and activates an internal chapter release',
    () async {
      final fixture = await _signedTransport(
        algorithm: algorithm,
        signingKey: signingKey,
        manifest: buildPublishedManifest(
          releaseId: 'release.personal.respiratory.001',
          version: '2026.07.27+701',
          channel: CurriculumReleaseChannel.internal,
        ),
        signedAt: clock.nowUtc(),
        packageId: 'pkg.personal.respiratory.001',
      );
      final gateway = _ContentGateway(
        manifest: fixture.channelManifest,
        packageBytes: {fixture.package.id: fixture.bytes},
      );
      final repository = _repository(
        clock: clock,
        manifest: fixture.manifest,
        publicKeyBytes: publicKeyBytes,
      );
      final channelState = PersonalContentChannelStateRepository(
        store: MemoryKeyValueStore(),
        clock: clock,
      );
      final coordinator = PersonalContentDeliveryCoordinator(
        gateway: gateway,
        packages: repository,
        channelState: channelState,
      );

      final result = await coordinator.refresh(accessToken: 'device-token');

      expect(result.kind, PersonalContentDeliveryResultKind.activated);
      expect(result.installedShards, 1);
      expect(result.activationChanged, isTrue);
      expect(
        (await repository.activeManifest(
          CurriculumActivationTarget.learner,
        ))?.release.id,
        fixture.manifest.release.id,
      );
      expect((await repository.inventory()).single.isChapterShard, isTrue);
      final accepted = (await channelState.read()).acceptedHead;
      expect(accepted, fixture.channelManifest.head);
      expect((await channelState.read()).latestFailure, isNull);

      final unchanged = await coordinator.refresh(accessToken: 'device-token');
      expect(unchanged.kind, PersonalContentDeliveryResultKind.notModified);
      expect(
        gateway.lastIfNoneMatch,
        fixture.channelManifest.head.manifestSha256,
      );
    },
  );

  test(
    'rejects tampered chapter bytes without changing the accepted head',
    () async {
      final fixture = await _signedTransport(
        algorithm: algorithm,
        signingKey: signingKey,
        manifest: buildPublishedManifest(
          releaseId: 'release.personal.kidney.001',
          version: '2026.07.27+702',
          channel: CurriculumReleaseChannel.internal,
        ),
        signedAt: clock.nowUtc(),
        packageId: 'pkg.personal.kidney.001',
      );
      final gateway = _ContentGateway(
        manifest: fixture.channelManifest,
        packageBytes: {
          fixture.package.id: Uint8List.fromList(
            utf8.encode('{"tampered":true}'),
          ),
        },
      );
      final repository = _repository(
        clock: clock,
        manifest: fixture.manifest,
        publicKeyBytes: publicKeyBytes,
      );
      final channelState = PersonalContentChannelStateRepository(
        store: MemoryKeyValueStore(),
        clock: clock,
      );
      final coordinator = PersonalContentDeliveryCoordinator(
        gateway: gateway,
        packages: repository,
        channelState: channelState,
      );

      await expectLater(
        coordinator.refresh(accessToken: 'device-token'),
        throwsA(
          isA<PersonalContentDeliveryException>().having(
            (error) => error.code,
            'code',
            'content_transport_hash_mismatch',
          ),
        ),
      );

      final state = await channelState.read();
      expect(state.acceptedHead, isNull);
      expect(state.latestFailure?.code, 'content_transport_hash_mismatch');
      expect(
        await repository.activeManifest(CurriculumActivationTarget.learner),
        isNull,
      );
    },
  );
}

final class _ContentGateway implements PersonalSyncGateway {
  _ContentGateway({required this.manifest, required this.packageBytes});

  final ContentManifest manifest;
  final Map<ContentPackageId, Uint8List> packageBytes;
  String? lastIfNoneMatch;

  @override
  Future<ContentManifest?> fetchManifest({
    required String accessToken,
    String? ifNoneMatch,
  }) async {
    lastIfNoneMatch = ifNoneMatch;
    if (ifNoneMatch == manifest.head.manifestSha256) return null;
    return manifest;
  }

  @override
  Future<Uint8List> downloadPackage({
    required String accessToken,
    required ContentPackageId packageId,
  }) async {
    final value = packageBytes[packageId];
    if (value == null) {
      throw const PersonalSyncApiException(
        code: 'content_package_missing',
        message: 'Test package is missing.',
        statusCode: 404,
      );
    }
    return Uint8List.fromList(value);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<
  ({
    CurriculumManifest manifest,
    SignedChapterPackage package,
    ContentManifest channelManifest,
    Uint8List bytes,
  })
>
_signedTransport({
  required Ed25519 algorithm,
  required SimpleKeyPair signingKey,
  required CurriculumManifest manifest,
  required DateTime signedAt,
  required ContentPackageId packageId,
}) async {
  final manifestJson = jsonEncode(manifest.toJson());
  final bytes = Uint8List.fromList(utf8.encode(manifestJson));
  final envelope = await _signedEnvelope(
    algorithm: algorithm,
    keyPair: signingKey,
    manifest: manifest,
    manifestJson: manifestJson,
    signedAt: signedAt,
  );
  final signature = base64Url
      .encode(envelope.signatureBytes)
      .replaceAll('=', '');
  final authorization = ChapterPackageAuthorization(
    keyId: envelope.keyId,
    sourceId: envelope.sourceId,
    releaseId: envelope.releaseId,
    releaseChannel: PersonalContentChannel.internal,
    canonicalSha256: envelope.canonicalSha256,
    canonicalByteLength: envelope.canonicalByteLength,
    transportSha256: envelope.transportSha256,
    transportByteLength: envelope.transportByteLength,
    signedAt: envelope.signedAt,
    signature: signature,
  );
  final package = SignedChapterPackage(
    id: packageId,
    releaseId: manifest.release.id,
    courseSourceKey: 'harrison-sim/course/06',
    chapterSourceKey: 'harrison-sim/course/06/chapter/001',
    ordinal: 1,
    byteLength: bytes.length,
    sha256: hashes.sha256.convert(bytes).toString(),
    signature: signature,
    objectKey: 'internal/$packageId.json',
    authorization: authorization,
  );
  final manifestHash = ContentManifest.canonicalSha256For(
    schemaVersion: ContentManifest.currentSchemaVersion,
    channel: PersonalContentChannel.internal,
    releaseId: manifest.release.id,
    sequence: 1,
    updatedAt: signedAt,
    packages: [package],
  );
  final channelManifest = ContentManifest(
    schemaVersion: ContentManifest.currentSchemaVersion,
    head: PersonalChannelHead(
      releaseId: manifest.release.id,
      manifestSha256: manifestHash,
      sequence: 1,
      updatedAt: signedAt,
    ),
    packages: [package],
  );
  return (
    manifest: manifest,
    package: package,
    channelManifest: channelManifest,
    bytes: bytes,
  );
}

LocalCurriculumPackageRepository _repository({
  required MutableClock clock,
  required CurriculumManifest manifest,
  required List<int> publicKeyBytes,
}) => LocalCurriculumPackageRepository(
  store: MemoryKeyValueStore(),
  clock: clock,
  idSource: SequenceIdSource([
    for (var index = 1; index <= 20; index++) 'content-receipt.$index',
  ]),
  releaseTrustVerifier: PinnedEd25519CurriculumReleaseTrustVerifier(
    anchors: [
      CurriculumReleaseTrustAnchor(
        keyId: 'curriculum-publisher-2026-01',
        publicKeyBytes: publicKeyBytes,
        allowedSourceIds: [manifest.source.id],
        allowedChannels: const [CurriculumReleaseChannel.internal],
        validFrom: DateTime.utc(2026, 7, 1),
        validUntil: DateTime.utc(2027),
      ),
    ],
    clock: clock,
  ),
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
    transportSha256: hashes.sha256
        .convert(utf8.encode(manifestJson))
        .toString(),
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

import 'package:synapse_core/synapse_core.dart';
import 'package:test/test.dart';

void main() {
  test('encrypted event round-trips without weakening associated data', () {
    final event = EncryptedSyncEvent(
      id: 'evt_001',
      workspaceId: 'wrk_001',
      deviceId: 'dev_windows',
      stream: 'academy.progress',
      entityHash: 'a' * 64,
      kind: PersonalSyncEventKind.progress,
      mergePolicy: PersonalSyncMergePolicy.monotonicMaximum,
      logicalRevision: 4,
      keyVersion: 1,
      idempotencyKey: 'idem_001',
      clientCreatedAt: DateTime.utc(2026, 7, 26, 10),
      nonce: 'YWJjZGVmZ2hpamts',
      cipherText: 'ZW5jcnlwdGVk',
      authenticationTag: 'YXV0aGVudGljYXRpb24',
    );

    expect(EncryptedSyncEvent.fromJson(event.toJson()), event);
    expect(event.canonicalAssociatedData(), contains('"logicalRevision":4'));
    expect(event.canonicalAssociatedData(), isNot(contains('cipherText')));
  });

  test('content manifest is internal-only and chapter sharded', () {
    final manifest = ContentManifest(
      schemaVersion: 1,
      head: PersonalChannelHead(
        releaseId: 'release_respiratory_001',
        manifestSha256: 'b' * 64,
        sequence: 1,
        updatedAt: DateTime.utc(2026, 7, 26),
      ),
      packages: [
        SignedChapterPackage(
          id: 'pkg_respiratory_001',
          releaseId: 'release_respiratory_001',
          courseSourceKey: 'part_07',
          chapterSourceKey: 'part_07/chapter_001',
          ordinal: 1,
          byteLength: 2048,
          sha256: 'c' * 64,
          signature: 'c2lnbmF0dXJl',
          objectKey: 'part_07/chapter_001/package.json',
        ),
      ],
    );

    final restored = ContentManifest.fromJson(manifest.toJson());
    expect(restored, manifest);
    expect(restored.head.channel, PersonalContentChannel.internal);
    expect(restored.packages.single.ordinal, 1);
  });

  test(
    'v2 content manifest binds its channel head to signed package metadata',
    () {
      final signedAt = DateTime.utc(2026, 7, 27, 12, 30);
      final authorization = ChapterPackageAuthorization(
        keyId: 'k1_internal_2026',
        sourceId: 'simulated_harrison',
        releaseId: 'release_respiratory_001',
        releaseChannel: PersonalContentChannel.internal,
        canonicalSha256: 'a' * 64,
        canonicalByteLength: 1024,
        transportSha256: 'b' * 64,
        transportByteLength: 2048,
        signedAt: signedAt,
        signature: 'c2lnbmF0dXJl',
      );
      final package = SignedChapterPackage(
        id: 'pkg_respiratory_001',
        releaseId: 'release_respiratory_001',
        courseSourceKey: 'part_07',
        chapterSourceKey: 'part_07/chapter_001',
        ordinal: 1,
        byteLength: 2048,
        sha256: 'b' * 64,
        signature: 'c2lnbmF0dXJl',
        objectKey: 'part_07/chapter_001/package.json',
        authorization: authorization,
      );
      final digest = ContentManifest.canonicalSha256For(
        schemaVersion: ContentManifest.currentSchemaVersion,
        channel: PersonalContentChannel.internal,
        releaseId: 'release_respiratory_001',
        sequence: 2,
        updatedAt: signedAt,
        packages: [package],
      );
      final manifest = ContentManifest(
        schemaVersion: ContentManifest.currentSchemaVersion,
        head: PersonalChannelHead(
          releaseId: 'release_respiratory_001',
          manifestSha256: digest,
          sequence: 2,
          updatedAt: signedAt,
        ),
        packages: [package],
      );

      expect(ContentManifest.fromJson(manifest.toJson()), manifest);
      expect(
        () => ContentManifest(
          schemaVersion: ContentManifest.currentSchemaVersion,
          head: PersonalChannelHead(
            releaseId: 'release_respiratory_001',
            manifestSha256: 'f' * 64,
            sequence: 2,
            updatedAt: signedAt,
          ),
          packages: [package],
        ),
        throwsArgumentError,
      );
    },
  );

  test('pairing session expiry is deterministic', () {
    final createdAt = DateTime.utc(2026, 7, 26, 10);
    final session = PairingSession(
      id: 'pair_001',
      pairingCode: '123-456',
      candidateDeviceId: 'dev_android',
      candidateLabel: 'Pixel',
      candidatePlatform: PersonalDevicePlatform.android,
      candidateSigningPublicKey: 'c2lnbmluZ19wdWJsaWNfa2V5',
      candidateEncryptionPublicKey: 'ZW5jcnlwdGlvbl9wdWJsaWNfa2V5',
      state: PairingSessionState.pending,
      createdAt: createdAt,
      expiresAt: createdAt.add(const Duration(minutes: 5)),
    );

    expect(
      session.isExpiredAt(createdAt.add(const Duration(minutes: 4))),
      isFalse,
    );
    expect(
      session.isExpiredAt(createdAt.add(const Duration(minutes: 5))),
      isTrue,
    );
  });
}

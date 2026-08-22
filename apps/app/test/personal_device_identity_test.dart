import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synapse_app/data/learner_data/secure_learner_data_key_provider.dart';
import 'package:synapse_app/data/personal_sync/personal_device_identity.dart';
import 'package:synapse_app/data/personal_sync/personal_workspace_key_store.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_services/synapse_services.dart';

void main() {
  test(
    'persists one device identity and signs a verifiable challenge',
    () async {
      final store = _MemorySecureStringStore();
      final first = await PersonalDeviceIdentityStore(
        secureStore: store,
        platform: PersonalDevicePlatform.windows,
        randomBytes: _fixtureBytes,
        now: _fixtureNow,
      ).loadOrCreate(label: 'My Windows');
      final restarted = await PersonalDeviceIdentityStore(
        secureStore: store,
        platform: PersonalDevicePlatform.windows,
        randomBytes: (_) => fail('a stored identity must not be regenerated'),
        now: _fixtureNow,
      ).loadOrCreate(label: 'Ignored after restore');

      const nonce = 'nonce_20260726';
      final timestamp = DateTime.utc(2026, 7, 26, 12, 0);
      final signature = base64Url.decode(
        _pad(
          await first.signDeviceTokenChallenge(
            nonce: nonce,
            timestamp: timestamp,
          ),
        ),
      );
      final verified = await Ed25519().verify(
        utf8.encode(
          'synapse-device-token-v1\n${first.id}\n$nonce\n'
          '${timestamp.toIso8601String()}',
        ),
        signature: Signature(
          signature,
          publicKey: SimplePublicKey(
            base64Url.decode(_pad(first.signingPublicKey)),
            type: KeyPairType.ed25519,
          ),
        ),
      );

      expect(restarted.id, first.id);
      expect(restarted.signingPublicKey, first.signingPublicKey);
      expect(restarted.encryptionPublicKey, first.encryptionPublicKey);
      expect(verified, isTrue);
      expect(store.values.keys, [PersonalDeviceIdentityStore.storageKey]);
    },
  );

  test(
    'sealed workspace key is recipient-bound and rejects tampering',
    () async {
      final recipient = await PersonalDeviceIdentityStore(
        secureStore: _MemorySecureStringStore(),
        platform: PersonalDevicePlatform.android,
        randomBytes: _fixtureBytes,
        now: _fixtureNow,
      ).loadOrCreate(label: 'Personal phone');
      final workspaceKey = WorkspaceSyncKey(
        version: 3,
        bytes: _fixtureBytes(32),
      );
      final sealer = WorkspaceKeySealer();
      final sealed = await sealer.seal(
        workspaceKey: workspaceKey,
        recipientEncryptionPublicKey: recipient.encryptionPublicKey,
      );
      final restored = await sealer.unseal(
        sealedWorkspaceKey: sealed,
        recipient: recipient,
      );
      final tampered =
          '${sealed.substring(0, sealed.length - 1)}'
          '${sealed.endsWith('A') ? 'B' : 'A'}';

      expect(restored.version, workspaceKey.version);
      expect(restored.bytes, workspaceKey.bytes);
      await expectLater(
        sealer.unseal(sealedWorkspaceKey: tampered, recipient: recipient),
        throwsA(
          isA<PersonalDeviceIdentityException>().having(
            (error) => error.code,
            'code',
            'workspace_key_unseal_failed',
          ),
        ),
      );
    },
  );

  test(
    'workspace keyring retains old versions while activating a newer key',
    () async {
      final store = _MemorySecureStringStore();
      final keys = SecureWorkspaceSyncKeyProvider(
        secureStore: store,
        randomBytes: _fixtureBytes,
      );
      final initial = await keys.createInitialKey();
      final rotated = WorkspaceSyncKey(
        version: 2,
        bytes: _fixtureBytes(32, 41),
      );

      await keys.install(rotated);
      final restarted = SecureWorkspaceSyncKeyProvider(
        secureStore: store,
        randomBytes: (_) => fail('stored keyring must not generate a new key'),
      );

      expect((await restarted.currentKey()).version, 2);
      expect((await restarted.readKey(1))?.bytes, initial.bytes);
      expect((await restarted.readKey(2))?.bytes, rotated.bytes);
      expect(await restarted.readKey(99), isNull);
    },
  );

  test(
    'corrupt identity fails closed instead of creating a replacement',
    () async {
      final store = _MemorySecureStringStore({
        PersonalDeviceIdentityStore.storageKey: '{"schemaVersion":1}',
      });
      final identityStore = PersonalDeviceIdentityStore(
        secureStore: store,
        platform: PersonalDevicePlatform.web,
        randomBytes: (_) => fail('corrupt identity must not be replaced'),
      );

      await expectLater(
        identityStore.loadOrCreate(label: 'Browser'),
        throwsA(
          isA<PersonalDeviceIdentityException>().having(
            (error) => error.code,
            'code',
            'corrupt_device_identity',
          ),
        ),
      );
      expect(store.values.values.single, '{"schemaVersion":1}');
    },
  );
}

DateTime _fixtureNow() => DateTime.utc(2026, 7, 26, 12);

List<int> _fixtureBytes(int length, [int offset = 0]) =>
    List<int>.generate(length, (index) => (index * 19 + 7 + offset) & 0xff);

String _pad(String value) => value.padRight((value.length + 3) ~/ 4 * 4, '=');

final class _MemorySecureStringStore implements SecureStringStore {
  _MemorySecureStringStore([Map<String, String>? seed]) : values = {...?seed};

  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

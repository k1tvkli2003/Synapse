import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_services/synapse_services.dart';
import 'package:test/test.dart';

void main() {
  test('workspace envelope is authenticated and server-safe', () async {
    final keys = _MemoryWorkspaceKeys(
      WorkspaceSyncKey(
        version: 1,
        bytes: List<int>.generate(32, (index) => index + 1),
      ),
    );
    final cipher = PersonalSyncEnvelopeCipher(keys: keys);
    final encrypted = await cipher.encrypt(
      PersonalSyncClearEvent(
        id: 'evt_001',
        workspaceId: 'wrk_001',
        deviceId: 'dev_windows',
        stream: 'academy.note',
        entityId: 'note.private.001',
        kind: PersonalSyncEventKind.note,
        mergePolicy: PersonalSyncMergePolicy.lastWriteWins,
        logicalRevision: 1,
        idempotencyKey: 'idem_001',
        clientCreatedAt: DateTime.utc(2026, 7, 26, 12),
        payload: const {'body': 'Private renal synthesis'},
      ),
    );

    expect(encrypted.toJson().toString(), isNot(contains('note.private.001')));
    expect(
      encrypted.toJson().toString(),
      isNot(contains('Private renal synthesis')),
    );

    final clear = await cipher.decrypt(encrypted);
    expect(clear.entityId, 'note.private.001');
    expect(clear.payload['body'], 'Private renal synthesis');

    final tampered = EncryptedSyncEvent.fromJson({
      ...encrypted.toJson(),
      'logicalRevision': 2,
    });
    await expectLater(
      cipher.decrypt(tampered),
      throwsA(
        isA<PersonalSyncCryptoException>().having(
          (error) => error.code,
          'code',
          'sync_event_authentication_failed',
        ),
      ),
    );
  });
}

final class _MemoryWorkspaceKeys implements WorkspaceSyncKeyProvider {
  _MemoryWorkspaceKeys(this.key);

  final WorkspaceSyncKey key;

  @override
  Future<WorkspaceSyncKey> currentKey() async => key;

  @override
  Future<WorkspaceSyncKey?> readKey(int version) async =>
      version == key.version ? key : null;
}

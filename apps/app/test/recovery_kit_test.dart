import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:synapse_app/data/personal_sync/recovery_kit.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_services/synapse_services.dart';

void main() {
  test(
    'recovery kit protects the key history and restores its verifier',
    () async {
      final codec = RecoveryKitCodec(
        randomBytes: _SequencedBytes().next,
        now: () => DateTime.utc(2026, 7, 27, 8),
      );
      final draft = await codec.prepare(
        passphrase: 'a precise personal recovery passphrase',
      );
      final kit = await draft.seal(
        workspace: PersonalWorkspace(
          id: 'wrk_personal',
          keyVersion: 2,
          recoveryGeneration: 3,
          createdAt: DateTime.utc(2026, 7, 27),
        ),
        keys: [
          WorkspaceSyncKey(version: 1, bytes: List<int>.filled(32, 0x31)),
          WorkspaceSyncKey(version: 2, bytes: List<int>.filled(32, 0x62)),
        ],
      );
      final serialized = kit.serialize();
      final restored = await codec.open(
        serialized: serialized,
        passphrase: 'a precise personal recovery passphrase',
      );

      expect(serialized, contains('pbkdf2-hmac-sha256'));
      expect(
        serialized,
        isNot(contains(base64Url.encode(List<int>.filled(32, 0x31)))),
      );
      expect(restored.workspaceId, 'wrk_personal');
      expect(restored.recoveryGeneration, 3);
      expect(restored.recoveryVerifierSha256, draft.recoveryVerifierSha256);
      expect(restored.keys.map((key) => key.version), [1, 2]);
      expect(restored.newestKey.version, 2);
    },
  );

  test('recovery kit rejects an incorrect passphrase and tampering', () async {
    final codec = RecoveryKitCodec(
      randomBytes: _SequencedBytes().next,
      now: () => DateTime.utc(2026, 7, 27, 8),
    );
    final draft = await codec.prepare(
      passphrase: 'another precise recovery passphrase',
    );
    final serialized = (await draft.seal(
      workspace: PersonalWorkspace(
        id: 'wrk_personal',
        keyVersion: 1,
        recoveryGeneration: 1,
        createdAt: DateTime.utc(2026, 7, 27),
      ),
      keys: [WorkspaceSyncKey(version: 1, bytes: List<int>.filled(32, 0x62))],
    )).serialize();

    await expectLater(
      codec.open(
        serialized: serialized,
        passphrase: 'a completely different passphrase',
      ),
      throwsA(
        isA<RecoveryKitException>().having(
          (error) => error.code,
          'code',
          'recovery_kit_authentication_failed',
        ),
      ),
    );
    final tampered = '${serialized.substring(0, serialized.length - 2)}xx';
    await expectLater(
      codec.open(
        serialized: tampered,
        passphrase: 'another precise recovery passphrase',
      ),
      throwsA(isA<RecoveryKitException>()),
    );
  });
}

final class _SequencedBytes {
  int _generation = 0;

  List<int> next(int length) {
    final generation = _generation++;
    return List<int>.generate(
      length,
      (index) => (index * 17 + generation * 53 + 11) & 0xff,
    );
  }
}

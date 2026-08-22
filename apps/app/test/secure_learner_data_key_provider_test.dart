import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:synapse_app/data/learner_data/secure_learner_data_key_provider.dart';
import 'package:synapse_services/synapse_services.dart';

void main() {
  test(
    'creates one secure key envelope and restores it after restart',
    () async {
      final secureStore = _MemorySecureStringStore();
      final provider = SecureLearnerDataKeyProvider(
        secureStore: secureStore,
        randomBytes: _fixtureBytes,
      );

      final first = await provider.currentKey();
      final concurrent = await Future.wait([
        provider.currentKey(),
        provider.currentKey(),
      ]);
      final restarted = SecureLearnerDataKeyProvider(
        secureStore: secureStore,
        randomBytes: (_) => fail('restart must not regenerate key material'),
      );
      final restored = await restarted.currentKey();

      expect(first.version, 1);
      expect(first.bytes, _fixtureBytes(32));
      expect(concurrent.map((key) => key.bytes), everyElement(first.bytes));
      expect(restored.bytes, first.bytes);
      expect(secureStore.writeCount, 1);
      expect(secureStore.values.keys, [
        SecureLearnerDataKeyProvider.storageKey,
      ]);
      expect(
        secureStore.values.values.single,
        isNot(contains(first.bytes.join())),
      );
    },
  );

  test('corrupt secure envelope fails closed without replacement', () async {
    final secureStore = _MemorySecureStringStore({
      SecureLearnerDataKeyProvider.storageKey:
          '{"schemaVersion":1,"keyVersion":1,"keyMaterial":"short"}',
    });
    final original = secureStore.values.values.single;
    final provider = SecureLearnerDataKeyProvider(
      secureStore: secureStore,
      randomBytes: (_) => fail('corrupt key must never be silently replaced'),
    );

    await expectLater(
      provider.currentKey(),
      throwsA(
        isA<LearnerDataPlaneException>()
            .having(
              (error) => error.code,
              'code',
              'corrupt_learner_data_key_envelope',
            )
            .having(
              (error) => error.toString(),
              'privacy-safe error',
              isNot(contains('short')),
            ),
      ),
    );
    expect(secureStore.values.values.single, original);
    expect(secureStore.writeCount, 0);
  });

  test('unknown key versions are not substituted', () async {
    final provider = SecureLearnerDataKeyProvider(
      secureStore: _MemorySecureStringStore(),
      randomBytes: _fixtureBytes,
    );

    expect(await provider.readKey(2), isNull);
  });

  test(
    'secure-storage stalls fail closed and a later call may retry',
    () async {
      final secureStore = _StalledSecureStringStore();
      final provider = SecureLearnerDataKeyProvider(
        secureStore: secureStore,
        randomBytes: _fixtureBytes,
        operationTimeout: const Duration(milliseconds: 10),
      );

      await expectLater(
        provider.currentKey(),
        throwsA(
          isA<LearnerDataPlaneException>().having(
            (error) => error.code,
            'code',
            'secure_learner_data_key_read_timeout',
          ),
        ),
      );
      await expectLater(
        provider.currentKey(),
        throwsA(isA<LearnerDataPlaneException>()),
      );
      expect(secureStore.readCount, 2);
      expect(secureStore.writeCount, 0);
    },
  );
}

List<int> _fixtureBytes(int length) =>
    List<int>.generate(length, (index) => (index * 19 + 7) & 0xff);

final class _MemorySecureStringStore implements SecureStringStore {
  _MemorySecureStringStore([Map<String, String>? seed]) : values = {...?seed};

  final Map<String, String> values;
  int writeCount = 0;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    writeCount++;
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

final class _StalledSecureStringStore implements SecureStringStore {
  int readCount = 0;
  int writeCount = 0;

  @override
  Future<String?> read(String key) {
    readCount += 1;
    return Completer<String?>().future;
  }

  @override
  Future<void> write(String key, String value) {
    writeCount += 1;
    return Completer<void>().future;
  }

  @override
  Future<void> delete(String key) => Completer<void>().future;
}

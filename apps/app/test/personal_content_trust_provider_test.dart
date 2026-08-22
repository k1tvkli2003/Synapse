import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synapse_app/state/app_providers.dart';
import 'package:synapse_app/state/curriculum_provider.dart';
import 'package:synapse_config/synapse_config.dart';
import 'package:synapse_foundation/synapse_foundation.dart';
import 'package:synapse_services/synapse_services.dart';

void main() {
  test('decodes a public internal-only curriculum trust keyring', () {
    final publicKey = base64Url
        .encode(List<int>.generate(32, (index) => index + 1))
        .replaceAll('=', '');
    final config = AppConfig(
      personalContentTrustAnchorsJson: jsonEncode([
        {
          'keyId': 'publisher_internal_2026',
          'publicKey': publicKey,
          'allowedSourceIds': ['source.harrison-sim'],
          'validFrom': '2026-07-01T00:00:00.000Z',
          'validUntil': '2027-01-01T00:00:00.000Z',
          'revoked': false,
        },
      ]),
    );
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        clockProvider.overrideWithValue(
          MutableClock(DateTime.utc(2026, 7, 27)),
        ),
      ],
    );
    addTearDown(container.dispose);

    final verifier = container.read(personalContentTrustVerifierProvider);

    expect(verifier, isA<PinnedEd25519CurriculumReleaseTrustVerifier>());
  });

  test('rejects malformed content trust JSON rather than widening trust', () {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(personalContentTrustAnchorsJson: '{}'),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      () => container.read(personalContentTrustVerifierProvider),
      throwsA(isA<FormatException>()),
    );
  });
}

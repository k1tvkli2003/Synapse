import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synapse_app/brand/synapse_identity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'restored LUMA identity assets resolve from the Flutter bundle',
    () async {
      const iconAssets = <String>[
        SynapseIdentityAssets.appIcon1024,
        SynapseIdentityAssets.appIcon512,
        SynapseIdentityAssets.appIcon256,
        SynapseIdentityAssets.appIcon96,
        SynapseIdentityAssets.appIcon48,
        SynapseIdentityAssets.appIcon24,
        SynapseIdentityAssets.appIcon16,
        SynapseIdentityAssets.appIconAdaptive,
        SynapseIdentityAssets.appIconMonochrome,
      ];

      final mascotAssets = <String>[
        for (final pose in SynapseCompanionPose.values)
          for (final pixels in const [256, 512, 1024])
            SynapseIdentityAssets.mascot(pose, pixels),
      ];

      for (final asset in [...iconAssets, ...mascotAssets]) {
        final bytes = await rootBundle.load(asset);
        expect(bytes.lengthInBytes, greaterThan(0), reason: asset);
      }
    },
  );

  test('runtime identity constants cannot drift back to MCR4', () {
    final activeAssets = <String>[
      SynapseIdentityAssets.appIcon1024,
      SynapseIdentityAssets.appIconAdaptive,
      for (final pose in SynapseCompanionPose.values)
        SynapseIdentityAssets.mascot(pose, 256),
    ];

    expect(
      activeAssets,
      everyElement(startsWith('assets/identity/luma_facefront/')),
    );
    expect(activeAssets, everyElement(isNot(contains('mcr4_companion'))));
  });
}

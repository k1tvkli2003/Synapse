import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_test_fixtures/synapse_test_fixtures.dart';
import 'package:test/test.dart';

void main() {
  test('fixture package covers all declared fixture families', () {
    expect(FixtureRoutes.all, isNotEmpty);
    expect(FixtureLocales.all, hasLength(2));
    expect(
      FixturePlatforms.all,
      hasLength(FixtureOperatingSystem.values.length),
    );
    expect(FixtureEvents.all, hasLength(10));
    expect(FixtureSchemas.eventEnvelope['schemaVersion'], 1);
    expect(FixtureModels.concept.id, startsWith('concept.fixture.'));
  });

  test('English and Persian catalogs have exact key parity', () {
    expect(
      FixtureLocales.english.strings.keys.toSet(),
      FixtureLocales.persian.strings.keys.toSet(),
    );
    expect(FixtureLocales.persian.direction, FixtureTextDirection.rtl);
  });

  test('every event fixture uses the versioned production codec', () {
    for (final event in FixtureEvents.all) {
      final encoded = SynapseEventCodec.encode(event);
      expect(encoded['schemaVersion'], SynapseEventCodec.currentSchemaVersion);
      expect(SynapseEventCodec.decode(encoded), isA<SynapseEvent>());
    }
  });

  test('route fixture locations are concrete absolute locations', () {
    for (final route in FixtureRoutes.all) {
      expect(route.location, startsWith('/'));
      expect(route.location, isNot(contains(':')));
    }
  });
}

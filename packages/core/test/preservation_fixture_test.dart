import 'dart:convert';
import 'dart:io';

import 'package:synapse_core/synapse_core.dart';
import 'package:test/test.dart';

const _fixturePath =
    '../../contracts/preservation/archived-domain-fixtures.v1.json';

void main() {
  late Map<String, dynamic> archive;

  setUpAll(() {
    final file =
        [
          File(_fixturePath),
          File('contracts/preservation/archived-domain-fixtures.v1.json'),
        ].firstWhere(
          (candidate) => candidate.existsSync(),
          orElse: () => File(_fixturePath),
        );
    expect(
      file.existsSync(),
      isTrue,
      reason:
          'Run from packages/core; missing preservation archive at '
          '${file.absolute.path}',
    );
    archive = Map<String, dynamic>.from(
      jsonDecode(file.readAsStringSync()) as Map,
    );
  });

  test('archived domain models round-trip without schema drift', () {
    final models = Map<String, dynamic>.from(archive['models'] as Map);

    final conceptJson = _map(models['Concept']);
    expect(Concept.fromJson(conceptJson).toJson(), equals(conceptJson));

    final masteryJson = _map(models['ConceptMastery']);
    expect(ConceptMastery.fromJson(masteryJson).toJson(), equals(masteryJson));

    final srsJson = _map(models['SrsCard']);
    expect(SrsCard.fromJson(srsJson).toJson(), equals(srsJson));

    final profileJson = _map(models['UserProfile']);
    expect(UserProfile.fromJson(profileJson).toJson(), equals(profileJson));

    expect(
      models.keys.toSet(),
      equals({'Concept', 'ConceptMastery', 'SrsCard', 'UserProfile'}),
      reason: 'Every archived model needs an explicit compatibility adapter.',
    );
  });

  test('all archived SynapseEvent variants round-trip exactly', () {
    final events = (archive['events'] as List)
        .map((value) => _map(value))
        .toList(growable: false);

    final encoded = events
        .map(SynapseEventCodec.decodeLegacy)
        .map(SynapseEventCodec.encodeLegacy)
        .toList(growable: false);

    expect(encoded, equals(events));
    expect(
      events.map((event) => event['type']).toSet(),
      equals({
        'ConceptStudied',
        'ConceptStruggled',
        'ItemMastered',
        'LessonCompleted',
        'CaseCompleted',
        'RewardGranted',
        'StreakChanged',
        'ContentCreated',
        'SocialInteraction',
        'QuestProgressed',
      }),
      reason:
          'Every legacy event type requires deliberate decode/encode logic.',
    );
  });
}

Map<String, dynamic> _map(Object? value) =>
    Map<String, dynamic>.from(value! as Map);

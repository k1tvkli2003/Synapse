import 'package:synapse_config/synapse_config.dart';
import 'package:synapse_core/synapse_core.dart';

abstract final class FixtureSchemas {
  static const environment = AppConfig(environment: AppEnvironment.test);

  static final eventEnvelope = SynapseEventCodec.encode(
    LessonCompleted(
      source: ModuleKey.terms,
      correct: 1,
      total: 1,
      conceptIds: const ['concept.fixture.syncope'],
      at: DateTime.utc(2026, 7, 17, 12),
    ),
  );

  static const backend = <String, Object>{
    'schemaVersion': 1,
    'tables': ['profiles', 'game_states'],
    'policies': ['owner_select', 'owner_update'],
  };
}

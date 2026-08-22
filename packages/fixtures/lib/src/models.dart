import 'package:synapse_core/synapse_core.dart';

abstract final class FixtureModels {
  static final timestamp = DateTime.utc(2026, 7, 17, 12);

  static const concept = Concept(
    id: 'concept.fixture.syncope',
    name: 'Fixture clinical concept',
    domain: ConceptDomain.clinical,
    tags: ['fixture'],
  );

  static final srsCard = SrsCard(
    id: 'srs.fixture.001',
    ownerId: 'user.fixture.001',
    origin: SrsOrigin.cards,
    front: 'Synthetic prompt',
    back: 'Synthetic answer',
    conceptId: concept.id,
    dueAt: timestamp,
  );

  static final user = UserProfile(
    id: 'user.fixture.001',
    handle: 'fixture_learner',
    displayName: 'Fixture Learner',
    role: UserRole.resident,
    specialty: 'Fixture Medicine',
    prefs: const UserPrefs(locale: 'en', analyticsOptIn: false),
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

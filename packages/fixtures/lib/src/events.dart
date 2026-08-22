import 'package:synapse_core/synapse_core.dart';

import 'models.dart';

abstract final class FixtureEvents {
  static final all = <SynapseEvent>[
    ConceptStudied(
      conceptId: FixtureModels.concept.id,
      source: ModuleKey.terms,
      correct: true,
      at: FixtureModels.timestamp,
    ),
    ConceptStruggled(
      conceptId: FixtureModels.concept.id,
      source: ModuleKey.cards,
      at: FixtureModels.timestamp,
    ),
    ItemMastered(
      conceptId: FixtureModels.concept.id,
      at: FixtureModels.timestamp,
    ),
    LessonCompleted(
      source: ModuleKey.terms,
      correct: 4,
      total: 5,
      conceptIds: [FixtureModels.concept.id],
      at: FixtureModels.timestamp,
    ),
    CaseCompleted(
      caseId: 'case.fixture.001',
      conceptIds: [FixtureModels.concept.id],
      at: FixtureModels.timestamp,
    ),
    RewardGranted(
      event: RewardEvent(
        source: ModuleKey.terms,
        kind: RewardKind.lesson,
        xp: 20,
        gems: 2,
        conceptIds: [FixtureModels.concept.id],
        firstTry: true,
        at: FixtureModels.timestamp,
      ),
      at: FixtureModels.timestamp,
    ),
    StreakChanged(current: 7, at: FixtureModels.timestamp),
    ContentCreated(
      source: ModuleKey.mnemonics,
      itemId: 'content.fixture.001',
      at: FixtureModels.timestamp,
    ),
    SocialInteraction(
      source: ModuleKey.rounds,
      kind: 'fixture-reaction',
      at: FixtureModels.timestamp,
    ),
    QuestProgressed(questId: 'quest.fixture.001', at: FixtureModels.timestamp),
  ];
}

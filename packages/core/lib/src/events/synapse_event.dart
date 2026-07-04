import 'package:equatable/equatable.dart';

import '../models/ids.dart';
import '../models/module_key.dart';
import '../models/reward.dart';

/// The typed domain-event union published on the in-app [EventBus] (prompt 32).
///
/// Every module **publishes** these on meaningful actions and **subscribes** to
/// others'. Reactors wired in the app layer turn them into cross-module effects:
/// a `ConceptStruggled` schedules an SRS card, raises the study-plan priority,
/// updates the weak-area heatmap and offers Copilot help — automatically.
sealed class SynapseEvent extends Equatable {
  const SynapseEvent({required this.at});
  final DateTime at;

  @override
  List<Object?> get props => [runtimeType, at];
}

/// A concept was practised somewhere, with a correct/incorrect outcome.
class ConceptStudied extends SynapseEvent {
  ConceptStudied({
    required this.conceptId,
    required this.source,
    required this.correct,
    DateTime? at,
  }) : super(at: at ?? DateTime.now());

  final ConceptId conceptId;
  final ModuleKey source;
  final bool correct;

  @override
  List<Object?> get props => [conceptId, source, correct, at];
}

/// A wrong answer / failed read anywhere — the trigger for remediation.
class ConceptStruggled extends SynapseEvent {
  ConceptStruggled({required this.conceptId, required this.source, DateTime? at})
      : super(at: at ?? DateTime.now());

  final ConceptId conceptId;
  final ModuleKey source;

  @override
  List<Object?> get props => [conceptId, source, at];
}

class ItemMastered extends SynapseEvent {
  ItemMastered({required this.conceptId, DateTime? at}) : super(at: at ?? DateTime.now());
  final ConceptId conceptId;
  @override
  List<Object?> get props => [conceptId, at];
}

class LessonCompleted extends SynapseEvent {
  LessonCompleted({
    required this.source,
    required this.correct,
    required this.total,
    this.conceptIds = const [],
    DateTime? at,
  }) : super(at: at ?? DateTime.now());

  final ModuleKey source;
  final int correct;
  final int total;
  final List<ConceptId> conceptIds;

  @override
  List<Object?> get props => [source, correct, total, at];
}

class CaseCompleted extends SynapseEvent {
  CaseCompleted({required this.caseId, this.conceptIds = const [], DateTime? at})
      : super(at: at ?? DateTime.now());
  final CaseId caseId;
  final List<ConceptId> conceptIds;
  @override
  List<Object?> get props => [caseId, conceptIds, at];
}

class RewardGranted extends SynapseEvent {
  RewardGranted({required this.event, DateTime? at}) : super(at: at ?? DateTime.now());
  final RewardEvent event;
  @override
  List<Object?> get props => [event, at];
}

class StreakChanged extends SynapseEvent {
  StreakChanged({required this.current, DateTime? at}) : super(at: at ?? DateTime.now());
  final int current;
  @override
  List<Object?> get props => [current, at];
}

class ContentCreated extends SynapseEvent {
  ContentCreated({required this.source, required this.itemId, DateTime? at})
      : super(at: at ?? DateTime.now());
  final ModuleKey source;
  final String itemId;
  @override
  List<Object?> get props => [source, itemId, at];
}

class SocialInteraction extends SynapseEvent {
  SocialInteraction({required this.source, required this.kind, DateTime? at})
      : super(at: at ?? DateTime.now());
  final ModuleKey source;
  final String kind; // 'like' | 'comment' | 'follow' | 'match' ...
  @override
  List<Object?> get props => [source, kind, at];
}

class QuestProgressed extends SynapseEvent {
  QuestProgressed({required this.questId, DateTime? at}) : super(at: at ?? DateTime.now());
  final String questId;
  @override
  List<Object?> get props => [questId, at];
}

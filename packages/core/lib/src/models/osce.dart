import 'package:equatable/equatable.dart';

import 'ids.dart';

/// Encounter type for an OSCE station (prompt 52 §1).
enum OsceType {
  history,
  counseling,
  sbar,
  consent,
  ethics,
  triage;

  String get label => switch (this) {
        OsceType.history => 'History taking',
        OsceType.counseling => 'Counseling',
        OsceType.sbar => 'SBAR handoff',
        OsceType.consent => 'Informed consent',
        OsceType.ethics => 'Ethics',
        OsceType.triage => 'Telephone triage',
      };
}

/// The five scoring domains of the OSCE rubric (prompt 52 §2).
enum OsceDomain {
  dataGathering,
  communication,
  empathy,
  diagnosis,
  safety;

  String get label => switch (this) {
        OsceDomain.dataGathering => 'Data gathering',
        OsceDomain.communication => 'Communication',
        OsceDomain.empathy => 'Empathy',
        OsceDomain.diagnosis => 'Diagnostic accuracy',
        OsceDomain.safety => 'Safety',
      };
}

/// A scripted patient response keyed by the topic the learner asks about
/// (prompt 52 §1). Keyword-matched so the encounter feels conversational while
/// staying grounded and fully offline.
class OsceBeat extends Equatable {
  const OsceBeat({
    required this.topic,
    required this.keywords,
    required this.response,
    this.domain = OsceDomain.dataGathering,
    this.essential = false,
  });

  final String topic;
  final List<String> keywords;
  final String response;
  final OsceDomain domain;

  /// Whether asking this is part of the data-gathering rubric.
  final bool essential;

  @override
  List<Object?> get props => [topic, keywords, response];
}

/// A single OSCE station — an AI standardized patient with a hidden script
/// (prompt 52). Encounters are scored against a transparent rubric.
class OsceStation extends Equatable {
  const OsceStation({
    required this.id,
    required this.title,
    required this.type,
    required this.patientName,
    required this.doorSign,
    required this.openingLine,
    this.conceptIds = const [],
    this.beats = const [],
    this.differentialOptions = const [],
    this.correctDifferential = const [],
    this.planOptions = const [],
    this.correctPlan = const [],
    this.redFlags = const [],
    this.affect,
    this.difficulty = 3,
    this.minutes = 8,
  });

  final String id;
  final String title;
  final OsceType type;
  final String patientName;

  /// The "door sign" briefing shown to the learner before entering.
  final String doorSign;
  final String openingLine;
  final List<ConceptId> conceptIds;
  final List<OsceBeat> beats;

  /// Differential choices the learner picks from after the interview.
  final List<String> differentialOptions;
  final List<String> correctDifferential;
  final List<String> planOptions;
  final List<String> correctPlan;
  final List<String> redFlags;

  /// The patient's emotional tone (drives empathy scoring guidance).
  final String? affect;
  final int difficulty;
  final int minutes;

  /// Essential data-gathering beats — the spine of the rubric.
  List<OsceBeat> get essentialBeats => beats.where((b) => b.essential).toList();

  @override
  List<Object?> get props => [id, title, type, difficulty];
}

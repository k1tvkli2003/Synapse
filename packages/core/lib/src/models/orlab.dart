import 'package:equatable/equatable.dart';

import 'ids.dart';

enum CueKind { keyTerm, instrument, step }

/// A timeline marker that scrolls in sync with an audio drama (prompt 18).
class TimelineCue extends Equatable {
  const TimelineCue({
    required this.atSec,
    required this.kind,
    required this.label,
    this.detail,
    this.conceptId,
  });

  final double atSec;
  final CueKind kind;
  final String label;
  final String? detail;
  final ConceptId? conceptId;

  @override
  List<Object?> get props => [atSec, kind, label];
}

/// A cinematic surgical audio drama with synced key terms / instruments.
class AudioDrama extends Equatable {
  const AudioDrama({
    required this.id,
    required this.title,
    required this.durationSec,
    this.surgery,
    this.audioUrl,
    this.cues = const [],
    this.conceptIds = const [],
    this.transcript,
  });

  final DramaId id;
  final String title;
  final String? surgery;
  final double durationSec;
  final String? audioUrl;
  final List<TimelineCue> cues;
  final List<ConceptId> conceptIds;
  final String? transcript;

  @override
  List<Object?> get props => [id, title, durationSec, cues];
}

/// A "be the doctor" branch point in simulation mode.
class SimDecision extends Equatable {
  const SimDecision({
    required this.atSec,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    this.rationale,
  });

  final double atSec;
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String? rationale;

  @override
  List<Object?> get props => [atSec, prompt, options, correctIndex];
}

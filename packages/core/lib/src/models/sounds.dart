import 'package:equatable/equatable.dart';

import 'ids.dart';

enum SoundKind { heart, lung }

/// A heart/lung auscultation entry with a diagram and quiz answer
/// (prompt 04 §5 / 15).
class BodySound extends Equatable {
  const BodySound({
    required this.id,
    required this.name,
    required this.kind,
    required this.options,
    required this.correctIndex,
    this.audioUrl,
    this.conceptId,
    this.location,
    this.description,
    this.timingHint,
  });

  final SoundId id;
  final String name;
  final SoundKind kind;
  final List<String> options;
  final int correctIndex;
  final String? audioUrl;
  final ConceptId? conceptId;

  /// Best auscultation site, e.g. "Apex (mitral area)".
  final String? location;
  final String? description;

  /// Hint for the synthesised waveform, e.g. "Holosystolic".
  final String? timingHint;

  @override
  List<Object?> get props => [id, name, kind, options, correctIndex];
}

/// A layer for the future sound simulator (S1/S2 + murmur), prompt 15.
class SoundLayer extends Equatable {
  const SoundLayer({required this.label, this.gain = 1.0, this.enabled = true});
  final String label;
  final double gain;
  final bool enabled;

  SoundLayer copyWith({double? gain, bool? enabled}) =>
      SoundLayer(label: label, gain: gain ?? this.gain, enabled: enabled ?? this.enabled);

  @override
  List<Object?> get props => [label, gain, enabled];
}

class SoundAttempt extends Equatable {
  const SoundAttempt({required this.soundId, required this.correct, this.at});
  final SoundId soundId;
  final bool correct;
  final DateTime? at;

  @override
  List<Object?> get props => [soundId, correct];
}

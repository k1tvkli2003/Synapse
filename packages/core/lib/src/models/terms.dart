import 'package:equatable/equatable.dart';

import 'ids.dart';

/// The eight exercise types in Terms (prompt 04 §5 / 11). Modelled as one
/// flexible value type keyed by [kind] so the drill renderer can switch on it.
enum ExerciseKind {
  multipleChoice, // pick the correct meaning
  reverseChoice, // pick the term for a meaning
  matchPairs, // match terms to meanings
  fillBlank, // complete the missing word
  typeAnswer, // type the term
  wordBank, // assemble the definition from chips
  trueFalse, // is this pairing correct?
  listen; // audio → choose (falls back to read-aloud)

  String get label => switch (this) {
        ExerciseKind.multipleChoice => 'Choose the meaning',
        ExerciseKind.reverseChoice => 'Choose the term',
        ExerciseKind.matchPairs => 'Match the pairs',
        ExerciseKind.fillBlank => 'Fill the blank',
        ExerciseKind.typeAnswer => 'Type the answer',
        ExerciseKind.wordBank => 'Build the definition',
        ExerciseKind.trueFalse => 'True or false',
        ExerciseKind.listen => 'Listen & choose',
      };
}

class Exercise extends Equatable {
  const Exercise({
    required this.id,
    required this.kind,
    required this.prompt,
    this.conceptId,
    this.options = const [],
    this.correctIndex = 0,
    this.answer = '',
    this.pairs = const {},
    this.tokens = const [],
    this.audioUrl,
    this.explanation,
  });

  final String id;
  final ExerciseKind kind;
  final ConceptId? conceptId;

  /// The question / sentence shown to the learner.
  final String prompt;

  /// Choices for choice-style exercises (first relevant field per kind).
  final List<String> options;
  final int correctIndex;

  /// Canonical text answer for type/fill exercises (case-insensitive compare).
  final String answer;

  /// term → meaning map for [ExerciseKind.matchPairs].
  final Map<String, String> pairs;

  /// Shuffled chips for [ExerciseKind.wordBank]; correct order is [answer].
  final List<String> tokens;

  final String? audioUrl;
  final String? explanation;

  /// Whether [response] is correct. [response] is either an index (as string),
  /// the typed text, or the assembled answer depending on [kind].
  bool isCorrect(String response) {
    switch (kind) {
      case ExerciseKind.multipleChoice:
      case ExerciseKind.reverseChoice:
      case ExerciseKind.listen:
      case ExerciseKind.trueFalse:
        return int.tryParse(response) == correctIndex;
      case ExerciseKind.fillBlank:
      case ExerciseKind.typeAnswer:
      case ExerciseKind.wordBank:
        return _normalize(response) == _normalize(answer);
      case ExerciseKind.matchPairs:
        return true; // graded pair-by-pair in the UI
    }
  }

  static String _normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  @override
  List<Object?> get props => [id, kind, prompt, options, correctIndex, answer];
}

class Lesson extends Equatable {
  const Lesson({
    required this.id,
    required this.title,
    required this.exercises,
    this.conceptIds = const [],
    this.xpReward = 15,
  });

  final LessonId id;
  final String title;
  final List<Exercise> exercises;
  final List<ConceptId> conceptIds;
  final int xpReward;

  @override
  List<Object?> get props => [id, title, exercises];
}

class Unit extends Equatable {
  const Unit({
    required this.id,
    required this.title,
    required this.lessons,
    this.subtitle,
  });

  final UnitId id;
  final String title;
  final String? subtitle;
  final List<Lesson> lessons;

  @override
  List<Object?> get props => [id, title, lessons];
}

/// A learning path such as Anatomy, Pharmacology, Clinical, Roots, Communication.
class CoursePath extends Equatable {
  const CoursePath({
    required this.id,
    required this.title,
    required this.units,
    this.description,
    this.iconKey = 'book',
  });

  final PathId id;
  final String title;
  final String? description;
  final String iconKey;
  final List<Unit> units;

  int get lessonCount => units.fold(0, (sum, u) => sum + u.lessons.length);

  @override
  List<Object?> get props => [id, title, units];
}

/// Outcome of a finished lesson, fed to rewards + concept mastery.
class ExerciseResult extends Equatable {
  const ExerciseResult({
    required this.lessonId,
    required this.correct,
    required this.total,
    required this.xpEarned,
    this.firstTry = false,
    this.conceptIds = const [],
  });

  final LessonId lessonId;
  final int correct;
  final int total;
  final int xpEarned;
  final bool firstTry;
  final List<ConceptId> conceptIds;

  double get accuracy => total == 0 ? 0 : correct / total;

  @override
  List<Object?> get props => [lessonId, correct, total, xpEarned];
}

import 'package:equatable/equatable.dart';

import '../models/ids.dart';

/// Local learner state is deliberately separate from immutable curriculum
/// packages. It records opaque IDs and choice outcomes only; free-text learner
/// responses and medical content bodies are never stored in this projection.
enum CurriculumSessionProgressPhase { inProgress, completed }

final _progressIdPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:/-]*$');

String _progressId(String value, String field) {
  if (value != value.trim() || !_progressIdPattern.hasMatch(value)) {
    throw ArgumentError.value(value, field, 'Invalid stable ID.');
  }
  return value;
}

DateTime _progressTime(Object? value, String field) {
  if (value is! String) {
    throw FormatException('$field must be an ISO-8601 timestamp.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('$field must be an ISO-8601 timestamp.');
  }
  return parsed.toUtc();
}

Map<String, Object?> _progressMap(Object? value, String field) {
  if (value is! Map) {
    throw FormatException('$field must be a JSON object.');
  }
  return Map<String, Object?>.from(value);
}

/// Immutable identity for learner-owned state. It binds a checkpoint to the
/// exact release and session that produced it, so a later content release can
/// never silently reinterpret a prior answer.
final class CurriculumSessionProgressKey extends Equatable {
  CurriculumSessionProgressKey({
    required this.releaseId,
    required this.microLessonNodeId,
    required this.sessionId,
  }) {
    _progressId(releaseId, 'releaseId');
    _progressId(microLessonNodeId, 'microLessonNodeId');
    _progressId(sessionId, 'sessionId');
  }

  final CurriculumReleaseId releaseId;
  final CurriculumNodeId microLessonNodeId;
  final CurriculumSessionId sessionId;

  /// Separator is outside the stable-ID alphabet, making this reversible and
  /// collision-free without deriving identity from any localized title.
  CurriculumSessionProgressId get stableId =>
      '$releaseId|$microLessonNodeId|$sessionId';

  Map<String, Object?> toJson() => {
    'releaseId': releaseId,
    'microLessonNodeId': microLessonNodeId,
    'sessionId': sessionId,
  };

  factory CurriculumSessionProgressKey.fromJson(Map<String, Object?> json) =>
      CurriculumSessionProgressKey(
        releaseId: json['releaseId'] as String,
        microLessonNodeId: json['microLessonNodeId'] as String,
        sessionId: json['sessionId'] as String,
      );

  @override
  List<Object?> get props => [releaseId, microLessonNodeId, sessionId];
}

/// An immutable, locally recorded response to one choice-based interaction.
/// The optional server/outbox layer consumes [id] later as an idempotency key;
/// this model does not mint rewards or make competence claims.
final class CurriculumChoiceResponse extends Equatable {
  CurriculumChoiceResponse({
    required this.id,
    required this.interactionId,
    required this.selectedOptionId,
    required this.isCorrect,
    required DateTime answeredAt,
  }) : answeredAt = answeredAt.toUtc() {
    _progressId(id, 'id');
    _progressId(interactionId, 'interactionId');
    _progressId(selectedOptionId, 'selectedOptionId');
  }

  final String id;
  final CurriculumInteractionId interactionId;
  final String selectedOptionId;
  final bool isCorrect;
  final DateTime answeredAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'interactionId': interactionId,
    'selectedOptionId': selectedOptionId,
    'isCorrect': isCorrect,
    'answeredAt': answeredAt.toIso8601String(),
  };

  factory CurriculumChoiceResponse.fromJson(Map<String, Object?> json) =>
      CurriculumChoiceResponse(
        id: json['id'] as String,
        interactionId: json['interactionId'] as String,
        selectedOptionId: json['selectedOptionId'] as String,
        isCorrect: json['isCorrect'] as bool,
        answeredAt: _progressTime(json['answeredAt'], 'answeredAt'),
      );

  @override
  List<Object?> get props => [
    id,
    interactionId,
    selectedOptionId,
    isCorrect,
    answeredAt,
  ];
}

/// Resumable local state for one signed curriculum session.
///
/// [revision] is a monotonic local compare-and-set token. UI calls must carry
/// their expected revision so an older screen cannot overwrite a newer
/// checkpoint after a restart, retry, or concurrent callback.
final class CurriculumSessionProgress extends Equatable {
  CurriculumSessionProgress({
    required this.key,
    required this.phase,
    required this.interactionIndex,
    required this.revision,
    required DateTime startedAt,
    required DateTime updatedAt,
    this.selectedOptionId,
    Map<CurriculumInteractionId, CurriculumChoiceResponse> choiceResponses =
        const {},
    DateTime? completedAt,
    this.completionReceiptId,
  }) : startedAt = startedAt.toUtc(),
       updatedAt = updatedAt.toUtc(),
       completedAt = completedAt?.toUtc(),
       choiceResponses = Map.unmodifiable(choiceResponses) {
    if (interactionIndex < 0) {
      throw ArgumentError.value(interactionIndex, 'interactionIndex');
    }
    if (revision < 1) {
      throw ArgumentError.value(revision, 'revision');
    }
    if (selectedOptionId != null) {
      _progressId(selectedOptionId!, 'selectedOptionId');
    }
    if (updatedAt.isBefore(startedAt)) {
      throw ArgumentError('updatedAt cannot precede startedAt.');
    }
    if (choiceResponses.keys.any(
      (id) => choiceResponses[id]?.interactionId != id,
    )) {
      throw ArgumentError(
        'Choice response map keys must match interaction IDs.',
      );
    }
    if (choiceResponses.values.map((value) => value.id).toSet().length !=
        choiceResponses.length) {
      throw ArgumentError('Choice response IDs must be unique.');
    }
    if (phase == CurriculumSessionProgressPhase.completed) {
      if (this.completedAt == null || completionReceiptId == null) {
        throw ArgumentError(
          'Completed progress requires a receipt and timestamp.',
        );
      }
      _progressId(completionReceiptId!, 'completionReceiptId');
      if (selectedOptionId != null) {
        throw ArgumentError(
          'Completed progress cannot retain a pending selection.',
        );
      }
    } else if (this.completedAt != null || completionReceiptId != null) {
      throw ArgumentError(
        'In-progress state cannot have a completion receipt.',
      );
    }
  }

  final CurriculumSessionProgressKey key;
  final CurriculumSessionProgressPhase phase;
  final int interactionIndex;
  final int revision;
  final DateTime startedAt;
  final DateTime updatedAt;
  final String? selectedOptionId;
  final Map<CurriculumInteractionId, CurriculumChoiceResponse> choiceResponses;
  final DateTime? completedAt;
  final String? completionReceiptId;

  bool get isCompleted => phase == CurriculumSessionProgressPhase.completed;

  /// Evidence that the learner moved beyond merely opening a Session.
  ///
  /// A pending option selection is deliberately insufficient: attempt-gated
  /// reading must not appear before the response is committed. Passive
  /// interactions count only after a revision advances the checkpoint.
  bool get hasAttemptEvidence =>
      isCompleted ||
      choiceResponses.isNotEmpty ||
      (revision > 1 && interactionIndex > 0);

  CurriculumChoiceResponse? responseFor(
    CurriculumInteractionId interactionId,
  ) => choiceResponses[interactionId];

  Map<String, Object?> toJson() => {
    'key': key.toJson(),
    'phase': phase.name,
    'interactionIndex': interactionIndex,
    'revision': revision,
    'startedAt': startedAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'selectedOptionId': selectedOptionId,
    'choiceResponses': choiceResponses.map(
      (interactionId, response) => MapEntry(interactionId, response.toJson()),
    ),
    'completedAt': completedAt?.toIso8601String(),
    'completionReceiptId': completionReceiptId,
  };

  factory CurriculumSessionProgress.fromJson(Map<String, Object?> json) {
    final responseMap = _progressMap(
      json['choiceResponses'],
      'choiceResponses',
    );
    return CurriculumSessionProgress(
      key: CurriculumSessionProgressKey.fromJson(
        _progressMap(json['key'], 'key'),
      ),
      phase: CurriculumSessionProgressPhase.values.byName(
        json['phase'] as String,
      ),
      interactionIndex: json['interactionIndex'] as int,
      revision: json['revision'] as int,
      startedAt: _progressTime(json['startedAt'], 'startedAt'),
      updatedAt: _progressTime(json['updatedAt'], 'updatedAt'),
      selectedOptionId: json['selectedOptionId'] as String?,
      choiceResponses: responseMap.map(
        (interactionId, raw) => MapEntry(
          interactionId,
          CurriculumChoiceResponse.fromJson(
            _progressMap(raw, 'choiceResponses.$interactionId'),
          ),
        ),
      ),
      completedAt: json['completedAt'] == null
          ? null
          : _progressTime(json['completedAt'], 'completedAt'),
      completionReceiptId: json['completionReceiptId'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    key,
    phase,
    interactionIndex,
    revision,
    startedAt,
    updatedAt,
    selectedOptionId,
    choiceResponses,
    completedAt,
    completionReceiptId,
  ];
}

/// Safe error boundary for the learner-progress repository. Presentation code
/// maps [code] to localised recovery copy and never shows [cause] directly.
final class CurriculumProgressException implements Exception {
  const CurriculumProgressException(this.code, this.message, [this.cause]);

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'CurriculumProgressException($code): $message';
}

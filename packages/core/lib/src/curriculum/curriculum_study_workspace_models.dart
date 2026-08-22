import 'package:equatable/equatable.dart';

import '../models/ids.dart';
import 'curriculum_models.dart';

final _workspaceIdPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:/-]*$');

String _workspaceId(String value, String field) {
  if (value != value.trim() || !_workspaceIdPattern.hasMatch(value)) {
    throw ArgumentError.value(value, field, 'Invalid stable ID.');
  }
  return value;
}

String _noteBody(String value) {
  if (value != value.trim() || value.isEmpty) {
    throw ArgumentError.value(value, 'body', 'Must be non-empty and trimmed.');
  }
  if (value.length > CurriculumStudyNote.maxBodyLength) {
    throw ArgumentError.value(
      value.length,
      'body.length',
      'A study note cannot exceed ${CurriculumStudyNote.maxBodyLength} characters.',
    );
  }
  return value;
}

DateTime _workspaceTime(Object? value, String field) {
  if (value is! String) {
    throw FormatException('$field must be an ISO-8601 timestamp.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('$field must be an ISO-8601 timestamp.');
  }
  return parsed.toUtc();
}

Map<String, Object?> _workspaceMap(Object? value, String field) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw FormatException('$field must be a JSON object.');
  }
  return Map<String, Object?>.from(value);
}

List<Object?> _workspaceList(Object? value, String field) {
  if (value is! List) {
    throw FormatException('$field must be a JSON array.');
  }
  return List<Object?>.from(value);
}

/// Stable identity for learner-owned material attached to a curriculum node.
///
/// The active release is deliberately absent from this key. Curriculum node
/// IDs are source-ordinal identities, so a reviewed package update can change
/// the body without orphaning a learner's notes or bookmark. The workspace
/// separately records which release was most recently opened.
final class CurriculumStudyWorkspaceKey extends Equatable {
  CurriculumStudyWorkspaceKey({required this.sourceId, required this.nodeId}) {
    _workspaceId(sourceId, 'sourceId');
    _workspaceId(nodeId, 'nodeId');
  }

  final CurriculumSourceId sourceId;
  final CurriculumNodeId nodeId;

  /// `|` is outside the stable-ID alphabet, making the compound identity
  /// reversible and collision-free without localized titles.
  String get stableId => '$sourceId|$nodeId';

  Map<String, Object?> toJson() => {'sourceId': sourceId, 'nodeId': nodeId};

  factory CurriculumStudyWorkspaceKey.fromJson(Map<String, Object?> json) =>
      CurriculumStudyWorkspaceKey(
        sourceId: json['sourceId'] as String,
        nodeId: json['nodeId'] as String,
      );

  @override
  List<Object?> get props => [sourceId, nodeId];
}

/// One bounded learner-authored note. It contains no medical-authority claim
/// and never becomes part of an immutable curriculum package.
final class CurriculumStudyNote extends Equatable {
  CurriculumStudyNote({
    required this.id,
    required this.locale,
    required this.body,
    required this.revision,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.anchorId,
  }) : createdAt = createdAt.toUtc(),
       updatedAt = updatedAt.toUtc() {
    _workspaceId(id, 'id');
    _noteBody(body);
    if (anchorId != null) _workspaceId(anchorId!, 'anchorId');
    if (revision < 1) throw ArgumentError.value(revision, 'revision');
    if (this.updatedAt.isBefore(this.createdAt)) {
      throw ArgumentError('updatedAt cannot precede createdAt.');
    }
  }

  static const maxBodyLength = 20000;

  final String id;
  final ContentLocale locale;
  final String body;
  final String? anchorId;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'locale': locale.name,
    'body': body,
    'anchorId': anchorId,
    'revision': revision,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory CurriculumStudyNote.fromJson(Map<String, Object?> json) =>
      CurriculumStudyNote(
        id: json['id'] as String,
        locale: ContentLocale.values.byName(json['locale'] as String),
        body: json['body'] as String,
        anchorId: json['anchorId'] as String?,
        revision: json['revision'] as int,
        createdAt: _workspaceTime(json['createdAt'], 'createdAt'),
        updatedAt: _workspaceTime(json['updatedAt'], 'updatedAt'),
      );

  @override
  List<Object?> get props => [
    id,
    locale,
    body,
    anchorId,
    revision,
    createdAt,
    updatedAt,
  ];
}

/// Bounded, release-aware local projection for a deep-study context.
///
/// Focus totals are a private study log, not XP, mastery, a streak, or a
/// clinical competence assertion. [lastFocusSegmentId] makes an immediate
/// retry idempotent without growing an unbounded timer-event ledger in the
/// compact local registry.
final class CurriculumStudyWorkspace extends Equatable {
  CurriculumStudyWorkspace({
    required this.key,
    required this.lastOpenedReleaseId,
    required this.isBookmarked,
    required Iterable<CurriculumStudyNote> notes,
    required this.focusSecondsTotal,
    required this.focusSessionCount,
    required this.revision,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.lastFocusSegmentId,
    this.lastFocusSegmentSeconds,
    DateTime? lastFocusCompletedAt,
  }) : notes = List.unmodifiable(notes),
       createdAt = createdAt.toUtc(),
       updatedAt = updatedAt.toUtc(),
       lastFocusCompletedAt = lastFocusCompletedAt?.toUtc() {
    _workspaceId(lastOpenedReleaseId, 'lastOpenedReleaseId');
    if (revision < 1) throw ArgumentError.value(revision, 'revision');
    if (focusSecondsTotal < 0) {
      throw ArgumentError.value(focusSecondsTotal, 'focusSecondsTotal');
    }
    if (focusSessionCount < 0) {
      throw ArgumentError.value(focusSessionCount, 'focusSessionCount');
    }
    if (this.updatedAt.isBefore(this.createdAt)) {
      throw ArgumentError('updatedAt cannot precede createdAt.');
    }
    if (this.notes.length > maxNotesPerWorkspace) {
      throw ArgumentError.value(this.notes.length, 'notes.length');
    }
    if (this.notes.map((note) => note.id).toSet().length != this.notes.length) {
      throw ArgumentError('Study note IDs must be unique within a workspace.');
    }
    final hasLastFocus =
        lastFocusSegmentId != null ||
        lastFocusSegmentSeconds != null ||
        this.lastFocusCompletedAt != null;
    if (hasLastFocus &&
        (lastFocusSegmentId == null ||
            lastFocusSegmentSeconds == null ||
            this.lastFocusCompletedAt == null)) {
      throw ArgumentError('Last focus segment fields must be set together.');
    }
    if (lastFocusSegmentId != null) {
      _workspaceId(lastFocusSegmentId!, 'lastFocusSegmentId');
      if (lastFocusSegmentSeconds! < 1 ||
          lastFocusSegmentSeconds! > maxFocusSegmentSeconds) {
        throw ArgumentError.value(
          lastFocusSegmentSeconds,
          'lastFocusSegmentSeconds',
        );
      }
      if (this.lastFocusCompletedAt!.isBefore(this.createdAt) ||
          this.lastFocusCompletedAt!.isAfter(this.updatedAt)) {
        throw ArgumentError(
          'lastFocusCompletedAt must be within the workspace lifetime.',
        );
      }
      if (focusSessionCount < 1 ||
          focusSecondsTotal < lastFocusSegmentSeconds!) {
        throw ArgumentError(
          'Focus aggregates cannot be smaller than the last segment.',
        );
      }
    }
  }

  static const maxNotesPerWorkspace = 100;
  static const maxFocusSegmentSeconds = 4 * 60 * 60;

  final CurriculumStudyWorkspaceKey key;
  final CurriculumReleaseId lastOpenedReleaseId;
  final bool isBookmarked;
  final List<CurriculumStudyNote> notes;
  final int focusSecondsTotal;
  final int focusSessionCount;
  final String? lastFocusSegmentId;
  final int? lastFocusSegmentSeconds;
  final DateTime? lastFocusCompletedAt;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
    'key': key.toJson(),
    'lastOpenedReleaseId': lastOpenedReleaseId,
    'isBookmarked': isBookmarked,
    'notes': notes.map((note) => note.toJson()).toList(),
    'focusSecondsTotal': focusSecondsTotal,
    'focusSessionCount': focusSessionCount,
    'lastFocusSegmentId': lastFocusSegmentId,
    'lastFocusSegmentSeconds': lastFocusSegmentSeconds,
    'lastFocusCompletedAt': lastFocusCompletedAt?.toIso8601String(),
    'revision': revision,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory CurriculumStudyWorkspace.fromJson(Map<String, Object?> json) =>
      CurriculumStudyWorkspace(
        key: CurriculumStudyWorkspaceKey.fromJson(
          _workspaceMap(json['key'], 'key'),
        ),
        lastOpenedReleaseId: json['lastOpenedReleaseId'] as String,
        isBookmarked: json['isBookmarked'] as bool,
        notes: [
          for (final raw in _workspaceList(json['notes'], 'notes'))
            CurriculumStudyNote.fromJson(_workspaceMap(raw, 'notes[]')),
        ],
        focusSecondsTotal: json['focusSecondsTotal'] as int,
        focusSessionCount: json['focusSessionCount'] as int,
        lastFocusSegmentId: json['lastFocusSegmentId'] as String?,
        lastFocusSegmentSeconds: json['lastFocusSegmentSeconds'] as int?,
        lastFocusCompletedAt: json['lastFocusCompletedAt'] == null
            ? null
            : _workspaceTime(
                json['lastFocusCompletedAt'],
                'lastFocusCompletedAt',
              ),
        revision: json['revision'] as int,
        createdAt: _workspaceTime(json['createdAt'], 'createdAt'),
        updatedAt: _workspaceTime(json['updatedAt'], 'updatedAt'),
      );

  @override
  List<Object?> get props => [
    key,
    lastOpenedReleaseId,
    isBookmarked,
    notes,
    focusSecondsTotal,
    focusSessionCount,
    lastFocusSegmentId,
    lastFocusSegmentSeconds,
    lastFocusCompletedAt,
    revision,
    createdAt,
    updatedAt,
  ];
}

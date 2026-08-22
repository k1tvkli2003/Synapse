import 'package:equatable/equatable.dart';

import '../models/ids.dart';
import '../serialization/stable_enum_codec.dart';
import 'curriculum_models.dart';
import 'curriculum_progress_models.dart';

/// The role a reviewed document plays inside one bounded Micro-lesson.
enum CurriculumStudyDocumentKind { primaryLesson, reference }

/// Semantic reading shapes supported by the first deep-study package contract.
///
/// These are content structures, not visual templates. The UI may recompose a
/// shape for compact, wide, RTL, high-text-scale, or reduced-motion contexts
/// without changing its order or meaning.
enum CurriculumStudyBlockKind {
  prose,
  keyIdea,
  mechanismChain,
  orderedSteps,
  bulletList,
  comparisonTable,
  clinicalPearl,
  safetyWarning,
  workedExample,
  recap,
}

/// Prevents remediation or debrief material from becoming an answer surface.
enum CurriculumStudyRevealPolicy {
  always,
  afterFirstAttempt,
  afterSessionCompletion,
}

final _documentKindCodec = StableEnumCodec<CurriculumStudyDocumentKind>({
  'primary_lesson': CurriculumStudyDocumentKind.primaryLesson,
  'reference': CurriculumStudyDocumentKind.reference,
});

final _blockKindCodec = StableEnumCodec<CurriculumStudyBlockKind>({
  'prose': CurriculumStudyBlockKind.prose,
  'key_idea': CurriculumStudyBlockKind.keyIdea,
  'mechanism_chain': CurriculumStudyBlockKind.mechanismChain,
  'ordered_steps': CurriculumStudyBlockKind.orderedSteps,
  'bullet_list': CurriculumStudyBlockKind.bulletList,
  'comparison_table': CurriculumStudyBlockKind.comparisonTable,
  'clinical_pearl': CurriculumStudyBlockKind.clinicalPearl,
  'safety_warning': CurriculumStudyBlockKind.safetyWarning,
  'worked_example': CurriculumStudyBlockKind.workedExample,
  'recap': CurriculumStudyBlockKind.recap,
});

final _revealPolicyCodec = StableEnumCodec<CurriculumStudyRevealPolicy>({
  'always': CurriculumStudyRevealPolicy.always,
  'after_first_attempt': CurriculumStudyRevealPolicy.afterFirstAttempt,
  'after_session_completion':
      CurriculumStudyRevealPolicy.afterSessionCompletion,
});

/// One immutable, bilingual, provenance-bound reading document.
///
/// Documents attach only to Micro-lesson hierarchy nodes in schema v2. This
/// keeps complete source detail inside fatigue-sensitive learning units rather
/// than recreating chapter-length scrolls.
final class CurriculumStudyDocument extends Equatable {
  CurriculumStudyDocument({
    required this.id,
    required this.microLessonNodeId,
    required this.ordinal,
    required this.kind,
    required this.titleUnitId,
    required this.estimatedSeconds,
    required Iterable<String> blockIds,
    required Iterable<String> sourceAtomIds,
    required Iterable<String> conceptIds,
    Iterable<String> claimIds = const [],
  }) : blockIds = _ids(blockIds, 'blockIds', nonEmpty: true, maximum: 24),
       sourceAtomIds = _ids(sourceAtomIds, 'sourceAtomIds', nonEmpty: true),
       claimIds = _ids(claimIds, 'claimIds'),
       conceptIds = _ids(conceptIds, 'conceptIds', nonEmpty: true) {
    _id(id, 'id');
    _id(microLessonNodeId, 'microLessonNodeId');
    _id(titleUnitId, 'titleUnitId');
    if (ordinal < 1) throw ArgumentError.value(ordinal, 'ordinal');
    if (estimatedSeconds.enSeconds > 720 || estimatedSeconds.faSeconds > 720) {
      throw ArgumentError(
        'A deep-study document cannot exceed twelve minutes in either locale.',
      );
    }
  }

  final CurriculumStudyDocumentId id;
  final CurriculumNodeId microLessonNodeId;
  final int ordinal;
  final CurriculumStudyDocumentKind kind;
  final CurriculumLocalizationUnitId titleUnitId;
  final List<CurriculumStudyBlockId> blockIds;
  final List<SourceAtomId> sourceAtomIds;
  final List<String> claimIds;
  final List<String> conceptIds;
  final LocaleDuration estimatedSeconds;

  Map<String, dynamic> toJson() => {
    'id': id,
    'microLessonNodeId': microLessonNodeId,
    'ordinal': ordinal,
    'kind': _documentKindCodec.encode(kind),
    'titleUnitId': titleUnitId,
    'blockIds': blockIds,
    'sourceAtomIds': sourceAtomIds,
    'claimIds': claimIds,
    'conceptIds': conceptIds,
    'estimatedSeconds': estimatedSeconds.toJson(),
  };

  factory CurriculumStudyDocument.fromJson(Map<String, dynamic> json) =>
      CurriculumStudyDocument(
        id: json['id'] as String,
        microLessonNodeId: json['microLessonNodeId'] as String,
        ordinal: json['ordinal'] as int,
        kind: _documentKindCodec.decode(json['kind']),
        titleUnitId: json['titleUnitId'] as String,
        blockIds: _strings(json['blockIds'], 'blockIds'),
        sourceAtomIds: _strings(json['sourceAtomIds'], 'sourceAtomIds'),
        claimIds: _strings(json['claimIds'], 'claimIds'),
        conceptIds: _strings(json['conceptIds'], 'conceptIds'),
        estimatedSeconds: LocaleDuration.fromJson(
          Map<String, dynamic>.from(json['estimatedSeconds'] as Map),
        ),
      );

  @override
  List<Object?> get props => [
    id,
    microLessonNodeId,
    ordinal,
    kind,
    titleUnitId,
    blockIds,
    sourceAtomIds,
    claimIds,
    conceptIds,
    estimatedSeconds,
  ];
}

/// One ordered semantic block inside a deep-study document.
///
/// Non-table blocks use [contentUnitIds]. Comparison tables use [tableRows],
/// where the first row is the column-header row and the first cell of later
/// rows is the row header. Every cell remains a reviewed localization unit.
final class CurriculumStudyBlock extends Equatable {
  CurriculumStudyBlock({
    required this.id,
    required this.documentId,
    required this.ordinal,
    required this.kind,
    required this.revealPolicy,
    required Iterable<String> sourceAtomIds,
    required Iterable<String> conceptIds,
    Iterable<String> claimIds = const [],
    this.headingUnitId,
    Iterable<String> contentUnitIds = const [],
    Iterable<Iterable<String>> tableRows = const [],
    this.revealedAfterSessionId,
  }) : contentUnitIds = _ids(contentUnitIds, 'contentUnitIds'),
       tableRows = List<List<CurriculumLocalizationUnitId>>.unmodifiable(
         tableRows.map(
           (row) => _ids(row, 'tableRows', nonEmpty: true, maximum: 4),
         ),
       ),
       sourceAtomIds = _ids(sourceAtomIds, 'sourceAtomIds', nonEmpty: true),
       claimIds = _ids(claimIds, 'claimIds'),
       conceptIds = _ids(conceptIds, 'conceptIds', nonEmpty: true) {
    _id(id, 'id');
    _id(documentId, 'documentId');
    if (headingUnitId != null) _id(headingUnitId!, 'headingUnitId');
    if (ordinal < 1) throw ArgumentError.value(ordinal, 'ordinal');
    _validateRevealPolicy();
    _validateShape();
    final localizationIds = <String>[
      ?headingUnitId,
      ...this.contentUnitIds,
      ...this.tableRows.expand((row) => row),
    ];
    if (localizationIds.toSet().length != localizationIds.length) {
      throw ArgumentError(
        'A study block cannot reuse one localization unit in multiple slots.',
      );
    }
  }

  final CurriculumStudyBlockId id;
  final CurriculumStudyDocumentId documentId;
  final int ordinal;
  final CurriculumStudyBlockKind kind;
  final CurriculumLocalizationUnitId? headingUnitId;
  final List<CurriculumLocalizationUnitId> contentUnitIds;
  final List<List<CurriculumLocalizationUnitId>> tableRows;
  final List<SourceAtomId> sourceAtomIds;
  final List<String> claimIds;
  final List<String> conceptIds;
  final CurriculumStudyRevealPolicy revealPolicy;
  final CurriculumSessionId? revealedAfterSessionId;

  bool get isAlwaysVisible =>
      revealPolicy == CurriculumStudyRevealPolicy.always;

  /// Resolves a delayed block only from the exact release-bound checkpoint.
  ///
  /// The caller supplies the owning Micro-lesson and active immutable release;
  /// a checkpoint from another release, node, or Session can never unlock this
  /// content. This method is intentionally fail-closed for missing progress.
  bool isRevealedBy({
    required CurriculumSessionProgress? progress,
    required CurriculumReleaseId releaseId,
    required CurriculumNodeId microLessonNodeId,
  }) {
    if (isAlwaysVisible) return true;
    if (progress == null ||
        progress.key.releaseId != releaseId ||
        progress.key.microLessonNodeId != microLessonNodeId ||
        progress.key.sessionId != revealedAfterSessionId) {
      return false;
    }
    return switch (revealPolicy) {
      CurriculumStudyRevealPolicy.always => true,
      CurriculumStudyRevealPolicy.afterFirstAttempt =>
        progress.hasAttemptEvidence,
      CurriculumStudyRevealPolicy.afterSessionCompletion =>
        progress.isCompleted,
    };
  }

  List<CurriculumLocalizationUnitId> get localizationUnitIds =>
      List.unmodifiable([
        ?headingUnitId,
        ...contentUnitIds,
        ...tableRows.expand((row) => row),
      ]);

  void _validateRevealPolicy() {
    if (revealPolicy == CurriculumStudyRevealPolicy.always) {
      if (revealedAfterSessionId != null) {
        throw ArgumentError(
          'Always-visible blocks cannot depend on a Session.',
        );
      }
      return;
    }
    if (revealedAfterSessionId == null) {
      throw ArgumentError(
        'Attempt- or completion-gated blocks require a Session ID.',
      );
    }
    _id(revealedAfterSessionId!, 'revealedAfterSessionId');
  }

  void _validateShape() {
    if (kind == CurriculumStudyBlockKind.comparisonTable) {
      if (contentUnitIds.isNotEmpty || tableRows.length < 2) {
        throw ArgumentError(
          'Comparison tables require at least a header and one data row.',
        );
      }
      if (tableRows.length > 7) {
        throw ArgumentError.value(tableRows.length, 'tableRows');
      }
      final columnCount = tableRows.first.length;
      if (columnCount < 2 || columnCount > 4) {
        throw ArgumentError.value(columnCount, 'table column count');
      }
      if (tableRows.any((row) => row.length != columnCount)) {
        throw ArgumentError('Every comparison row must have equal columns.');
      }
      return;
    }
    if (tableRows.isNotEmpty) {
      throw ArgumentError('Only comparison blocks may contain table rows.');
    }
    final bounds = switch (kind) {
      CurriculumStudyBlockKind.prose => (1, 3),
      CurriculumStudyBlockKind.keyIdea => (1, 2),
      CurriculumStudyBlockKind.mechanismChain => (2, 7),
      CurriculumStudyBlockKind.orderedSteps => (2, 7),
      CurriculumStudyBlockKind.bulletList => (2, 5),
      CurriculumStudyBlockKind.clinicalPearl => (1, 2),
      CurriculumStudyBlockKind.safetyWarning => (1, 2),
      CurriculumStudyBlockKind.workedExample => (1, 3),
      CurriculumStudyBlockKind.recap => (1, 3),
      CurriculumStudyBlockKind.comparisonTable => throw StateError(
        'Comparison tables were handled above.',
      ),
    };
    if (contentUnitIds.length < bounds.$1 ||
        contentUnitIds.length > bounds.$2) {
      throw ArgumentError.value(
        contentUnitIds.length,
        'contentUnitIds',
        '${kind.name} requires ${bounds.$1}–${bounds.$2} units.',
      );
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'documentId': documentId,
    'ordinal': ordinal,
    'kind': _blockKindCodec.encode(kind),
    'headingUnitId': headingUnitId,
    'contentUnitIds': contentUnitIds,
    'tableRows': tableRows,
    'sourceAtomIds': sourceAtomIds,
    'claimIds': claimIds,
    'conceptIds': conceptIds,
    'revealPolicy': _revealPolicyCodec.encode(revealPolicy),
    'revealedAfterSessionId': revealedAfterSessionId,
  };

  factory CurriculumStudyBlock.fromJson(Map<String, dynamic> json) =>
      CurriculumStudyBlock(
        id: json['id'] as String,
        documentId: json['documentId'] as String,
        ordinal: json['ordinal'] as int,
        kind: _blockKindCodec.decode(json['kind']),
        headingUnitId: json['headingUnitId'] as String?,
        contentUnitIds: _strings(json['contentUnitIds'], 'contentUnitIds'),
        tableRows: _rows(json['tableRows']),
        sourceAtomIds: _strings(json['sourceAtomIds'], 'sourceAtomIds'),
        claimIds: _strings(json['claimIds'], 'claimIds'),
        conceptIds: _strings(json['conceptIds'], 'conceptIds'),
        revealPolicy: _revealPolicyCodec.decode(json['revealPolicy']),
        revealedAfterSessionId: json['revealedAfterSessionId'] as String?,
      );

  @override
  List<Object?> get props => [
    id,
    documentId,
    ordinal,
    kind,
    headingUnitId,
    contentUnitIds,
    tableRows,
    sourceAtomIds,
    claimIds,
    conceptIds,
    revealPolicy,
    revealedAfterSessionId,
  ];
}

List<String> _ids(
  Iterable<String> values,
  String field, {
  bool nonEmpty = false,
  int? maximum,
}) {
  final result = List<String>.unmodifiable(values);
  if (nonEmpty && result.isEmpty) {
    throw ArgumentError.value(result, field, 'Must not be empty.');
  }
  if (maximum != null && result.length > maximum) {
    throw ArgumentError.value(result.length, field, 'Maximum is $maximum.');
  }
  for (final value in result) {
    _id(value, field);
  }
  if (result.toSet().length != result.length) {
    throw ArgumentError.value(result, field, 'Duplicate IDs are not allowed.');
  }
  return result;
}

void _id(String value, String field) {
  if (value.length > 200 ||
      !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:/-]*$').hasMatch(value)) {
    throw ArgumentError.value(value, field, 'Expected a stable identifier.');
  }
}

List<String> _strings(Object? value, String field) {
  if (value is! List || value.any((item) => item is! String)) {
    throw ArgumentError.value(value, field, 'Expected a string array.');
  }
  return value.cast<String>().toList(growable: false);
}

List<List<String>> _rows(Object? value) {
  if (value is! List) {
    throw ArgumentError.value(value, 'tableRows', 'Expected an array.');
  }
  return value.map((row) => _strings(row, 'tableRows')).toList(growable: false);
}

import 'package:equatable/equatable.dart';

import '../models/ids.dart';
import '../serialization/canonical_json.dart';
import 'curriculum_learning_models.dart';
import 'curriculum_models.dart';
import 'curriculum_study_models.dart';

final class CurriculumManifestException implements Exception {
  const CurriculumManifestException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'CurriculumManifestException($code): $message';
}

/// Immutable app-facing curriculum release.
///
/// Raw source documents and authoring drafts stay outside this object. A
/// published manifest can contain only approved hierarchy nodes and publishable
/// bilingual localization pairs.
final class CurriculumManifest extends Equatable {
  factory CurriculumManifest({
    int manifestSchemaVersion = schemaVersion,
    required CurriculumSource source,
    required CurriculumRelease release,
    required Iterable<CurriculumNode> nodes,
    Iterable<CurriculumLocalizationUnit> localizationUnits = const [],
    Iterable<CurriculumMicroLesson> microLessons = const [],
    Iterable<CurriculumSession> sessions = const [],
    Iterable<CurriculumInteraction> interactions = const [],
    Iterable<CurriculumStudyDocument> studyDocuments = const [],
    Iterable<CurriculumStudyBlock> studyBlocks = const [],
  }) {
    final manifest = CurriculumManifest._(
      manifestSchemaVersion: manifestSchemaVersion,
      source: source,
      release: release,
      nodes: List.unmodifiable(nodes),
      localizationUnits: List.unmodifiable(localizationUnits),
      microLessons: List.unmodifiable(microLessons),
      sessions: List.unmodifiable(sessions),
      interactions: List.unmodifiable(interactions),
      studyDocuments: List.unmodifiable(studyDocuments),
      studyBlocks: List.unmodifiable(studyBlocks),
    );
    manifest._validate();
    return manifest;
  }

  const CurriculumManifest._({
    required this.manifestSchemaVersion,
    required this.source,
    required this.release,
    required this.nodes,
    required this.localizationUnits,
    required this.microLessons,
    required this.sessions,
    required this.interactions,
    required this.studyDocuments,
    required this.studyBlocks,
  });

  /// Current writer schema. The reader intentionally keeps schema v1 support
  /// so already-installed signed packages remain usable during migration.
  static const schemaVersion = 2;
  static const legacySchemaVersion = 1;

  final int manifestSchemaVersion;
  final CurriculumSource source;
  final CurriculumRelease release;
  final List<CurriculumNode> nodes;
  final List<CurriculumLocalizationUnit> localizationUnits;
  final List<CurriculumMicroLesson> microLessons;
  final List<CurriculumSession> sessions;
  final List<CurriculumInteraction> interactions;
  final List<CurriculumStudyDocument> studyDocuments;
  final List<CurriculumStudyBlock> studyBlocks;

  bool get isScaffold =>
      microLessons.isEmpty &&
      sessions.isEmpty &&
      interactions.isEmpty &&
      studyDocuments.isEmpty &&
      studyBlocks.isEmpty;

  String get canonicalSha256 => CanonicalJson.sha256Hex(toJson());

  Map<String, dynamic> toJson() => {
    'schemaVersion': manifestSchemaVersion,
    'source': source.toJson(),
    'release': release.toJson(),
    'nodes': nodes.map((node) => node.toJson()).toList(),
    'localizationUnits': localizationUnits
        .map((unit) => unit.toJson())
        .toList(),
    'microLessons': microLessons.map((lesson) => lesson.toJson()).toList(),
    'sessions': sessions.map((session) => session.toJson()).toList(),
    'interactions': interactions
        .map((interaction) => interaction.toJson())
        .toList(),
    if (manifestSchemaVersion >= schemaVersion) ...{
      'studyDocuments': studyDocuments
          .map((document) => document.toJson())
          .toList(),
      'studyBlocks': studyBlocks.map((block) => block.toJson()).toList(),
    },
  };

  factory CurriculumManifest.fromJson(Map<String, dynamic> json) {
    final version = json['schemaVersion'];
    if (version != legacySchemaVersion && version != schemaVersion) {
      throw const CurriculumManifestException(
        'unsupported_schema',
        'Expected curriculum manifest schema $legacySchemaVersion or $schemaVersion.',
      );
    }
    if (version == legacySchemaVersion &&
        (json.containsKey('studyDocuments') ||
            json.containsKey('studyBlocks'))) {
      throw const CurriculumManifestException(
        'legacy_schema_study_body',
        'Schema v1 cannot declare Deep Study documents or blocks.',
      );
    }
    return CurriculumManifest(
      manifestSchemaVersion: version! as int,
      source: CurriculumSource.fromJson(
        Map<String, dynamic>.from(json['source'] as Map),
      ),
      release: CurriculumRelease.fromJson(
        Map<String, dynamic>.from(json['release'] as Map),
      ),
      nodes: _maps(json['nodes'], 'nodes').map(CurriculumNode.fromJson),
      localizationUnits: _maps(
        json['localizationUnits'],
        'localizationUnits',
      ).map(CurriculumLocalizationUnit.fromJson),
      microLessons: _maps(
        json['microLessons'],
        'microLessons',
      ).map(CurriculumMicroLesson.fromJson),
      sessions: _maps(
        json['sessions'],
        'sessions',
      ).map(CurriculumSession.fromJson),
      interactions: _maps(
        json['interactions'],
        'interactions',
      ).map(CurriculumInteraction.fromJson),
      studyDocuments: version == schemaVersion
          ? _maps(
              json['studyDocuments'],
              'studyDocuments',
            ).map(CurriculumStudyDocument.fromJson)
          : const [],
      studyBlocks: version == schemaVersion
          ? _maps(
              json['studyBlocks'],
              'studyBlocks',
            ).map(CurriculumStudyBlock.fromJson)
          : const [],
    );
  }

  void _validate() {
    if (manifestSchemaVersion != legacySchemaVersion &&
        manifestSchemaVersion != schemaVersion) {
      _fail(
        'unsupported_schema',
        'Unsupported curriculum manifest schema $manifestSchemaVersion.',
      );
    }
    if (manifestSchemaVersion == legacySchemaVersion &&
        (studyDocuments.isNotEmpty || studyBlocks.isNotEmpty)) {
      _fail(
        'legacy_schema_study_body',
        'Schema v1 cannot contain Deep Study documents or blocks.',
      );
    }
    if (release.sourceId != source.id) {
      _fail(
        'source_release_mismatch',
        'Release ${release.id} belongs to another source.',
      );
    }
    if (release.sourceTreeSha256 != source.sourceTreeSha256) {
      _fail('source_hash_mismatch', 'Source and release tree hashes differ.');
    }

    CurriculumTree(nodes);
    final nodesById = _unique(nodes, (node) => node.id, 'node');
    final localizationById = _unique(
      localizationUnits,
      (unit) => unit.id,
      'localization unit',
    );
    final lessonsById = _unique(
      microLessons,
      (lesson) => lesson.id,
      'micro-lesson',
    );
    final sessionsById = _unique(sessions, (session) => session.id, 'session');
    final interactionsById = _unique(
      interactions,
      (interaction) => interaction.id,
      'interaction',
    );
    final studyDocumentsById = _unique(
      studyDocuments,
      (document) => document.id,
      'study document',
    );
    final studyBlocksById = _unique(
      studyBlocks,
      (block) => block.id,
      'study block',
    );
    final microLessonIdsByNodeId =
        <CurriculumNodeId, CurriculumMicroLessonId>{};

    for (final node in nodes) {
      _requireLocalization(
        localizationById,
        node.titleUnitId,
        'node ${node.id} title',
      );
      if (release.isLearnerVisible &&
          node.identityState != CurriculumIdentityState.approved) {
        _fail('unapproved_node', 'Published release contains ${node.id}.');
      }
    }

    for (final lesson in microLessons) {
      final existingLessonId = microLessonIdsByNodeId[lesson.hierarchyNodeId];
      if (existingLessonId != null) {
        _fail(
          'duplicate_micro_lesson_node',
          '${lesson.hierarchyNodeId} is owned by both $existingLessonId and ${lesson.id}.',
        );
      }
      microLessonIdsByNodeId[lesson.hierarchyNodeId] = lesson.id;
      final hierarchyNode = nodesById[lesson.hierarchyNodeId];
      if (hierarchyNode?.kind != CurriculumNodeKind.microLesson) {
        _fail(
          'invalid_micro_lesson_node',
          '${lesson.id} has no Micro-lesson hierarchy node.',
        );
      }
      if (nodesById[lesson.unitId]?.kind != CurriculumNodeKind.unit ||
          nodesById[lesson.conceptClusterId]?.kind !=
              CurriculumNodeKind.conceptCluster) {
        _fail(
          'invalid_micro_lesson_lineage',
          '${lesson.id} has invalid Unit/Concept Cluster lineage.',
        );
      }
      if (hierarchyNode!.parentId != lesson.conceptClusterId ||
          nodesById[lesson.conceptClusterId]!.parentId != lesson.unitId) {
        _fail(
          'micro_lesson_lineage_mismatch',
          '${lesson.id} does not match its hierarchy-node ancestry.',
        );
      }
      if (hierarchyNode.ordinal != lesson.ordinal) {
        _fail(
          'micro_lesson_order_mismatch',
          '${lesson.id} does not match its hierarchy-node ordinal.',
        );
      }
      _requireLocalization(
        localizationById,
        lesson.titleUnitId,
        '${lesson.id} title',
      );
      for (final id in lesson.objectiveUnitIds) {
        _requireLocalization(localizationById, id, '${lesson.id} objective');
      }
      for (var index = 0; index < lesson.sessionIds.length; index++) {
        final sessionId = lesson.sessionIds[index];
        final session = sessionsById[sessionId];
        if (session == null) {
          _fail('missing_session', '${lesson.id} references $sessionId.');
        }
        if (session.microLessonId != lesson.id) {
          _fail(
            'session_owner_mismatch',
            '$sessionId is declared by ${lesson.id} but belongs to ${session.microLessonId}.',
          );
        }
        if (session.ordinal != index + 1) {
          _fail(
            'session_order_mismatch',
            '$sessionId does not match ${lesson.id} playback order.',
          );
        }
      }
    }
    if (!isScaffold) {
      for (final node in nodes) {
        if (node.kind == CurriculumNodeKind.microLesson &&
            !microLessonIdsByNodeId.containsKey(node.id)) {
          _fail(
            'missing_micro_lesson_body',
            '${node.id} has no declared Micro-lesson body.',
          );
        }
      }
    }

    _validateStudyBody(
      nodesById: nodesById,
      localizationById: localizationById,
      lessonsById: lessonsById,
      sessionsById: sessionsById,
      interactionsById: interactionsById,
      microLessonIdsByNodeId: microLessonIdsByNodeId,
      studyDocumentsById: studyDocumentsById,
      studyBlocksById: studyBlocksById,
    );

    for (final session in sessions) {
      final lesson = lessonsById[session.microLessonId];
      if (lesson == null) {
        _fail(
          'missing_micro_lesson',
          '${session.id} references ${session.microLessonId}.',
        );
      }
      if (!lesson.sessionIds.contains(session.id)) {
        _fail(
          'undeclared_session',
          '${session.id} is not declared in ${lesson.id} playback order.',
        );
      }
      _requireLocalization(
        localizationById,
        session.titleUnitId,
        '${session.id} title',
      );
      for (final id in session.objectiveUnitIds) {
        _requireLocalization(localizationById, id, '${session.id} objective');
      }
      final queue = <CurriculumInteraction>[];
      for (final interactionId in session.interactionIds) {
        final interaction = interactionsById[interactionId];
        if (interaction == null) {
          _fail(
            'missing_interaction',
            '${session.id} references $interactionId.',
          );
        }
        queue.add(interaction);
      }
      CurriculumSessionBundle(session: session, interactions: queue);
    }

    for (final interaction in interactions) {
      final session = sessionsById[interaction.sessionId];
      if (session == null) {
        _fail(
          'missing_session',
          '${interaction.id} references ${interaction.sessionId}.',
        );
      }
      if (!session.interactionIds.contains(interaction.id)) {
        _fail(
          'undeclared_interaction',
          '${interaction.id} is not declared in ${session.id} playback order.',
        );
      }
      final localizationIds = <CurriculumLocalizationUnitId>{
        interaction.promptUnitId,
        ?interaction.instructionUnitId,
        ...interaction.stimulus.localizationUnitIds,
        ...interaction.options.map((option) => option.labelUnitId),
        ...interaction.options.map((option) => option.whyWrongUnitId).nonNulls,
        ...interaction.evaluationSpec.rubricUnitIds,
        interaction.feedbackSpec.flashUnitId,
        interaction.feedbackSpec.repairUnitId,
        interaction.feedbackSpec.deepUnitId,
        interaction.feedbackSpec.whyCorrectUnitId,
        ...interaction.feedbackSpec.whyWrongByOptionId.values,
      };
      for (final id in localizationIds) {
        _requireLocalization(localizationById, id, '${interaction.id} content');
      }
    }

    if (release.isLearnerVisible) {
      for (final unit in localizationUnits) {
        if (!unit.isPublishable) {
          _fail(
            'unpublishable_localization',
            'Published release contains ${unit.id}.',
          );
        }
      }
      if (isScaffold) {
        _fail(
          'published_empty_scaffold',
          'A body-free scaffold cannot be published as a content release.',
        );
      }
    }
  }

  void _validateStudyBody({
    required Map<CurriculumNodeId, CurriculumNode> nodesById,
    required Map<CurriculumLocalizationUnitId, CurriculumLocalizationUnit>
    localizationById,
    required Map<CurriculumMicroLessonId, CurriculumMicroLesson> lessonsById,
    required Map<CurriculumSessionId, CurriculumSession> sessionsById,
    required Map<CurriculumInteractionId, CurriculumInteraction>
    interactionsById,
    required Map<CurriculumNodeId, CurriculumMicroLessonId>
    microLessonIdsByNodeId,
    required Map<CurriculumStudyDocumentId, CurriculumStudyDocument>
    studyDocumentsById,
    required Map<CurriculumStudyBlockId, CurriculumStudyBlock> studyBlocksById,
  }) {
    if (manifestSchemaVersion == legacySchemaVersion) return;

    final answerSurfaceLocalizationIds = <CurriculumLocalizationUnitId>{};
    for (final interaction in interactionsById.values) {
      answerSurfaceLocalizationIds.addAll(
        interaction.options.map((option) => option.labelUnitId),
      );
      answerSurfaceLocalizationIds.addAll(
        interaction.options.map((option) => option.whyWrongUnitId).nonNulls,
      );
      answerSurfaceLocalizationIds.addAll(
        interaction.evaluationSpec.rubricUnitIds,
      );
      answerSurfaceLocalizationIds.addAll([
        interaction.feedbackSpec.flashUnitId,
        interaction.feedbackSpec.repairUnitId,
        interaction.feedbackSpec.deepUnitId,
        interaction.feedbackSpec.whyCorrectUnitId,
        ...interaction.feedbackSpec.whyWrongByOptionId.values,
      ]);
    }

    const allowedStudyRoles = <ContentSemanticRole>{
      ContentSemanticRole.title,
      ContentSemanticRole.objective,
      ContentSemanticRole.instruction,
      ContentSemanticRole.explanation,
      ContentSemanticRole.caption,
      ContentSemanticRole.altText,
      ContentSemanticRole.accessibleAlternative,
      ContentSemanticRole.recap,
      ContentSemanticRole.debrief,
      ContentSemanticRole.disclaimer,
    };
    final documentsByNodeId =
        <CurriculumNodeId, List<CurriculumStudyDocument>>{};
    final declaredBlockIds = <CurriculumStudyBlockId>{};

    for (final document in studyDocumentsById.values) {
      final node = nodesById[document.microLessonNodeId];
      final lessonId = microLessonIdsByNodeId[document.microLessonNodeId];
      final lesson = lessonId == null ? null : lessonsById[lessonId];
      if (node?.kind != CurriculumNodeKind.microLesson || lesson == null) {
        _fail(
          'invalid_study_document_node',
          '${document.id} has no declared Micro-lesson owner.',
        );
      }
      final title = localizationById[document.titleUnitId];
      if (title == null) {
        _fail(
          'missing_localization',
          '${document.id} title references missing ${document.titleUnitId}.',
        );
      }
      if (title.semanticRole != ContentSemanticRole.title) {
        _fail(
          'invalid_study_document_title_role',
          '${document.titleUnitId} is not a title localization unit.',
        );
      }
      _requireSubset(
        document.sourceAtomIds,
        lesson.sourceAtomIds,
        'study_document_source_scope',
        '${document.id} source atoms exceed ${lesson.id}.',
      );
      _requireSubset(
        document.claimIds,
        lesson.claimIds,
        'study_document_claim_scope',
        '${document.id} claims exceed ${lesson.id}.',
      );
      _requireSubset(
        document.conceptIds,
        lesson.conceptIds,
        'study_document_concept_scope',
        '${document.id} concepts exceed ${lesson.id}.',
      );
      documentsByNodeId
          .putIfAbsent(document.microLessonNodeId, () => [])
          .add(document);

      for (var index = 0; index < document.blockIds.length; index++) {
        final blockId = document.blockIds[index];
        final block = studyBlocksById[blockId];
        if (block == null) {
          _fail('missing_study_block', '${document.id} references $blockId.');
        }
        if (!declaredBlockIds.add(blockId)) {
          _fail(
            'study_block_multiple_owners',
            '$blockId is declared by more than one study document.',
          );
        }
        if (block.documentId != document.id) {
          _fail(
            'study_block_owner_mismatch',
            '$blockId is declared by ${document.id} but belongs to ${block.documentId}.',
          );
        }
        if (block.ordinal != index + 1) {
          _fail(
            'study_block_order_mismatch',
            '$blockId does not match ${document.id} block order.',
          );
        }
        _requireSubset(
          block.sourceAtomIds,
          document.sourceAtomIds,
          'study_block_source_scope',
          '$blockId source atoms exceed ${document.id}.',
        );
        _requireSubset(
          block.claimIds,
          document.claimIds,
          'study_block_claim_scope',
          '$blockId claims exceed ${document.id}.',
        );
        _requireSubset(
          block.conceptIds,
          document.conceptIds,
          'study_block_concept_scope',
          '$blockId concepts exceed ${document.id}.',
        );
        for (final localizationId in block.localizationUnitIds) {
          final unit = localizationById[localizationId];
          if (unit == null) {
            _fail(
              'missing_localization',
              '$blockId references missing $localizationId.',
            );
          }
          if (answerSurfaceLocalizationIds.contains(localizationId)) {
            _fail(
              'study_answer_surface_leak',
              '$blockId reuses answer or feedback unit $localizationId.',
            );
          }
          if (!allowedStudyRoles.contains(unit.semanticRole)) {
            _fail(
              'invalid_study_localization_role',
              '$blockId cannot use ${unit.semanticRole.name} unit $localizationId.',
            );
          }
          _requireSubset(
            unit.sourceAtomIds,
            block.sourceAtomIds,
            'study_localization_source_scope',
            '$localizationId source atoms exceed $blockId.',
          );
          _requireSubset(
            unit.claimIds,
            block.claimIds,
            'study_localization_claim_scope',
            '$localizationId claims exceed $blockId.',
          );
          _requireSubset(
            unit.conceptIds,
            block.conceptIds,
            'study_localization_concept_scope',
            '$localizationId concepts exceed $blockId.',
          );
        }
        final gateSessionId = block.revealedAfterSessionId;
        if (gateSessionId != null &&
            sessionsById[gateSessionId]?.microLessonId != lesson.id) {
          _fail(
            'study_reveal_session_scope',
            '$blockId is gated by a Session outside ${lesson.id}.',
          );
        }
      }
    }

    for (final block in studyBlocksById.values) {
      if (!declaredBlockIds.contains(block.id)) {
        _fail(
          'undeclared_study_block',
          '${block.id} is not declared by a study document.',
        );
      }
    }

    for (final entry in documentsByNodeId.entries) {
      final documents = entry.value
        ..sort((a, b) => a.ordinal.compareTo(b.ordinal));
      for (var index = 0; index < documents.length; index++) {
        if (documents[index].ordinal != index + 1) {
          _fail(
            'study_document_order_mismatch',
            '${documents[index].id} does not match ${entry.key} document order.',
          );
        }
      }
    }

    if (release.isLearnerVisible) {
      for (final lesson in lessonsById.values) {
        final documents = documentsByNodeId[lesson.hierarchyNodeId] ?? const [];
        final primaryCount = documents
            .where(
              (document) =>
                  document.kind == CurriculumStudyDocumentKind.primaryLesson,
            )
            .length;
        if (primaryCount != 1) {
          _fail(
            'published_primary_study_document_count',
            '${lesson.id} requires exactly one primary Deep Study document; found $primaryCount.',
          );
        }
      }
    }
  }

  static List<Map<String, dynamic>> _maps(Object? value, String field) {
    if (value is! List) {
      throw CurriculumManifestException(
        'invalid_$field',
        '$field must be an array.',
      );
    }
    return value
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  }

  static Map<String, T> _unique<T>(
    Iterable<T> values,
    String Function(T value) id,
    String label,
  ) {
    final result = <String, T>{};
    for (final value in values) {
      final key = id(value);
      if (result.containsKey(key)) {
        _fail('duplicate_id', 'Duplicate $label ID $key.');
      }
      result[key] = value;
    }
    return result;
  }

  static void _requireLocalization(
    Map<String, CurriculumLocalizationUnit> values,
    String id,
    String context,
  ) {
    if (!values.containsKey(id)) {
      _fail('missing_localization', '$context references missing $id.');
    }
  }

  static void _requireSubset(
    Iterable<String> values,
    Iterable<String> allowed,
    String code,
    String message,
  ) {
    final allowedSet = allowed.toSet();
    if (values.any((value) => !allowedSet.contains(value))) {
      _fail(code, message);
    }
  }

  static Never _fail(String code, String message) =>
      throw CurriculumManifestException(code, message);

  @override
  List<Object?> get props => [
    manifestSchemaVersion,
    source,
    release,
    nodes,
    localizationUnits,
    microLessons,
    sessions,
    interactions,
    studyDocuments,
    studyBlocks,
  ];
}

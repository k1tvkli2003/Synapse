import 'package:synapse_core/synapse_core.dart';

final class CurriculumCatalogException implements Exception {
  const CurriculumCatalogException(this.code, this.message, [this.cause]);

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'CurriculumCatalogException($code): $message';
}

final class CurriculumCatalogEntry {
  const CurriculumCatalogEntry({
    required this.node,
    required this.titleEn,
    required this.titleFa,
  });

  final CurriculumNode node;
  final String titleEn;
  final String titleFa;

  String title(ContentLocale locale) =>
      locale == ContentLocale.fa ? titleFa : titleEn;
}

enum CurriculumCatalogMatchOrigin { requestedLocale, fallbackLocale, sourceKey }

final class CurriculumCatalogSearchHit {
  const CurriculumCatalogSearchHit({
    required this.entry,
    required this.matchedLocale,
    required this.matchOrigin,
    required this.matchTier,
  });

  final CurriculumCatalogEntry entry;
  final ContentLocale? matchedLocale;
  final CurriculumCatalogMatchOrigin matchOrigin;

  /// Lower is a stronger match: exact, prefix, word-prefix, substring, then
  /// source-key fallback. Cross-locale matches are deliberately lower ranked.
  final int matchTier;
}

/// Immutable query view derived from one validated curriculum manifest.
///
/// The snapshot is always rebuildable from the immutable package. It owns no
/// learner progress and is safe to discard under memory pressure.
final class CurriculumCatalogSnapshot {
  CurriculumCatalogSnapshot._({
    required this.releaseId,
    required this.sourceId,
    required this.canonicalSha256,
    required Map<CurriculumNodeId, CurriculumCatalogEntry> entriesById,
    required Map<CurriculumNodeId?, List<CurriculumCatalogEntry>> children,
    required Map<CurriculumNodeId, Set<CurriculumNodeId>> ancestorIdsByNodeId,
    required Map<CurriculumNodeId, _CurriculumSearchDocument> searchDocuments,
    required Map<CurriculumLocalizationUnitId, CurriculumLocalizationUnit>
    localizationById,
    required Map<CurriculumNodeId, CurriculumMicroLesson> microLessonsByNodeId,
    required Map<CurriculumMicroLessonId, List<CurriculumSession>>
    sessionsByMicroLessonId,
    required Map<CurriculumSessionId, List<CurriculumInteraction>>
    interactionsBySessionId,
    required Map<CurriculumNodeId, List<CurriculumStudyDocument>>
    studyDocumentsByMicroLessonNodeId,
    required Map<CurriculumStudyDocumentId, List<CurriculumStudyBlock>>
    studyBlocksByDocumentId,
  }) : _entriesById =
           Map<CurriculumNodeId, CurriculumCatalogEntry>.unmodifiable(
             entriesById,
           ),
       _children =
           Map<CurriculumNodeId?, List<CurriculumCatalogEntry>>.unmodifiable(
             children.map(
               (key, value) => MapEntry(
                 key,
                 List<CurriculumCatalogEntry>.unmodifiable(value),
               ),
             ),
           ),
       _ancestorIdsByNodeId = Map.unmodifiable(
         ancestorIdsByNodeId.map(
           (key, value) =>
               MapEntry(key, Set<CurriculumNodeId>.unmodifiable(value)),
         ),
       ),
       _searchDocuments = Map.unmodifiable(searchDocuments),
       _localizationById =
           Map<
             CurriculumLocalizationUnitId,
             CurriculumLocalizationUnit
           >.unmodifiable(localizationById),
       _microLessonsByNodeId =
           Map<CurriculumNodeId, CurriculumMicroLesson>.unmodifiable(
             microLessonsByNodeId,
           ),
       _sessionsByMicroLessonId =
           Map<CurriculumMicroLessonId, List<CurriculumSession>>.unmodifiable(
             sessionsByMicroLessonId.map(
               (key, value) =>
                   MapEntry(key, List<CurriculumSession>.unmodifiable(value)),
             ),
           ),
       _interactionsBySessionId =
           Map<CurriculumSessionId, List<CurriculumInteraction>>.unmodifiable(
             interactionsBySessionId.map(
               (key, value) => MapEntry(
                 key,
                 List<CurriculumInteraction>.unmodifiable(value),
               ),
             ),
           ),
       _studyDocumentsByMicroLessonNodeId =
           Map<CurriculumNodeId, List<CurriculumStudyDocument>>.unmodifiable(
             studyDocumentsByMicroLessonNodeId.map(
               (key, value) => MapEntry(
                 key,
                 List<CurriculumStudyDocument>.unmodifiable(value),
               ),
             ),
           ),
       _studyBlocksByDocumentId =
           Map<
             CurriculumStudyDocumentId,
             List<CurriculumStudyBlock>
           >.unmodifiable(
             studyBlocksByDocumentId.map(
               (key, value) => MapEntry(
                 key,
                 List<CurriculumStudyBlock>.unmodifiable(value),
               ),
             ),
           );

  factory CurriculumCatalogSnapshot.fromManifest(CurriculumManifest manifest) {
    final localizationById = {
      for (final unit in manifest.localizationUnits) unit.id: unit,
    };
    final entriesById = <CurriculumNodeId, CurriculumCatalogEntry>{};
    final children = <CurriculumNodeId?, List<CurriculumCatalogEntry>>{};
    for (final node in manifest.nodes) {
      final localization = localizationById[node.titleUnitId];
      if (localization == null) {
        throw CurriculumCatalogException(
          'missing_title_localization',
          'Curriculum node ${node.id} has no title localization.',
        );
      }
      final entry = CurriculumCatalogEntry(
        node: node,
        titleEn: localization.en.text,
        titleFa: localization.fa.text,
      );
      entriesById[node.id] = entry;
      children.putIfAbsent(node.parentId, () => []).add(entry);
    }
    for (final values in children.values) {
      values.sort(_compareEntries);
    }
    final ancestorIdsByNodeId = <CurriculumNodeId, Set<CurriculumNodeId>>{};
    for (final entry in entriesById.values) {
      final ancestors = <CurriculumNodeId>{};
      final visited = <CurriculumNodeId>{entry.node.id};
      var parentId = entry.node.parentId;
      while (parentId != null) {
        if (!visited.add(parentId)) {
          throw CurriculumCatalogException(
            'catalog_cycle',
            'Catalog ancestry for ${entry.node.id} contains a cycle.',
          );
        }
        final parent = entriesById[parentId];
        if (parent == null) {
          throw CurriculumCatalogException(
            'catalog_orphan',
            'Catalog ancestry for ${entry.node.id} is missing $parentId.',
          );
        }
        ancestors.add(parentId);
        parentId = parent.node.parentId;
      }
      ancestorIdsByNodeId[entry.node.id] = ancestors;
    }
    final searchDocuments = {
      for (final entry in entriesById.values)
        entry.node.id: _CurriculumSearchDocument(
          titleEn: normalizeSearchText(entry.titleEn),
          titleFa: normalizeSearchText(entry.titleFa),
          sourceKey: normalizeSearchText(entry.node.sourceKey),
        ),
    };

    final microLessonsByNodeId = <CurriculumNodeId, CurriculumMicroLesson>{};
    final sessionsById = <CurriculumSessionId, CurriculumSession>{
      for (final session in manifest.sessions) session.id: session,
    };
    final interactionsById = <CurriculumInteractionId, CurriculumInteraction>{
      for (final interaction in manifest.interactions)
        interaction.id: interaction,
    };
    final sessionsByMicroLessonId =
        <CurriculumMicroLessonId, List<CurriculumSession>>{};
    final interactionsBySessionId =
        <CurriculumSessionId, List<CurriculumInteraction>>{};
    final studyBlocksById = <CurriculumStudyBlockId, CurriculumStudyBlock>{
      for (final block in manifest.studyBlocks) block.id: block,
    };
    final studyDocumentsByMicroLessonNodeId =
        <CurriculumNodeId, List<CurriculumStudyDocument>>{};
    final studyBlocksByDocumentId =
        <CurriculumStudyDocumentId, List<CurriculumStudyBlock>>{};
    for (final lesson in manifest.microLessons) {
      if (microLessonsByNodeId.containsKey(lesson.hierarchyNodeId)) {
        throw CurriculumCatalogException(
          'duplicate_micro_lesson_node',
          'Catalog node ${lesson.hierarchyNodeId} has multiple micro-lessons.',
        );
      }
      microLessonsByNodeId[lesson.hierarchyNodeId] = lesson;
      sessionsByMicroLessonId[lesson.id] = [
        for (final sessionId in lesson.sessionIds)
          sessionsById[sessionId] ??
              (throw CurriculumCatalogException(
                'catalog_missing_session',
                '${lesson.id} references missing $sessionId.',
              )),
      ];
    }
    for (final session in manifest.sessions) {
      interactionsBySessionId[session.id] = [
        for (final interactionId in session.interactionIds)
          interactionsById[interactionId] ??
              (throw CurriculumCatalogException(
                'catalog_missing_interaction',
                '${session.id} references missing $interactionId.',
              )),
      ];
    }
    for (final document in manifest.studyDocuments) {
      studyDocumentsByMicroLessonNodeId
          .putIfAbsent(document.microLessonNodeId, () => [])
          .add(document);
      studyBlocksByDocumentId[document.id] = [
        for (final blockId in document.blockIds)
          studyBlocksById[blockId] ??
              (throw CurriculumCatalogException(
                'catalog_missing_study_block',
                '${document.id} references missing $blockId.',
              )),
      ];
    }

    return CurriculumCatalogSnapshot._(
      releaseId: manifest.release.id,
      sourceId: manifest.source.id,
      canonicalSha256: manifest.canonicalSha256,
      entriesById: entriesById,
      children: children,
      ancestorIdsByNodeId: ancestorIdsByNodeId,
      searchDocuments: searchDocuments,
      localizationById: localizationById,
      microLessonsByNodeId: microLessonsByNodeId,
      sessionsByMicroLessonId: sessionsByMicroLessonId,
      interactionsBySessionId: interactionsBySessionId,
      studyDocumentsByMicroLessonNodeId: studyDocumentsByMicroLessonNodeId,
      studyBlocksByDocumentId: studyBlocksByDocumentId,
    );
  }

  final CurriculumReleaseId releaseId;
  final CurriculumSourceId sourceId;
  final String canonicalSha256;
  final Map<CurriculumNodeId, CurriculumCatalogEntry> _entriesById;
  final Map<CurriculumNodeId?, List<CurriculumCatalogEntry>> _children;
  final Map<CurriculumNodeId, Set<CurriculumNodeId>> _ancestorIdsByNodeId;
  final Map<CurriculumNodeId, _CurriculumSearchDocument> _searchDocuments;
  final Map<CurriculumLocalizationUnitId, CurriculumLocalizationUnit>
  _localizationById;
  final Map<CurriculumNodeId, CurriculumMicroLesson> _microLessonsByNodeId;
  final Map<CurriculumMicroLessonId, List<CurriculumSession>>
  _sessionsByMicroLessonId;
  final Map<CurriculumSessionId, List<CurriculumInteraction>>
  _interactionsBySessionId;
  final Map<CurriculumNodeId, List<CurriculumStudyDocument>>
  _studyDocumentsByMicroLessonNodeId;
  final Map<CurriculumStudyDocumentId, List<CurriculumStudyBlock>>
  _studyBlocksByDocumentId;

  int get nodeCount => _entriesById.length;
  int get searchDocumentCount => _searchDocuments.length;
  int get microLessonCount => _microLessonsByNodeId.length;
  int get sessionCount => _sessionsByMicroLessonId.values.fold(
    0,
    (total, values) => total + values.length,
  );
  int get studyDocumentCount => _studyDocumentsByMicroLessonNodeId.values.fold(
    0,
    (total, values) => total + values.length,
  );
  int get studyBlockCount => _studyBlocksByDocumentId.values.fold(
    0,
    (total, values) => total + values.length,
  );

  CurriculumCatalogEntry? entryById(CurriculumNodeId id) => _entriesById[id];

  List<CurriculumCatalogEntry> get courses => childrenOf(null);

  List<CurriculumCatalogEntry> childrenOf(CurriculumNodeId? parentId) =>
      _children[parentId] ?? const [];

  List<CurriculumCatalogEntry> ancestorsOf(CurriculumNodeId id) {
    final result = <CurriculumCatalogEntry>[];
    final visited = <CurriculumNodeId>{};
    var current = _entriesById[id];
    if (current == null) return const [];
    while (current!.node.parentId != null) {
      if (!visited.add(current.node.id)) {
        throw CurriculumCatalogException(
          'catalog_cycle',
          'Catalog ancestry for $id contains a cycle.',
        );
      }
      final parent = _entriesById[current.node.parentId];
      if (parent == null) {
        throw CurriculumCatalogException(
          'catalog_orphan',
          'Catalog ancestry for $id is missing ${current.node.parentId}.',
        );
      }
      result.insert(0, parent);
      current = parent;
    }
    return List.unmodifiable(result);
  }

  CurriculumMicroLesson? microLessonForNode(CurriculumNodeId nodeId) =>
      _microLessonsByNodeId[nodeId];

  List<CurriculumSession> sessionsForMicroLesson(
    CurriculumMicroLessonId microLessonId,
  ) => _sessionsByMicroLessonId[microLessonId] ?? const [];

  List<CurriculumInteraction> interactionsForSession(
    CurriculumSessionId sessionId,
  ) => _interactionsBySessionId[sessionId] ?? const [];

  List<CurriculumStudyDocument> studyDocumentsForMicroLessonNode(
    CurriculumNodeId microLessonNodeId,
  ) => _studyDocumentsByMicroLessonNodeId[microLessonNodeId] ?? const [];

  CurriculumStudyDocument? primaryStudyDocumentForMicroLessonNode(
    CurriculumNodeId microLessonNodeId,
  ) {
    for (final document in studyDocumentsForMicroLessonNode(
      microLessonNodeId,
    )) {
      if (document.kind == CurriculumStudyDocumentKind.primaryLesson) {
        return document;
      }
    }
    return null;
  }

  List<CurriculumStudyBlock> studyBlocksForDocument(
    CurriculumStudyDocumentId documentId,
  ) => _studyBlocksByDocumentId[documentId] ?? const [];

  CurriculumLocalizationUnit? localizationUnit(
    CurriculumLocalizationUnitId id,
  ) => _localizationById[id];

  String? localizedText(
    CurriculumLocalizationUnitId id,
    ContentLocale locale,
  ) => _localizationById[id]?.variant(locale).text;

  List<CurriculumCatalogSearchHit> search(
    String query,
    ContentLocale locale, {
    CurriculumNodeKind? kind,
    CurriculumNodeId? withinNodeId,
    int limit = 20,
  }) {
    if (limit < 1 || limit > 100) {
      throw RangeError.range(limit, 1, 100, 'limit');
    }
    if (withinNodeId != null && !_entriesById.containsKey(withinNodeId)) {
      throw CurriculumCatalogException(
        'catalog_search_scope_missing',
        'Catalog search scope $withinNodeId does not exist.',
      );
    }
    final normalizedQuery = normalizeSearchText(query);
    if (normalizedQuery.isEmpty) return const [];
    final otherLocale = locale == ContentLocale.en
        ? ContentLocale.fa
        : ContentLocale.en;
    final hits = <CurriculumCatalogSearchHit>[];
    for (final entry in _entriesById.values) {
      if (kind != null && entry.node.kind != kind) continue;
      if (withinNodeId != null &&
          entry.node.id != withinNodeId &&
          !_ancestorIdsByNodeId[entry.node.id]!.contains(withinNodeId)) {
        continue;
      }
      final document = _searchDocuments[entry.node.id]!;
      final requestedTier = _textMatchTier(
        document.title(locale),
        normalizedQuery,
      );
      final fallbackTier = _textMatchTier(
        document.title(otherLocale),
        normalizedQuery,
      );
      final sourceTier = _textMatchTier(document.sourceKey, normalizedQuery);
      if (requestedTier != null) {
        hits.add(
          CurriculumCatalogSearchHit(
            entry: entry,
            matchedLocale: locale,
            matchOrigin: CurriculumCatalogMatchOrigin.requestedLocale,
            matchTier: requestedTier,
          ),
        );
      } else if (fallbackTier != null) {
        hits.add(
          CurriculumCatalogSearchHit(
            entry: entry,
            matchedLocale: otherLocale,
            matchOrigin: CurriculumCatalogMatchOrigin.fallbackLocale,
            matchTier: fallbackTier + 10,
          ),
        );
      } else if (sourceTier != null) {
        hits.add(
          CurriculumCatalogSearchHit(
            entry: entry,
            matchedLocale: null,
            matchOrigin: CurriculumCatalogMatchOrigin.sourceKey,
            matchTier: sourceTier + 20,
          ),
        );
      }
    }
    hits.sort((left, right) {
      final tier = left.matchTier.compareTo(right.matchTier);
      if (tier != 0) return tier;
      return _compareEntries(left.entry, right.entry);
    });
    return List.unmodifiable(hits.take(limit));
  }

  static String normalizeSearchText(String value) {
    var normalized = value
        .trim()
        .toLowerCase()
        .replaceAll('ي', 'ی')
        .replaceAll('ى', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED]'), '')
        .replaceAll('\u200c', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    while (normalized.contains('  ')) {
      normalized = normalized.replaceAll('  ', ' ');
    }
    return normalized;
  }

  static int? _textMatchTier(String value, String query) {
    if (value == query) return 0;
    if (value.startsWith(query)) return 1;
    if (value.split(' ').any((word) => word.startsWith(query))) return 2;
    if (value.contains(query)) return 3;
    return null;
  }

  static int _compareEntries(
    CurriculumCatalogEntry left,
    CurriculumCatalogEntry right,
  ) {
    final ordinal = left.node.ordinal.compareTo(right.node.ordinal);
    return ordinal != 0 ? ordinal : left.node.id.compareTo(right.node.id);
  }
}

final class _CurriculumSearchDocument {
  const _CurriculumSearchDocument({
    required this.titleEn,
    required this.titleFa,
    required this.sourceKey,
  });

  final String titleEn;
  final String titleFa;
  final String sourceKey;

  String title(ContentLocale locale) =>
      locale == ContentLocale.fa ? titleFa : titleEn;
}

/// Privacy-safe state for the rebuildable catalog cache. It contains release
/// identifiers and aggregate counts only—never curriculum bodies or learner
/// state.
final class CurriculumCatalogCacheStatus {
  const CurriculumCatalogCacheStatus({
    required this.releaseIdsLeastRecentFirst,
    required this.totalNodeCount,
    required this.hitCount,
    required this.missCount,
    required this.evictionCount,
    required this.oversizedBypassCount,
    required this.invalidatedBuildCount,
    required this.inFlightBuildCount,
    required this.activeLookupCount,
  });

  final List<CurriculumReleaseId> releaseIdsLeastRecentFirst;
  final int totalNodeCount;
  final int hitCount;
  final int missCount;
  final int evictionCount;
  final int oversizedBypassCount;
  final int invalidatedBuildCount;
  final int inFlightBuildCount;
  final int activeLookupCount;

  int get releaseCount => releaseIdsLeastRecentFirst.length;
}

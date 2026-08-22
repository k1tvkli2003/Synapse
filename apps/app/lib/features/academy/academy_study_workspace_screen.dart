import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_services/synapse_services.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../../brand/synapse_identity.dart';
import '../../router/routes.dart';
import '../../state/app_providers.dart';
import '../../state/curriculum_provider.dart';
import '../../state/settings_provider.dart';

/// The contextual deep-study surface for one stable curriculum node.
///
/// This is the unified home for contextual reading, note, bookmark, source and
/// focus primitives. It is deliberately not a second product or a generic
/// tools dashboard: every action remains attached to the active package source
/// and curriculum node.
class AcademyStudyWorkspaceScreen extends ConsumerWidget {
  const AcademyStudyWorkspaceScreen({super.key, required this.nodeId});

  final String nodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = _studyLocale(ref.watch(settingsProvider).locale);
    final runtime = ref.watch(curriculumRuntimeProvider);
    return _StudyCanvas(
      child: runtime.when(
        loading: () => _StudyState(
          locale: locale,
          icon: Icons.auto_stories_rounded,
          title: _StudyCopy(locale).openingWorkspace,
          body: _StudyCopy(locale).openingWorkspaceBody,
          busy: true,
        ),
        error: (_, _) => _StudyState(
          locale: locale,
          icon: Icons.sync_problem_rounded,
          title: _StudyCopy(locale).workspaceUnavailable,
          body: _StudyCopy(locale).workspaceUnavailableBody,
          onRetry: () => ref.invalidate(curriculumRuntimeProvider),
        ),
        data: (result) {
          if (result.status != CurriculumRuntimeBootstrapStatus.ready) {
            return _StudyState(
              locale: locale,
              icon: Icons.inventory_2_outlined,
              title: _StudyCopy(locale).reviewedPackageRequired,
              body: _StudyCopy(locale).reviewedPackageRequiredBody,
              onRetry: result.canRetry
                  ? () => ref.invalidate(curriculumRuntimeProvider)
                  : null,
            );
          }
          final catalog = result.catalog!;
          final entry = catalog.entryById(nodeId);
          if (entry == null) {
            return _StudyState(
              locale: locale,
              icon: Icons.travel_explore_rounded,
              title: _StudyCopy(locale).contextNotFound,
              body: _StudyCopy(locale).contextNotFoundBody,
            );
          }
          return _StudyWorkspaceBody(
            locale: locale,
            catalog: catalog,
            entry: entry,
          );
        },
      ),
    );
  }
}

class _StudyCanvas extends StatelessWidget {
  const _StudyCanvas({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _StudyColors.midnight,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.72, -0.92),
            radius: 1.45,
            colors: [Color(0xFF082447), _StudyColors.midnight],
            stops: [0, 0.72],
          ),
        ),
        child: SafeArea(child: child),
      ),
    );
  }
}

class _StudyState extends StatelessWidget {
  const _StudyState({
    required this.locale,
    required this.icon,
    required this.title,
    required this.body,
    this.busy = false,
    this.onRetry,
  });

  final ContentLocale locale;
  final IconData icon;
  final String title;
  final String body;
  final bool busy;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final copy = _StudyCopy(locale);
    return Directionality(
      textDirection: locale == ContentLocale.fa
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Column(
        children: [
          _StudyTopBar(locale: locale),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: AppCard(
                    color: _StudyColors.panel.withValues(alpha: 0.9),
                    accent: _StudyColors.cyan,
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        if (busy)
                          const SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              color: _StudyColors.cyan,
                              strokeWidth: 3,
                            ),
                          )
                        else
                          Icon(icon, color: _StudyColors.cyan, size: 42),
                        const SizedBox(height: 18),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          body,
                          textAlign: TextAlign.center,
                          style: _bodyStyle(context),
                        ),
                        if (onRetry != null) ...[
                          const SizedBox(height: 22),
                          AppButton(
                            label: copy.tryAgain,
                            icon: Icons.refresh_rounded,
                            accent: _StudyColors.cyan,
                            onPressed: onRetry,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudyWorkspaceBody extends ConsumerStatefulWidget {
  const _StudyWorkspaceBody({
    required this.locale,
    required this.catalog,
    required this.entry,
  });

  final ContentLocale locale;
  final CurriculumCatalogSnapshot catalog;
  final CurriculumCatalogEntry entry;

  @override
  ConsumerState<_StudyWorkspaceBody> createState() =>
      _StudyWorkspaceBodyState();
}

class _StudyWorkspaceBodyState extends ConsumerState<_StudyWorkspaceBody>
    with WidgetsBindingObserver {
  final TextEditingController _noteController = TextEditingController();
  final ScrollController _mainScrollController = ScrollController();
  final Map<CurriculumStudyBlockId, GlobalKey> _studyBlockKeys = {};
  Timer? _focusTimer;
  Timer? _readingPositionTimer;
  _WorkspaceTool _selectedTool = _WorkspaceTool.notes;
  int _selectedFocusMinutes = 25;
  int _remainingFocusSeconds = 25 * 60;
  int _elapsedFocusSeconds = 0;
  String? _focusSegmentId;
  String? _writeError;
  bool _mutating = false;
  bool _focusSaving = false;
  bool _importingDocument = false;
  ResourceDocumentId? _detachingDocumentId;
  bool _readingPositionSaving = false;
  bool _readingPositionWriteFailed = false;
  bool _initialReadingRestoreHandled = false;
  bool _storedReadingAnchorMissing = false;
  CurriculumStudyBlock? _pendingReadingBlock;

  CurriculumStudyWorkspaceKey get _workspaceKey => CurriculumStudyWorkspaceKey(
    sourceId: widget.catalog.sourceId,
    nodeId: widget.entry.node.id,
  );

  CurriculumStudyWorkspaceRequest get _request =>
      (key: _workspaceKey, releaseId: widget.catalog.releaseId);

  CurriculumStudyDocument? get _studyDocument => widget.catalog
      .primaryStudyDocumentForMicroLessonNode(widget.entry.node.id);

  List<CurriculumStudyBlock> get _studyBlocks {
    final document = _studyDocument;
    return document == null
        ? const []
        : widget.catalog.studyBlocksForDocument(document.id);
  }

  CurriculumReadingPositionKey? get _readingPositionKey {
    final document = _studyDocument;
    if (document == null) return null;
    return CurriculumReadingPositionKey(
      sourceId: widget.catalog.sourceId,
      microLessonNodeId: document.microLessonNodeId,
      documentId: document.id,
    );
  }

  ResourceReference get _nodeResource => ResourceReference.curriculumNode(
    sourceId: widget.catalog.sourceId,
    nodeId: widget.entry.node.id,
  );

  WholeResourceAnchor get _nodeAnchor => WholeResourceAnchor(_nodeResource);

  GlobalKey _blockKey(CurriculumStudyBlockId blockId) => _studyBlockKeys
      .putIfAbsent(blockId, () => GlobalKey(debugLabel: 'deep-study-$blockId'));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mainScrollController.addListener(_onReadingScroll);
  }

  @override
  void didUpdateWidget(covariant _StudyWorkspaceBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.catalog.releaseId != widget.catalog.releaseId ||
        oldWidget.entry.node.id != widget.entry.node.id) {
      _readingPositionTimer?.cancel();
      _studyBlockKeys.clear();
      _pendingReadingBlock = null;
      _initialReadingRestoreHandled = false;
      _storedReadingAnchorMissing = false;
      _readingPositionWriteFailed = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusTimer?.cancel();
    _readingPositionTimer?.cancel();
    _mainScrollController
      ..removeListener(_onReadingScroll)
      ..dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_focusTimer != null &&
        state != AppLifecycleState.resumed &&
        state != AppLifecycleState.inactive) {
      unawaited(_pauseAndSaveFocus());
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(curriculumStudyWorkspaceProvider(_request));
    final readingKey = _readingPositionKey;
    final readingPosition = readingKey == null
        ? null
        : ref.watch(curriculumReadingPositionProvider(readingKey));
    final bookmark = ref.watch(resourceBookmarkProvider(_nodeAnchor.stableId));
    final isBookmarked = bookmark.asData?.value != null;
    final openedWorkspace = workspace.asData?.value;
    return Directionality(
      textDirection: widget.locale == ContentLocale.fa
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Column(
        children: [
          _StudyTopBar(
            locale: widget.locale,
            trailing: openedWorkspace == null
                ? null
                : AppIconButton(
                    icon: isBookmarked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    tooltip: isBookmarked
                        ? _StudyCopy(widget.locale).removeBookmark
                        : _StudyCopy(widget.locale).bookmarkLesson,
                    color: isBookmarked ? _StudyColors.gold : Colors.white70,
                    onPressed: _mutating || bookmark.isLoading
                        ? null
                        : () => _setBookmark(!isBookmarked),
                  ),
          ),
          Expanded(
            child: workspace.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: _StudyColors.cyan),
              ),
              error: (_, _) => _WorkspaceInlineFailure(
                locale: widget.locale,
                onRetry: () =>
                    ref.invalidate(curriculumStudyWorkspaceProvider(_request)),
              ),
              data: (value) {
                if (readingPosition != null) {
                  _scheduleInitialReadingRestore(readingPosition);
                }
                return _workspaceLayout(
                  context,
                  value,
                  readingPosition: readingPosition,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _workspaceLayout(
    BuildContext context,
    CurriculumStudyWorkspace workspace, {
    required AsyncValue<CurriculumReadingPosition?>? readingPosition,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    final main = _StudyMainPane(
      locale: widget.locale,
      catalog: widget.catalog,
      entry: widget.entry,
      studyBlockKeys: {
        for (final block in _studyBlocks) block.id: _blockKey(block.id),
      },
      readingPosition: readingPosition,
      readingPositionSaving: _readingPositionSaving,
      readingPositionWriteFailed: _readingPositionWriteFailed,
      storedReadingAnchorMissing: _storedReadingAnchorMissing,
      onRetryReadingPosition: _retryReadingPosition,
      onOpenNotes: () => setState(() => _selectedTool = _WorkspaceTool.notes),
    );
    final tools = _StudyToolsPane(
      locale: widget.locale,
      entry: widget.entry,
      catalog: widget.catalog,
      workspace: workspace,
      selectedTool: _selectedTool,
      noteController: _noteController,
      selectedFocusMinutes: _selectedFocusMinutes,
      remainingFocusSeconds: _remainingFocusSeconds,
      elapsedFocusSeconds: _elapsedFocusSeconds,
      focusRunning: _focusTimer != null,
      mutating: _mutating || _focusSaving,
      importingDocument: _importingDocument,
      detachingDocumentId: _detachingDocumentId,
      writeError: _writeError,
      onToolSelected: (tool) => setState(() => _selectedTool = tool),
      onAddNote: _addNote,
      onDeleteNote: _deleteNote,
      onFocusMinutesChanged: _changeFocusPreset,
      onFocusAction: _focusTimer == null ? _startFocus : _pauseAndSaveFocus,
      onImportDocument: _importDocument,
      onDetachDocument: _detachDocument,
      onOpenDocument: (document) => context.push(
        Routes.academyDocumentFor(document.id, widget.entry.node.id),
      ),
    );

    if (width >= 980) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1440),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: _mainScrollController,
                  padding: const EdgeInsets.fromLTRB(28, 22, 18, 40),
                  child: main,
                ),
              ),
              Container(width: 1, color: Colors.white.withValues(alpha: 0.08)),
              SizedBox(
                width: width >= 1240 ? 420 : 360,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 22, 28, 40),
                  child: tools,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      controller: _mainScrollController,
      padding: EdgeInsets.fromLTRB(
        width < 600 ? 18 : 28,
        18,
        width < 600 ? 18 : 28,
        40,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(children: [main, const SizedBox(height: 18), tools]),
        ),
      ),
    );
  }

  void _scheduleInitialReadingRestore(
    AsyncValue<CurriculumReadingPosition?> readingPosition,
  ) {
    if (_initialReadingRestoreHandled ||
        readingPosition.isLoading ||
        readingPosition.hasError) {
      return;
    }
    _initialReadingRestoreHandled = true;
    final saved = readingPosition.asData?.value;
    if (saved == null) return;
    final blocks = _studyBlocks;
    if (blocks.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _storedReadingAnchorMissing = true);
      });
      return;
    }
    CurriculumStudyBlock? exactBlock;
    for (final candidate in blocks) {
      if (candidate.id == saved.blockId) {
        exactBlock = candidate;
        break;
      }
    }
    final ordinalIndex = saved.blockOrdinal - 1;
    final fallbackIndex = ordinalIndex >= 0 && ordinalIndex < blocks.length
        ? ordinalIndex
        : blocks.length == 1
        ? 0
        : ((saved.documentPositionPermille / 1000) * (blocks.length - 1))
              .round();
    final block =
        exactBlock ?? blocks[fallbackIndex.clamp(0, blocks.length - 1)];
    var restoredByFallback = exactBlock == null;
    final anchorUnitId = saved.anchorUnitId;
    if (anchorUnitId != null &&
        !block.localizationUnitIds.contains(anchorUnitId)) {
      restoredByFallback = true;
    }
    if (restoredByFallback) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _storedReadingAnchorMissing = true);
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final anchorContext = _blockKey(block.id).currentContext;
      if (anchorContext == null) return;
      final duration = MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 320);
      unawaited(
        Scrollable.ensureVisible(
          anchorContext,
          alignment: 0.08,
          duration: duration,
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  void _onReadingScroll() {
    if (!_mainScrollController.hasClients) return;
    _readingPositionTimer?.cancel();
    _readingPositionTimer = Timer(
      const Duration(milliseconds: 650),
      _queueVisibleReadingAnchor,
    );
  }

  void _queueVisibleReadingAnchor() {
    if (!mounted || !_mainScrollController.hasClients) return;
    final blocks = _studyBlocks;
    if (blocks.isEmpty) return;
    final anchorLine = MediaQuery.paddingOf(context).top + 96;
    CurriculumStudyBlock? candidate;
    for (final block in blocks) {
      final renderObject = _blockKey(
        block.id,
      ).currentContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.attached) continue;
      final top = renderObject.localToGlobal(Offset.zero).dy;
      final bottom = top + renderObject.size.height;
      if (top <= anchorLine) candidate = block;
      if (top <= anchorLine && bottom >= anchorLine) break;
      if (candidate == null && top > anchorLine) {
        candidate = block;
        break;
      }
    }
    if (candidate == null) return;
    _pendingReadingBlock = candidate;
    unawaited(_flushReadingPosition());
  }

  Future<void> _flushReadingPosition() async {
    if (_readingPositionSaving) return;
    final block = _pendingReadingBlock;
    final key = _readingPositionKey;
    final document = _studyDocument;
    if (block == null || key == null || document == null) return;
    _pendingReadingBlock = null;
    final blocks = _studyBlocks;
    final index = blocks.indexWhere((item) => item.id == block.id);
    if (index < 0) return;
    final positionPermille = blocks.length == 1
        ? 0
        : ((index * 1000) / (blocks.length - 1)).round();
    setState(() {
      _readingPositionSaving = true;
      _readingPositionWriteFailed = false;
    });
    try {
      final repository = ref.read(curriculumReadingStateRepositoryProvider);
      final current = await repository.read(key);
      await repository.savePosition(
        key: key,
        releaseId: widget.catalog.releaseId,
        blockId: block.id,
        blockOrdinal: block.ordinal,
        anchorUnitId: _firstAnchorUnitId(block),
        documentPositionPermille: positionPermille,
        locale: widget.locale,
        expectedRevision: current?.revision,
      );
      ref.invalidate(curriculumReadingPositionProvider(key));
    } on CurriculumReadingStateException {
      if (mounted) setState(() => _readingPositionWriteFailed = true);
    } on Object {
      if (mounted) setState(() => _readingPositionWriteFailed = true);
    } finally {
      if (mounted) setState(() => _readingPositionSaving = false);
      if (_pendingReadingBlock != null) unawaited(_flushReadingPosition());
    }
  }

  CurriculumLocalizationUnitId? _firstAnchorUnitId(CurriculumStudyBlock block) {
    if (block.headingUnitId != null) return block.headingUnitId;
    if (block.contentUnitIds.isNotEmpty) return block.contentUnitIds.first;
    for (final row in block.tableRows) {
      if (row.isNotEmpty) return row.first;
    }
    return null;
  }

  void _retryReadingPosition() {
    final key = _readingPositionKey;
    if (key != null) ref.invalidate(curriculumReadingPositionProvider(key));
    setState(() {
      _readingPositionWriteFailed = false;
      _storedReadingAnchorMissing = false;
    });
    _queueVisibleReadingAnchor();
  }

  Future<void> _setBookmark(bool value) async {
    if (_mutating) return;
    setState(() {
      _mutating = true;
      _writeError = null;
    });
    try {
      final repository = ref.read(resourceWorkspaceRepositoryProvider);
      final existing = await repository.readBookmark(
        _nodeAnchor.stableId,
        includeDeleted: true,
      );
      await repository.setBookmarked(
        anchor: _nodeAnchor,
        isBookmarked: value,
        color: ResourceArtifactColor.gold,
        expectedRevision: existing?.revision,
      );
      ref.invalidate(resourceBookmarkProvider(_nodeAnchor.stableId));
      await ref.read(resourceBookmarkProvider(_nodeAnchor.stableId).future);
    } on Object {
      if (mounted) {
        setState(() => _writeError = _StudyCopy(widget.locale).saveFailed);
      }
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _importDocument() async {
    if (_importingDocument) return;
    setState(() {
      _importingDocument = true;
      _writeError = null;
    });
    try {
      final result = await ref
          .read(resourceDocumentImportServiceProvider)
          .pickAndImportPdf(context: _nodeResource);
      if (result == null || !mounted) return;
      ref.invalidate(contextualResourceDocumentsProvider(_nodeResource));
      ref.invalidate(resourceDocumentProvider(result.document.id));
      await ref.read(contextualResourceDocumentsProvider(_nodeResource).future);
    } on Object {
      if (mounted) {
        setState(
          () => _writeError = _StudyCopy(widget.locale).documentImportFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _importingDocument = false);
    }
  }

  Future<void> _detachDocument(ResourceDocument document) async {
    if (_detachingDocumentId != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_StudyCopy(widget.locale).detachReference),
        content: Text(
          _StudyCopy(widget.locale).detachReferenceBody(document.displayName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(_StudyCopy(widget.locale).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(_StudyCopy(widget.locale).detach),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _detachingDocumentId = document.id;
      _writeError = null;
    });
    try {
      final repository = ref.read(resourceWorkspaceRepositoryProvider);
      final id = ResourceCrossReference.stableIdFor(
        from: _nodeResource,
        to: document.reference,
        kind: ResourceCrossReferenceKind.supportingDocument,
      );
      final existing = await repository.readCrossReference(
        id,
        includeDeleted: true,
      );
      if (existing != null && !existing.isDeleted) {
        await repository.setCrossReference(
          from: _nodeResource,
          to: document.reference,
          kind: ResourceCrossReferenceKind.supportingDocument,
          isLinked: false,
          expectedRevision: existing.revision,
        );
      }
      ref.invalidate(contextualResourceDocumentsProvider(_nodeResource));
      await ref.read(contextualResourceDocumentsProvider(_nodeResource).future);
    } on Object {
      if (mounted) {
        setState(
          () => _writeError = _StudyCopy(widget.locale).detachReferenceFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _detachingDocumentId = null);
    }
  }

  Future<void> _addNote() async {
    final body = _noteController.text.trim();
    if (body.isEmpty || _mutating) return;
    setState(() {
      _mutating = true;
      _writeError = null;
    });
    try {
      final anchor = await _currentNoteAnchor();
      await ref
          .read(resourceWorkspaceRepositoryProvider)
          .registerAnchor(anchor);
      final saved = await _mutateWorkspace(
        (repository, current) => repository.addNote(
          key: _workspaceKey,
          releaseId: widget.catalog.releaseId,
          locale: widget.locale,
          body: body,
          anchorId: anchor.stableId,
          expectedRevision: current.revision,
        ),
        ownsBusyState: false,
      );
      if (saved) _noteController.clear();
    } on Object {
      if (mounted) {
        setState(() => _writeError = _StudyCopy(widget.locale).saveFailed);
      }
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<ResourceAnchor> _currentNoteAnchor() async {
    final key = _readingPositionKey;
    if (key != null) {
      final position = await ref
          .read(curriculumReadingStateRepositoryProvider)
          .read(key);
      if (position != null) return position.resourceAnchor;
    }
    return _nodeAnchor;
  }

  Future<void> _deleteNote(String noteId) => _mutateWorkspace(
    (repository, current) => repository.deleteNote(
      key: _workspaceKey,
      releaseId: widget.catalog.releaseId,
      noteId: noteId,
      expectedRevision: current.revision,
    ),
  );

  void _changeFocusPreset(int minutes) {
    if (_focusTimer != null || _elapsedFocusSeconds > 0) return;
    setState(() {
      _selectedFocusMinutes = minutes;
      _remainingFocusSeconds = minutes * 60;
    });
  }

  void _startFocus() {
    if (_focusSaving || _focusTimer != null) return;
    if (_remainingFocusSeconds <= 0) {
      _remainingFocusSeconds = _selectedFocusMinutes * 60;
    }
    _focusSegmentId ??= ref.read(operationalIdSourceProvider).nextId();
    setState(() {
      _writeError = null;
      _focusTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (_remainingFocusSeconds <= 1) {
          setState(() {
            _remainingFocusSeconds = 0;
            _elapsedFocusSeconds += 1;
          });
          unawaited(_pauseAndSaveFocus());
          return;
        }
        setState(() {
          _remainingFocusSeconds -= 1;
          _elapsedFocusSeconds += 1;
        });
      });
    });
  }

  Future<void> _pauseAndSaveFocus() async {
    if (_focusSaving) return;
    _focusTimer?.cancel();
    if (mounted) setState(() => _focusTimer = null);
    if (_elapsedFocusSeconds < 1 || _focusSegmentId == null) return;
    _focusSaving = true;
    if (mounted) setState(() {});
    final elapsed = _elapsedFocusSeconds;
    final segmentId = _focusSegmentId!;
    final saved = await _mutateWorkspace(
      (repository, current) => repository.recordFocusSegment(
        key: _workspaceKey,
        releaseId: widget.catalog.releaseId,
        segmentId: segmentId,
        durationSeconds: elapsed,
        expectedRevision: current.revision,
      ),
      ownsBusyState: false,
    );
    _focusSaving = false;
    if (!mounted) return;
    setState(() {
      if (saved) {
        _elapsedFocusSeconds = 0;
        _remainingFocusSeconds = _selectedFocusMinutes * 60;
        _focusSegmentId = null;
      }
    });
  }

  Future<bool> _mutateWorkspace(
    Future<CurriculumStudyWorkspace> Function(
      CurriculumStudyWorkspaceRepository repository,
      CurriculumStudyWorkspace current,
    )
    operation, {
    bool ownsBusyState = true,
  }) async {
    if (ownsBusyState && _mutating) return false;
    if (mounted) {
      setState(() {
        if (ownsBusyState) _mutating = true;
        _writeError = null;
      });
    }
    try {
      final repository = ref.read(curriculumStudyWorkspaceRepositoryProvider);
      final current = await repository.read(_workspaceKey);
      if (current == null) {
        throw const CurriculumStudyWorkspaceException(
          'workspace_missing',
          'The study workspace is not open.',
        );
      }
      await operation(repository, current);
      ref.invalidate(curriculumStudyWorkspaceProvider(_request));
      await ref.read(curriculumStudyWorkspaceProvider(_request).future);
      return true;
    } on Object {
      if (mounted) {
        setState(() => _writeError = _StudyCopy(widget.locale).saveFailed);
      }
      return false;
    } finally {
      if (ownsBusyState && mounted) setState(() => _mutating = false);
    }
  }
}

class _StudyTopBar extends StatelessWidget {
  const _StudyTopBar({required this.locale, this.trailing});

  final ContentLocale locale;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final copy = _StudyCopy(locale);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
      child: Row(
        children: [
          AppIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: copy.back,
            color: Colors.white70,
            onPressed: () => _leaveWorkspace(context),
          ),
          const SizedBox(width: 8),
          const SynapseWordmark(height: 24),
          const SizedBox(width: 12),
          Container(
            width: 1,
            height: 24,
            color: Colors.white.withValues(alpha: 0.16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              copy.studyWorkspace,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _StudyMainPane extends ConsumerWidget {
  const _StudyMainPane({
    required this.locale,
    required this.catalog,
    required this.entry,
    required this.studyBlockKeys,
    required this.readingPosition,
    required this.readingPositionSaving,
    required this.readingPositionWriteFailed,
    required this.storedReadingAnchorMissing,
    required this.onRetryReadingPosition,
    required this.onOpenNotes,
  });

  final ContentLocale locale;
  final CurriculumCatalogSnapshot catalog;
  final CurriculumCatalogEntry entry;
  final Map<CurriculumStudyBlockId, GlobalKey> studyBlockKeys;
  final AsyncValue<CurriculumReadingPosition?>? readingPosition;
  final bool readingPositionSaving;
  final bool readingPositionWriteFailed;
  final bool storedReadingAnchorMissing;
  final VoidCallback onRetryReadingPosition;
  final VoidCallback onOpenNotes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = _StudyCopy(locale);
    final ancestors = catalog.ancestorsOf(entry.node.id);
    final microLesson = catalog.microLessonForNode(entry.node.id);
    final sessions = microLesson == null
        ? const <CurriculumSession>[]
        : catalog.sessionsForMicroLesson(microLesson.id);
    final studyDocument = catalog.primaryStudyDocumentForMicroLessonNode(
      entry.node.id,
    );
    final studyBlocks = studyDocument == null
        ? const <CurriculumStudyBlock>[]
        : catalog.studyBlocksForDocument(studyDocument.id);
    final studyGates = <CurriculumSessionId, _StudyGateState>{};
    if (studyDocument != null) {
      for (final block in studyBlocks) {
        final sessionId = block.revealedAfterSessionId;
        if (sessionId == null || studyGates.containsKey(sessionId)) continue;
        final key = CurriculumSessionProgressKey(
          releaseId: catalog.releaseId,
          microLessonNodeId: studyDocument.microLessonNodeId,
          sessionId: sessionId,
        );
        studyGates[sessionId] = _StudyGateState(
          progress: ref.watch(curriculumSessionProgressSnapshotProvider(key)),
          onRetry: () =>
              ref.invalidate(curriculumSessionProgressSnapshotProvider(key)),
        );
      }
    }
    final objectives =
        microLesson?.objectiveUnitIds
            .map((id) => catalog.localizedText(id, locale))
            .whereType<String>()
            .toList(growable: false) ??
        const <String>[];
    final estimatedSeconds = microLesson?.estimatedSeconds.forLocale(locale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final ancestor in ancestors)
              _LineageChip(label: ancestor.title(locale)),
            _LineageChip(label: entry.title(locale), active: true),
          ],
        ),
        const SizedBox(height: 16),
        AppCard(
          feature: true,
          color: _StudyColors.panel.withValues(alpha: 0.88),
          accent: _StudyColors.cyan,
          padding: const EdgeInsets.fromLTRB(24, 22, 18, 22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(copy.deepStudy.toUpperCase(), style: _eyebrowStyle),
                    const SizedBox(height: 8),
                    Text(
                      entry.title(locale),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1.08,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(copy.deepStudyBody, style: _bodyStyle(context)),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 9,
                      runSpacing: 9,
                      children: [
                        if (estimatedSeconds != null)
                          _MetricPill(
                            icon: Icons.schedule_rounded,
                            label: copy.minutes((estimatedSeconds / 60).ceil()),
                          ),
                        _MetricPill(
                          icon: Icons.route_rounded,
                          label: copy.sessions(sessions.length),
                        ),
                        if (microLesson != null)
                          _MetricPill(
                            icon: Icons.hub_outlined,
                            label: copy.sourceAnchors(
                              microLesson.sourceAtomIds.length,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SynapseCompanion(
                pose: SynapseCompanionPose.thinking,
                size: 104,
                semanticLabel: copy.lumaStudyGuide,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _StudySection(
          title: copy.learningObjectives,
          icon: Icons.adjust_rounded,
          child: objectives.isEmpty
              ? _TruthPanel(text: copy.noReviewedObjectives)
              : Column(
                  children: [
                    for (var index = 0; index < objectives.length; index++)
                      _ObjectiveRow(index: index + 1, text: objectives[index]),
                  ],
                ),
        ),
        const SizedBox(height: 18),
        if (studyDocument == null)
          _StudySection(
            title: copy.reviewedReading,
            icon: Icons.chrome_reader_mode_outlined,
            child: _TruthPanel(text: copy.noReviewedReading),
          )
        else
          _DeepStudyDocumentCard(
            locale: locale,
            catalog: catalog,
            document: studyDocument,
            blocks: studyBlocks,
            blockKeys: studyBlockKeys,
            gates: studyGates,
            readingPosition: readingPosition,
            readingPositionSaving: readingPositionSaving,
            readingPositionWriteFailed: readingPositionWriteFailed,
            storedReadingAnchorMissing: storedReadingAnchorMissing,
            onRetryReadingPosition: onRetryReadingPosition,
          ),
        const SizedBox(height: 18),
        _StudySection(
          title: copy.guidedSessions,
          icon: Icons.stairs_rounded,
          child: sessions.isEmpty
              ? _TruthPanel(text: copy.noGuidedSessions)
              : Column(
                  children: [
                    for (var index = 0; index < sessions.length; index++) ...[
                      _SessionLaunchCard(
                        locale: locale,
                        catalog: catalog,
                        microLessonNodeId: entry.node.id,
                        session: sessions[index],
                      ),
                      if (index != sessions.length - 1)
                        const SizedBox(height: 10),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 18),
        AppCard(
          color: _StudyColors.paper.withValues(alpha: 0.98),
          border: false,
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.edit_note_rounded,
                color: _StudyColors.ink,
                size: 28,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy.makeItYours,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _StudyColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      copy.makeItYoursBody,
                      style: const TextStyle(
                        color: Color(0xFF33415C),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: onOpenNotes,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(copy.openNotes),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StudyToolsPane extends StatelessWidget {
  const _StudyToolsPane({
    required this.locale,
    required this.entry,
    required this.catalog,
    required this.workspace,
    required this.selectedTool,
    required this.noteController,
    required this.selectedFocusMinutes,
    required this.remainingFocusSeconds,
    required this.elapsedFocusSeconds,
    required this.focusRunning,
    required this.mutating,
    required this.importingDocument,
    required this.detachingDocumentId,
    required this.writeError,
    required this.onToolSelected,
    required this.onAddNote,
    required this.onDeleteNote,
    required this.onFocusMinutesChanged,
    required this.onFocusAction,
    required this.onImportDocument,
    required this.onDetachDocument,
    required this.onOpenDocument,
  });

  final ContentLocale locale;
  final CurriculumCatalogEntry entry;
  final CurriculumCatalogSnapshot catalog;
  final CurriculumStudyWorkspace workspace;
  final _WorkspaceTool selectedTool;
  final TextEditingController noteController;
  final int selectedFocusMinutes;
  final int remainingFocusSeconds;
  final int elapsedFocusSeconds;
  final bool focusRunning;
  final bool mutating;
  final bool importingDocument;
  final ResourceDocumentId? detachingDocumentId;
  final String? writeError;
  final ValueChanged<_WorkspaceTool> onToolSelected;
  final VoidCallback onAddNote;
  final ValueChanged<String> onDeleteNote;
  final ValueChanged<int> onFocusMinutesChanged;
  final VoidCallback onFocusAction;
  final VoidCallback onImportDocument;
  final ValueChanged<ResourceDocument> onDetachDocument;
  final ValueChanged<ResourceDocument> onOpenDocument;

  @override
  Widget build(BuildContext context) {
    final copy = _StudyCopy(locale);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return AppCard(
      color: _StudyColors.panel.withValues(alpha: 0.92),
      accent: _toolAccent(selectedTool),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(copy.studyToolkit, style: _eyebrowStyle),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final tool in _WorkspaceTool.values)
                _ToolChip(
                  label: copy.toolName(tool),
                  icon: _toolIcon(tool),
                  selected: selectedTool == tool,
                  onTap: () => onToolSelected(tool),
                ),
            ],
          ),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: duration,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: switch (selectedTool) {
              _WorkspaceTool.notes => _NotesTool(
                key: const ValueKey('notes'),
                locale: locale,
                workspace: workspace,
                controller: noteController,
                mutating: mutating,
                onAdd: onAddNote,
                onDelete: onDeleteNote,
              ),
              _WorkspaceTool.focus => _FocusTool(
                key: const ValueKey('focus'),
                locale: locale,
                workspace: workspace,
                selectedMinutes: selectedFocusMinutes,
                remainingSeconds: remainingFocusSeconds,
                elapsedSeconds: elapsedFocusSeconds,
                running: focusRunning,
                busy: mutating,
                onMinutesChanged: onFocusMinutesChanged,
                onAction: onFocusAction,
              ),
              _WorkspaceTool.sources => _SourcesTool(
                key: const ValueKey('sources'),
                locale: locale,
                entry: entry,
                catalog: catalog,
                importing: importingDocument,
                detachingDocumentId: detachingDocumentId,
                onImport: onImportDocument,
                onOpenDocument: onOpenDocument,
                onDetachDocument: onDetachDocument,
              ),
            },
          ),
          if (writeError != null) ...[
            const SizedBox(height: 12),
            Semantics(liveRegion: true, child: _InlineError(text: writeError!)),
          ],
        ],
      ),
    );
  }
}

class _NotesTool extends StatelessWidget {
  const _NotesTool({
    super.key,
    required this.locale,
    required this.workspace,
    required this.controller,
    required this.mutating,
    required this.onAdd,
    required this.onDelete,
  });

  final ContentLocale locale;
  final CurriculumStudyWorkspace workspace;
  final TextEditingController controller;
  final bool mutating;
  final VoidCallback onAdd;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final copy = _StudyCopy(locale);
    final notes = workspace.notes.reversed.toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(copy.personalNotes, style: _toolTitleStyle(context)),
        const SizedBox(height: 5),
        Text(copy.personalNotesBody, style: _bodyStyle(context)),
        const SizedBox(height: 14),
        AppTextField(
          controller: controller,
          label: copy.newNote,
          hint: copy.noteHint,
          icon: Icons.edit_rounded,
          maxLines: 4,
          accent: _StudyColors.cyan,
          onSubmitted: (_) {
            if (!mutating) onAdd();
          },
        ),
        const SizedBox(height: 10),
        AppButton(
          label: copy.saveNote,
          icon: Icons.add_rounded,
          expand: true,
          size: AppButtonSize.medium,
          accent: _StudyColors.cyan,
          loading: mutating,
          onPressed: mutating ? null : onAdd,
        ),
        const SizedBox(height: 18),
        if (notes.isEmpty)
          _TruthPanel(text: copy.noPersonalNotes)
        else
          for (var index = 0; index < notes.length; index++) ...[
            _NoteCard(
              locale: locale,
              note: notes[index],
              onDelete: mutating ? null : () => onDelete(notes[index].id),
            ),
            if (index != notes.length - 1) const SizedBox(height: 9),
          ],
      ],
    );
  }
}

class _FocusTool extends StatelessWidget {
  const _FocusTool({
    super.key,
    required this.locale,
    required this.workspace,
    required this.selectedMinutes,
    required this.remainingSeconds,
    required this.elapsedSeconds,
    required this.running,
    required this.busy,
    required this.onMinutesChanged,
    required this.onAction,
  });

  final ContentLocale locale;
  final CurriculumStudyWorkspace workspace;
  final int selectedMinutes;
  final int remainingSeconds;
  final int elapsedSeconds;
  final bool running;
  final bool busy;
  final ValueChanged<int> onMinutesChanged;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final copy = _StudyCopy(locale);
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    final timerLabel =
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(copy.focusMode, style: _toolTitleStyle(context)),
        const SizedBox(height: 5),
        Text(copy.focusModeBody, style: _bodyStyle(context)),
        const SizedBox(height: 14),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final minutes in const [10, 25, 45])
              _ToolChip(
                label: copy.minutes(minutes),
                icon: Icons.schedule_rounded,
                selected: selectedMinutes == minutes,
                onTap: running || elapsedSeconds > 0
                    ? null
                    : () => onMinutesChanged(minutes),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Semantics(
          liveRegion: running,
          label: copy.focusRemaining(timerLabel),
          child: Center(
            child: Container(
              width: 184,
              constraints: const BoxConstraints(minHeight: 184),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _StudyColors.cyan.withValues(alpha: 0.1),
                border: Border.all(
                  color: _StudyColors.cyan.withValues(alpha: 0.55),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _StudyColors.cyan.withValues(alpha: 0.13),
                    blurRadius: 28,
                  ),
                ],
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  timerLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        AppButton(
          label: running ? copy.pauseAndSave : copy.startFocus,
          icon: running ? Icons.pause_rounded : Icons.play_arrow_rounded,
          expand: true,
          accent: _StudyColors.cyan,
          loading: busy,
          onPressed: busy ? null : onAction,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _FocusMetric(
                value: copy.focusTime(workspace.focusSecondsTotal),
                label: copy.focusLogged,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _FocusMetric(
                value: '${workspace.focusSessionCount}',
                label: copy.focusSessions,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _TruthPanel(text: copy.focusTruth),
      ],
    );
  }
}

class _SourcesTool extends ConsumerWidget {
  const _SourcesTool({
    super.key,
    required this.locale,
    required this.entry,
    required this.catalog,
    required this.importing,
    required this.detachingDocumentId,
    required this.onImport,
    required this.onOpenDocument,
    required this.onDetachDocument,
  });

  final ContentLocale locale;
  final CurriculumCatalogEntry entry;
  final CurriculumCatalogSnapshot catalog;
  final bool importing;
  final ResourceDocumentId? detachingDocumentId;
  final VoidCallback onImport;
  final ValueChanged<ResourceDocument> onOpenDocument;
  final ValueChanged<ResourceDocument> onDetachDocument;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = _StudyCopy(locale);
    final microLesson = catalog.microLessonForNode(entry.node.id);
    final contextResource = ResourceReference.curriculumNode(
      sourceId: catalog.sourceId,
      nodeId: entry.node.id,
    );
    final documents = ref.watch(
      contextualResourceDocumentsProvider(contextResource),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(copy.sourceContext, style: _toolTitleStyle(context)),
        const SizedBox(height: 5),
        Text(copy.sourceContextBody, style: _bodyStyle(context)),
        const SizedBox(height: 14),
        _SourceRow(
          icon: Icons.verified_user_outlined,
          label: copy.packageState,
          value: copy.reviewedActiveRelease,
          accent: _StudyColors.green,
        ),
        const SizedBox(height: 9),
        _SourceRow(
          icon: Icons.account_tree_outlined,
          label: copy.curriculumAnchor,
          value: entry.node.sourceKey,
          accent: _StudyColors.cyan,
        ),
        const SizedBox(height: 9),
        _SourceRow(
          icon: Icons.link_rounded,
          label: copy.sourceAtomsLabel,
          value: '${microLesson?.sourceAtomIds.length ?? 0}',
          accent: _StudyColors.gold,
        ),
        const SizedBox(height: 14),
        AppCard(
          color: _StudyColors.paper,
          border: false,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.shield_outlined,
                color: _StudyColors.ink,
                size: 24,
              ),
              const SizedBox(height: 10),
              Text(
                copy.educationBoundary,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: _StudyColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                copy.educationBoundaryBody,
                style: const TextStyle(color: Color(0xFF33415C), height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                copy.attachedReferences,
                style: _toolTitleStyle(context),
              ),
            ),
            if (documents.asData case final data?)
              _MetricPill(
                icon: Icons.picture_as_pdf_outlined,
                label: copy.referenceCount(data.value.length),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(copy.attachedReferencesBody, style: _bodyStyle(context)),
        const SizedBox(height: 12),
        documents.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: CircularProgressIndicator(
                color: _StudyColors.cyan,
                strokeWidth: 2,
              ),
            ),
          ),
          error: (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TruthPanel(text: copy.referenceListUnavailable),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => ref.invalidate(
                  contextualResourceDocumentsProvider(contextResource),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(copy.tryAgain),
              ),
            ],
          ),
          data: (values) => values.isEmpty
              ? _TruthPanel(text: copy.noAttachedReferences)
              : Column(
                  children: [
                    for (var index = 0; index < values.length; index++) ...[
                      _AttachedDocumentCard(
                        locale: locale,
                        document: values[index],
                        onOpen: () => onOpenDocument(values[index]),
                        detaching: detachingDocumentId == values[index].id,
                        onDetach: () => onDetachDocument(values[index]),
                      ),
                      if (index != values.length - 1) const SizedBox(height: 9),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 12),
        AppButton(
          label: copy.attachPdf,
          icon: Icons.add_to_photos_outlined,
          expand: true,
          size: AppButtonSize.medium,
          accent: _StudyColors.cyan,
          loading: importing,
          onPressed: importing ? null : onImport,
        ),
        const SizedBox(height: 10),
        _TruthPanel(text: copy.sourceAttachmentTruth),
      ],
    );
  }
}

class _AttachedDocumentCard extends StatelessWidget {
  const _AttachedDocumentCard({
    required this.locale,
    required this.document,
    required this.onOpen,
    required this.detaching,
    required this.onDetach,
  });

  final ContentLocale locale;
  final ResourceDocument document;
  final VoidCallback onOpen;
  final bool detaching;
  final VoidCallback onDetach;

  @override
  Widget build(BuildContext context) {
    final copy = _StudyCopy(locale);
    return Semantics(
      button: true,
      label: copy.openReference(document.displayName),
      child: Material(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: ValueKey('attached-document-${document.id}'),
          onTap: onOpen,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _StudyColors.coral.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: _StudyColors.coral.withValues(alpha: 0.34),
                    ),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: _StudyColors.coral,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        copy.documentMeta(
                          document.pageCount,
                          document.byteLength,
                        ),
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                if (detaching)
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _StudyColors.cyan,
                      ),
                    ),
                  )
                else
                  IconButton(
                    tooltip: copy.detachReference,
                    onPressed: onDetach,
                    color: Colors.white54,
                    icon: const Icon(Icons.link_off_rounded, size: 19),
                  ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white38,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StudySection extends StatelessWidget {
  const _StudySection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: _StudyColors.panel.withValues(alpha: 0.7),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: _StudyColors.cyan, size: 21),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }
}

class _DeepStudyDocumentCard extends StatelessWidget {
  const _DeepStudyDocumentCard({
    required this.locale,
    required this.catalog,
    required this.document,
    required this.blocks,
    required this.blockKeys,
    required this.gates,
    required this.readingPosition,
    required this.readingPositionSaving,
    required this.readingPositionWriteFailed,
    required this.storedReadingAnchorMissing,
    required this.onRetryReadingPosition,
  });

  final ContentLocale locale;
  final CurriculumCatalogSnapshot catalog;
  final CurriculumStudyDocument document;
  final List<CurriculumStudyBlock> blocks;
  final Map<CurriculumStudyBlockId, GlobalKey> blockKeys;
  final Map<CurriculumSessionId, _StudyGateState> gates;
  final AsyncValue<CurriculumReadingPosition?>? readingPosition;
  final bool readingPositionSaving;
  final bool readingPositionWriteFailed;
  final bool storedReadingAnchorMissing;
  final VoidCallback onRetryReadingPosition;

  bool _isRevealed(CurriculumStudyBlock block) => block.isRevealedBy(
    progress: gates[block.revealedAfterSessionId]?.progress.asData?.value,
    releaseId: catalog.releaseId,
    microLessonNodeId: document.microLessonNodeId,
  );

  @override
  Widget build(BuildContext context) {
    final copy = _StudyCopy(locale);
    final title = catalog.localizedText(document.titleUnitId, locale)!;
    final seconds = document.estimatedSeconds.forLocale(locale);
    final visibleCount = blocks.where(_isRevealed).length;
    final savedPosition = readingPosition?.asData?.value;
    final readingPositionUnavailable = readingPosition?.hasError ?? false;
    return AppCard(
      key: const ValueKey('academy-deep-study-document'),
      color: _StudyColors.paper,
      border: false,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _StudyColors.cyan.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.chrome_reader_mode_rounded,
                        color: Color(0xFF087EA8),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            copy.reviewedReading.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF087EA8),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            title,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: _StudyColors.ink,
                                  height: 1.16,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  copy.reviewedReadingBody,
                  style: const TextStyle(color: Color(0xFF40506A), height: 1.5),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PaperMetric(
                      icon: Icons.schedule_rounded,
                      label: copy.minutes((seconds / 60).ceil()),
                    ),
                    _PaperMetric(
                      icon: Icons.view_agenda_outlined,
                      label: copy.readingBlocks(visibleCount, blocks.length),
                    ),
                    _PaperMetric(
                      icon: Icons.link_rounded,
                      label: copy.sourceAnchors(document.sourceAtomIds.length),
                    ),
                    if (readingPositionSaving)
                      _PaperMetric(
                        icon: Icons.sync_rounded,
                        label: copy.savingReadingPlace,
                      )
                    else if (savedPosition != null)
                      _PaperMetric(
                        icon: Icons.bookmark_added_outlined,
                        label: copy.readingPlaceSaved(
                          savedPosition.blockOrdinal,
                          blocks.length,
                        ),
                      ),
                  ],
                ),
                if (readingPositionUnavailable ||
                    readingPositionWriteFailed ||
                    storedReadingAnchorMissing) ...[
                  const SizedBox(height: 12),
                  _ReadingPositionNotice(
                    text: storedReadingAnchorMissing
                        ? copy.readingAnchorMoved
                        : readingPositionWriteFailed
                        ? copy.readingPlaceSaveFailed
                        : copy.readingPlaceUnavailable,
                    onRetry: onRetryReadingPosition,
                    retryLabel: copy.tryAgain,
                  ),
                ],
              ],
            ),
          ),
          Container(height: 1, color: const Color(0x1A0B1D39)),
          for (var index = 0; index < blocks.length; index++) ...[
            KeyedSubtree(
              key: blockKeys[blocks[index].id],
              child: _DeepStudyBlockView(
                locale: locale,
                catalog: catalog,
                block: blocks[index],
                revealed: _isRevealed(blocks[index]),
                gate: gates[blocks[index].revealedAfterSessionId],
              ),
            ),
            if (index != blocks.length - 1)
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 22),
                color: const Color(0x120B1D39),
              ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  color: Color(0xFF47705F),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    copy.immutableReadingTruth,
                    style: const TextStyle(
                      color: Color(0xFF526077),
                      fontSize: 12,
                      height: 1.42,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadingPositionNotice extends StatelessWidget {
  const _ReadingPositionNotice({
    required this.text,
    required this.onRetry,
    required this.retryLabel,
  });

  final String text;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: const Color(0x14B56A20),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0x2AB56A20)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.bookmark_outline_rounded,
              color: Color(0xFF8B5A22),
              size: 19,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Color(0xFF65431F),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
            TextButton(onPressed: onRetry, child: Text(retryLabel)),
          ],
        ),
      ),
    );
  }
}

class _PaperMetric extends StatelessWidget {
  const _PaperMetric({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0x0F0B1D39),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x180B1D39)),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 3,
        children: [
          Icon(icon, color: const Color(0xFF3C4D69), size: 15),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF33415C),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeepStudyBlockView extends StatelessWidget {
  const _DeepStudyBlockView({
    required this.locale,
    required this.catalog,
    required this.block,
    required this.revealed,
    required this.gate,
  });

  final ContentLocale locale;
  final CurriculumCatalogSnapshot catalog;
  final CurriculumStudyBlock block;
  final bool revealed;
  final _StudyGateState? gate;

  @override
  Widget build(BuildContext context) {
    final copy = _StudyCopy(locale);
    if (!revealed) {
      final progress = gate?.progress;
      final state = progress == null || progress.isLoading
          ? _LockedStudyBlockState.checking
          : progress.hasError
          ? _LockedStudyBlockState.unavailable
          : _LockedStudyBlockState.requirement;
      return _LockedStudyBlock(
        locale: locale,
        policy: block.revealPolicy,
        state: state,
        onRetry: state == _LockedStudyBlockState.unavailable
            ? gate?.onRetry
            : null,
      );
    }
    final heading = block.headingUnitId == null
        ? null
        : catalog.localizedText(block.headingUnitId!, locale);
    final content = [
      for (final id in block.contentUnitIds) catalog.localizedText(id, locale)!,
    ];
    final tableRows = [
      for (final row in block.tableRows)
        [for (final id in row) catalog.localizedText(id, locale)!],
    ];
    final body = switch (block.kind) {
      CurriculumStudyBlockKind.prose => _StudyParagraphs(values: content),
      CurriculumStudyBlockKind.keyIdea => _StudyCallout(
        icon: Icons.lightbulb_outline_rounded,
        accent: const Color(0xFF087EA8),
        values: content,
      ),
      CurriculumStudyBlockKind.mechanismChain => _StudySequence(
        values: content,
        accent: const Color(0xFF087EA8),
        causal: true,
      ),
      CurriculumStudyBlockKind.orderedSteps => _StudySequence(
        values: content,
        accent: const Color(0xFF47705F),
        causal: false,
      ),
      CurriculumStudyBlockKind.bulletList => _StudyBulletList(values: content),
      CurriculumStudyBlockKind.comparisonTable => _StudyComparison(
        rows: tableRows,
      ),
      CurriculumStudyBlockKind.clinicalPearl => _StudyCallout(
        icon: Icons.diamond_outlined,
        accent: const Color(0xFF9A6810),
        values: content,
      ),
      CurriculumStudyBlockKind.safetyWarning => _StudyCallout(
        icon: Icons.health_and_safety_outlined,
        accent: const Color(0xFFB64035),
        values: content,
      ),
      CurriculumStudyBlockKind.workedExample => _StudyCallout(
        icon: Icons.route_outlined,
        accent: const Color(0xFF47705F),
        values: content,
      ),
      CurriculumStudyBlockKind.recap => _StudyCallout(
        icon: Icons.replay_rounded,
        accent: const Color(0xFF545FA3),
        values: content,
      ),
    };
    return Semantics(
      container: true,
      label: copy.blockKind(block.kind),
      child: Padding(
        key: ValueKey('academy-study-block-${block.kind.name}'),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (heading != null) ...[
              Text(
                heading,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _StudyColors.ink,
                  fontWeight: FontWeight.w900,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 12),
            ],
            body,
          ],
        ),
      ),
    );
  }
}

enum _LockedStudyBlockState { requirement, checking, unavailable }

class _LockedStudyBlock extends StatelessWidget {
  const _LockedStudyBlock({
    required this.locale,
    required this.policy,
    required this.state,
    required this.onRetry,
  });

  final ContentLocale locale;
  final CurriculumStudyRevealPolicy policy;
  final _LockedStudyBlockState state;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final copy = _StudyCopy(locale);
    final title = switch (state) {
      _LockedStudyBlockState.requirement => copy.lockedStudyBlock,
      _LockedStudyBlockState.checking => copy.checkingLinkedProgress,
      _LockedStudyBlockState.unavailable => copy.progressCheckUnavailable,
    };
    final body = switch (state) {
      _LockedStudyBlockState.requirement => copy.revealRequirement(policy),
      _LockedStudyBlockState.checking => copy.checkingLinkedProgressBody,
      _LockedStudyBlockState.unavailable => copy.progressCheckUnavailableBody,
    };
    return Semantics(
      container: true,
      liveRegion: state != _LockedStudyBlockState.requirement,
      label: '$title. $body',
      child: Padding(
        key: const ValueKey('academy-study-block-locked'),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color(0x0F0B1D39),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0x180B1D39)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state == _LockedStudyBlockState.checking)
                const SizedBox.square(
                  dimension: 21,
                  child: CircularProgressIndicator(
                    color: Color(0xFF64718A),
                    strokeWidth: 2,
                  ),
                )
              else
                Icon(
                  state == _LockedStudyBlockState.unavailable
                      ? Icons.sync_problem_rounded
                      : Icons.lock_outline_rounded,
                  color: const Color(0xFF64718A),
                  size: 21,
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _StudyColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: const TextStyle(
                        color: Color(0xFF526077),
                        height: 1.42,
                      ),
                    ),
                    if (onRetry != null) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(copy.tryAgain),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _StudyGateState {
  const _StudyGateState({required this.progress, required this.onRetry});

  final AsyncValue<CurriculumSessionProgress?> progress;
  final VoidCallback onRetry;
}

class _StudyParagraphs extends StatelessWidget {
  const _StudyParagraphs({required this.values});

  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < values.length; index++) ...[
          Text(
            values[index],
            style: const TextStyle(
              color: Color(0xFF24344F),
              fontSize: 15,
              height: 1.62,
            ),
          ),
          if (index != values.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _StudyCallout extends StatelessWidget {
  const _StudyCallout({
    required this.icon,
    required this.accent,
    required this.values,
  });

  final IconData icon;
  final Color accent;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.075),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(width: 11),
          Expanded(child: _StudyParagraphs(values: values)),
        ],
      ),
    );
  }
}

class _StudySequence extends StatelessWidget {
  const _StudySequence({
    required this.values,
    required this.accent,
    required this.causal,
  });

  final List<String> values;
  final Color accent;
  final bool causal;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < values.length; index++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    values[index],
                    style: const TextStyle(
                      color: Color(0xFF24344F),
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (index != values.length - 1)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 13),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: SizedBox(
                  height: 18,
                  child: VerticalDivider(
                    width: 1,
                    thickness: causal ? 2 : 1,
                    color: accent.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _StudyBulletList extends StatelessWidget {
  const _StudyBulletList({required this.values});

  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final value in values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 7),
                  child: Icon(Icons.circle, color: Color(0xFF087EA8), size: 7),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFF24344F),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StudyComparison extends StatelessWidget {
  const _StudyComparison({required this.rows});

  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaledBodySize = MediaQuery.textScalerOf(context).scale(14);
        final compact = constraints.maxWidth < 520 || scaledBodySize > 19;
        return compact
            ? _CompactStudyComparison(rows: rows)
            : _WideStudyComparison(rows: rows);
      },
    );
  }
}

class _WideStudyComparison extends StatelessWidget {
  const _WideStudyComparison({required this.rows});

  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Table(
        border: TableBorder.all(color: const Color(0x1F0B1D39)),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          for (var rowIndex = 0; rowIndex < rows.length; rowIndex++)
            TableRow(
              decoration: BoxDecoration(
                color: rowIndex == 0
                    ? const Color(0x14087EA8)
                    : rowIndex.isEven
                    ? const Color(0x080B1D39)
                    : Colors.transparent,
              ),
              children: [
                for (final value in rows[rowIndex])
                  Padding(
                    padding: const EdgeInsets.all(11),
                    child: Text(
                      value,
                      style: TextStyle(
                        color: _StudyColors.ink,
                        height: 1.38,
                        fontSize: 13,
                        fontWeight: rowIndex == 0
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CompactStudyComparison extends StatelessWidget {
  const _CompactStudyComparison({required this.rows});

  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    final headers = rows.first;
    return Column(
      children: [
        for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0x0A0B1D39),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x180B1D39)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  rows[rowIndex].first,
                  style: const TextStyle(
                    color: _StudyColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 9),
                for (var column = 1; column < headers.length; column++) ...[
                  Text(
                    headers[column],
                    style: const TextStyle(
                      color: Color(0xFF68758A),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rows[rowIndex][column],
                    style: const TextStyle(
                      color: Color(0xFF24344F),
                      height: 1.42,
                    ),
                  ),
                  if (column != headers.length - 1) const SizedBox(height: 9),
                ],
              ],
            ),
          ),
          if (rowIndex != rows.length - 1) const SizedBox(height: 9),
        ],
      ],
    );
  }
}

class _SessionLaunchCard extends StatelessWidget {
  const _SessionLaunchCard({
    required this.locale,
    required this.catalog,
    required this.microLessonNodeId,
    required this.session,
  });

  final ContentLocale locale;
  final CurriculumCatalogSnapshot catalog;
  final String microLessonNodeId;
  final CurriculumSession session;

  @override
  Widget build(BuildContext context) {
    final copy = _StudyCopy(locale);
    final title =
        catalog.localizedText(session.titleUnitId, locale) ?? copy.session;
    final seconds = session.estimatedSeconds.forLocale(locale);
    return Material(
      color: Colors.white.withValues(alpha: 0.045),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(
          Routes.academySessionFor(microLessonNodeId, session.id),
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _StudyColors.cyan.withValues(alpha: 0.14),
                  border: Border.all(
                    color: _StudyColors.cyan.withValues(alpha: 0.35),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${session.ordinal}',
                  style: const TextStyle(
                    color: _StudyColors.cyan,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${copy.sessionType(session.sessionType)} · '
                      '${copy.minutes((seconds / 60).ceil())} · '
                      '${copy.interactions(session.interactionIds.length)}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.play_circle_fill_rounded,
                color: _StudyColors.cyan,
                size: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ObjectiveRow extends StatelessWidget {
  const _ObjectiveRow({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: _StudyColors.cyan.withValues(alpha: 0.13),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: const TextStyle(
                color: _StudyColors.cyan,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(child: Text(text, style: _bodyStyle(context))),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.locale, required this.note, this.onDelete});

  final ContentLocale locale;
  final CurriculumStudyNote note;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final copy = _StudyCopy(locale);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Directionality(
              textDirection: note.locale == ContentLocale.fa
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              child: Text(note.body, style: _bodyStyle(context)),
            ),
          ),
          AppIconButton(
            icon: Icons.delete_outline_rounded,
            tooltip: copy.deleteNote,
            color: Colors.white54,
            size: 19,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                SelectableText(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LineageChip extends StatelessWidget {
  const _LineageChip({required this.label, this.active = false});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? _StudyColors.cyan.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: active
              ? _StudyColors.cyan.withValues(alpha: 0.42)
              : Colors.white.withValues(alpha: 0.09),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? _StudyColors.cyan : Colors.white60,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 2,
        children: [
          Icon(icon, color: _StudyColors.cyan, size: 15),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({
    required this.label,
    required this.icon,
    required this.selected,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _StudyColors.cyan;
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      child: Material(
        color: selected
            ? accent.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(99),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(99),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: selected ? accent : Colors.white54),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white60,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FocusMetric extends StatelessWidget {
  const _FocusMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _TruthPanel extends StatelessWidget {
  const _TruthPanel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Colors.white54,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: _bodyStyle(context))),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _StudyColors.coral.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _StudyColors.coral.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.sync_problem_rounded,
            color: _StudyColors.coral,
            size: 19,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceInlineFailure extends StatelessWidget {
  const _WorkspaceInlineFailure({required this.locale, required this.onRetry});

  final ContentLocale locale;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final copy = _StudyCopy(locale);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.sync_problem_rounded,
                color: _StudyColors.coral,
                size: 38,
              ),
              const SizedBox(height: 12),
              Text(
                copy.workspaceUnavailable,
                textAlign: TextAlign.center,
                style: _toolTitleStyle(context),
              ),
              const SizedBox(height: 8),
              Text(
                copy.workspaceUnavailableBody,
                textAlign: TextAlign.center,
                style: _bodyStyle(context),
              ),
              const SizedBox(height: 18),
              AppButton(
                label: copy.tryAgain,
                icon: Icons.refresh_rounded,
                accent: _StudyColors.cyan,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _WorkspaceTool { notes, focus, sources }

IconData _toolIcon(_WorkspaceTool tool) => switch (tool) {
  _WorkspaceTool.notes => Icons.edit_note_rounded,
  _WorkspaceTool.focus => Icons.timer_outlined,
  _WorkspaceTool.sources => Icons.menu_book_outlined,
};

Color _toolAccent(_WorkspaceTool tool) => switch (tool) {
  _WorkspaceTool.notes => _StudyColors.cyan,
  _WorkspaceTool.focus => _StudyColors.green,
  _WorkspaceTool.sources => _StudyColors.gold,
};

ContentLocale _studyLocale(String value) =>
    value.toLowerCase().startsWith('fa') ? ContentLocale.fa : ContentLocale.en;

void _leaveWorkspace(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(Routes.academy);
  }
}

TextStyle _bodyStyle(BuildContext context) =>
    Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: Colors.white70, height: 1.48) ??
    const TextStyle(color: Colors.white70, height: 1.48);

TextStyle _toolTitleStyle(BuildContext context) =>
    Theme.of(context).textTheme.titleLarge?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w800,
    ) ??
    const TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.w800,
    );

const _eyebrowStyle = TextStyle(
  color: _StudyColors.cyan,
  fontSize: 11,
  fontWeight: FontWeight.w800,
  letterSpacing: 1.25,
);

abstract final class _StudyColors {
  static const midnight = Color(0xFF031126);
  static const panel = Color(0xFF0A1C36);
  static const cyan = Color(0xFF24BDF2);
  static const coral = Color(0xFFFF6E5D);
  static const gold = Color(0xFFF2BB43);
  static const green = Color(0xFF54D6A0);
  static const paper = Color(0xFFFFF8E9);
  static const ink = Color(0xFF0B1D39);
}

final class _StudyCopy {
  const _StudyCopy(this.locale);

  final ContentLocale locale;

  String _t(String en, String fa) => locale == ContentLocale.fa ? fa : en;

  String get back => _t('Back', 'بازگشت');
  String get studyWorkspace => _t('Study Workspace', 'فضای مطالعه');
  String get openingWorkspace =>
      _t('Opening your study workspace', 'در حال بازکردن فضای مطالعه');
  String get openingWorkspaceBody => _t(
    'Your reviewed lesson context and personal study tools are being restored.',
    'بافت درس بازبینی‌شده و ابزارهای شخصی مطالعه در حال بازیابی‌اند.',
  );
  String get workspaceUnavailable =>
      _t('Study workspace needs attention', 'فضای مطالعه نیاز به بررسی دارد');
  String get workspaceUnavailableBody => _t(
    'Your notes were not replaced or cleared. Retry the local workspace safely.',
    'یادداشت‌های شما جایگزین یا پاک نشده‌اند. بازیابی امن فضای محلی را دوباره امتحان کنید.',
  );
  String get reviewedPackageRequired => _t(
    'A reviewed course package is required',
    'یک بستهٔ درسی بازبینی‌شده لازم است',
  );
  String get reviewedPackageRequiredBody => _t(
    'The workspace will not invent lesson text or source evidence while no approved package is active.',
    'تا زمانی که بستهٔ تأییدشده‌ای فعال نیست، فضای مطالعه متن درس یا شواهد منبع را جعل نمی‌کند.',
  );
  String get contextNotFound =>
      _t('This study context is unavailable', 'این بافت مطالعه در دسترس نیست');
  String get contextNotFoundBody => _t(
    'The requested curriculum node is not part of the active reviewed release.',
    'گره درخواستی بخشی از انتشار بازبینی‌شدهٔ فعال نیست.',
  );
  String get tryAgain => _t('Try again', 'تلاش دوباره');
  String get removeBookmark => _t('Remove bookmark', 'حذف نشانک');
  String get bookmarkLesson => _t('Bookmark this lesson', 'نشان‌کردن این درس');
  String get deepStudy => _t('Deep study', 'مطالعهٔ عمیق');
  String get deepStudyBody => _t(
    'Understand the objective, move through short guided sessions, and keep your own thinking beside the source-backed lesson.',
    'هدف را عمیق بفهمید، جلسه‌های کوتاه هدایت‌شده را پیش ببرید و برداشت شخصی‌تان را کنار درس مبتنی بر منبع نگه دارید.',
  );
  String get lumaStudyGuide => _t(
    'LUMA is thinking beside your study workspace',
    'لوما در کنار فضای مطالعه در حال فکرکردن است',
  );
  String get learningObjectives => _t('Learning objectives', 'هدف‌های یادگیری');
  String get noReviewedObjectives => _t(
    'No reviewed objective is available for this node. Nothing has been substituted.',
    'برای این گره هدف بازبینی‌شده‌ای در دسترس نیست و چیزی جایگزین نشده است.',
  );
  String get reviewedReading => _t('Reviewed lesson', 'درس بازبینی‌شده');
  String get reviewedReadingBody => _t(
    'Read one bounded semantic path, then use the guided sessions to retrieve, discriminate, and apply it.',
    'یک مسیر معنایی کوتاه و محدود را بخوانید؛ سپس با جلسه‌های هدایت‌شده آن را بازیابی، تفکیک و به‌کار ببرید.',
  );
  String get noReviewedReading => _t(
    'No approved Deep Study document is attached to this node. The workspace will not generate substitute teaching text.',
    'هیچ سند تأییدشدهٔ مطالعهٔ عمیقی به این گره متصل نیست و فضای مطالعه متن آموزشی جایگزین تولید نمی‌کند.',
  );
  String readingBlocks(int visible, int total) =>
      _t('$visible of $total blocks ready', '$visible از $total بلوک آماده');
  String get savingReadingPlace =>
      _t('Saving your place', 'در حال ذخیرهٔ جای مطالعه');
  String readingPlaceSaved(int block, int total) => _t(
    'Resume saved at block $block of $total',
    'ادامه از بلوک $block از $total ذخیره شد',
  );
  String get readingPlaceUnavailable => _t(
    'Your saved place could not be restored. The reviewed lesson is still available.',
    'جای ذخیره‌شدهٔ مطالعه بازیابی نشد؛ درس بازبینی‌شده همچنان در دسترس است.',
  );
  String get readingPlaceSaveFailed => _t(
    'Your latest reading place was not saved. The previous saved place remains intact.',
    'آخرین جای مطالعه ذخیره نشد؛ جای ذخیره‌شدهٔ قبلی سالم باقی مانده است.',
  );
  String get readingAnchorMoved => _t(
    'This reviewed release changed the saved anchor, so the closest safe block was restored.',
    'در این انتشار بازبینی‌شده لنگر ذخیره‌شده تغییر کرده است؛ نزدیک‌ترین بلوک امن بازیابی شد.',
  );
  String get immutableReadingTruth => _t(
    'This reviewed EN/FA lesson body is immutable in the learner app. Personal notes remain separate and never rewrite the source-backed release.',
    'متن بازبینی‌شدهٔ انگلیسی/فارسی در اپ یادگیرنده تغییرناپذیر است؛ یادداشت‌های شخصی جدا می‌مانند و انتشار مبتنی بر منبع را بازنویسی نمی‌کنند.',
  );
  String get lockedStudyBlock =>
      _t('A review block is still locked', 'یک بلوک مرور هنوز قفل است');
  String get checkingLinkedProgress =>
      _t('Checking linked session progress', 'در حال بررسی پیشرفت جلسهٔ مرتبط');
  String get checkingLinkedProgressBody => _t(
    'The block stays hidden until the exact release-bound checkpoint is verified.',
    'تا تأیید نقطهٔ ادامهٔ دقیق و وابسته به همین انتشار، بلوک پنهان می‌ماند.',
  );
  String get progressCheckUnavailable =>
      _t('Progress could not be verified', 'پیشرفت قابل تأیید نبود');
  String get progressCheckUnavailableBody => _t(
    'The block remains safely locked. Try the progress check again.',
    'بلوک به‌صورت امن قفل می‌ماند. بررسی پیشرفت را دوباره انجام دهید.',
  );
  String revealRequirement(
    CurriculumStudyRevealPolicy policy,
  ) => switch (policy) {
    CurriculumStudyRevealPolicy.always => _t(
      'This block is available now.',
      'این بلوک اکنون در دسترس است.',
    ),
    CurriculumStudyRevealPolicy.afterFirstAttempt => _t(
      'Attempt the linked session once to reveal it. Its content is not previewed here.',
      'برای آشکارشدن آن، جلسهٔ مرتبط را یک بار انجام دهید. محتوای آن اینجا پیش‌نمایش نمی‌شود.',
    ),
    CurriculumStudyRevealPolicy.afterSessionCompletion => _t(
      'Complete the linked session to reveal it. Its content is not previewed here.',
      'برای آشکارشدن آن، جلسهٔ مرتبط را کامل کنید. محتوای آن اینجا پیش‌نمایش نمی‌شود.',
    ),
  };
  String blockKind(CurriculumStudyBlockKind kind) => switch (kind) {
    CurriculumStudyBlockKind.prose => _t('Explanation', 'توضیح'),
    CurriculumStudyBlockKind.keyIdea => _t('Key idea', 'ایدهٔ کلیدی'),
    CurriculumStudyBlockKind.mechanismChain => _t(
      'Mechanism chain',
      'زنجیرهٔ سازوکار',
    ),
    CurriculumStudyBlockKind.orderedSteps => _t(
      'Ordered steps',
      'مراحل ترتیبی',
    ),
    CurriculumStudyBlockKind.bulletList => _t('Key points', 'نکته‌های کلیدی'),
    CurriculumStudyBlockKind.comparisonTable => _t('Comparison', 'مقایسه'),
    CurriculumStudyBlockKind.clinicalPearl => _t(
      'Clinical pearl',
      'نکتهٔ بالینی',
    ),
    CurriculumStudyBlockKind.safetyWarning => _t(
      'Safety warning',
      'هشدار ایمنی',
    ),
    CurriculumStudyBlockKind.workedExample => _t(
      'Worked example',
      'مثال حل‌شده',
    ),
    CurriculumStudyBlockKind.recap => _t('Recap', 'مرور'),
  };
  String get guidedSessions => _t('Guided sessions', 'جلسه‌های هدایت‌شده');
  String get noGuidedSessions => _t(
    'No approved session is attached to this node yet.',
    'هنوز جلسهٔ تأییدشده‌ای به این گره متصل نیست.',
  );
  String get makeItYours => _t('Make the lesson yours', 'درس را مال خودت کن');
  String get makeItYoursBody => _t(
    'Capture a question, distinction, or memory cue without changing the reviewed lesson body.',
    'یک پرسش، تمایز یا سرنخ حافظه ثبت کن؛ بدون اینکه متن بازبینی‌شدهٔ درس تغییر کند.',
  );
  String get openNotes => _t('Open personal notes', 'بازکردن یادداشت‌های شخصی');
  String get studyToolkit => _t('Context tools', 'ابزارهای همین درس');
  String toolName(_WorkspaceTool tool) => switch (tool) {
    _WorkspaceTool.notes => _t('Notes', 'یادداشت‌ها'),
    _WorkspaceTool.focus => _t('Focus', 'تمرکز'),
    _WorkspaceTool.sources => _t('Sources', 'منابع'),
  };
  String get personalNotes => _t('Personal notes', 'یادداشت‌های شخصی');
  String get personalNotesBody => _t(
    'Private learner-authored material, kept separate from published medical content.',
    'محتوای خصوصی نوشته‌شده توسط یادگیرنده که از محتوای پزشکی منتشرشده جدا می‌ماند.',
  );
  String get newNote => _t('New note', 'یادداشت جدید');
  String get noteHint => _t(
    'Write a distinction, question, or memory cue…',
    'یک تمایز، پرسش یا سرنخ حافظه بنویس…',
  );
  String get saveNote => _t('Save note', 'ذخیرهٔ یادداشت');
  String get noPersonalNotes => _t(
    'No personal note yet. Your reviewed lesson remains unchanged.',
    'هنوز یادداشت شخصی‌ای ندارید. درس بازبینی‌شده بدون تغییر باقی می‌ماند.',
  );
  String get deleteNote => _t('Delete note', 'حذف یادداشت');
  String get focusMode => _t('Calm focus', 'تمرکز آرام');
  String get focusModeBody => _t(
    'A humane timer for this lesson. Pausing saves elapsed study time; no reward depends on speed.',
    'زمان‌سنجی انسانی برای همین درس. توقف، زمان سپری‌شده را ذخیره می‌کند و هیچ پاداشی به سرعت وابسته نیست.',
  );
  String get startFocus => _t('Start focus', 'شروع تمرکز');
  String get pauseAndSave => _t('Pause & save', 'توقف و ذخیره');
  String focusRemaining(String time) =>
      _t('$time remaining', '$time باقی‌مانده');
  String get focusLogged => _t('Time logged', 'زمان ثبت‌شده');
  String get focusSessions => _t('Focus sessions', 'جلسه‌های تمرکز');
  String focusTime(int seconds) {
    final minutes = seconds ~/ 60;
    return minutes < 60
        ? _t('$minutes min', '$minutes دقیقه')
        : _t('${minutes ~/ 60}h ${minutes % 60}m', '${minutes ~/ 60} ساعت');
  }

  String get focusTruth => _t(
    'Focus time is a private study log—not XP, mastery, streak, or clinical competence.',
    'زمان تمرکز فقط گزارش خصوصی مطالعه است؛ نه XP، تسلط، استریک یا صلاحیت بالینی.',
  );
  String get sourceContext => _t('Source context', 'بافت منبع');
  String get sourceContextBody => _t(
    'Provenance stays beside the lesson without exposing a local corpus path.',
    'منشأ محتوا کنار درس می‌ماند، بدون اینکه مسیر محلی مجموعه آشکار شود.',
  );
  String get packageState => _t('Package state', 'وضعیت بسته');
  String get reviewedActiveRelease =>
      _t('Active reviewed release', 'انتشار بازبینی‌شدهٔ فعال');
  String get curriculumAnchor => _t('Curriculum anchor', 'لنگر برنامهٔ درسی');
  String get sourceAtomsLabel => _t('Source atoms', 'اتم‌های منبع');
  String get educationBoundary => _t('Education mode', 'حالت آموزشی');
  String get educationBoundaryBody => _t(
    'This workspace supports medical learning and does not provide patient-specific guidance.',
    'این فضا برای آموزش پزشکی است و راهنمایی مختص بیمار ارائه نمی‌کند.',
  );
  String get sourceAttachmentTruth => _t(
    'Attached PDFs stay private and local. They support this lesson context but do not become reviewed medical evidence or change the published package.',
    'PDFهای متصل خصوصی و محلی می‌مانند. آن‌ها از بافت همین درس پشتیبانی می‌کنند، اما به شواهد پزشکی بازبینی‌شده تبدیل نمی‌شوند و بستهٔ منتشرشده را تغییر نمی‌دهند.',
  );
  String get attachedReferences => _t('Attached reading', 'مطالعه‌های متصل');
  String get attachedReferencesBody => _t(
    'Only documents explicitly linked to this lesson appear here.',
    'فقط سندهایی که صریحاً به همین درس متصل شده‌اند اینجا نمایش داده می‌شوند.',
  );
  String referenceCount(int value) =>
      _t('$value PDF${value == 1 ? '' : 's'}', '$value PDF');
  String get noAttachedReferences => _t(
    'No private PDF is attached to this lesson yet.',
    'هنوز PDF خصوصی‌ای به این درس متصل نشده است.',
  );
  String get referenceListUnavailable => _t(
    'Attached reading could not be restored. No document was removed.',
    'مطالعه‌های متصل بازیابی نشدند؛ هیچ سندی حذف نشده است.',
  );
  String get attachPdf =>
      _t('Attach a PDF to this lesson', 'اتصال PDF به این درس');
  String get detachReference =>
      _t('Detach from this lesson', 'جداکردن از این درس');
  String detachReferenceBody(String name) => _t(
    'Detach “$name” from this lesson? The private PDF, its reading place, bookmarks, and annotations will not be deleted.',
    '«$name» از این درس جدا شود؟ PDF خصوصی، جای مطالعه، نشانک‌ها و حاشیه‌نویسی‌هایش حذف نمی‌شوند.',
  );
  String get cancel => _t('Cancel', 'لغو');
  String get detach => _t('Detach', 'جدا کن');
  String get detachReferenceFailed => _t(
    'The PDF was not detached. Its lesson relationship remains intact.',
    'PDF جدا نشد و ارتباطش با درس سالم باقی مانده است.',
  );
  String openReference(String name) => _t('Open $name', 'بازکردن $name');
  String documentMeta(int? pageCount, int byteLength) {
    final pages = pageCount == null
        ? _t('Page count pending', 'تعداد صفحه نامشخص')
        : _t('$pageCount pages', '$pageCount صفحه');
    final size = byteLength < 1024 * 1024
        ? '${(byteLength / 1024).ceil()} KB'
        : '${(byteLength / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '$pages · $size';
  }

  String get documentImportFailed => _t(
    'The PDF was not attached. Existing lesson sources remain intact.',
    'PDF متصل نشد؛ منبع‌های فعلی درس سالم باقی مانده‌اند.',
  );
  String get saveFailed => _t(
    'The change was not saved. Your previous workspace is intact; try again.',
    'تغییر ذخیره نشد. فضای قبلی شما سالم است؛ دوباره تلاش کنید.',
  );
  String get session => _t('Learning session', 'جلسهٔ یادگیری');
  String minutes(int value) => _t('$value min', '$value دقیقه');
  String sessions(int value) => _t('$value sessions', '$value جلسه');
  String sourceAnchors(int value) =>
      _t('$value source anchors', '$value لنگر منبع');
  String interactions(int value) => _t('$value interactions', '$value تعامل');
  String sessionType(CurriculumSessionType type) => switch (type) {
    CurriculumSessionType.learn => _t('Learn', 'یادگیری'),
    CurriculumSessionType.recall => _t('Recall', 'بازیابی فعال'),
    CurriculumSessionType.repair => _t('Repair', 'اصلاح خطا'),
    CurriculumSessionType.apply => _t('Apply', 'کاربرد'),
    CurriculumSessionType.challenge => _t('Challenge', 'چالش'),
    CurriculumSessionType.checkpoint => _t('Checkpoint', 'ایستگاه سنجش'),
    CurriculumSessionType.teach => _t('Teach back', 'بازآموزی'),
    CurriculumSessionType.transfer => _t('Transfer', 'انتقال یادگیری'),
  };
}

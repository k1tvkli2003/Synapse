import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:synapse_core/synapse_core.dart';

import '../../brand/synapse_identity.dart';
import '../../data/resource_documents/resource_document_blob_store.dart';
import '../../state/app_providers.dart';
import '../../state/curriculum_provider.dart';
import '../../state/settings_provider.dart';

/// Full-screen, six-platform reader for one content-addressed private PDF.
///
/// Reading position and learner artifacts are kept outside curriculum mastery
/// and reward systems. Opening, scrolling, or searching can never award XP.
class AcademyResourceDocumentScreen extends ConsumerWidget {
  const AcademyResourceDocumentScreen({
    super.key,
    required this.documentId,
    this.nodeId,
  });

  final ResourceDocumentId documentId;
  final String? nodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(settingsProvider).locale == 'fa'
        ? ContentLocale.fa
        : ContentLocale.en;
    final copy = _ReaderCopy(locale);
    final document = documentId.trim().isEmpty
        ? const AsyncValue<ResourceDocument?>.data(null)
        : ref.watch(resourceDocumentProvider(documentId));
    return Directionality(
      textDirection: locale == ContentLocale.fa
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: _ReaderColors.midnight,
        body: SafeArea(
          child: document.when(
            loading: () => _ReaderState(
              title: copy.openingDocument,
              body: copy.openingDocumentBody,
              busy: true,
            ),
            error: (_, _) => _ReaderState(
              title: copy.metadataUnavailable,
              body: copy.metadataUnavailableBody,
              actionLabel: copy.tryAgain,
              onAction: () =>
                  ref.invalidate(resourceDocumentProvider(documentId)),
            ),
            data: (value) => value == null
                ? _ReaderState(
                    title: copy.documentNotFound,
                    body: copy.documentNotFoundBody,
                  )
                : _ResolvedDocumentReader(
                    key: ValueKey(value.contentSha256),
                    locale: locale,
                    document: value,
                    nodeId: nodeId,
                  ),
          ),
        ),
      ),
    );
  }
}

class _ResolvedDocumentReader extends ConsumerWidget {
  const _ResolvedDocumentReader({
    super.key,
    required this.locale,
    required this.document,
    this.nodeId,
  });

  final ContentLocale locale;
  final ResourceDocument document;
  final String? nodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = _ReaderCopy(locale);
    final source = ref.watch(resourceDocumentSourceProvider(document));
    return source.when(
      loading: () => _ReaderState(
        title: copy.verifyingLocalCopy,
        body: copy.verifyingLocalCopyBody,
        busy: true,
      ),
      error: (_, _) => _ReaderState(
        title: copy.localCopyUnavailable,
        body: copy.localCopyUnavailableBody,
        actionLabel: copy.tryAgain,
        onAction: () =>
            ref.invalidate(resourceDocumentSourceProvider(document)),
      ),
      data: (value) => value == null
          ? _ReaderState(
              title: copy.localCopyMissing,
              body: copy.localCopyMissingBody,
            )
          : _DocumentReaderBody(
              locale: locale,
              document: document,
              source: value,
              nodeId: nodeId,
            ),
    );
  }
}

class _DocumentReaderBody extends ConsumerStatefulWidget {
  const _DocumentReaderBody({
    required this.locale,
    required this.document,
    required this.source,
    this.nodeId,
  });

  final ContentLocale locale;
  final ResourceDocument document;
  final ResourceDocumentSource source;
  final String? nodeId;

  @override
  ConsumerState<_DocumentReaderBody> createState() =>
      _DocumentReaderBodyState();
}

class _DocumentReaderBodyState extends ConsumerState<_DocumentReaderBody>
    with WidgetsBindingObserver {
  final PdfViewerController _viewerController = PdfViewerController();
  final TextEditingController _searchController = TextEditingController();
  PdfTextSearcher? _searcher;
  Timer? _positionTimer;
  int _currentPage = 1;
  int? _pendingPage;
  bool _viewerReady = false;
  bool _restoreResolved = false;
  bool _restoreScheduled = false;
  bool _savingPosition = false;
  bool _positionSaveFailed = false;
  bool _artifactBusy = false;
  bool _searchOpen = false;
  bool _viewerLoadFailed = false;
  bool _inkMode = false;
  int? _draftInkPage;
  List<ResourceInkPoint> _draftInkPoints = const [];
  List<_SelectedTextSlice> _selectedTextSlices = const [];
  Map<int, List<PdfPageTextRange>> _paintedHighlights = const {};
  String? _highlightHydrationSignature;
  bool _hydratingHighlights = false;

  ResourceReference get _resource => widget.document.reference;

  DocumentPageRangeResourceAnchor get _pageAnchor =>
      DocumentPageRangeResourceAnchor(
        resource: _resource,
        startPage: _currentPage,
        endPage: _currentPage,
      );

  _ReaderCopy get _copy => _ReaderCopy(widget.locale);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionTimer?.cancel();
    _searcher
      ?..removeListener(_onSearchChanged)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _pendingPage != null) {
      _positionTimer?.cancel();
      unawaited(_flushReadingPosition());
    }
  }

  @override
  Widget build(BuildContext context) {
    final position = ref.watch(
      resourceDocumentReadingPositionProvider(widget.document.id),
    );
    final bookmarks = ref.watch(
      resourceBookmarksForResourceProvider(_resource),
    );
    final annotations = ref.watch(
      resourceAnnotationsForResourceProvider(_resource),
    );
    final anchors = ref.watch(resourceAnchorsForResourceProvider(_resource));
    _scheduleRestore(position);
    _scheduleHighlightHydration(annotations, anchors);
    final pageAnchorId = _pageAnchor.stableId;
    final isBookmarked =
        bookmarks.asData?.value.any(
          (bookmark) => bookmark.anchorId == pageAnchorId,
        ) ??
        false;
    final anchorById = {
      for (final anchor in anchors.asData?.value ?? const <ResourceAnchor>[])
        anchor.stableId: anchor,
    };
    final pageArtifacts =
        annotations.asData?.value
            .where((annotation) {
              if (annotation.state == ResourceAnnotationState.deleted) {
                return false;
              }
              final anchor = anchorById[annotation.anchorId];
              return anchor != null && _anchorTouchesPage(anchor, _currentPage);
            })
            .toList(growable: false) ??
        const <ResourceAnnotation>[];
    final inkByPage = <int, List<ResourceAnnotation>>{};
    for (final annotation
        in annotations.asData?.value ?? const <ResourceAnnotation>[]) {
      if (annotation.kind != ResourceAnnotationKind.ink ||
          annotation.state == ResourceAnnotationState.deleted) {
        continue;
      }
      final anchor = anchorById[annotation.anchorId];
      if (anchor is DocumentRegionResourceAnchor) {
        inkByPage.putIfAbsent(anchor.pageNumber, () => []).add(annotation);
      }
    }
    return Column(
      children: [
        _readerHeader(
          context,
          isBookmarked: isBookmarked,
          pageArtifacts: pageArtifacts,
        ),
        if (_searchOpen) _searchBar(context),
        if (_inkMode)
          _ReaderBanner(
            icon: Icons.gesture_rounded,
            color: _ReaderColors.cyan,
            text: _copy.inkModeBody,
          ),
        if (_viewerLoadFailed)
          _ReaderBanner(
            icon: Icons.error_outline_rounded,
            color: _ReaderColors.coral,
            text: _copy.viewerLoadFailed,
          ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(child: _buildViewer(inkByPage)),
              if (!_viewerReady && !_viewerLoadFailed)
                const Positioned.fill(
                  child: ColoredBox(
                    color: _ReaderColors.midnight,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: _ReaderColors.cyan,
                      ),
                    ),
                  ),
                ),
              if (_artifactBusy)
                const Positioned(top: 14, right: 14, child: _ReaderBusyPill()),
            ],
          ),
        ),
        _readerFooter(position),
      ],
    );
  }

  Widget _readerHeader(
    BuildContext context, {
    required bool isBookmarked,
    required List<ResourceAnnotation> pageArtifacts,
  }) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    return Container(
      padding: EdgeInsets.fromLTRB(compact ? 8 : 18, 8, compact ? 8 : 18, 10),
      decoration: const BoxDecoration(
        color: _ReaderColors.header,
        border: Border(bottom: BorderSide(color: Color(0x243D6EA8))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: _copy.back,
                onPressed: context.pop,
                color: Colors.white,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              if (!compact) ...[
                const SynapseWordmark(height: 22),
                const SizedBox(width: 14),
                Container(width: 1, height: 24, color: Colors.white12),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.document.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _copy.privateReference,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.25,
                      ),
                    ),
                  ],
                ),
              ),
              _ReaderIconButton(
                tooltip: _copy.searchDocument,
                icon: _searchOpen
                    ? Icons.search_off_rounded
                    : Icons.search_rounded,
                active: _searchOpen,
                onPressed: _viewerReady
                    ? () => setState(() => _searchOpen = !_searchOpen)
                    : null,
              ),
              _ReaderIconButton(
                tooltip: isBookmarked
                    ? _copy.removePageBookmark
                    : _copy.bookmarkPage,
                icon: isBookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                active: isBookmarked,
                onPressed: _artifactBusy
                    ? null
                    : () => _togglePageBookmark(!isBookmarked),
              ),
              _ReaderIconButton(
                tooltip: _selectedTextSlices.isEmpty
                    ? _copy.selectTextToHighlight
                    : _copy.saveHighlight,
                icon: Icons.border_color_rounded,
                active: _selectedTextSlices.isNotEmpty,
                onPressed: _artifactBusy || _selectedTextSlices.isEmpty
                    ? null
                    : _saveSelectionHighlights,
              ),
              _ReaderIconButton(
                tooltip: _inkMode ? _copy.finishInkMode : _copy.startInkMode,
                icon: _inkMode ? Icons.gesture_rounded : Icons.draw_outlined,
                active: _inkMode,
                onPressed: _viewerReady && !_artifactBusy
                    ? () => setState(() {
                        _inkMode = !_inkMode;
                        _draftInkPage = null;
                        _draftInkPoints = const [];
                      })
                    : null,
              ),
              Badge.count(
                count: pageArtifacts.length,
                isLabelVisible: pageArtifacts.isNotEmpty,
                backgroundColor: _ReaderColors.coral,
                child: _ReaderIconButton(
                  tooltip: _copy.pageNotes,
                  icon: Icons.rate_review_outlined,
                  onPressed: () => _openPageNotes(pageArtifacts),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ReaderControlButton(
                  icon: Icons.chevron_left_rounded,
                  label: _copy.previousPage,
                  compact: compact,
                  onPressed: _viewerReady && _currentPage > 1
                      ? () => _goToPage(_currentPage - 1)
                      : null,
                ),
                const SizedBox(width: 6),
                _ReaderPageButton(
                  currentPage: _currentPage,
                  pageCount: widget.document.pageCount ?? 1,
                  onPressed: _viewerReady ? _choosePage : null,
                ),
                const SizedBox(width: 6),
                _ReaderControlButton(
                  icon: Icons.chevron_right_rounded,
                  label: _copy.nextPage,
                  compact: compact,
                  onPressed:
                      _viewerReady &&
                          _currentPage < (widget.document.pageCount ?? 1)
                      ? () => _goToPage(_currentPage + 1)
                      : null,
                ),
                const SizedBox(width: 16),
                _ReaderControlButton(
                  icon: Icons.remove_rounded,
                  label: _copy.zoomOut,
                  compact: true,
                  onPressed: _viewerReady
                      ? () => _viewerController.zoomDown(
                          duration: _motionDuration(context),
                        )
                      : null,
                ),
                const SizedBox(width: 6),
                _ReaderControlButton(
                  icon: Icons.fit_screen_rounded,
                  label: _copy.fitWidth,
                  compact: compact,
                  onPressed: _viewerReady ? _fitWidth : null,
                ),
                const SizedBox(width: 6),
                _ReaderControlButton(
                  icon: Icons.add_rounded,
                  label: _copy.zoomIn,
                  compact: true,
                  onPressed: _viewerReady
                      ? () => _viewerController.zoomUp(
                          duration: _motionDuration(context),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBar(BuildContext context) {
    final searcher = _searcher;
    final searching = searcher?.isSearching ?? false;
    final matches = searcher?.matches.length ?? 0;
    final currentIndex = searcher?.currentIndex;
    return Material(
      color: const Color(0xFF071A34),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('document-search-field'),
                controller: _searchController,
                autofocus: true,
                onChanged: (value) => _searcher?.startTextSearch(value.trim()),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: _copy.searchHint,
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  suffixIcon: searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _ReaderColors.cyan,
                          ),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 72,
              child: Text(
                matches == 0
                    ? _copy.noMatchesShort
                    : '${(currentIndex ?? 0) + 1}/$matches',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: _copy.previousMatch,
              onPressed: matches > 0 ? () => _searcher?.goToPrevMatch() : null,
              icon: const Icon(Icons.keyboard_arrow_up_rounded),
            ),
            IconButton(
              tooltip: _copy.nextMatch,
              onPressed: matches > 0 ? () => _searcher?.goToNextMatch() : null,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewer(Map<int, List<ResourceAnnotation>> inkByPage) {
    final params = PdfViewerParams(
      margin: 18,
      backgroundColor: _ReaderColors.viewer,
      forceEnableTextSemantics: true,
      panEnabled: !_inkMode,
      scaleEnabled: !_inkMode,
      textSelectionParams: PdfTextSelectionParams(
        enabled: !_inkMode,
        onTextSelectionChange: _onTextSelectionChanged,
      ),
      onViewerReady: (_, _) => _onViewerReady(),
      onPageChanged: _onPageChanged,
      onDocumentLoadFinished: (_, succeeded) {
        if (!succeeded && mounted) {
          setState(() => _viewerLoadFailed = true);
        }
      },
      pagePaintCallbacks: [
        _paintPersistedHighlights,
        (canvas, pageRect, page) =>
            _searcher?.pageTextMatchPaintCallback(canvas, pageRect, page),
      ],
      pageOverlaysBuilder: (_, _, page) => [
        Positioned.fill(
          child: _PdfInkOverlay(
            enabled: _inkMode,
            annotations:
                inkByPage[page.pageNumber] ?? const <ResourceAnnotation>[],
            draftPoints: _draftInkPage == page.pageNumber
                ? _draftInkPoints
                : const <ResourceInkPoint>[],
            onStart: (position, size) =>
                _startInkStroke(page.pageNumber, position, size),
            onUpdate: (position, size) =>
                _updateInkStroke(page.pageNumber, position, size),
            onEnd: _finishInkStroke,
          ),
        ),
      ],
      matchTextColor: _ReaderColors.gold.withValues(alpha: 0.44),
      activeMatchTextColor: _ReaderColors.coral.withValues(alpha: 0.55),
    );
    final source = widget.source;
    if (source is ResourceDocumentFileSource) {
      return PdfViewer.file(
        source.filePath,
        key: ValueKey('pdf-file-${source.contentSha256}'),
        controller: _viewerController,
        params: params,
      );
    }
    final bytes = source as ResourceDocumentBytesSource;
    return PdfViewer.data(
      bytes.bytes,
      sourceName: bytes.contentSha256,
      key: ValueKey('pdf-bytes-${source.contentSha256}'),
      controller: _viewerController,
      params: params,
    );
  }

  Widget _readerFooter(AsyncValue<ResourceDocumentReadingPosition?> position) {
    final restored = position.asData?.value;
    final progress = widget.document.pageCount == null
        ? 0.0
        : (_currentPage / widget.document.pageCount!).clamp(0.0, 1.0);
    return Container(
      color: _ReaderColors.header,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 3,
              value: progress,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation(_ReaderColors.cyan),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Icon(
                _positionSaveFailed
                    ? Icons.cloud_off_outlined
                    : _savingPosition
                    ? Icons.sync_rounded
                    : Icons.book_outlined,
                size: 14,
                color: _positionSaveFailed
                    ? _ReaderColors.coral
                    : Colors.white54,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _positionSaveFailed
                      ? _copy.positionSaveFailed
                      : _savingPosition
                      ? _copy.savingPlace
                      : restored == null
                      ? _copy.rewardNeutralReading
                      : _copy.resumeSaved(restored.pageNumber),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _positionSaveFailed
                        ? _ReaderColors.coral
                        : Colors.white54,
                    fontSize: 10.5,
                  ),
                ),
              ),
              Text(
                _copy.educationMode,
                style: const TextStyle(
                  color: _ReaderColors.gold,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _onViewerReady() {
    _searcher ??= PdfTextSearcher(_viewerController)
      ..addListener(_onSearchChanged);
    if (mounted) setState(() => _viewerReady = true);
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  void _onTextSelectionChanged(PdfTextSelection selection) {
    unawaited(_captureTextSelection(selection));
  }

  Future<void> _captureTextSelection(PdfTextSelection selection) async {
    if (!selection.hasSelectedText || !selection.isCopyAllowed) {
      if (mounted && _selectedTextSlices.isNotEmpty) {
        setState(() => _selectedTextSlices = const []);
      }
      return;
    }
    try {
      final ranges = await selection.getSelectedTextRanges();
      final slices = <_SelectedTextSlice>[];
      for (final range in ranges.take(32)) {
        if (range.end <= range.start || range.text.trim().isEmpty) continue;
        slices.add(
          _SelectedTextSlice(
            pageNumber: range.pageNumber,
            startOffset: range.start,
            endOffset: range.end,
            selectedTextSha256: _selectionDigest(range.text),
          ),
        );
      }
      if (mounted) {
        setState(() => _selectedTextSlices = List.unmodifiable(slices));
      }
    } on Object {
      if (mounted) setState(() => _selectedTextSlices = const []);
    }
  }

  Future<void> _saveSelectionHighlights() async {
    if (_artifactBusy || _selectedTextSlices.isEmpty) return;
    setState(() => _artifactBusy = true);
    try {
      final repository = ref.read(resourceWorkspaceRepositoryProvider);
      final activeHighlights =
          (await repository.listAnnotationsForResource(_resource)).where(
            (annotation) =>
                annotation.kind == ResourceAnnotationKind.highlight &&
                annotation.state == ResourceAnnotationState.active,
          );
      final activeAnchorIds = activeHighlights
          .map((annotation) => annotation.anchorId)
          .toSet();
      for (final slice in _selectedTextSlices) {
        final anchor = DocumentTextRangeResourceAnchor(
          resource: _resource,
          pageNumber: slice.pageNumber,
          startOffset: slice.startOffset,
          endOffset: slice.endOffset,
          selectedTextSha256: slice.selectedTextSha256,
        );
        if (activeAnchorIds.add(anchor.stableId)) {
          await repository.addHighlight(
            anchor: anchor,
            color: ResourceArtifactColor.gold,
          );
        }
      }
      await _viewerController.textSelectionDelegate.clearTextSelection();
      if (mounted) setState(() => _selectedTextSlices = const []);
      ref.invalidate(resourceAnchorsForResourceProvider(_resource));
      ref.invalidate(resourceAnnotationsForResourceProvider(_resource));
    } on Object {
      _showMessage(_copy.artifactSaveFailed);
    } finally {
      if (mounted) setState(() => _artifactBusy = false);
    }
  }

  void _scheduleHighlightHydration(
    AsyncValue<List<ResourceAnnotation>> annotations,
    AsyncValue<List<ResourceAnchor>> anchors,
  ) {
    if (!_viewerReady ||
        _searcher == null ||
        annotations.isLoading ||
        anchors.isLoading ||
        annotations.hasError ||
        anchors.hasError ||
        _hydratingHighlights) {
      return;
    }
    final activeAnchorIds = annotations.asData!.value
        .where(
          (annotation) =>
              annotation.kind == ResourceAnnotationKind.highlight &&
              annotation.state == ResourceAnnotationState.active,
        )
        .map((annotation) => annotation.anchorId)
        .toSet();
    final targets =
        anchors.asData!.value
            .whereType<DocumentTextRangeResourceAnchor>()
            .where((anchor) => activeAnchorIds.contains(anchor.stableId))
            .toList()
          ..sort((left, right) => left.stableId.compareTo(right.stableId));
    final signature = targets.map((anchor) => anchor.stableId).join('|');
    if (signature == _highlightHydrationSignature) return;
    _highlightHydrationSignature = signature;
    _hydratingHighlights = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_hydrateHighlights(targets));
    });
  }

  Future<void> _hydrateHighlights(
    List<DocumentTextRangeResourceAnchor> anchors,
  ) async {
    final hydrated = <int, List<PdfPageTextRange>>{};
    try {
      for (final anchor in anchors) {
        final pageText = await _searcher?.loadText(
          pageNumber: anchor.pageNumber,
        );
        if (pageText == null ||
            anchor.startOffset < 0 ||
            anchor.endOffset > pageText.fullText.length ||
            anchor.endOffset <= anchor.startOffset) {
          continue;
        }
        final range = PdfPageTextRange(
          pageText: pageText,
          start: anchor.startOffset,
          end: anchor.endOffset,
        );
        if (_selectionDigest(range.text) != anchor.selectedTextSha256) {
          continue;
        }
        hydrated.putIfAbsent(anchor.pageNumber, () => []).add(range);
      }
      if (!mounted) return;
      setState(() {
        _paintedHighlights = {
          for (final entry in hydrated.entries)
            entry.key: List.unmodifiable(entry.value),
        };
      });
      _viewerController.invalidate();
    } on Object {
      _highlightHydrationSignature = null;
    } finally {
      _hydratingHighlights = false;
    }
  }

  void _paintPersistedHighlights(Canvas canvas, Rect pageRect, PdfPage page) {
    final ranges = _paintedHighlights[page.pageNumber];
    if (ranges == null || ranges.isEmpty) return;
    final paint = Paint()
      ..color = _ReaderColors.gold.withValues(alpha: 0.32)
      ..style = PaintingStyle.fill;
    for (final range in ranges) {
      for (final fragment in range.enumerateFragmentBoundingRects()) {
        final rect = fragment.bounds
            .toRect(page: page, scaledPageSize: pageRect.size)
            .translate(pageRect.left, pageRect.top);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.inflate(1.2), const Radius.circular(2)),
          paint,
        );
      }
    }
  }

  void _startInkStroke(int pageNumber, Offset position, Size size) {
    if (!_inkMode || _artifactBusy || size.isEmpty) return;
    final point = _normalizedInkPoint(position, size);
    setState(() {
      _currentPage = pageNumber;
      _draftInkPage = pageNumber;
      _draftInkPoints = [point];
    });
    _viewerController.setCurrentPageNumber(pageNumber);
  }

  void _updateInkStroke(int pageNumber, Offset position, Size size) {
    if (!_inkMode ||
        _artifactBusy ||
        _draftInkPage != pageNumber ||
        _draftInkPoints.isEmpty ||
        _draftInkPoints.length >= ResourceInkStroke.maxPoints ||
        size.isEmpty) {
      return;
    }
    final point = _normalizedInkPoint(position, size);
    final prior = _draftInkPoints.last;
    if ((point.xMillionths - prior.xMillionths).abs() < 900 &&
        (point.yMillionths - prior.yMillionths).abs() < 900) {
      return;
    }
    setState(() => _draftInkPoints = [..._draftInkPoints, point]);
  }

  ResourceInkPoint _normalizedInkPoint(Offset position, Size size) =>
      ResourceInkPoint(
        xMillionths:
            ((position.dx.clamp(0, size.width) / size.width) *
                    ResourceInkPoint.scale)
                .round(),
        yMillionths:
            ((position.dy.clamp(0, size.height) / size.height) *
                    ResourceInkPoint.scale)
                .round(),
        pressurePermille: 700,
      );

  Future<void> _finishInkStroke() async {
    final pageNumber = _draftInkPage;
    final points = _draftInkPoints;
    if (!_inkMode || _artifactBusy || pageNumber == null || points.length < 2) {
      if (mounted && points.length < 2) {
        setState(() {
          _draftInkPage = null;
          _draftInkPoints = const [];
        });
      }
      return;
    }
    setState(() => _artifactBusy = true);
    try {
      final anchor = DocumentRegionResourceAnchor(
        resource: _resource,
        pageNumber: pageNumber,
        region: NormalizedResourceRegion(
          leftMillionths: 0,
          topMillionths: 0,
          widthMillionths: NormalizedResourceRegion.scale,
          heightMillionths: NormalizedResourceRegion.scale,
        ),
      );
      await ref
          .read(resourceWorkspaceRepositoryProvider)
          .addInk(
            anchor: anchor,
            strokes: [
              ResourceInkStroke(
                id: 'stroke.${ref.read(operationalIdSourceProvider).nextId()}',
                points: points,
                widthMillionths: 4500,
                opacityPermille: 850,
              ),
            ],
            color: ResourceArtifactColor.cyan,
          );
      ref.invalidate(resourceAnchorsForResourceProvider(_resource));
      ref.invalidate(resourceAnnotationsForResourceProvider(_resource));
      await ref.read(resourceAnnotationsForResourceProvider(_resource).future);
      if (mounted) {
        setState(() {
          _draftInkPage = null;
          _draftInkPoints = const [];
        });
      }
    } on Object {
      _showMessage(_copy.artifactSaveFailed);
    } finally {
      if (mounted) setState(() => _artifactBusy = false);
    }
  }

  void _scheduleRestore(AsyncValue<ResourceDocumentReadingPosition?> position) {
    if (_restoreScheduled || !_viewerReady || position.isLoading) return;
    if (position.hasError) return;
    _restoreScheduled = true;
    final saved = position.asData?.value;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final target = saved?.pageNumber.clamp(1, widget.document.pageCount ?? 1);
      if (target != null) {
        _currentPage = target;
        await _viewerController.goToPage(
          pageNumber: target,
          duration: Duration.zero,
        );
      }
      if (mounted) setState(() => _restoreResolved = true);
    });
  }

  void _onPageChanged(int? pageNumber) {
    if (pageNumber == null || pageNumber == _currentPage) return;
    if (mounted) setState(() => _currentPage = pageNumber);
    if (!_restoreResolved) return;
    _pendingPage = pageNumber;
    _positionTimer?.cancel();
    _positionTimer = Timer(
      const Duration(milliseconds: 650),
      _flushReadingPosition,
    );
  }

  Future<void> _flushReadingPosition() async {
    if (_savingPosition || !_restoreResolved) return;
    final page = _pendingPage;
    if (page == null) return;
    _pendingPage = null;
    if (mounted) {
      setState(() {
        _savingPosition = true;
        _positionSaveFailed = false;
      });
    }
    try {
      final repository = ref.read(
        resourceDocumentReadingStateRepositoryProvider,
      );
      final current = await repository.read(widget.document.id);
      await repository.savePosition(
        document: widget.document,
        pageNumber: page,
        pagePositionMillionths: 0,
        expectedRevision: current?.revision,
      );
      ref.invalidate(
        resourceDocumentReadingPositionProvider(widget.document.id),
      );
    } on Object {
      if (mounted) setState(() => _positionSaveFailed = true);
    } finally {
      if (mounted) setState(() => _savingPosition = false);
      if (_pendingPage != null) unawaited(_flushReadingPosition());
    }
  }

  Future<void> _goToPage(int page) => _viewerController.goToPage(
    pageNumber: page.clamp(1, widget.document.pageCount ?? 1),
    duration: _motionDuration(context),
  );

  Future<void> _fitWidth() => _viewerController.goTo(
    _viewerController.calcMatrixFitWidthForPage(pageNumber: _currentPage),
    duration: _motionDuration(context),
  );

  Future<void> _choosePage() async {
    final controller = TextEditingController(text: '$_currentPage');
    final chosen = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_copy.goToPage),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: _copy.pageRange(widget.document.pageCount ?? 1),
          ),
          onSubmitted: (_) =>
              Navigator.of(dialogContext).pop(int.tryParse(controller.text)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(_copy.cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(int.tryParse(controller.text)),
            child: Text(_copy.go),
          ),
        ],
      ),
    );
    controller.dispose();
    if (chosen != null && mounted) await _goToPage(chosen);
  }

  Future<void> _togglePageBookmark(bool value) async {
    if (_artifactBusy) return;
    setState(() => _artifactBusy = true);
    try {
      final repository = ref.read(resourceWorkspaceRepositoryProvider);
      final existing = await repository.readBookmark(
        _pageAnchor.stableId,
        includeDeleted: true,
      );
      await repository.setBookmarked(
        anchor: _pageAnchor,
        isBookmarked: value,
        color: ResourceArtifactColor.gold,
        expectedRevision: existing?.revision,
        label: _copy.pageLabel(_currentPage),
      );
      ref.invalidate(resourceBookmarksForResourceProvider(_resource));
    } on Object {
      _showMessage(_copy.artifactSaveFailed);
    } finally {
      if (mounted) setState(() => _artifactBusy = false);
    }
  }

  Future<void> _openPageNotes(List<ResourceAnnotation> pageArtifacts) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _ReaderColors.panel,
      showDragHandle: true,
      builder: (sheetContext) => _PageNotesSheet(
        locale: widget.locale,
        pageNumber: _currentPage,
        artifacts: pageArtifacts,
        onAdd: () {
          Navigator.of(sheetContext).pop();
          unawaited(_addPageComment());
        },
        onDelete: (annotation) async {
          Navigator.of(sheetContext).pop();
          await _deleteAnnotation(annotation);
        },
      ),
    );
  }

  Future<void> _addPageComment() async {
    final controller = TextEditingController();
    final body = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_copy.addPageNote(_currentPage)),
        content: TextField(
          key: const ValueKey('page-comment-field'),
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          maxLength: ResourceAnnotation.maxCommentLength,
          decoration: InputDecoration(hintText: _copy.pageNoteHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(_copy.cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(_copy.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (body == null || body.isEmpty || !mounted) return;
    setState(() => _artifactBusy = true);
    try {
      await ref
          .read(resourceWorkspaceRepositoryProvider)
          .addComment(
            anchor: _pageAnchor,
            locale: widget.locale,
            body: body,
            color: ResourceArtifactColor.cyan,
          );
      ref.invalidate(resourceAnnotationsForResourceProvider(_resource));
    } on Object {
      _showMessage(_copy.artifactSaveFailed);
    } finally {
      if (mounted) setState(() => _artifactBusy = false);
    }
  }

  Future<void> _deleteAnnotation(ResourceAnnotation annotation) async {
    if (_artifactBusy) return;
    setState(() => _artifactBusy = true);
    try {
      await ref
          .read(resourceWorkspaceRepositoryProvider)
          .setAnnotationState(
            annotationId: annotation.id,
            state: ResourceAnnotationState.deleted,
            expectedRevision: annotation.revision,
          );
      ref.invalidate(resourceAnnotationsForResourceProvider(_resource));
    } on Object {
      _showMessage(_copy.artifactSaveFailed);
    } finally {
      if (mounted) setState(() => _artifactBusy = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Duration _motionDuration(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 180);
}

class _ReaderState extends StatelessWidget {
  const _ReaderState({
    required this.title,
    required this.body,
    this.busy = false,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String body;
  final bool busy;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                const CircularProgressIndicator(color: _ReaderColors.cyan)
              else
                const SynapseCompanion(
                  pose: SynapseCompanionPose.thinking,
                  size: 112,
                ),
              const SizedBox(height: 22),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, height: 1.5),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PageNotesSheet extends StatelessWidget {
  const _PageNotesSheet({
    required this.locale,
    required this.pageNumber,
    required this.artifacts,
    required this.onAdd,
    required this.onDelete,
  });

  final ContentLocale locale;
  final int pageNumber;
  final List<ResourceAnnotation> artifacts;
  final VoidCallback onAdd;
  final ValueChanged<ResourceAnnotation> onDelete;

  @override
  Widget build(BuildContext context) {
    final copy = _ReaderCopy(locale);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                copy.pageNotesFor(pageNumber),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                copy.pageNotesPrivacy,
                style: const TextStyle(color: Colors.white60, height: 1.4),
              ),
              const SizedBox(height: 16),
              if (artifacts.isEmpty)
                _ReaderBanner(
                  icon: Icons.note_add_outlined,
                  color: _ReaderColors.cyan,
                  text: copy.noPageNotes,
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: artifacts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final artifact = artifacts[index];
                      final icon = switch (artifact.kind) {
                        ResourceAnnotationKind.highlight =>
                          Icons.border_color_rounded,
                        ResourceAnnotationKind.comment =>
                          Icons.chat_bubble_outline_rounded,
                        ResourceAnnotationKind.ink => Icons.gesture_rounded,
                      };
                      final color = switch (artifact.kind) {
                        ResourceAnnotationKind.highlight => _ReaderColors.gold,
                        ResourceAnnotationKind.comment => _ReaderColors.cyan,
                        ResourceAnnotationKind.ink => _ReaderColors.coral,
                      };
                      final label = switch (artifact.kind) {
                        ResourceAnnotationKind.highlight =>
                          copy.highlightedTextRange,
                        ResourceAnnotationKind.comment => artifact.body ?? '',
                        ResourceAnnotationKind.ink => copy.inkStroke,
                      };
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.055),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(icon, color: color, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  height: 1.45,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: copy.delete,
                              onPressed: () => onDelete(artifact),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: _ReaderColors.coral,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_comment_outlined),
                label: Text(copy.addPageNote(pageNumber)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PdfInkOverlay extends StatelessWidget {
  const _PdfInkOverlay({
    required this.enabled,
    required this.annotations,
    required this.draftPoints,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });

  final bool enabled;
  final List<ResourceAnnotation> annotations;
  final List<ResourceInkPoint> draftPoints;
  final void Function(Offset position, Size size) onStart;
  final void Function(Offset position, Size size) onUpdate;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: enabled
              ? (details) => onStart(details.localPosition, size)
              : null,
          onPanUpdate: enabled
              ? (details) => onUpdate(details.localPosition, size)
              : null,
          onPanEnd: enabled ? (_) => onEnd() : null,
          onPanCancel: enabled ? onEnd : null,
          child: CustomPaint(
            painter: _PdfInkPainter(
              annotations: annotations,
              draftPoints: draftPoints,
            ),
            size: Size.infinite,
          ),
        );
      },
    );
  }
}

class _PdfInkPainter extends CustomPainter {
  const _PdfInkPainter({required this.annotations, required this.draftPoints});

  final List<ResourceAnnotation> annotations;
  final List<ResourceInkPoint> draftPoints;

  @override
  void paint(Canvas canvas, Size size) {
    for (final annotation in annotations) {
      for (final stroke in annotation.inkStrokes) {
        _paintStroke(
          canvas,
          size,
          stroke.points,
          color: _inkColor(
            annotation.color,
          ).withValues(alpha: stroke.opacityPermille / 1000),
          widthMillionths: stroke.widthMillionths,
        );
      }
    }
    if (draftPoints.length >= 2) {
      _paintStroke(
        canvas,
        size,
        draftPoints,
        color: _ReaderColors.cyan.withValues(alpha: 0.82),
        widthMillionths: 4500,
      );
    }
  }

  void _paintStroke(
    Canvas canvas,
    Size size,
    List<ResourceInkPoint> points, {
    required Color color,
    required int widthMillionths,
  }) {
    if (points.length < 2 || size.isEmpty) return;
    final path = Path();
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final position = Offset(
        point.xMillionths / ResourceInkPoint.scale * size.width,
        point.yMillionths / ResourceInkPoint.scale * size.height,
      );
      if (index == 0) {
        path.moveTo(position.dx, position.dy);
      } else {
        path.lineTo(position.dx, position.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth =
            size.shortestSide * widthMillionths / ResourceInkPoint.scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _PdfInkPainter oldDelegate) =>
      oldDelegate.annotations != annotations ||
      oldDelegate.draftPoints != draftPoints;
}

Color _inkColor(ResourceArtifactColor color) => switch (color) {
  ResourceArtifactColor.cyan => _ReaderColors.cyan,
  ResourceArtifactColor.gold => _ReaderColors.gold,
  ResourceArtifactColor.coral => _ReaderColors.coral,
  ResourceArtifactColor.violet => const Color(0xFF9D8BFF),
  ResourceArtifactColor.green => const Color(0xFF54D6A0),
};

class _ReaderIconButton extends StatelessWidget {
  const _ReaderIconButton({
    required this.tooltip,
    required this.icon,
    this.active = false,
    this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool active;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tooltip,
      button: true,
      enabled: onPressed != null,
      child: ExcludeSemantics(
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: active
                ? _ReaderColors.cyan.withValues(alpha: 0.15)
                : Colors.transparent,
            foregroundColor: active ? _ReaderColors.cyan : Colors.white70,
          ),
          icon: Icon(icon),
        ),
      ),
    );
  }
}

class _ReaderControlButton extends StatelessWidget {
  const _ReaderControlButton({
    required this.icon,
    required this.label,
    required this.compact,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool compact;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      enabled: onPressed != null,
      child: ExcludeSemantics(
        child: Tooltip(
          message: label,
          child: OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 18),
            label: compact ? const SizedBox.shrink() : Text(label),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white12),
              minimumSize: Size(compact ? 40 : 48, 38),
              padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 13),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderPageButton extends StatelessWidget {
  const _ReaderPageButton({
    required this.currentPage,
    required this.pageCount,
    this.onPressed,
  });

  final int currentPage;
  final int pageCount;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: _ReaderColors.cyan.withValues(alpha: 0.35)),
        minimumSize: const Size(92, 38),
      ),
      child: Text(
        '$currentPage / $pageCount',
        textDirection: TextDirection.ltr,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _ReaderBanner extends StatelessWidget {
  const _ReaderBanner({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      color: color.withValues(alpha: 0.12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 12, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReaderBusyPill extends StatelessWidget {
  const _ReaderBusyPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _ReaderColors.header.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white12),
      ),
      child: const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: _ReaderColors.cyan,
        ),
      ),
    );
  }
}

final class _SelectedTextSlice {
  const _SelectedTextSlice({
    required this.pageNumber,
    required this.startOffset,
    required this.endOffset,
    required this.selectedTextSha256,
  });

  final int pageNumber;
  final int startOffset;
  final int endOffset;
  final String selectedTextSha256;
}

String _selectionDigest(String value) {
  final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  return sha256.convert(utf8.encode(normalized)).toString();
}

bool _anchorTouchesPage(ResourceAnchor anchor, int pageNumber) =>
    switch (anchor) {
      DocumentPageRangeResourceAnchor() =>
        anchor.startPage <= pageNumber && anchor.endPage >= pageNumber,
      DocumentTextRangeResourceAnchor() => anchor.pageNumber == pageNumber,
      DocumentRegionResourceAnchor() => anchor.pageNumber == pageNumber,
      _ => false,
    };

abstract final class _ReaderColors {
  static const midnight = Color(0xFF031126);
  static const header = Color(0xFF07172E);
  static const panel = Color(0xFF0A1C36);
  static const viewer = Color(0xFF061326);
  static const cyan = Color(0xFF24BDF2);
  static const coral = Color(0xFFFF6E5D);
  static const gold = Color(0xFFF2BB43);
}

final class _ReaderCopy {
  const _ReaderCopy(this.locale);

  final ContentLocale locale;

  String _t(String en, String fa) => locale == ContentLocale.fa ? fa : en;

  String get back => _t('Back', 'بازگشت');
  String get tryAgain => _t('Try again', 'تلاش دوباره');
  String get openingDocument =>
      _t('Opening your reference', 'در حال بازکردن منبع');
  String get openingDocumentBody => _t(
    'Restoring immutable metadata before accessing the private local copy.',
    'پیش از دسترسی به نسخهٔ خصوصی محلی، فرادادهٔ تغییرناپذیر بازیابی می‌شود.',
  );
  String get metadataUnavailable => _t(
    'Document metadata needs attention',
    'فرادادهٔ سند نیاز به بررسی دارد',
  );
  String get metadataUnavailableBody => _t(
    'The registry could not be read. No document or annotation was removed.',
    'رجیستری خوانده نشد؛ هیچ سند یا حاشیه‌نویسی‌ای حذف نشده است.',
  );
  String get documentNotFound => _t('Reference not found', 'منبع پیدا نشد');
  String get documentNotFoundBody => _t(
    'This route does not point to registered document metadata.',
    'این مسیر به فرادادهٔ یک سند ثبت‌شده اشاره نمی‌کند.',
  );
  String get verifyingLocalCopy =>
      _t('Verifying the private PDF', 'در حال بررسی PDF خصوصی');
  String get verifyingLocalCopyBody => _t(
    'Synapse is checking the content-addressed local copy before rendering it.',
    'سیناپس پیش از نمایش، نسخهٔ محلی محتوامحور را بررسی می‌کند.',
  );
  String get localCopyUnavailable =>
      _t('The local copy needs attention', 'نسخهٔ محلی نیاز به بررسی دارد');
  String get localCopyUnavailableBody => _t(
    'The PDF failed an integrity or storage check. Metadata and learner artifacts remain intact.',
    'PDF در بررسی یکپارچگی یا ذخیره‌سازی ناموفق بود؛ فراداده و یادداشت‌های یادگیرنده سالم مانده‌اند.',
  );
  String get localCopyMissing =>
      _t('The PDF is not on this device', 'PDF روی این دستگاه نیست');
  String get localCopyMissingBody => _t(
    'Its metadata is still registered, but the private blob could not be found on this platform.',
    'فراداده هنوز ثبت است، اما فایل خصوصی روی این پلتفرم پیدا نشد.',
  );
  String get privateReference =>
      _t('PRIVATE LESSON REFERENCE', 'منبع خصوصی همین درس');
  String get searchDocument => _t('Search document', 'جست‌وجوی سند');
  String get searchHint =>
      _t('Find a term or phrase…', 'واژه یا عبارت را پیدا کن…');
  String get noMatchesShort => _t('0 results', '۰ نتیجه');
  String get previousMatch => _t('Previous match', 'نتیجهٔ قبلی');
  String get nextMatch => _t('Next match', 'نتیجهٔ بعدی');
  String get bookmarkPage => _t('Bookmark this page', 'نشان‌کردن این صفحه');
  String get removePageBookmark => _t('Remove page bookmark', 'حذف نشانک صفحه');
  String get selectTextToHighlight => _t(
    'Select text to create a highlight',
    'برای ساخت هایلایت، متن را انتخاب کن',
  );
  String get saveHighlight =>
      _t('Save selected highlight', 'ذخیرهٔ هایلایت انتخاب‌شده');
  String get startInkMode => _t('Draw on this page', 'طراحی روی این صفحه');
  String get finishInkMode => _t('Finish drawing', 'پایان طراحی');
  String get inkModeBody => _t(
    'Ink mode is active. Draw directly on a page; navigation and zoom resume when you finish.',
    'حالت طراحی فعال است. مستقیم روی صفحه بکش؛ پس از پایان، پیمایش و بزرگ‌نمایی دوباره فعال می‌شوند.',
  );
  String get pageNotes => _t('Page notes', 'یادداشت‌های صفحه');
  String get previousPage => _t('Previous', 'قبلی');
  String get nextPage => _t('Next', 'بعدی');
  String get zoomOut => _t('Zoom out', 'کوچک‌نمایی');
  String get zoomIn => _t('Zoom in', 'بزرگ‌نمایی');
  String get fitWidth => _t('Fit width', 'هم‌اندازهٔ عرض');
  String get goToPage => _t('Go to page', 'رفتن به صفحه');
  String pageRange(int count) => _t('Page 1–$count', 'صفحهٔ ۱ تا $count');
  String get cancel => _t('Cancel', 'لغو');
  String get go => _t('Go', 'برو');
  String get save => _t('Save', 'ذخیره');
  String get delete => _t('Delete', 'حذف');
  String get viewerLoadFailed => _t(
    'The PDF renderer could not open this local copy.',
    'نمایشگر PDF نتوانست این نسخهٔ محلی را باز کند.',
  );
  String get positionSaveFailed => _t(
    'Latest reading place was not saved; the previous place is intact.',
    'آخرین جای مطالعه ذخیره نشد؛ جای قبلی سالم است.',
  );
  String get savingPlace =>
      _t('Saving reading place…', 'در حال ذخیرهٔ جای مطالعه…');
  String get rewardNeutralReading => _t(
    'Reading position is private and reward-neutral.',
    'جای مطالعه خصوصی است و پاداشی ایجاد نمی‌کند.',
  );
  String resumeSaved(int page) =>
      _t('Resume saved at page $page', 'ادامه از صفحهٔ $page ذخیره شد');
  String get educationMode => _t('EDUCATION MODE', 'حالت آموزشی');
  String pageLabel(int page) => _t('Page $page', 'صفحهٔ $page');
  String pageNotesFor(int page) =>
      _t('Notes on page $page', 'یادداشت‌های صفحهٔ $page');
  String get pageNotesPrivacy => _t(
    'Private learner thinking. It never rewrites the source PDF or reviewed lesson.',
    'یادداشت خصوصی یادگیرنده است و PDF منبع یا درس بازبینی‌شده را بازنویسی نمی‌کند.',
  );
  String get noPageNotes => _t(
    'No private note on this page yet.',
    'هنوز یادداشت خصوصی‌ای روی این صفحه نیست.',
  );
  String get highlightedTextRange => _t(
    'Private text highlight (source text is not copied into Synapse storage)',
    'هایلایت خصوصی متن (متن منبع در ذخیره‌سازی سیناپس کپی نشده است)',
  );
  String get inkStroke =>
      _t('Private freehand annotation', 'حاشیه‌نویسی آزاد و خصوصی');
  String addPageNote(int page) =>
      _t('Add note to page $page', 'افزودن یادداشت به صفحهٔ $page');
  String get pageNoteHint => _t(
    'Capture a distinction, question, or memory cue…',
    'یک تمایز، پرسش یا سرنخ حافظه بنویس…',
  );
  String get artifactSaveFailed => _t(
    'The page artifact was not saved. Existing annotations remain intact.',
    'یادداشت صفحه ذخیره نشد؛ حاشیه‌نویسی‌های فعلی سالم مانده‌اند.',
  );
}

// lib/features/viewer/widgets/markdown_view.dart
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:markread/third_party/gpt_markdown/custom_widgets/markdown_config.dart';
import 'package:markread/third_party/gpt_markdown/gpt_markdown.dart';
import 'package:markread/third_party/gpt_markdown/theme.dart';
import '../../../core/models/user_preferences.dart';
import '../providers/viewer_provider.dart';
import '../services/markdown_block_splitter.dart';
import 'blue_topaz_code_style.dart';
import 'blue_topaz_markdown_theme.dart';
import 'github_code_style.dart';
import 'github_markdown_theme.dart';
import 'markdown_anchors.dart';
import 'monospace_code_style.dart';
import 'monospace_markdown_theme.dart';
import 'search_code_highlight.dart';
import 'zoomable_area.dart';

class MarkdownView extends StatefulWidget {
  final String content;
  /// Original file size in bytes (not search-inflated display length).
  /// Used to gate virtualized vs monolith rendering.
  final int? sourceByteLength;
  final double fontSize;
  final double lineHeight;
  final ReadingTextAlign textAlignment;
  final bool isWordWrapEnabled;
  final ScrollController? scrollController;
  final Color? textColor;
  final void Function(String url, String title)? onLinkTap;
  final double fontScale;
  final ValueChanged<double>? onFontScaleChanged;
  final int headingCount;
  final int searchMatchCount;
  /// Active search query; used to paint highlights inside fenced/inline code.
  final String searchQuery;
  /// Document chrome theme (headings/links/HR/code/tables). Default: GitHub.
  final MarkdownTheme markdownTheme;
  /// Which render path to use (auto / always virtualized / always monolith).
  final MarkdownRenderMode renderMode;

  /// Files at or above this size use the virtualized block [ListView] in
  /// [MarkdownRenderMode.auto].
  static const int kVirtualizeThresholdBytes = 100 * 1024;

  /// Gap matching gpt_markdown [NewLines]: always emits `"\n\n"` at
  /// `fontSize × height: 1.15` (multi-blank runs collapse to one gap).
  static double paragraphBreakGap(double fontSize) => fontSize * 1.15;

  /// Resolve virtualized vs monolith from [renderMode] and document size.
  static bool shouldVirtualize({
    required MarkdownRenderMode renderMode,
    required int? sourceByteLength,
    required int contentLength,
  }) {
    switch (renderMode) {
      case MarkdownRenderMode.performance:
        return true;
      case MarkdownRenderMode.standard:
        return false;
      case MarkdownRenderMode.auto:
        return (sourceByteLength ?? contentLength) >= kVirtualizeThresholdBytes;
    }
  }

  const MarkdownView({
    super.key,
    required this.content,
    this.sourceByteLength,
    this.fontSize = 16.0,
    this.lineHeight = 1.6,
    this.textAlignment = ReadingTextAlign.left,
    this.isWordWrapEnabled = true,
    this.scrollController,
    this.textColor,
    this.onLinkTap,
    this.fontScale = 1.0,
    this.onFontScaleChanged,
    this.headingCount = 0,
    this.searchMatchCount = 0,
    this.searchQuery = '',
    this.markdownTheme = MarkdownTheme.github,
    this.renderMode = MarkdownRenderMode.auto,
  });

  @override
  State<MarkdownView> createState() => MarkdownViewState();
}

class MarkdownViewState extends State<MarkdownView> {
  late List<GlobalKey> _headingKeys;
  late List<GlobalKey> _matchKeys;
  late List<MarkdownBlock> _blocks;
  late _BlockHeightCache _heightCache;

  /// Prefer sticky file bytes; fall back to content length when unknown.
  bool get _useVirtualized => MarkdownView.shouldVirtualize(
        renderMode: widget.renderMode,
        sourceByteLength: widget.sourceByteLength,
        contentLength: widget.content.length,
      );

  /// headingIndex → block index (first match).
  Map<int, int> _headingToBlock = const {};

  /// search match index → block index.
  Map<int, int> _matchToBlock = const {};

  /// Cached reveal offsets for mounted headings (sparse under virtualization).
  List<double?> _cachedHeadingOffsets = const [];
  bool _cacheRefreshScheduled = false;
  bool _firstLayoutSeen = false;

  /// Temporary deep-perf probe: one-shot open/layout metrics per content.
  final GlobalKey _markdownBodyKey = GlobalKey(debugLabel: 'mdBody');
  String? _probedContentIdentity;
  bool _openProbePending = false;
  int _openProbeFrame = 0;
  Stopwatch? _openProbeWatch;
  int _buildPass = 0;

  @override
  void initState() {
    super.initState();
    _headingKeys = _createKeys(widget.headingCount);
    _matchKeys = _createKeys(widget.searchMatchCount);
    _rebuildBlocks();
    _scheduleOffsetCacheRefresh();
    _armOpenProbe(force: true);
  }

  @override
  void didUpdateWidget(covariant MarkdownView oldWidget) {
    super.didUpdateWidget(oldWidget);

    var keysChanged = false;
    if (oldWidget.headingCount != widget.headingCount) {
      _headingKeys = _createKeys(widget.headingCount);
      keysChanged = true;
    }
    if (oldWidget.searchMatchCount != widget.searchMatchCount) {
      _matchKeys = _createKeys(widget.searchMatchCount);
      keysChanged = true;
    }

    final contentChanged = oldWidget.content != widget.content;
    final oldUseVirtualized = MarkdownView.shouldVirtualize(
      renderMode: oldWidget.renderMode,
      sourceByteLength: oldWidget.sourceByteLength,
      contentLength: oldWidget.content.length,
    );
    final pathChanged = oldUseVirtualized != _useVirtualized;
    final layoutAffecting = contentChanged ||
        pathChanged ||
        oldWidget.fontScale != widget.fontScale ||
        oldWidget.fontSize != widget.fontSize ||
        oldWidget.lineHeight != widget.lineHeight ||
        oldWidget.isWordWrapEnabled != widget.isWordWrapEnabled ||
        oldWidget.textAlignment != widget.textAlignment ||
        oldWidget.headingCount != widget.headingCount ||
        // GitHub ↔ Default changes heading scale / table chrome heights.
        oldWidget.markdownTheme != widget.markdownTheme ||
        oldWidget.renderMode != widget.renderMode;

    if (contentChanged || keysChanged || pathChanged) {
      _rebuildBlocks();
    } else if (layoutAffecting && _useVirtualized) {
      _heightCache.invalidateEstimates(
        fontSize: widget.fontSize * widget.fontScale,
        lineHeight: widget.lineHeight,
      );
    }

    if (layoutAffecting || keysChanged) {
      _cachedHeadingOffsets = const [];
      _firstLayoutSeen = false;
      _scheduleOffsetCacheRefresh();
    }
    if (contentChanged) {
      _armOpenProbe(force: true);
    }
  }

  void _rebuildBlocks() {
    if (!_useVirtualized) {
      // Monolith path: skip split / height cache cost.
      _blocks = const [];
      _heightCache = _BlockHeightCache(
        blocks: _blocks,
        fontSize: widget.fontSize * widget.fontScale,
        lineHeight: widget.lineHeight,
      );
      _headingToBlock = const {};
      _matchToBlock = const {};
      _firstLayoutSeen = false;
      return;
    }

    _blocks = splitMarkdownBlocks(widget.content);
    _heightCache = _BlockHeightCache(
      blocks: _blocks,
      fontSize: widget.fontSize * widget.fontScale,
      lineHeight: widget.lineHeight,
    );
    _headingToBlock = <int, int>{};
    for (var i = 0; i < _blocks.length; i++) {
      final hi = _blocks[i].headingIndex;
      if (hi != null && !_headingToBlock.containsKey(hi)) {
        _headingToBlock[hi] = i;
      }
    }
    _matchToBlock = _buildMatchToBlockMap(_blocks, widget.searchMatchCount);
    _firstLayoutSeen = false;
  }

  Map<int, int> _buildMatchToBlockMap(
    List<MarkdownBlock> blocks,
    int matchCount,
  ) {
    if (matchCount <= 0) return const {};
    final map = <int, int>{};
    for (var bi = 0; bi < blocks.length; bi++) {
      final text = blocks[bi].text;
      for (final m in searchMatchExp.allMatches(text)) {
        final idx = int.tryParse(m.group(1) ?? '');
        if (idx != null && idx >= 0 && idx < matchCount) {
          map.putIfAbsent(idx, () => bi);
        }
      }
    }
    return map;
  }

  void _armOpenProbe({bool force = false}) {
    final id = '${widget.content.length}:${widget.headingCount}:'
        '${widget.content.hashCode}';
    if (!force && _probedContentIdentity == id) return;
    _probedContentIdentity = id;
    _openProbePending = true;
    _openProbeFrame = 0;
    _openProbeWatch = Stopwatch()..start();
    _buildPass = 0;
    debugPrint(
      '[bench-md] arm contentLen=${widget.content.length} '
      'sourceBytes=${widget.sourceByteLength ?? -1} '
      'virtualized=$_useVirtualized '
      'headings=${widget.headingCount} '
      'matches=${widget.searchMatchCount} '
      'blocks=${_blocks.length}',
    );
  }

  void _scheduleOpenProbeFrames() {
    if (!_openProbePending) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_openProbePending) return;
      _openProbeFrame += 1;
      // Full tree walk only on frame 1 and 5 — can be expensive on huge docs.
      final walkTree = _openProbeFrame == 1 || _openProbeFrame == 5;
      _emitOpenProbeSample(phase: 'frame$_openProbeFrame', walkTree: walkTree);
      // Sample a few frames: first layout, settle, early idle.
      if (_openProbeFrame < 5) {
        _scheduleOpenProbeFrames();
      } else {
        _openProbePending = false;
        _openProbeWatch?.stop();
      }
    });
  }

  void _emitOpenProbeSample({
    required String phase,
    bool walkTree = false,
  }) {
    final sw = _openProbeWatch;
    final elapsedMs = sw?.elapsedMilliseconds ?? -1;
    final ro = _markdownBodyKey.currentContext?.findRenderObject();
    Size? size;
    if (ro is RenderBox) {
      size = ro.hasSize ? ro.size : null;
    }
    final stats = walkTree ? _countElementTree() : null;
    final controller = widget.scrollController;
    final maxExtent = (controller != null && controller.hasClients)
        ? controller.position.maxScrollExtent
        : -1.0;
    final offset = (controller != null && controller.hasClients)
        ? controller.offset
        : -1.0;
    final mountedHeadings =
        _headingKeys.where((k) => k.currentContext != null).length;
    final treePart = stats == null
        ? 'tree=skipped'
        : 'elements=${stats.elements} '
            'stateful=${stats.stateful} '
            'renderBoxes=${stats.renderBoxes} '
            'depth=${stats.maxDepth} '
            'walkMs=${stats.walkMs} '
            'truncated=${stats.truncated}';
    debugPrint(
      '[bench-md] $phase elapsedMs=$elapsedMs '
      'buildPass=$_buildPass '
      'size=${size == null ? "null" : "${size.width.toStringAsFixed(0)}x${size.height.toStringAsFixed(0)}"} '
      'maxExtent=${maxExtent.toStringAsFixed(0)} '
      'offset=${offset.toStringAsFixed(0)} '
      'blocks=${_blocks.length} '
      'mountedHeadings=$mountedHeadings/${_headingKeys.length} '
      '$treePart',
    );
  }

  _TreeStats _countElementTree() {
    var elements = 0;
    var stateful = 0;
    var renderBoxes = 0;
    var maxDepth = 0;
    var truncated = false;
    const maxNodes = 200000;
    final walkSw = Stopwatch()..start();
    void walk(Element el, int depth) {
      if (elements >= maxNodes || walkSw.elapsedMilliseconds > 250) {
        truncated = true;
        return;
      }
      elements += 1;
      if (depth > maxDepth) maxDepth = depth;
      if (el is StatefulElement) stateful += 1;
      final ro = el.renderObject;
      if (ro is RenderBox) renderBoxes += 1;
      el.visitChildren((child) {
        if (!truncated) walk(child, depth + 1);
      });
    }

    // Count from MarkdownView's element so HUD/app chrome is excluded.
    walk(context as Element, 0);
    walkSw.stop();
    return _TreeStats(
      elements: elements,
      stateful: stateful,
      renderBoxes: renderBoxes,
      maxDepth: maxDepth,
      walkMs: walkSw.elapsedMilliseconds,
      truncated: truncated,
    );
  }

  List<GlobalKey> _createKeys(int count) {
    return List<GlobalKey>.generate(count, (_) => GlobalKey());
  }

  void _scheduleOffsetCacheRefresh() {
    if (_cacheRefreshScheduled) return;
    _cacheRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cacheRefreshScheduled = false;
      if (!mounted) return;
      _refreshOffsetCache();
      final controller = widget.scrollController;
      if (controller != null &&
          controller.hasClients &&
          controller.position.maxScrollExtent > 0) {
        _firstLayoutSeen = true;
      }
      // First frame after content swap can still have null contexts; retry once.
      if (_headingKeys.isNotEmpty &&
          _cachedHeadingOffsets.every((o) => o == null) &&
          !_firstLayoutSeen) {
        _scheduleOffsetCacheRefresh();
      }
    });
  }

  void _refreshOffsetCache() {
    if (_headingKeys.isEmpty) {
      _cachedHeadingOffsets = const [];
      return;
    }
    // Prefer measured key reveals; fall back to block height cache (virtualized).
    final offsets = List<double?>.filled(_headingKeys.length, null);
    for (var i = 0; i < _headingKeys.length; i++) {
      final fromKey = _revealOffset(_headingKeys[i]);
      if (fromKey != null) {
        offsets[i] = fromKey;
        continue;
      }
      if (_useVirtualized) {
        final bi = _headingToBlock[i];
        if (bi != null) {
          // Estimate from block height cache (+ list padding top).
          offsets[i] = _heightCache.offsetOf(bi) + 16.0;
        }
      }
    }
    _cachedHeadingOffsets = offsets;
  }

  /// Ensure cache is populated before mapping. Cheap if already warm.
  void _ensureOffsetCache() {
    if (_headingKeys.isEmpty) return;
    if (_cachedHeadingOffsets.length != _headingKeys.length ||
        _cachedHeadingOffsets.every((o) => o == null)) {
      _refreshOffsetCache();
    }
  }

  void _jumpToBlock(int index) {
    final controller = widget.scrollController;
    if (controller == null || !controller.hasClients) return;
    if (index < 0 || index >= _blocks.length) return;
    final maxExtent = controller.position.maxScrollExtent;
    // ListView padding is 16 all around; height cache is content-relative.
    final offset = (_heightCache.offsetOf(index) + 16.0).clamp(0.0, maxExtent);
    controller.jumpTo(offset);
  }

  /// Scroll so the heading at [index] is at the top of the viewport.
  Future<bool> ensureHeadingVisible(int index) async {
    if (index < 0 || index >= _headingKeys.length) return false;

    if (_useVirtualized) {
      final blockIndex = _headingToBlock[index];
      if (blockIndex != null) {
        _jumpToBlock(blockIndex);
      }

      // Wait a frame for the item to mount, then fine-tune with ensureVisible.
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return false;
      WidgetsBinding.instance.scheduleFrame();
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return false;
    }

    final headingCtx = _headingKeys[index].currentContext;
    if (headingCtx != null && headingCtx.mounted) {
      await Scrollable.ensureVisible(
        headingCtx,
        alignment: 0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      if (!mounted) return true;
      _scheduleOffsetCacheRefresh();
      return true;
    }

    // Key still unmounted after jump — let the screen retry / ratio-fallback.
    _scheduleOffsetCacheRefresh();
    return false;
  }

  /// Scroll so the search match at [index] is at the top of the viewport.
  Future<bool> ensureMatchVisible(int index) async {
    if (index < 0 || index >= _matchKeys.length) return false;

    if (_useVirtualized) {
      var blockIndex = _matchToBlock[index];
      if (blockIndex == null) {
        // Fallback: scan markers (map may miss if rebuilt mid-flight).
        final marker = '\uE000$index\uE001';
        for (var i = 0; i < _blocks.length; i++) {
          if (_blocks[i].text.contains(marker)) {
            blockIndex = i;
            break;
          }
        }
      }
      if (blockIndex != null) {
        _jumpToBlock(blockIndex);
      }

      await Future<void>.delayed(Duration.zero);
      if (!mounted) return false;
      WidgetsBinding.instance.scheduleFrame();
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return false;
    }

    final matchCtx = _matchKeys[index].currentContext;
    if (matchCtx != null && matchCtx.mounted) {
      await Scrollable.ensureVisible(
        matchCtx,
        alignment: 0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      if (!mounted) return true;
      _scheduleOffsetCacheRefresh();
      return true;
    }

    // Key still unmounted after jump — let the screen retry / ratio-fallback.
    _scheduleOffsetCacheRefresh();
    return false;
  }

  /// Map a character offset to a scroll pixel position via piecewise linear
  /// interpolation between adjacent heading anchors, falling back to block
  /// height cache when keys are unmounted.
  ///
  /// Returns null only when there is no useful mapping at all.
  double? scrollOffsetForCharOffset(
    int charOffset,
    List<HeadingItem> headings,
  ) {
    final anchors = _headingAnchors(headings);
    if (anchors.isNotEmpty) {
      if (charOffset <= anchors.first.charOffset) {
        return anchors.first.scrollOffset;
      }
      if (charOffset >= anchors.last.charOffset) {
        return anchors.last.scrollOffset;
      }
      for (var i = 0; i < anchors.length - 1; i++) {
        final a = anchors[i];
        final b = anchors[i + 1];
        if (charOffset >= a.charOffset && charOffset <= b.charOffset) {
          final span = b.charOffset - a.charOffset;
          if (span <= 0) return a.scrollOffset;
          final t = (charOffset - a.charOffset) / span;
          return a.scrollOffset + t * (b.scrollOffset - a.scrollOffset);
        }
      }
    }

    // Virtualized: block-based fallback using display-content offsets.
    if (_useVirtualized && _blocks.isNotEmpty) {
      final bi = _blockIndexForCharOffset(charOffset);
      if (bi == null) return null;
      final block = _blocks[bi];
      final blockLen = (block.endOffset - block.startOffset).clamp(1, 1 << 30);
      final t = ((charOffset - block.startOffset) / blockLen).clamp(0.0, 1.0);
      final h = _heightCache.heightOf(bi);
      return _heightCache.offsetOf(bi) + t * h + 16.0;
    }
    return null;
  }

  /// Inverse of [scrollOffsetForCharOffset]: map scroll pixels to a character
  /// offset using piecewise linear interpolation between heading anchors, then
  /// block height cache.
  int? charOffsetFromScroll(
    double scrollOffset,
    List<HeadingItem> headings,
    int totalLength,
  ) {
    final anchors = _headingAnchors(headings);
    if (anchors.isNotEmpty) {
      if (scrollOffset <= anchors.first.scrollOffset) {
        final first = anchors.first;
        if (first.scrollOffset <= 0) {
          return first.charOffset.clamp(0, totalLength);
        }
        final t = (scrollOffset / first.scrollOffset).clamp(0.0, 1.0);
        return (t * first.charOffset).round().clamp(0, totalLength);
      }

      if (scrollOffset >= anchors.last.scrollOffset) {
        final last = anchors.last;
        final controller = widget.scrollController;
        final maxExtent = (controller != null && controller.hasClients)
            ? controller.position.maxScrollExtent
            : last.scrollOffset;
        if (maxExtent <= last.scrollOffset) {
          return last.charOffset.clamp(0, totalLength);
        }
        final t = ((scrollOffset - last.scrollOffset) /
                (maxExtent - last.scrollOffset))
            .clamp(0.0, 1.0);
        final remaining = totalLength - last.charOffset;
        return (last.charOffset + t * remaining).round().clamp(0, totalLength);
      }

      for (var i = 0; i < anchors.length - 1; i++) {
        final a = anchors[i];
        final b = anchors[i + 1];
        if (scrollOffset >= a.scrollOffset && scrollOffset <= b.scrollOffset) {
          final span = b.scrollOffset - a.scrollOffset;
          if (span <= 0) return a.charOffset.clamp(0, totalLength);
          final t = (scrollOffset - a.scrollOffset) / span;
          return (a.charOffset + t * (b.charOffset - a.charOffset))
              .round()
              .clamp(0, totalLength);
        }
      }
    }

    if (_useVirtualized && _blocks.isNotEmpty) {
      final contentOffset = (scrollOffset - 16.0).clamp(0.0, double.infinity);
      final bi = _heightCache.indexAt(contentOffset);
      final block = _blocks[bi];
      final blockStartY = _heightCache.offsetOf(bi);
      final h = _heightCache.heightOf(bi).clamp(1.0, double.infinity);
      final t = ((contentOffset - blockStartY) / h).clamp(0.0, 1.0);
      final blockLen = (block.endOffset - block.startOffset).clamp(1, 1 << 30);
      // Map into original file offsets when possible via heading table; else use
      // display offsets (same as file when search is inactive).
      final char = (block.startOffset + t * blockLen).round();
      return char.clamp(0, totalLength);
    }
    return null;
  }

  /// Index of the last heading whose offset is at or below the current scroll
  /// position. Uses height cache / sparse key offsets — no GlobalKey required.
  int? activeHeadingIndex(double scrollOffset) {
    if (_headingKeys.isEmpty && _headingToBlock.isEmpty) return null;
    _ensureOffsetCache();

    // Virtualized: prefer height-cache path (nearest preceding heading block).
    if (_useVirtualized && _blocks.isNotEmpty) {
      final contentOffset = (scrollOffset - 16.0).clamp(0.0, double.infinity);
      final bi = _heightCache.indexAt(contentOffset);
      for (var i = bi; i >= 0; i--) {
        final hi = _blocks[i].headingIndex;
        if (hi != null) return hi;
      }
    }

    // Monolith (and sparse virtualized keys): scan mounted / estimated offsets.
    if (_cachedHeadingOffsets.isEmpty) return null;
    const epsilon = 8.0;
    int? result;
    final limit = _cachedHeadingOffsets.length;
    for (var i = 0; i < limit; i++) {
      final offset = _cachedHeadingOffsets[i];
      if (offset == null) continue;
      if (offset <= scrollOffset + epsilon) {
        result = i;
      } else if (result != null) {
        break;
      }
    }
    return result;
  }

  /// True when first layout / any heading key is mounted — so resume does not
  /// hang waiting for all keys. Monolith: any mounted heading or maxExtent > 0.
  bool get hasMountedHeadingKeys {
    if (_useVirtualized) {
      if (_firstLayoutSeen && _blocks.isNotEmpty) return true;
      final controller = widget.scrollController;
      if (controller != null &&
          controller.hasClients &&
          controller.position.maxScrollExtent > 0 &&
          _blocks.isNotEmpty) {
        return true;
      }
    } else {
      final controller = widget.scrollController;
      if (_firstLayoutSeen) return true;
      if (controller != null &&
          controller.hasClients &&
          controller.position.maxScrollExtent > 0) {
        return true;
      }
    }
    for (final key in _headingKeys) {
      if (key.currentContext != null) return true;
    }
    return false;
  }

  int? _blockIndexForCharOffset(int charOffset) {
    if (_blocks.isEmpty) return null;
    // Binary search by startOffset.
    var lo = 0;
    var hi = _blocks.length - 1;
    if (charOffset < _blocks.first.startOffset) return 0;
    if (charOffset >= _blocks.last.endOffset) return _blocks.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final b = _blocks[mid];
      if (charOffset < b.startOffset) {
        hi = mid - 1;
      } else if (charOffset >= b.endOffset) {
        lo = mid + 1;
      } else {
        return mid;
      }
    }
    return lo.clamp(0, _blocks.length - 1);
  }

  List<_HeadingAnchor> _headingAnchors(List<HeadingItem> headings) {
    _ensureOffsetCache();
    final count = _headingKeys.length < headings.length
        ? _headingKeys.length
        : headings.length;
    final anchors = <_HeadingAnchor>[];
    for (var i = 0; i < count; i++) {
      double? scroll = i < _cachedHeadingOffsets.length
          ? _cachedHeadingOffsets[i]
          : null;
      if (scroll == null && _useVirtualized) {
        final bi = _headingToBlock[i];
        if (bi != null) {
          scroll = _heightCache.offsetOf(bi) + 16.0;
        }
      }
      if (scroll == null) continue;
      anchors.add(_HeadingAnchor(
        charOffset: headings[i].offset,
        scrollOffset: scroll,
      ));
    }
    return anchors;
  }

  double? _revealOffset(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final renderObject = ctx.findRenderObject();
    if (renderObject == null) return null;
    final viewport = RenderAbstractViewport.maybeOf(renderObject);
    if (viewport == null) return null;
    try {
      return viewport.getOffsetToReveal(renderObject, 0.0).offset;
    } catch (_) {
      return null;
    }
  }

  void _onBlockHeight(int index, double height) {
    if (_heightCache.report(index, height)) {
      // Measured height changed estimates; refresh sparse heading cache.
      _scheduleOffsetCacheRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    _buildPass += 1;
    final buildSw = Stopwatch()..start();
    final textAlign = widget.textAlignment == ReadingTextAlign.justified
        ? TextAlign.justify
        : TextAlign.left;

    final parentStyle = DefaultTextStyle.of(context).style;
    final resolvedColor = widget.textColor ?? parentStyle.color;
    final effectiveFontSize = widget.fontSize * widget.fontScale;
    // Strip color to prevent MdWidget re-parsing on every animation frame
    // during AnimatedDefaultTextStyle transitions. Color is inherited via
    // DefaultTextStyle and heading theme overrides.
    //
    // Keep scaled fontSize/height on config.style so WidgetSpan builders
    // (inline `code`, fenced blocks) receive the display scale. Outer
    // DefaultTextStyle alone is not enough: highlightBuilder bakes an
    // absolute size from config.style, and MdWidget only regenerates spans
    // when config.isSame is false.
    //
    // Monospace theme also forces body fontFamily so spans match source-like
    // chrome; other themes leave family unset (Material default).
    final useMonospaceBody = widget.markdownTheme == MarkdownTheme.monospace;
    final stableStyle = parentStyle.copyWith(
      color: null,
      fontSize: effectiveFontSize,
      height: widget.lineHeight,
      fontFamily: useMonospaceBody ? 'monospace' : null,
    );

    // Build a GptMarkdownTheme that injects the reader's text color
    // into heading styles so that HTag components inherit it regardless
    // of how DefaultTextStyle propagates through WidgetSpan children.
    //
    // GitHub / Blue Topaz / Monospace modes use their own tokens for
    // headings/links/HR; standard mode keeps Material typography scaled to
    // the display body size so pinch / preference font scale affects
    // headings the same as body text.
    final resolvedTextColor =
        resolvedColor ?? Theme.of(context).colorScheme.onSurface;
    late final GptMarkdownThemeData gptTheme;
    late final HighlightBuilder inlineCodeBuilder;
    late final CodeBlockBuilder fencedCodeBuilder;
    late final TableBuilder? themedTableBuilder;

    switch (widget.markdownTheme) {
      case MarkdownTheme.github:
        gptTheme = buildGithubGptMarkdownTheme(
          context: context,
          textColor: resolvedTextColor,
          effectiveFontSize: effectiveFontSize,
        );
        inlineCodeBuilder = githubInlineCode;
        fencedCodeBuilder = githubCodeBlock;
        themedTableBuilder = githubTableBuilder;
      case MarkdownTheme.blueTopaz:
        gptTheme = buildBlueTopazGptMarkdownTheme(
          context: context,
          textColor: resolvedTextColor,
          effectiveFontSize: effectiveFontSize,
        );
        inlineCodeBuilder = blueTopazInlineCode;
        fencedCodeBuilder = blueTopazCodeBlock;
        themedTableBuilder = blueTopazTableBuilder;
      case MarkdownTheme.monospace:
        gptTheme = buildMonospaceGptMarkdownTheme(
          context: context,
          textColor: resolvedTextColor,
          effectiveFontSize: effectiveFontSize,
        );
        inlineCodeBuilder = monospaceInlineCode;
        fencedCodeBuilder = monospaceCodeBlock;
        themedTableBuilder = monospaceTableBuilder;
      case MarkdownTheme.standard:
        final baseTheme = GptMarkdownThemeData(
          brightness: Theme.of(context).brightness,
        );
        const themeBodySize = 16.0;
        final headingScale = effectiveFontSize / themeBodySize;
        TextStyle? scaledHeading(TextStyle? style) {
          if (style == null) return null;
          final baseSize = style.fontSize ?? themeBodySize;
          return style.copyWith(
            color: resolvedColor,
            fontSize: baseSize * headingScale,
          );
        }

        gptTheme = baseTheme.copyWith(
          h1: scaledHeading(baseTheme.h1),
          h2: scaledHeading(baseTheme.h2),
          h3: scaledHeading(baseTheme.h3),
          h4: scaledHeading(baseTheme.h4),
          h5: scaledHeading(baseTheme.h5),
          h6: scaledHeading(baseTheme.h6),
        );
        // Always use our code builders so search can paint inside
        // fenced/inline code.
        inlineCodeBuilder = defaultInlineCode;
        fencedCodeBuilder = defaultCodeBlock;
        themedTableBuilder = null;
    }

    final inlineComponents = buildAnchoredInlineComponents(_matchKeys);

    final Widget scrollChild;
    if (_useVirtualized) {
      // Large docs: virtualized ListView of per-block GptMarkdown.
      scrollChild = KeyedSubtree(
        key: _markdownBodyKey,
        child: GptMarkdownTheme(
          gptThemeData: gptTheme,
          child: DefaultTextStyle(
            style: TextStyle(
              fontSize: effectiveFontSize,
              height: widget.lineHeight,
              fontFamily: useMonospaceBody ? 'monospace' : null,
            ),
            textAlign: textAlign,
            child: ListView.custom(
              controller: widget.scrollController,
              padding: const EdgeInsets.all(16),
              // Variable-height items — do not force itemExtent (would clip).
              // estimateMaxScrollOffset keeps jumps usable before full layout.
              childrenDelegate: _MarkdownBlockChildDelegate(
                blockCount: _blocks.length,
                heightCache: _heightCache,
                builder: (context, i) {
                  final block = _blocks[i];
                  final topGap = block.hasPrecedingParagraphBreak
                      ? MarkdownView.paragraphBreakGap(effectiveFontSize)
                      : 0.0;
                  // Padding is inside _MeasuredBlock so measured heights
                  // (TOC jumps / prefix sums) include the paragraph gap.
                  return _MeasuredBlock(
                    onHeight: (h) => _onBlockHeight(i, h),
                    child: Padding(
                      padding: EdgeInsets.only(top: topGap),
                      child: GptMarkdown(
                        block.text,
                        style: stableStyle,
                        onLinkTap: widget.onLinkTap,
                        selectable: false,
                        highlightBuilder: inlineCodeBuilder,
                        codeBuilder: fencedCodeBuilder,
                        tableBuilder: themedTableBuilder,
                        components: buildAnchoredComponentsForBlock(
                          headingKeys: _headingKeys,
                          headingIndex: block.headingIndex,
                        ),
                        inlineComponents: inlineComponents,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
    } else {
      // Small docs: single GptMarkdown in a scroll view (simpler tree, all keys live).
      scrollChild = KeyedSubtree(
        key: _markdownBodyKey,
        child: GptMarkdownTheme(
          gptThemeData: gptTheme,
          child: DefaultTextStyle(
            style: TextStyle(
              fontSize: effectiveFontSize,
              height: widget.lineHeight,
              fontFamily: useMonospaceBody ? 'monospace' : null,
            ),
            textAlign: textAlign,
            child: SingleChildScrollView(
              controller: widget.scrollController,
              padding: const EdgeInsets.all(16),
              child: GptMarkdown(
                widget.content,
                style: stableStyle,
                onLinkTap: widget.onLinkTap,
                selectable: false,
                highlightBuilder: inlineCodeBuilder,
                codeBuilder: fencedCodeBuilder,
                tableBuilder: themedTableBuilder,
                components: buildAnchoredComponents(_headingKeys),
                inlineComponents: inlineComponents,
              ),
            ),
          ),
        ),
      );
    }

    Widget result;
    if (!widget.isWordWrapEnabled) {
      result = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 800,
          child: scrollChild,
        ),
      );
    } else {
      result = scrollChild;
    }

    buildSw.stop();
    // Only spam on first few builds / open probe window.
    if (_openProbePending || _buildPass <= 3) {
      debugPrint(
        '[bench-md] build pass=$_buildPass '
        'buildMethodMs=${buildSw.elapsedMilliseconds} '
        'contentLen=${widget.content.length} '
        'sourceBytes=${widget.sourceByteLength ?? -1} '
        'virtualized=$_useVirtualized '
        'blocks=${_blocks.length}',
      );
      if (_openProbePending && _openProbeFrame == 0) {
        _scheduleOpenProbeFrames();
      }
    }

    return SearchHighlightScope(
      query: widget.searchQuery,
      child: ZoomableArea(
        scale: widget.fontScale,
        onScaleChanged: widget.onFontScaleChanged,
        child: result,
      ),
    );
  }
}

/// Reports laid-out height of a list item once per layout change.
class _MeasuredBlock extends SingleChildRenderObjectWidget {
  final ValueChanged<double> onHeight;

  const _MeasuredBlock({
    required this.onHeight,
    required Widget child,
  }) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderMeasuredBlock(onHeight: onHeight);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderMeasuredBlock renderObject,
  ) {
    renderObject.onHeight = onHeight;
  }
}

class _RenderMeasuredBlock extends RenderProxyBox {
  ValueChanged<double> onHeight;
  double? _lastReported;

  _RenderMeasuredBlock({required this.onHeight});

  @override
  void performLayout() {
    super.performLayout();
    final h = size.height;
    if (_lastReported == null || (h - _lastReported!).abs() > 0.5) {
      _lastReported = h;
      // Defer callback out of layout.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onHeight(h);
      });
    }
  }
}

/// Estimated + measured block heights with prefix sums for jump mapping.
class _BlockHeightCache {
  final List<MarkdownBlock> _blocks;
  late List<double> _heights;
  late List<bool> _measured;
  late List<double> _prefix; // prefix[i] = sum of heights[0..i-1]
  double _fontSize;
  double _lineHeight;
  double _scale = 1.0;
  int _measuredCount = 0;
  double _measuredSum = 0;
  double _estimateSumForMeasured = 0;
  bool _prefixDirty = false;
  bool _rebuildScheduled = false;
  static const double _paddingFudge = 2.0;

  // Visible text for wrap estimates: drop URL destinations so
  // `1. [title](https://…)` does not look like 3–4 soft-wrapped lines.
  static final RegExp _mdLink = RegExp(r'\[([^\]]*)\]\([^)]*\)');
  static final RegExp _bareUrl = RegExp(r'https?://\S+');

  _BlockHeightCache({
    required List<MarkdownBlock> blocks,
    required double fontSize,
    required double lineHeight,
  })  : _blocks = blocks,
        _fontSize = fontSize,
        _lineHeight = lineHeight {
    _heights = List<double>.generate(
      blocks.length,
      (i) => _estimate(blocks[i]),
    );
    _measured = List<bool>.filled(blocks.length, false);
    _rebuildPrefix();
  }

  void invalidateEstimates({
    required double fontSize,
    required double lineHeight,
  }) {
    _fontSize = fontSize;
    _lineHeight = lineHeight;
    _scale = 1.0;
    _measuredCount = 0;
    _measuredSum = 0;
    _estimateSumForMeasured = 0;
    for (var i = 0; i < _blocks.length; i++) {
      _heights[i] = _estimate(_blocks[i]);
      _measured[i] = false;
    }
    _rebuildPrefix();
  }

  /// Returns true if the height actually changed.
  bool report(int index, double height) {
    if (index < 0 || index >= _heights.length) return false;
    if ((_heights[index] - height).abs() < 0.5 && _measured[index]) {
      return false;
    }

    if (!_measured[index]) {
      final baseEstimate = _estimate(_blocks[index]);
      _measuredCount += 1;
      _measuredSum += height;
      _estimateSumForMeasured += baseEstimate;
      _measured[index] = true;
    }

    _heights[index] = height;
    _maybeRecalibrateUnmeasured();
    _schedulePrefixRebuild();
    return true;
  }

  double heightOf(int index) {
    if (index < 0 || index >= _heights.length) return 0;
    return _heights[index];
  }

  /// Sum of all block heights (content only, no ListView padding).
  double get totalExtent {
    _ensurePrefix();
    if (_prefix.isEmpty) return 0;
    return _prefix.last;
  }

  /// Content Y of the top of [index] (without ListView padding).
  double offsetOf(int index) {
    _ensurePrefix();
    if (_prefix.isEmpty) return 0;
    if (index <= 0) return 0;
    if (index >= _prefix.length) return _prefix.last;
    return _prefix[index];
  }

  /// Block index whose content range covers [contentOffset].
  int indexAt(double contentOffset) {
    _ensurePrefix();
    if (_heights.isEmpty) return 0;
    if (contentOffset <= 0) return 0;
    // Binary search prefix.
    var lo = 0;
    var hi = _heights.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_prefix[mid] <= contentOffset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo.clamp(0, _heights.length - 1);
  }

  void _maybeRecalibrateUnmeasured() {
    // After a few real layouts, pull the unmeasured tail toward reality so
    // estimateMaxScrollOffset / TOC jumps are not 2–3× too large.
    if (_measuredCount < 4 || _estimateSumForMeasured <= 0) return;
    final next = (_measuredSum / _estimateSumForMeasured).clamp(0.4, 1.5);
    if ((next - _scale).abs() < 0.03) return;
    _scale = next;
    for (var i = 0; i < _heights.length; i++) {
      if (_measured[i]) continue;
      _heights[i] = _estimate(_blocks[i]) * _scale;
    }
  }

  double _estimate(MarkdownBlock block) {
    final text = block.text;
    final breakGap = block.hasPrecedingParagraphBreak
        ? MarkdownView.paragraphBreakGap(_fontSize)
        : 0.0;

    if (text.isEmpty) {
      return _fontSize * _lineHeight + _paddingFudge + breakGap;
    }
    // Blocks often include a trailing \n from the splitter; ignore edge
    // whitespace when classifying single-line structured items.
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return _fontSize * _lineHeight + _paddingFudge + breakGap;
    }

    // Single-line structured blocks (dominant on v2ex sample) almost always
    // render as one list-row / heading row. Measured avg ~1× line height.
    final isListOrHeading =
        RegExp(r'^(\d+\.\s|[-*]\s|#{1,6}\s)').hasMatch(trimmed);
    if (isListOrHeading && !trimmed.contains('\n')) {
      return _fontSize * _lineHeight + _paddingFudge + breakGap;
    }

    // Approximate *rendered* visible text length (link labels, not URLs).
    final visible = trimmed
        .replaceAllMapped(_mdLink, (m) => m.group(1) ?? '')
        .replaceAll(_bareUrl, '');

    // Soft-wrap estimate for phone width. Chinese is wider (~22 glyphs/line).
    var softLines = 0;
    for (final line in visible.split('\n')) {
      final len = line.trim().length;
      if (len <= 0) {
        softLines += 1;
      } else {
        softLines += (len / 28).ceil().clamp(1, 8);
      }
    }
    final lineCount = softLines < 1 ? 1 : softLines;
    return lineCount * _fontSize * _lineHeight + _paddingFudge + breakGap;
  }

  void _schedulePrefixRebuild() {
    _prefixDirty = true;
    if (_rebuildScheduled) return;
    _rebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rebuildScheduled = false;
      if (_prefixDirty) _rebuildPrefix();
    });
  }

  void _ensurePrefix() {
    if (_prefixDirty) _rebuildPrefix();
  }

  void _rebuildPrefix() {
    _prefix = List<double>.filled(_heights.length + 1, 0);
    for (var i = 0; i < _heights.length; i++) {
      _prefix[i + 1] = _prefix[i] + _heights[i];
    }
    _prefixDirty = false;
  }
}

/// Builder delegate that reports a full-document estimated max scroll offset
/// so [ScrollController.jumpTo] can reach late headings before they mount.
class _MarkdownBlockChildDelegate extends SliverChildBuilderDelegate {
  _MarkdownBlockChildDelegate({
    required int blockCount,
    required this.heightCache,
    required NullableIndexedWidgetBuilder builder,
  }) : super(
          builder,
          childCount: blockCount,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
        );

  final _BlockHeightCache heightCache;

  @override
  double? estimateMaxScrollOffset(
    int firstIndex,
    int lastIndex,
    double leadingScrollOffset,
    double trailingScrollOffset,
  ) {
    // Prefer the live height-cache total so unbuilt tail items contribute and
    // measured updates are reflected without requiring a full rebuild.
    final total = heightCache.totalExtent;
    if (total > 0) return total;
    return super.estimateMaxScrollOffset(
      firstIndex,
      lastIndex,
      leadingScrollOffset,
      trailingScrollOffset,
    );
  }
}

class _TreeStats {
  final int elements;
  final int stateful;
  final int renderBoxes;
  final int maxDepth;
  final int walkMs;
  final bool truncated;

  const _TreeStats({
    required this.elements,
    required this.stateful,
    required this.renderBoxes,
    required this.maxDepth,
    required this.walkMs,
    required this.truncated,
  });
}

class _HeadingAnchor {
  final int charOffset;
  final double scrollOffset;

  const _HeadingAnchor({
    required this.charOffset,
    required this.scrollOffset,
  });
}

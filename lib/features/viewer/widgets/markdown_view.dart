// lib/features/viewer/widgets/markdown_view.dart
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:markread/third_party/gpt_markdown/gpt_markdown.dart';
import 'package:markread/third_party/gpt_markdown/theme.dart';
import '../../../core/models/user_preferences.dart';
import '../providers/viewer_provider.dart';
import 'markdown_anchors.dart';
import 'zoomable_area.dart';

class MarkdownView extends StatefulWidget {
  final String content;
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

  const MarkdownView({
    super.key,
    required this.content,
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
  });

  @override
  State<MarkdownView> createState() => MarkdownViewState();
}

class MarkdownViewState extends State<MarkdownView> {
  late List<GlobalKey> _headingKeys;
  late List<GlobalKey> _matchKeys;

  /// Cached reveal offsets for headings. Avoids calling
  /// [RenderAbstractViewport.getOffsetToReveal] on every scroll tick.
  List<double?> _cachedHeadingOffsets = const [];
  bool _cacheRefreshScheduled = false;

  @override
  void initState() {
    super.initState();
    _headingKeys = _createKeys(widget.headingCount);
    _matchKeys = _createKeys(widget.searchMatchCount);
    _scheduleOffsetCacheRefresh();
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

    final layoutAffecting = oldWidget.content != widget.content ||
        oldWidget.fontScale != widget.fontScale ||
        oldWidget.fontSize != widget.fontSize ||
        oldWidget.lineHeight != widget.lineHeight ||
        oldWidget.isWordWrapEnabled != widget.isWordWrapEnabled ||
        oldWidget.textAlignment != widget.textAlignment ||
        oldWidget.headingCount != widget.headingCount;

    if (layoutAffecting || keysChanged) {
      _cachedHeadingOffsets = const [];
      _scheduleOffsetCacheRefresh();
    }
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
      // First frame after content swap can still have null contexts; retry once.
      if (_headingKeys.isNotEmpty &&
          _cachedHeadingOffsets.every((o) => o == null)) {
        _scheduleOffsetCacheRefresh();
      }
    });
  }

  void _refreshOffsetCache() {
    if (_headingKeys.isEmpty) {
      _cachedHeadingOffsets = const [];
      return;
    }
    _cachedHeadingOffsets = List<double?>.generate(
      _headingKeys.length,
      (i) => _revealOffset(_headingKeys[i]),
    );
  }

  /// Ensure cache is populated before mapping. Cheap if already warm.
  void _ensureOffsetCache() {
    if (_headingKeys.isEmpty) return;
    if (_cachedHeadingOffsets.length != _headingKeys.length ||
        _cachedHeadingOffsets.every((o) => o == null)) {
      _refreshOffsetCache();
    }
  }

  /// Scroll so the heading at [index] is at the top of the viewport.
  Future<bool> ensureHeadingVisible(int index) async {
    return _ensureKeyVisible(_headingKeys, index);
  }

  /// Scroll so the search match at [index] is at the top of the viewport.
  Future<bool> ensureMatchVisible(int index) async {
    return _ensureKeyVisible(_matchKeys, index);
  }

  Future<bool> _ensureKeyVisible(List<GlobalKey> keys, int index) async {
    if (index < 0 || index >= keys.length) return false;
    final ctx = keys[index].currentContext;
    if (ctx == null) return false;
    await Scrollable.ensureVisible(
      ctx,
      alignment: 0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    // Layout may shift slightly after ensureVisible; refresh cache.
    _scheduleOffsetCacheRefresh();
    return true;
  }

  /// Map a character offset to a scroll pixel position via piecewise linear
  /// interpolation between adjacent heading anchors.
  ///
  /// Returns null when keys are unavailable (caller should use ratio).
  double? scrollOffsetForCharOffset(
    int charOffset,
    List<HeadingItem> headings,
  ) {
    final anchors = _headingAnchors(headings);
    if (anchors.isEmpty) return null;

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
    return null;
  }

  /// Inverse of [scrollOffsetForCharOffset]: map scroll pixels to a character
  /// offset using piecewise linear interpolation between heading anchors.
  ///
  /// Returns null when keys are unavailable (caller should use ratio).
  int? charOffsetFromScroll(
    double scrollOffset,
    List<HeadingItem> headings,
    int totalLength,
  ) {
    final anchors = _headingAnchors(headings);
    if (anchors.isEmpty) return null;

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
    return null;
  }

  /// Index of the last heading whose cached reveal offset is at or below the
  /// current scroll position. Uses the offset cache only — no layout queries.
  /// Returns null if the cache is cold.
  int? activeHeadingIndex(double scrollOffset) {
    if (_headingKeys.isEmpty) return null;
    _ensureOffsetCache();
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
        // Offsets are monotonic for laid-out headings; stop early once past.
        break;
      }
    }
    return result;
  }

  /// True when at least one heading key has a mounted context.
  bool get hasMountedHeadingKeys {
    for (final key in _headingKeys) {
      if (key.currentContext != null) return true;
    }
    return false;
  }

  List<_HeadingAnchor> _headingAnchors(List<HeadingItem> headings) {
    _ensureOffsetCache();
    final count = _headingKeys.length < headings.length
        ? _headingKeys.length
        : headings.length;
    final anchors = <_HeadingAnchor>[];
    for (var i = 0; i < count; i++) {
      final scroll = i < _cachedHeadingOffsets.length
          ? _cachedHeadingOffsets[i]
          : null;
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

  @override
  Widget build(BuildContext context) {
    final textAlign = widget.textAlignment == ReadingTextAlign.justified
        ? TextAlign.justify
        : TextAlign.left;

    final parentStyle = DefaultTextStyle.of(context).style;
    final resolvedColor = widget.textColor ?? parentStyle.color;
    // Strip color to prevent MdWidget re-parsing on every animation frame
    // during AnimatedDefaultTextStyle transitions. Color is inherited via
    // DefaultTextStyle and heading theme overrides.
    final stableStyle = parentStyle.copyWith(color: null);

    // Build a GptMarkdownTheme that injects the reader's text color
    // into heading styles so that HTag components inherit it regardless
    // of how DefaultTextStyle propagates through WidgetSpan children.
    final baseTheme = GptMarkdownThemeData(
      brightness: Theme.of(context).brightness,
    );
    final gptTheme = baseTheme.copyWith(
      h1: baseTheme.h1?.copyWith(color: resolvedColor),
      h2: baseTheme.h2?.copyWith(color: resolvedColor),
      h3: baseTheme.h3?.copyWith(color: resolvedColor),
      h4: baseTheme.h4?.copyWith(color: resolvedColor),
      h5: baseTheme.h5?.copyWith(color: resolvedColor),
      h6: baseTheme.h6?.copyWith(color: resolvedColor),
    );

    final effectiveFontSize = widget.fontSize * widget.fontScale;

    // Fresh component instances each build so AnchoredHTag's parse counter
    // starts at 0. Allocation is cheap; the expensive work was layout queries
    // during scroll and parent setState rebuilding this tree.
    final components = buildAnchoredComponents(_headingKeys);
    final inlineComponents = buildAnchoredInlineComponents(_matchKeys);

    final textWidget = DefaultTextStyle(
      style: TextStyle(
        fontSize: effectiveFontSize,
        height: widget.lineHeight,
      ),
      textAlign: textAlign,
      child: SingleChildScrollView(
        controller: widget.scrollController,
        padding: const EdgeInsets.all(16),
        child: RepaintBoundary(
          child: GptMarkdownTheme(
            gptThemeData: gptTheme,
            child: GptMarkdown(
              widget.content,
              style: stableStyle,
              onLinkTap: widget.onLinkTap,
              selectable: false,
              components: components,
              inlineComponents: inlineComponents,
            ),
          ),
        ),
      ),
    );

    Widget result;
    if (!widget.isWordWrapEnabled) {
      result = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 800,
          child: textWidget,
        ),
      );
    } else {
      result = textWidget;
    }

    return ZoomableArea(
      scale: widget.fontScale,
      onScaleChanged: widget.onFontScaleChanged,
      child: result,
    );
  }
}

class _HeadingAnchor {
  final int charOffset;
  final double scrollOffset;

  const _HeadingAnchor({
    required this.charOffset,
    required this.scrollOffset,
  });
}

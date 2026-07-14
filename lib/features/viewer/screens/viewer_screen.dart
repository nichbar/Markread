// lib/features/viewer/screens/viewer_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/user_preferences.dart';
import '../../../core/providers/preferences_provider.dart';
import '../../../core/providers/reading_progress_provider.dart';
import '../../../core/widgets/app_layout_body.dart';
import '../providers/viewer_provider.dart';
import '../widgets/markdown_view.dart';
import '../widgets/reading_progress_badge.dart';
import '../widgets/source_code_view.dart';
import '../widgets/reader_theme.dart';
import '../widgets/search_bar.dart';
import '../widgets/toc_sheet.dart';

class ViewerScreen extends ConsumerStatefulWidget {
  final String fileName;

  const ViewerScreen({super.key, required this.fileName});

  @override
  ConsumerState<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends ConsumerState<ViewerScreen>
    with WidgetsBindingObserver {
  bool _isReadingSurfaceDark = false;
  bool _isWordWrapEnabled = true;
  bool _isCodeBlockWrapEnabled = true;
  double _fontScale = 1.0;
  int _activeHeadingIndex = -1;
  late final ScrollController _scrollController;
  final GlobalKey<MarkdownViewState> _markdownViewKey =
      GlobalKey<MarkdownViewState>();
  DateTime _lastHeadingUpdate = DateTime.now();

  Timer? _progressSaveDebounce;
  int? _lastSavedCharOffset;
  bool _didAttemptResume = false;
  bool _isRestoring = false;

  // Badge state is isolated so scroll updates do not rebuild MarkdownView.
  final ValueNotifier<_ProgressBadgeState> _progressBadge =
      ValueNotifier(const _ProgressBadgeState(percent: 0, visible: false));
  // Section subtitle is isolated the same way — setState on heading changes
  // was rebuilding MarkdownView and causing scroll jank.
  final ValueNotifier<String> _sectionTitle = ValueNotifier('');
  Timer? _readingProgressHideTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController = ScrollController();
    _scrollController.addListener(_onScrollTick);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateStatusBarStyle();
      // Handle already-loaded state (listen does not fire for current value).
      final state = ref.read(viewerProvider).value;
      if (state != null) {
        unawaited(_tryResumeReadingProgress(state));
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _progressSaveDebounce?.cancel();
      unawaited(_flushReadingProgress());
    }
  }

  void _onScrollTick() {
    // Throttle heading updates to avoid per-frame work during fast flings.
    // Updating every ~100ms is imperceptible and prevents frame drops
    // when scrolling rapidly to boundaries and reversing direction.
    final now = DateTime.now();
    if (now.difference(_lastHeadingUpdate).inMilliseconds >= 100) {
      _lastHeadingUpdate = now;
      _updateActiveHeading();
    }

    if (_isRestoring) return;
    _progressSaveDebounce?.cancel();
    _progressSaveDebounce = Timer(const Duration(milliseconds: 500), () {
      unawaited(_flushReadingProgress());
    });

    _updateReadingProgressBadge();
  }

  int _scrollProgressPercent() {
    if (!_scrollController.hasClients) return 0;
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent <= 0) return 0;
    final ratio = (_scrollController.offset / maxExtent).clamp(0.0, 1.0);
    return (ratio * 100).round();
  }

  void _updateReadingProgressBadge() {
    if (!_scrollController.hasClients) return;
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent <= 0) return;

    final percent = _scrollProgressPercent();
    final current = _progressBadge.value;
    if (!current.visible || percent != current.percent) {
      _progressBadge.value =
          _ProgressBadgeState(percent: percent, visible: true);
    }

    _readingProgressHideTimer?.cancel();
    _readingProgressHideTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      final latest = _progressBadge.value;
      if (latest.visible) {
        _progressBadge.value =
            _ProgressBadgeState(percent: latest.percent, visible: false);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _progressSaveDebounce?.cancel();
    _readingProgressHideTimer?.cancel();
    // Capture and flush synchronously before controller/ref teardown.
    _flushReadingProgressSync();
    _scrollController.removeListener(_onScrollTick);
    _scrollController.dispose();
    _progressBadge.dispose();
    _sectionTitle.dispose();
    super.dispose();
  }

  /// Synchronous capture of scroll position + fire-and-forget save.
  /// Safe to call from dispose (reads ref/controller before they are torn down).
  void _flushReadingProgressSync() {
    if (_isRestoring) return;
    if (!_scrollController.hasClients) return;

    try {
      final state = ref.read(viewerProvider).value;
      final service = ref.read(readingProgressProvider);
      if (state == null || state.status != ViewerStatus.loaded) return;
      if (state.fileByteLength <= 0 || state.fileContent.isEmpty) return;

      final charOffset = _charOffsetFromScroll();
      if (charOffset == null) return;

      if (_lastSavedCharOffset != null &&
          charOffset == _lastSavedCharOffset) {
        return;
      }
      _lastSavedCharOffset = charOffset;
      unawaited(service.save(
        fileName: state.fileName,
        byteLength: state.fileByteLength,
        charOffset: charOffset,
      ));
    } catch (_) {
      // Provider may already be unavailable during teardown.
    }
  }

  int? _charOffsetFromScroll() {
    final state = ref.read(viewerProvider).value;
    if (state == null || state.status != ViewerStatus.loaded) return null;
    if (state.fileByteLength <= 0 || state.fileContent.isEmpty) return null;
    if (!_scrollController.hasClients) return null;

    final maxExtent = _scrollController.position.maxScrollExtent;
    final totalLength = state.fileContent.length;
    if (maxExtent <= 0 || totalLength <= 0) return 0;

    // Prefer layout-accurate mapping via heading anchors when available.
    if (_canUseMarkdownAnchors(state)) {
      final mapped = _markdownViewKey.currentState?.charOffsetFromScroll(
        _scrollController.offset,
        state.headings,
        totalLength,
      );
      if (mapped != null) return mapped;
    }

    final ratio =
        (_scrollController.offset / maxExtent).clamp(0.0, 1.0);
    return (ratio * totalLength).round().clamp(0, totalLength);
  }

  bool _canUseMarkdownAnchors(ViewerState state) {
    return state.viewMode == ViewMode.rendered &&
        !state.isSourceCode &&
        !state.isBinary;
  }

  Future<void> _flushReadingProgress() async {
    if (_isRestoring) return;
    final state = ref.read(viewerProvider).value;
    if (state == null || state.status != ViewerStatus.loaded) return;
    if (state.fileByteLength <= 0 || state.fileContent.isEmpty) return;

    final charOffset = _charOffsetFromScroll();
    if (charOffset == null) return;
    if (_lastSavedCharOffset != null &&
        charOffset == _lastSavedCharOffset) {
      return;
    }

    _lastSavedCharOffset = charOffset;
    await ref.read(readingProgressProvider).save(
          fileName: state.fileName,
          byteLength: state.fileByteLength,
          charOffset: charOffset,
        );
  }

  void _scrollToOffset(int offset, int totalLength) {
    if (!_scrollController.hasClients) return;
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent <= 0 || totalLength <= 0) return;
    final target = (offset / totalLength) * maxExtent;
    _scrollController.animateTo(
      target.clamp(0.0, maxExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _jumpToCharOffset(int charOffset, int totalLength) {
    if (!_scrollController.hasClients) return;
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent <= 0 || totalLength <= 0) return;

    final state = ref.read(viewerProvider).value;
    double? target;
    if (state != null && _canUseMarkdownAnchors(state)) {
      target = _markdownViewKey.currentState?.scrollOffsetForCharOffset(
        charOffset,
        state.headings,
      );
    }
    target ??= (charOffset / totalLength) * maxExtent;
    _scrollController.jumpTo(target.clamp(0.0, maxExtent));
  }

  Future<void> _tryResumeReadingProgress(ViewerState state) async {
    if (_didAttemptResume) return;
    if (state.status != ViewerStatus.loaded) return;
    if (state.fileByteLength <= 0 || state.fileContent.isEmpty) return;

    _didAttemptResume = true;

    final progress = await ref.read(readingProgressProvider).get(
          state.fileName,
          state.fileByteLength,
        );
    if (!mounted) return;
    if (progress == null || progress.charOffset <= 0) return;

    final totalLength = state.fileContent.length;
    final charOffset = progress.charOffset.clamp(0, totalLength);
    if (charOffset <= 0) return;

    await _jumpToCharOffsetWithRetry(charOffset, totalLength, state: state);
  }

  Future<void> _jumpToCharOffsetWithRetry(
    int charOffset,
    int totalLength, {
    required ViewerState state,
    int attempt = 0,
  }) async {
    if (!mounted) return;

    final layoutReady = _scrollController.hasClients &&
        _scrollController.position.maxScrollExtent > 0;

    // For rendered markdown with headings, wait a few frames for keys to mount.
    final needKeys = _canUseMarkdownAnchors(state) && state.headings.isNotEmpty;
    final keysReady =
        !needKeys || (_markdownViewKey.currentState?.hasMountedHeadingKeys ?? false);

    if (layoutReady && (keysReady || attempt >= 3)) {
      _isRestoring = true;
      _jumpToCharOffset(charOffset, totalLength);
      _lastSavedCharOffset = charOffset;
      // Allow the jump to settle before scroll listener can re-save.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _isRestoring = false;
      });
      return;
    }

    if (attempt >= 5) {
      // Last-chance ratio jump even without full layout readiness.
      if (layoutReady) {
        _isRestoring = true;
        _jumpToCharOffset(charOffset, totalLength);
        _lastSavedCharOffset = charOffset;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _isRestoring = false;
        });
      }
      return;
    }

    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      completer.complete();
    });
    await completer.future;
    if (!mounted) return;
    await _jumpToCharOffsetWithRetry(
      charOffset,
      totalLength,
      state: state,
      attempt: attempt + 1,
    );
  }

  Future<void> _scrollToCurrentMatch() async {
    final state = ref.read(viewerProvider).value;
    if (state == null || state.searchMatchCount == 0) return;

    final index = state.searchMatchIndex;

    // Rendered markdown: try key-based locate with a couple of post-frame retries.
    if (_canUseMarkdownAnchors(state) && state.highlightContent.isNotEmpty) {
      for (var attempt = 0; attempt < 3; attempt++) {
        final ok =
            await _markdownViewKey.currentState?.ensureMatchVisible(index) ??
                false;
        if (ok) return;
        if (!mounted) return;
        final completer = Completer<void>();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          completer.complete();
        });
        await completer.future;
      }
    }

    // Fallback: ratio on original fileContent match offsets (never highlight length).
    final offsets = state.searchMatchOffsets.isNotEmpty
        ? state.searchMatchOffsets
        : ref.read(viewerProvider.notifier).getMatchOffsets();
    if (index >= offsets.length) return;
    _scrollToOffset(offsets[index], state.fileContent.length);
  }

  void _updateActiveHeading() {
    final state = ref.read(viewerProvider).value;
    if (state == null || state.headings.isEmpty) {
      if (_activeHeadingIndex != -1) _activeHeadingIndex = -1;
      if (_sectionTitle.value.isNotEmpty) _sectionTitle.value = '';
      return;
    }
    if (!_scrollController.hasClients) return;

    final currentOffset = _scrollController.offset;
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent <= 0) return;

    int newIndex = -1;

    if (_canUseMarkdownAnchors(state)) {
      final keyIndex =
          _markdownViewKey.currentState?.activeHeadingIndex(currentOffset);
      if (keyIndex != null) {
        newIndex = keyIndex;
      }
    }

    // Ratio fallback when keys are unavailable.
    if (newIndex < 0) {
      final totalLength = state.fileContent.length;
      if (totalLength <= 0) return;
      for (int i = 0; i < state.headings.length; i++) {
        final estimatedPixel =
            (state.headings[i].offset / totalLength) * maxExtent;
        if (estimatedPixel <= currentOffset) {
          newIndex = i;
        } else {
          break;
        }
      }
    }

    if (newIndex != _activeHeadingIndex) {
      // Avoid setState — it rebuilds MarkdownView and causes scroll jank.
      // TOC still reads _activeHeadingIndex; AppBar subtitle uses notifier.
      _activeHeadingIndex = newIndex;
      final next = _secondaryTitle(state.headings, newIndex);
      if (_sectionTitle.value != next) {
        _sectionTitle.value = next;
      }
    }
  }

  /// Scroll-based section title for AppBar subtitle (H1/H2; H3 walks back).
  String _secondaryTitle(List<HeadingItem> headings, int activeIndex) {
    if (activeIndex < 0 || activeIndex >= headings.length) return '';
    for (int i = activeIndex; i >= 0; i--) {
      final h = headings[i];
      if (h.level <= 2) {
        return h.text;
      }
    }
    return '';
  }

  Future<void> _scrollToHeading(int index) async {
    final state = ref.read(viewerProvider).value;
    if (state == null || index < 0 || index >= state.headings.length) return;

    if (_canUseMarkdownAnchors(state)) {
      for (var attempt = 0; attempt < 3; attempt++) {
        final ok =
            await _markdownViewKey.currentState?.ensureHeadingVisible(index) ??
                false;
        if (ok) return;
        if (!mounted) return;
        final completer = Completer<void>();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          completer.complete();
        });
        await completer.future;
      }
    }

    // Fallback to char-ratio.
    _scrollToOffset(state.headings[index].offset, state.fileContent.length);
  }

  void _updateStatusBarStyle() {
    final brightness = _isReadingSurfaceDark ? Brightness.dark : Brightness.light;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: brightness,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewerStateAsync = ref.watch(viewerProvider);
    final preferences = ref.watch(preferencesProvider);

    // Silent resume once the document is loaded.
    ref.listen(viewerProvider, (previous, next) {
      final state = next.value;
      if (state == null) return;
      unawaited(_tryResumeReadingProgress(state));
    });

    final isSystemDark = Theme.of(context).brightness == Brightness.dark;
    final isBaseDark = switch (preferences.appThemeMode) {
      AppThemeMode.system => isSystemDark,
      AppThemeMode.dark => true,
      AppThemeMode.light => false,
    };
    final isSurfaceDark = _isReadingSurfaceDark ? !isBaseDark : isBaseDark;

    final activeReaderLightTheme = preferences.readerLightTheme;
    final activeReaderDarkTheme = preferences.readerDarkTheme;

    final chromeColors = viewerChromeColors(
      readerLightTheme: activeReaderLightTheme,
      readerDarkTheme: activeReaderDarkTheme,
      isSurfaceDark: isSurfaceDark,
    );

    final colorPair = resolveReaderColorPair(
      readerLightTheme: activeReaderLightTheme,
      readerDarkTheme: activeReaderDarkTheme,
    );
    final readerColors = isSurfaceDark ? colorPair.dark : colorPair.light;

    return Scaffold(
      backgroundColor: readerColors.surface,
      appBar: _buildAppBar(viewerStateAsync, chromeColors),
      body: AppLayoutBody(
        child: viewerStateAsync.when(
          data: (state) =>
              _buildBody(state, preferences, readerColors, chromeColors),
          loading: () => _LoadingView(
            fileName: widget.fileName,
            chromeColors: chromeColors,
          ),
          error: (err, _) => _ErrorView(
            message: 'Failed to load file: $err',
            onRetry: () => context.go('/'),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    AsyncValue<ViewerState> viewerStateAsync,
    ReaderColors chromeColors,
  ) {
    final state = viewerStateAsync.value;
    final isLoading = viewerStateAsync.isLoading ||
        state == null ||
        state.status == ViewerStatus.loading ||
        state.status == ViewerStatus.initial;
    final isReady = state != null && state.status == ViewerStatus.loaded;
    final isSearchActive = isReady && state.isSearchActive;
    final isMarkdown =
        isReady && !state.isSourceCode && !state.isBinary;
    final isSourceCodeModeOn =
        isReady && (state.viewMode == ViewMode.raw || state.isBinary);
    final canToggleSourceCodeMode = isReady && !state.isBinary;

    if (isSearchActive) {
      return PreferredSize(
        preferredSize: const Size.fromHeight(120),
        child: ViewerSearchBar(
          query: state.searchQuery,
          matchIndex: state.searchMatchIndex,
          matchCount: state.searchMatchCount,
          onQueryChanged: (q) =>
              ref.read(viewerProvider.notifier).setSearchQuery(q),
          onNext: () {
            ref.read(viewerProvider.notifier).nextMatch();
            unawaited(_scrollToCurrentMatch());
          },
          onPrevious: () {
            ref.read(viewerProvider.notifier).previousMatch();
            unawaited(_scrollToCurrentMatch());
          },
          onClear: () =>
              ref.read(viewerProvider.notifier).setSearchQuery(''),
          onBack: () => ref.read(viewerProvider.notifier).toggleSearch(),
          modeLabel: state.viewMode == ViewMode.raw || state.isBinary
              ? 'Source code mode'
              : state.isSourceCode
                  ? 'Source code'
                  : 'Rendered mode',
          chromeColors: chromeColors,
        ),
      );
    }

    final titleName = (state?.fileName.isNotEmpty ?? false)
        ? state!.fileName
        : widget.fileName;

    return AppBar(
      backgroundColor: chromeColors.surface,
      foregroundColor: chromeColors.content,
      surfaceTintColor: Colors.transparent,
      leading: isMarkdown
          ? IconButton(
              icon: Icon(Icons.format_list_bulleted,
                  color: chromeColors.content),
              tooltip: 'Table of contents',
              onPressed: () => _showTocSheet(chromeColors),
            )
          : IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back',
              onPressed: () => context.go('/'),
            ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titleName,
            style: const TextStyle(fontSize: 16),
            overflow: TextOverflow.ellipsis,
          ),
          // Source code mode / binary: fixed subtitle. Otherwise section heading.
          // Do not clear _sectionTitle when entering raw so it restores on exit.
          if (isSourceCodeModeOn)
            Text(
              'SOURCE CODE MODE',
              style: TextStyle(fontSize: 11, color: chromeColors.muted),
              overflow: TextOverflow.ellipsis,
            )
          else if (isReady)
            ValueListenableBuilder<String>(
              valueListenable: _sectionTitle,
              builder: (context, sectionTitle, _) {
                if (sectionTitle.isEmpty) return const SizedBox.shrink();
                return Text(
                  sectionTitle,
                  style: TextStyle(fontSize: 11, color: chromeColors.muted),
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
        ],
      ),
      actions: [
        if (isReady)
          IconButton(
            icon: Icon(Icons.search, color: chromeColors.content),
            tooltip: 'Search',
            onPressed: () => ref.read(viewerProvider.notifier).toggleSearch(),
          )
        else
          IconButton(
            icon: Icon(Icons.search, color: chromeColors.muted),
            tooltip: 'Search',
            onPressed: null,
          ),
        PopupMenuButton<String>(
          enabled: !isLoading,
          icon: Icon(
            Icons.more_vert,
            color: isLoading ? chromeColors.muted : chromeColors.content,
          ),
          color: chromeColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: (value) {
            switch (value) {
              case 'word_wrap':
                {
                  final saved = _scrollController.offset;
                  setState(() => _isWordWrapEnabled = !_isWordWrapEnabled);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController.jumpTo(saved.clamp(
                        0.0,
                        _scrollController.position.maxScrollExtent,
                      ));
                    }
                  });
                }
                break;
              case 'code_block_wrap':
                {
                  final saved = _scrollController.offset;
                  setState(
                      () => _isCodeBlockWrapEnabled = !_isCodeBlockWrapEnabled);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController.jumpTo(saved.clamp(
                        0.0,
                        _scrollController.position.maxScrollExtent,
                      ));
                    }
                  });
                }
                break;
              case 'source_code_mode':
                {
                  final current = ref.read(viewerProvider).value;
                  if (current == null || current.isBinary) return;
                  final saved = _scrollController.hasClients
                      ? _scrollController.offset
                      : null;
                  ref.read(viewerProvider.notifier).toggleViewMode();
                  if (saved != null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollController.hasClients) {
                        _scrollController.jumpTo(saved.clamp(
                          0.0,
                          _scrollController.position.maxScrollExtent,
                        ));
                      }
                    });
                  }
                }
                break;
              case 'reader_surface':
                {
                  final saved = _scrollController.offset;
                  setState(
                      () => _isReadingSurfaceDark = !_isReadingSurfaceDark);
                  _updateStatusBarStyle();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController.jumpTo(saved.clamp(
                        0.0,
                        _scrollController.position.maxScrollExtent,
                      ));
                    }
                  });
                }
                break;
              case 'settings':
                context.push('/settings');
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'word_wrap',
              child: Row(
                children: [
                  Icon(Icons.wrap_text, color: chromeColors.content),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Wrap long lines',
                        style: TextStyle(color: chromeColors.content)),
                  ),
                  Switch(
                    value: _isWordWrapEnabled,
                    onChanged: null,
                  ),
                ],
              ),
            ),
            if (_isWordWrapEnabled)
              PopupMenuItem(
                value: 'code_block_wrap',
                child: Row(
                  children: [
                    Icon(Icons.code, color: chromeColors.content),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Wrap code blocks',
                          style: TextStyle(color: chromeColors.content)),
                    ),
                    Switch(
                      value: _isCodeBlockWrapEnabled,
                      onChanged: null,
                    ),
                  ],
                ),
              ),
            PopupMenuItem(
              value: 'source_code_mode',
              enabled: canToggleSourceCodeMode,
              child: Row(
                children: [
                  Icon(
                    Icons.code_off,
                    color: canToggleSourceCodeMode
                        ? chromeColors.content
                        : chromeColors.muted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Source code mode',
                      style: TextStyle(
                        color: canToggleSourceCodeMode
                            ? chromeColors.content
                            : chromeColors.muted,
                      ),
                    ),
                  ),
                  Switch(
                    value: isSourceCodeModeOn,
                    onChanged: null,
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'reader_surface',
              child: Row(
                children: [
                  Icon(
                    _isReadingSurfaceDark
                        ? Icons.dark_mode
                        : Icons.light_mode,
                    color: chromeColors.content,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isReadingSurfaceDark
                          ? 'Reader surface: Dark'
                          : 'Reader surface: Light',
                      style: TextStyle(color: chromeColors.content),
                    ),
                  ),
                  Text(
                    _isReadingSurfaceDark ? 'Dark' : 'Light',
                    style:
                        TextStyle(fontSize: 11, color: chromeColors.muted),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(height: 1),
            PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings, color: chromeColors.content),
                  const SizedBox(width: 12),
                  Text('Settings',
                      style: TextStyle(color: chromeColors.content)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBody(
    ViewerState state,
    UserPreferences preferences,
    ReaderColors readerColors,
    ReaderColors chromeColors,
  ) {
    if (state.status == ViewerStatus.initial ||
        state.status == ViewerStatus.loading) {
      final name =
          state.fileName.isNotEmpty ? state.fileName : widget.fileName;
      return _LoadingView(fileName: name, chromeColors: chromeColors);
    }
    if (state.status == ViewerStatus.error) {
      return _ErrorView(
        message: state.errorMessage ?? 'Unknown error',
        onRetry: () => context.go('/'),
      );
    }
    if (state.fileContent.isEmpty) {
      return const Center(child: Text('This file is empty.'));
    }

    return Column(
      children: [
        if (state.warningMessage != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: chromeColors.container,
            child: Text(
              state.warningMessage!,
              style: TextStyle(
                fontSize: 12,
                color: chromeColors.content,
              ),
            ),
          ),
        Expanded(
          child: Container(
            color: readerColors.surface,
            child: DefaultTextStyle(
              style: TextStyle(color: readerColors.content),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _buildContent(state, preferences, readerColors),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: ValueListenableBuilder<_ProgressBadgeState>(
                      valueListenable: _progressBadge,
                      builder: (context, badge, _) {
                        return ReadingProgressBadge(
                          percent: badge.percent,
                          visible: badge.visible,
                          colors: readerColors,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(ViewerState state, UserPreferences preferences, ReaderColors readerColors) {
    if (state.viewMode == ViewMode.raw || state.isBinary) {
      final textAlign =
          preferences.textAlignment == ReadingTextAlign.justified
              ? TextAlign.justify
              : TextAlign.left;

      final textWidget = SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        child: Text(
          state.fileContent,
          style: TextStyle(
            fontSize: preferences.fontSize,
            height: preferences.lineHeight,
          ),
          textAlign: textAlign,
        ),
      );

      if (_isWordWrapEnabled) {
        return textWidget;
      }
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(width: 800, child: textWidget),
      );
    }

    if (state.isSourceCode) {
      return SourceCodeView(
        content: state.fileContent,
        language: state.codeLanguage ?? '',
        fontSize: preferences.fontSize,
        lineHeight: preferences.lineHeight,
        isWordWrapEnabled: _isWordWrapEnabled,
        scrollController: _scrollController,
        onLinkTap: _onLinkTap,
        fontScale: _fontScale,
        onFontScaleChanged: (s) => setState(() => _fontScale = s),
      );
    }

    final displayContent =
        state.highlightContent.isNotEmpty ? state.highlightContent : state.fileContent;

    return MarkdownView(
      key: _markdownViewKey,
      content: displayContent,
      fontSize: preferences.fontSize,
      lineHeight: preferences.lineHeight,
      textAlignment: preferences.textAlignment,
      isWordWrapEnabled: _isWordWrapEnabled,
      scrollController: _scrollController,
      textColor: readerColors.content,
      onLinkTap: _onLinkTap,
      fontScale: _fontScale,
      onFontScaleChanged: (s) => setState(() => _fontScale = s),
      headingCount: state.headings.length,
      searchMatchCount:
          state.highlightContent.isNotEmpty ? state.searchMatchCount : 0,
    );
  }

  Future<void> _onLinkTap(String url, String title) async {
    final uri = Uri.tryParse(url);
    if (uri == null || (!uri.hasScheme && !uri.hasAuthority)) return;
    if (!['http', 'https'].contains(uri.scheme)) return;

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $url')),
        );
      }
    }
  }

  void _showTocSheet(ReaderColors chromeColors) {
    final state = ref.read(viewerProvider).value;
    if (state == null || state.headings.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: chromeColors.surface,
      builder: (_) => TocSheet(
        headings: state.headings,
        activeHeadingIndex: _activeHeadingIndex,
        chromeColors: chromeColors,
        onHeadingSelected: (index) {
          unawaited(_scrollToHeading(index));
        },
      ),
    );
  }
}

class _ProgressBadgeState {
  final int percent;
  final bool visible;

  const _ProgressBadgeState({
    required this.percent,
    required this.visible,
  });
}

class _LoadingView extends StatelessWidget {
  final String fileName;
  final ReaderColors chromeColors;

  const _LoadingView({
    required this.fileName,
    required this.chromeColors,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = fileName.isEmpty ? 'file' : fileName;
    return Semantics(
      label: 'Opening $displayName',
      liveRegion: true,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.insert_drive_file_outlined,
                  size: 48,
                  color: chromeColors.muted,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                displayName,
                style: TextStyle(fontSize: 14, color: chromeColors.muted),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
              const SizedBox(height: 4),
              Text(
                'Opening…',
                style: TextStyle(fontSize: 12, color: chromeColors.muted),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: chromeColors.content.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.file_open),
              label: const Text('Open Different File'),
            ),
          ],
        ),
      ),
    );
  }
}

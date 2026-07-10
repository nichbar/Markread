// lib/features/viewer/screens/viewer_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/user_preferences.dart';
import '../../../core/providers/preferences_provider.dart';
import '../../../core/widgets/app_layout_body.dart';
import '../providers/viewer_provider.dart';
import '../widgets/markdown_view.dart';
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

class _ViewerScreenState extends ConsumerState<ViewerScreen> {
  bool _isReadingSurfaceDark = false;
  bool _isWordWrapEnabled = true;
  bool _isCodeBlockWrapEnabled = true;
  double _fontScale = 1.0;
  int _activeHeadingIndex = -1;
  late final ScrollController _scrollController;
  DateTime _lastHeadingUpdate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScrollTick);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateStatusBarStyle());
  }

  void _onScrollTick() {
    // Throttle heading updates to avoid per-frame work during fast flings.
    // Updating every ~100ms is imperceptible and prevents frame drops
    // when scrolling rapidly to boundaries and reversing direction.
    final now = DateTime.now();
    if (now.difference(_lastHeadingUpdate).inMilliseconds < 100) return;
    _lastHeadingUpdate = now;
    _updateActiveHeading();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScrollTick);
    _scrollController.dispose();
    super.dispose();
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

  void _scrollToCurrentMatch() {
    final state = ref.read(viewerProvider).value;
    if (state == null || state.searchMatchCount == 0) return;
    if (state.highlightContent.isNotEmpty) {
      final totalLength = state.highlightContent.length;
      if (totalLength <= 0) return;
      _scrollToOffset(state.scrollTargetOffset, totalLength);
      return;
    }
    final offsets = ref.read(viewerProvider.notifier).getMatchOffsets();
    if (state.searchMatchIndex >= offsets.length) return;
    final offset = offsets[state.searchMatchIndex];
    _scrollToOffset(offset, state.fileContent.length);
  }

  void _updateActiveHeading() {
    final state = ref.read(viewerProvider).value;
    if (state == null || state.headings.isEmpty) return;
    if (!_scrollController.hasClients) return;

    final currentOffset = _scrollController.offset;
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent <= 0) return;

    final totalLength = state.fileContent.length;
    if (totalLength <= 0) return;

    int newIndex = -1;
    for (int i = 0; i < state.headings.length; i++) {
      final estimatedPixel =
          (state.headings[i].offset / totalLength) * maxExtent;
      if (estimatedPixel <= currentOffset) {
        newIndex = i;
      } else {
        break;
      }
    }

    if (newIndex != _activeHeadingIndex) {
      _activeHeadingIndex = newIndex;
    }
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
        loading: () => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.insert_drive_file_outlined,
                  size: 48, color: chromeColors.muted),
              const SizedBox(height: 12),
              Text(widget.fileName,
                  style: TextStyle(
                      fontSize: 14, color: chromeColors.muted),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: chromeColors.muted,
                ),
              ),
            ],
          ),
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
    final isSearchActive = state?.isSearchActive ?? false;
    final isMarkdown = state != null && !state.isSourceCode && !state.isBinary;

    if (isSearchActive && state != null) {
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
            _scrollToCurrentMatch();
          },
          onPrevious: () {
            ref.read(viewerProvider.notifier).previousMatch();
            _scrollToCurrentMatch();
          },
          onClear: () =>
              ref.read(viewerProvider.notifier).setSearchQuery(''),
          onBack: () => ref.read(viewerProvider.notifier).toggleSearch(),
          modeLabel: state.isSourceCode
              ? 'Source code'
              : state.viewMode == ViewMode.raw
                  ? 'Raw mode'
                  : 'Rendered mode',
          chromeColors: chromeColors,
        ),
      );
    }

    final viewModeLabel = state == null
        ? 'Loading...'
        : state.isSourceCode
            ? 'Source code'
            : state.viewMode == ViewMode.raw
                ? 'Raw mode'
                : 'Rendered mode';

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
              onPressed: () => context.go('/'),
            ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.fileName,
              style: const TextStyle(fontSize: 16),
              overflow: TextOverflow.ellipsis),
          Text(
            viewModeLabel,
            style: TextStyle(fontSize: 11, color: chromeColors.muted),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.search, color: chromeColors.content),
          tooltip: 'Search',
          onPressed: () => ref.read(viewerProvider.notifier).toggleSearch(),
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: chromeColors.content),
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
            PopupMenuDivider(height: 1),
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
    if (state.status == ViewerStatus.initial) {
      return const SizedBox.shrink();
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
              child: _buildContent(state, preferences, readerColors),
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

      final fontFamily = preferences.readingFont == ReadingFont.merriweather
          ? 'Merriweather'
          : null;

      final textWidget = SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        child: Text(
          state.fileContent,
          style: TextStyle(
            fontSize: preferences.fontSize,
            height: preferences.lineHeight,
            fontFamily: fontFamily,
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
        codeFont: preferences.codeFont,
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
      content: displayContent,
      fontSize: preferences.fontSize,
      lineHeight: preferences.lineHeight,
      textAlignment: preferences.textAlignment,
      readingFont: preferences.readingFont,
      isWordWrapEnabled: _isWordWrapEnabled,
      scrollController: _scrollController,
      textColor: readerColors.content,
      onLinkTap: _onLinkTap,
      fontScale: _fontScale,
      onFontScaleChanged: (s) => setState(() => _fontScale = s),
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
        onHeadingSelected: (offset) {
          _scrollToOffset(offset, state.fileContent.length);
        },
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

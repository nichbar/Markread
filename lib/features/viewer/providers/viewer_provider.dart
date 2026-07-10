// lib/features/viewer/providers/viewer_provider.dart
import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/file_service.dart';

enum ViewerStatus { initial, loading, loaded, error }

enum ViewMode { rendered, raw }

class HeadingItem {
  final String text;
  final int level;
  final int offset;

  const HeadingItem({
    required this.text,
    required this.level,
    required this.offset,
  });
}

class ViewerState {
  final String fileName;
  final String fileContent;
  final ViewerStatus status;
  final String? errorMessage;
  final bool isSourceCode;
  final String? codeLanguage;
  final ViewMode viewMode;
  final List<HeadingItem> headings;
  final bool isBinary;
  final String? warningMessage;
  final bool isSearchActive;
  final String searchQuery;
  final int searchMatchCount;
  final int searchMatchIndex;
  final String highlightContent;
  final int scrollTargetOffset;

  const ViewerState({
    this.fileName = '',
    this.fileContent = '',
    this.status = ViewerStatus.initial,
    this.errorMessage,
    this.isSourceCode = false,
    this.codeLanguage,
    this.viewMode = ViewMode.rendered,
    this.headings = const [],
    this.isBinary = false,
    this.warningMessage,
    this.isSearchActive = false,
    this.searchQuery = '',
    this.searchMatchCount = 0,
    this.searchMatchIndex = 0,
    this.highlightContent = '',
    this.scrollTargetOffset = 0,
  });

  ViewerState copyWith({
    String? fileName,
    String? fileContent,
    ViewerStatus? status,
    String? errorMessage,
    bool? isSourceCode,
    String? codeLanguage,
    ViewMode? viewMode,
    List<HeadingItem>? headings,
    bool? isBinary,
    String? warningMessage,
    bool? isSearchActive,
    String? searchQuery,
    int? searchMatchCount,
    int? searchMatchIndex,
    String? highlightContent,
    int? scrollTargetOffset,
  }) {
    return ViewerState(
      fileName: fileName ?? this.fileName,
      fileContent: fileContent ?? this.fileContent,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      isSourceCode: isSourceCode ?? this.isSourceCode,
      codeLanguage: codeLanguage ?? this.codeLanguage,
      viewMode: viewMode ?? this.viewMode,
      headings: headings ?? this.headings,
      isBinary: isBinary ?? this.isBinary,
      warningMessage: warningMessage ?? this.warningMessage,
      isSearchActive: isSearchActive ?? this.isSearchActive,
      searchQuery: searchQuery ?? this.searchQuery,
      searchMatchCount: searchMatchCount ?? this.searchMatchCount,
      searchMatchIndex: searchMatchIndex ?? this.searchMatchIndex,
      highlightContent: highlightContent ?? this.highlightContent,
      scrollTargetOffset: scrollTargetOffset ?? this.scrollTargetOffset,
    );
  }
}

class ViewerNotifier extends AsyncNotifier<ViewerState> {
  Timer? _searchDebounce;

  @override
  Future<ViewerState> build() async {
    return const ViewerState();
  }

  Future<void> loadFile(PlatformFile file, FileService fileService) async {
    state = const AsyncLoading();

    try {
      final name = file.name;
      final isMarkdown = fileService.isMarkdownFile(name);

      String? codeLanguage;
      bool isSourceCode = false;

      if (isMarkdown) {
        isSourceCode = false;
      } else {
        codeLanguage = fileService.detectLanguage(name);
        if (codeLanguage != null) {
          isSourceCode = true;
        }
      }

      final content = await fileService.readFileBytes(file);

      final isBinary = fileService.isProbablyBinary(content);
      List<HeadingItem> headings = [];
      ViewMode viewMode = ViewMode.rendered;
      String? warningMessage;

      if (isBinary) {
        viewMode = ViewMode.raw;
        warningMessage = 'This file looks binary or malformed. Showing raw text.';
      } else if (isSourceCode) {
        viewMode = ViewMode.rendered;
      } else {
        headings = _parseHeadings(content);
      }

      state = AsyncData(ViewerState(
        fileName: name,
        fileContent: content,
        status: ViewerStatus.loaded,
        isSourceCode: isSourceCode,
        codeLanguage: codeLanguage,
        viewMode: viewMode,
        headings: headings,
        isBinary: isBinary,
        warningMessage: warningMessage,
      ));
    } catch (e) {
      state = AsyncData(ViewerState(
        fileName: file.name,
        status: ViewerStatus.error,
        errorMessage: 'Could not read file: ${e.toString()}',
      ));
    }
  }

  Future<void> loadFileFromBytes(PlatformFile file, List<int> bytes, FileService fileService) async {
    state = const AsyncLoading();

    try {
      final name = file.name;
      final isMarkdown = fileService.isMarkdownFile(name);

      String? codeLanguage;
      bool isSourceCode = false;

      if (!isMarkdown) {
        codeLanguage = fileService.detectLanguage(name);
        if (codeLanguage != null) {
          isSourceCode = true;
        }
      }

      final content = utf8.decode(bytes);

      final isBinary = fileService.isProbablyBinary(content);
      List<HeadingItem> headings = [];
      ViewMode viewMode = ViewMode.rendered;
      String? warningMessage;

      if (isBinary) {
        viewMode = ViewMode.raw;
        warningMessage = 'This file looks binary or malformed. Showing raw text.';
      } else if (isSourceCode) {
        viewMode = ViewMode.rendered;
      } else {
        headings = _parseHeadings(content);
      }

      state = AsyncData(ViewerState(
        fileName: name,
        fileContent: content,
        status: ViewerStatus.loaded,
        isSourceCode: isSourceCode,
        codeLanguage: codeLanguage,
        viewMode: viewMode,
        headings: headings,
        isBinary: isBinary,
        warningMessage: warningMessage,
      ));
    } catch (e) {
      state = AsyncData(ViewerState(
        fileName: file.name,
        status: ViewerStatus.error,
        errorMessage: 'Could not read file: ${e.toString()}',
      ));
    }
  }

  void toggleViewMode() {
    final current = state.value;
    if (current == null) return;
    final next =
        current.viewMode == ViewMode.rendered ? ViewMode.raw : ViewMode.rendered;
    state = AsyncData(current.copyWith(viewMode: next));
  }

  void toggleSearch() {
    _searchDebounce?.cancel();
    final current = state.value;
    if (current == null) return;
    if (current.isSearchActive) {
      state = AsyncData(current.copyWith(
        isSearchActive: false,
        searchQuery: '',
        searchMatchCount: 0,
        searchMatchIndex: 0,
        highlightContent: '',
        scrollTargetOffset: 0,
      ));
    } else {
      state = AsyncData(current.copyWith(isSearchActive: true));
    }
  }

  void setSearchQuery(String query) {
    _searchDebounce?.cancel();

    final current = state.value;
    if (current == null) return;

    // Update the query immediately so the text field is responsive.
    state = AsyncData(current.copyWith(
      searchQuery: query,
      scrollTargetOffset: 0,
    ));

    if (query.isEmpty) {
      state = AsyncData(state.value!.copyWith(
        searchMatchCount: 0,
        searchMatchIndex: 0,
        highlightContent: '',
      ));
      return;
    }

    // Debounce the expensive full-text scan and highlight building.
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      final current = state.value;
      if (current == null) return;
      final matches = _findMatches(current.fileContent, query);
      String highlightContent = '';
      if (current.viewMode == ViewMode.rendered) {
        highlightContent =
            _buildHighlightedContent(current.fileContent, query, matches);
      }
      state = AsyncData(current.copyWith(
        searchMatchCount: matches.length,
        searchMatchIndex: 0,
        highlightContent: highlightContent,
      ));
    });
  }

  void nextMatch() {
    final current = state.value;
    if (current == null || current.searchMatchCount == 0) return;
    final next =
        (current.searchMatchIndex + 1) % current.searchMatchCount;
    final offsets = _findMatches(current.fileContent, current.searchQuery);
    final scrollTargetOffset = _computeHighlightOffset(next, offsets);
    state = AsyncData(current.copyWith(
      searchMatchIndex: next,
      scrollTargetOffset: scrollTargetOffset,
    ));
  }

  void previousMatch() {
    final current = state.value;
    if (current == null || current.searchMatchCount == 0) return;
    final prev = current.searchMatchIndex - 1 < 0
        ? current.searchMatchCount - 1
        : current.searchMatchIndex - 1;
    final offsets = _findMatches(current.fileContent, current.searchQuery);
    final scrollTargetOffset = _computeHighlightOffset(prev, offsets);
    state = AsyncData(current.copyWith(
      searchMatchIndex: prev,
      scrollTargetOffset: scrollTargetOffset,
    ));
  }

  List<int> getMatchOffsets() {
    final current = state.value;
    if (current == null) return [];
    return _findMatches(current.fileContent, current.searchQuery);
  }

  List<int> _findMatches(String text, String query) {
    if (query.isEmpty) return [];
    final offsets = <int>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    int start = 0;
    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) break;
      offsets.add(index);
      start = index + lowerQuery.length;
    }
    return offsets;
  }

  String _buildHighlightedContent(
      String text, String query, List<int> matches) {
    if (matches.isEmpty) return text;
    final buffer = StringBuffer();
    int lastEnd = 0;
    for (final offset in matches) {
      // Write text between matches (preserving original casing)
      buffer.write(text.substring(lastEnd, offset));
      // Write the match wrapped in **bold**
      buffer.write('**');
      buffer.write(text.substring(offset, offset + query.length));
      buffer.write('**');
      lastEnd = offset + query.length;
    }
    buffer.write(text.substring(lastEnd));
    return buffer.toString();
  }

  int _computeHighlightOffset(int matchIndex, List<int> offsets) {
    if (matchIndex < 0 || matchIndex >= offsets.length) return 0;
    // Each prior match adds 4 characters (** before and ** after)
    return offsets[matchIndex] + (matchIndex * 4);
  }

  static List<HeadingItem> _parseHeadings(String markdown) {
    final headings = <HeadingItem>[];
    final lines = markdown.split('\n');
    int offset = 0;
    for (final line in lines) {
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('#')) {
        final level = trimmed.indexOf(' ');
        if (level >= 1 && level <= 3) {
          final text = trimmed.substring(level + 1).trim();
          if (text.isNotEmpty) {
            headings.add(HeadingItem(
              text: text,
              level: level,
              offset: offset,
            ));
          }
        }
      }
      offset += line.length + 1; // +1 for the '\n' removed by split
    }
    return headings;
  }
}

final viewerProvider =
    AsyncNotifierProvider<ViewerNotifier, ViewerState>(ViewerNotifier.new);

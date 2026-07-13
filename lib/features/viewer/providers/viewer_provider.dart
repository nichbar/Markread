// lib/features/viewer/providers/viewer_provider.dart
import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/file_content_processor.dart';
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
  final int fileByteLength;
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
    this.fileByteLength = 0,
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
    int? fileByteLength,
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
      fileByteLength: fileByteLength ?? this.fileByteLength,
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

  /// Enter loading with a stable [AsyncData] so the viewer can render
  /// themed chrome and a loading body (not a pure [AsyncLoading] blank).
  void beginLoad({String fileName = ''}) {
    state = AsyncData(ViewerState(
      fileName: fileName,
      status: ViewerStatus.loading,
    ));
  }

  Future<void> completeLoad(PlatformFile file, FileService fileService) async {
    // If caller forgot beginLoad, still enter loading (safe).
    final current = state.value;
    if (current == null || current.status != ViewerStatus.loading) {
      state = AsyncData(ViewerState(
        fileName: file.name,
        status: ViewerStatus.loading,
      ));
    }

    try {
      final bytes = await fileService.readFileAsBytes(file);
      final name = file.name;

      final processed = await _process(name, bytes);

      state = AsyncData(
        _viewerStateFromProcessed(processed, byteLength: bytes.length),
      );
    } catch (e) {
      state = AsyncData(ViewerState(
        fileName: file.name,
        status: ViewerStatus.error,
        errorMessage: 'Could not read file: ${e.toString()}',
      ));
    }
  }

  ViewerState _viewerStateFromProcessed(
    ProcessedFileContent p, {
    required int byteLength,
  }) {
    return ViewerState(
      fileName: p.fileName,
      fileContent: p.fileContent,
      fileByteLength: byteLength,
      status: ViewerStatus.loaded,
      isSourceCode: p.isSourceCode,
      codeLanguage: p.codeLanguage,
      viewMode: p.viewMode == ProcessedViewMode.raw
          ? ViewMode.raw
          : ViewMode.rendered,
      headings: [
        for (final h in p.headings)
          HeadingItem(text: h.text, level: h.level, offset: h.offset),
      ],
      isBinary: p.isBinary,
      warningMessage: p.warningMessage,
    );
  }

  Future<ProcessedFileContent> _process(String name, Uint8List bytes) async {
    // kIsWeb: process on main after yield; VM: Isolate.run
    if (kIsWeb) {
      return processFileContent(fileName: name, bytes: bytes);
    }
    return Isolate.run(() => processFileContent(fileName: name, bytes: bytes));
  }

  /// Convenience for call sites that still want one method.
  Future<void> loadFile(PlatformFile file, FileService fileService) async {
    beginLoad();
    await Future<void>.delayed(Duration.zero);
    await completeLoad(file, fileService);
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
}

final viewerProvider =
    AsyncNotifierProvider<ViewerNotifier, ViewerState>(ViewerNotifier.new);

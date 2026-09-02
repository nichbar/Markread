// test/features/viewer/raw_markdown_view_test.dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markread/core/services/file_service.dart';
import 'package:markread/core/theme/app_theme.dart';
import 'package:markread/features/viewer/providers/viewer_provider.dart';
import 'package:markread/features/viewer/screens/viewer_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockViewerNotifier extends AsyncNotifier<ViewerState>
    implements ViewerNotifier {
  final ViewerState initialState;

  _MockViewerNotifier(this.initialState);

  @override
  Future<ViewerState> build() async {
    return initialState;
  }

  @override
  void beginLoad({String fileName = '', String? filePath}) {}

  @override
  Future<void> completeLoad(PlatformFile file, FileService fileService) async {}

  @override
  Future<void> loadFile(PlatformFile file, FileService fileService) async {}

  @override
  Future<void> saveContent(String newContent, {FileService? fileService}) async {}

  @override
  void toggleViewMode() {}

  @override
  void toggleSearch() {}

  @override
  void setSearchQuery(String query) {}

  @override
  void nextMatch() {}

  @override
  void previousMatch() {}

  @override
  List<int> getMatchOffsets() => [];
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Raw markdown mode renders SelectableText for selection and copy',
      (tester) async {
    const markdownContent = '# Hello World\n\nThis is raw content to select and copy.';
    const testState = ViewerState(
      fileName: 'test.md',
      fileContent: markdownContent,
      fileByteLength: markdownContent.length,
      status: ViewerStatus.loaded,
      viewMode: ViewMode.raw,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          viewerProvider.overrideWith(() => _MockViewerNotifier(testState)),
        ],
        child: MaterialApp(
          theme: buildLightTheme(),
          home: const ViewerScreen(fileName: 'test.md'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final selectableTextFinder = find.byType(SelectableText);
    expect(selectableTextFinder, findsOneWidget);

    final selectableText = tester.widget<SelectableText>(selectableTextFinder);
    expect(selectableText.textSpan?.toPlainText(), contains('This is raw content to select and copy.'));
  });

  testWidgets('Raw markdown mode highlights search matches in SelectableText',
      (tester) async {
    const markdownContent = 'Line 1: search target\nLine 2: other text';
    const testState = ViewerState(
      fileName: 'test.md',
      fileContent: markdownContent,
      fileByteLength: markdownContent.length,
      status: ViewerStatus.loaded,
      viewMode: ViewMode.raw,
      searchQuery: 'target',
      searchMatchCount: 1,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          viewerProvider.overrideWith(() => _MockViewerNotifier(testState)),
        ],
        child: MaterialApp(
          theme: buildLightTheme(),
          home: const ViewerScreen(fileName: 'test.md'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final selectableTextFinder = find.byType(SelectableText);
    expect(selectableTextFinder, findsOneWidget);

    final selectableText = tester.widget<SelectableText>(selectableTextFinder);
    final span = selectableText.textSpan as TextSpan;
    // Check that children contain highlighted span
    final highlighted = span.children?.any(
      (c) => c is TextSpan && c.text == 'target' && c.style?.backgroundColor != null,
    );
    expect(highlighted, isTrue);
  });
}

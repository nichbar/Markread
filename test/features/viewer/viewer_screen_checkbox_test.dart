// test/features/viewer/viewer_screen_checkbox_test.dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markread/core/providers/preferences_provider.dart';
import 'package:markread/core/services/file_service.dart';
import 'package:markread/core/theme/app_theme.dart';
import 'package:markread/features/viewer/providers/viewer_provider.dart';
import 'package:markread/features/viewer/screens/viewer_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TrackingViewerNotifier extends AsyncNotifier<ViewerState>
    implements ViewerNotifier {
  ViewerState currentState;
  String? lastSavedContent;

  _TrackingViewerNotifier(this.currentState);

  @override
  Future<ViewerState> build() async {
    return currentState;
  }

  @override
  void beginLoad({String fileName = '', String? filePath, String? fileUri}) {}

  @override
  Future<void> completeLoad(
    PlatformFile file,
    FileService fileService, {
    String? fileUri,
  }) async {}

  @override
  Future<void> loadFile(PlatformFile file, FileService fileService) async {}

  @override
  Future<void> saveContent(
    String newContent, {
    FileService? fileService,
  }) async {
    lastSavedContent = newContent;
    currentState = currentState.copyWith(fileContent: newContent);
    state = AsyncData(currentState);
  }

  @override
  Future<void> updateSavedAs({
    required String newFileName,
    String? newFilePath,
    String? newFileUri,
    required String newContent,
  }) async {}

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

  testWidgets(
    'ViewerScreen toggles checkbox and saves to file when setting is enabled',
    (tester) async {
      const markdown = '# Tasks\n\n- [ ] Task 1\n- [x] Task 2';
      const testState = ViewerState(
        fileName: 'tasks.md',
        fileContent: markdown,
        fileByteLength: markdown.length,
        status: ViewerStatus.loaded,
        viewMode: ViewMode.rendered,
      );

      final notifier = _TrackingViewerNotifier(testState);
      final container = ProviderContainer(
        overrides: [
          viewerProvider.overrideWith(() => notifier),
        ],
      );
      addTearDown(container.dispose);

      // Enable the preference
      await container
          .read(preferencesProvider.notifier)
          .setToggleCheckboxesInReadOnly(true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildLightTheme(),
            home: const ViewerScreen(fileName: 'tasks.md'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsNWidgets(2));

      // Tap first checkbox
      await tester.tap(checkboxes.at(0));
      await tester.pumpAndSettle();

      expect(
        notifier.lastSavedContent,
        '# Tasks\n\n- [x] Task 1\n- [x] Task 2',
      );
    },
  );

  testWidgets(
    'ViewerScreen does not toggle checkbox when setting is disabled',
    (tester) async {
      const markdown = '# Tasks\n\n- [ ] Task 1\n- [x] Task 2';
      const testState = ViewerState(
        fileName: 'tasks.md',
        fileContent: markdown,
        fileByteLength: markdown.length,
        status: ViewerStatus.loaded,
        viewMode: ViewMode.rendered,
      );

      final notifier = _TrackingViewerNotifier(testState);
      final container = ProviderContainer(
        overrides: [
          viewerProvider.overrideWith(() => notifier),
        ],
      );
      addTearDown(container.dispose);

      // Preference is false by default
      expect(
        container.read(preferencesProvider).toggleCheckboxesInReadOnly,
        isFalse,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildLightTheme(),
            home: const ViewerScreen(fileName: 'tasks.md'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsNWidgets(2));

      // Attempt to tap first checkbox
      await tester.tap(checkboxes.at(0));
      await tester.pumpAndSettle();

      // Nothing should have been saved
      expect(notifier.lastSavedContent, isNull);
    },
  );
}

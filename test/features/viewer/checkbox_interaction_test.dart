// test/features/viewer/checkbox_interaction_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markread/core/models/user_preferences.dart';
import 'package:markread/features/viewer/widgets/markdown_view.dart';
import 'package:markread/third_party/gpt_markdown/gpt_markdown.dart';

void main() {
  group('GptMarkdown Checkbox Interaction', () {
    testWidgets('GptMarkdown renders checkboxes and fires onCheckboxTap', (
      tester,
    ) async {
      int? tappedIndex;
      bool? tappedValue;

      const markdown = '''
- [ ] Task 1
- [x] Task 2
''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GptMarkdown(
              markdown,
              onCheckboxTap: (index, value) {
                tappedIndex = index;
                tappedValue = value;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsNWidgets(2));

      // First checkbox is unchecked (false)
      final checkbox1 = tester.widget<Checkbox>(checkboxes.at(0));
      expect(checkbox1.value, isFalse);

      // Tap first checkbox -> should toggle to true
      await tester.tap(checkboxes.at(0));
      await tester.pumpAndSettle();

      expect(tappedIndex, 0);
      expect(tappedValue, isTrue);

      // Second checkbox is checked (true)
      final checkbox2 = tester.widget<Checkbox>(checkboxes.at(1));
      expect(checkbox2.value, isTrue);

      // Tap second checkbox -> should toggle to false
      await tester.tap(checkboxes.at(1));
      await tester.pumpAndSettle();

      expect(tappedIndex, 1);
      expect(tappedValue, isFalse);
    });

    testWidgets('GptMarkdown respects checkboxStartIndex', (tester) async {
      int? tappedIndex;
      bool? tappedValue;

      const markdown = '- [ ] Task with offset';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GptMarkdown(
              markdown,
              checkboxStartIndex: 7,
              onCheckboxTap: (index, value) {
                tappedIndex = index;
                tappedValue = value;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final checkbox = find.byType(Checkbox);
      expect(checkbox, findsOneWidget);

      await tester.tap(checkbox);
      await tester.pumpAndSettle();

      expect(tappedIndex, 7);
      expect(tappedValue, isTrue);
    });

    testWidgets('GptMarkdown has disabled checkboxes when onCheckboxTap is null', (
      tester,
    ) async {
      const markdown = '- [ ] Disabled task';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GptMarkdown(
              markdown,
              onCheckboxTap: null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.onChanged, isNull);
    });
  });

  group('MarkdownView Checkbox Interaction', () {
    testWidgets('Monolith mode fires onCheckboxToggled with correct index', (
      tester,
    ) async {
      int? tappedIndex;
      bool? tappedValue;

      const markdown = '''
# Monolith Document

- [ ] Item 1
- [x] Item 2
''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownView(
              content: markdown,
              renderMode: MarkdownRenderMode.standard,
              onCheckboxToggled: (index, value) {
                tappedIndex = index;
                tappedValue = value;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsNWidgets(2));

      await tester.tap(checkboxes.at(0));
      await tester.pumpAndSettle();

      expect(tappedIndex, 0);
      expect(tappedValue, isTrue);

      await tester.tap(checkboxes.at(1));
      await tester.pumpAndSettle();

      expect(tappedIndex, 1);
      expect(tappedValue, isFalse);
    });

    testWidgets('Virtualized mode fires onCheckboxToggled with correct index', (
      tester,
    ) async {
      int? tappedIndex;
      bool? tappedValue;

      const markdown = '''
# Virtualized Document

- [ ] Item 1
- [x] Item 2
- [ ] Item 3
''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownView(
              content: markdown,
              renderMode: MarkdownRenderMode.performance,
              onCheckboxToggled: (index, value) {
                tappedIndex = index;
                tappedValue = value;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsWidgets);

      await tester.tap(checkboxes.at(0));
      await tester.pumpAndSettle();

      expect(tappedIndex, 0);
      expect(tappedValue, isTrue);

      await tester.tap(checkboxes.at(1));
      await tester.pumpAndSettle();

      expect(tappedIndex, 1);
      expect(tappedValue, isFalse);
    });

    testWidgets('Consecutive checkbox toggles stay perfectly synchronized across state updates',
        (tester) async {
      var content = '''
- [ ] Task 1
- [x] Task 2
- [ ] Task 3
''';
      final tappedLog = <(int, bool)>[];

      Widget buildWidget() {
        return MaterialApp(
          home: Scaffold(
            body: MarkdownView(
              content: content,
              onCheckboxToggled: (index, val) {
                tappedLog.add((index, val));
              },
            ),
          ),
        );
      }

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      // Tap task 3 (index 2, currently false)
      var cbWidgets = find.byType(Checkbox);
      expect(cbWidgets, findsNWidgets(3));
      expect(tester.widget<Checkbox>(cbWidgets.at(2)).value, isFalse);

      await tester.tap(cbWidgets.at(2));
      await tester.pumpAndSettle();

      expect(tappedLog.last, equals((2, true)));

      // Simulate parent updating content after save
      content = '''
- [ ] Task 1
- [x] Task 2
- [x] Task 3
''';
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      cbWidgets = find.byType(Checkbox);
      expect(tester.widget<Checkbox>(cbWidgets.at(2)).value, isTrue);

      // Now tap task 1 (index 0, currently false)
      await tester.tap(cbWidgets.at(0));
      await tester.pumpAndSettle();

      expect(tappedLog.last, equals((0, true)));

      content = '''
- [x] Task 1
- [x] Task 2
- [x] Task 3
''';
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      cbWidgets = find.byType(Checkbox);
      expect(tester.widget<Checkbox>(cbWidgets.at(0)).value, isTrue);
      expect(tester.widget<Checkbox>(cbWidgets.at(2)).value, isTrue);

      // Now tap task 2 (index 1, currently true)
      await tester.tap(cbWidgets.at(1));
      await tester.pumpAndSettle();

      expect(tappedLog.last, equals((1, false)));
    });
  });
}

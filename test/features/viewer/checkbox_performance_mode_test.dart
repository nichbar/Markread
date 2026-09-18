import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markread/core/models/user_preferences.dart';
import 'package:markread/features/viewer/services/markdown_checkbox_helper.dart';
import 'package:markread/features/viewer/widgets/markdown_view.dart';

void main() {
  group('Performance render mode (virtualized ListView) checkbox integration', () {
    testWidgets(
      'Performance mode correctly indexes, renders, and toggles checkboxes across multiple blocks',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());
        // Create a markdown document that splits into multiple distinct blocks.
        // In MarkdownBlockSplitter, headings, blank lines, and paragraphs split into separate blocks.
        var content = '''
# Block 1 - Introduction

Paragraph text here.

## Block 2 - First task list

- [ ] Task 0 (Block 2)
- [x] Task 1 (Block 2)

Some intermediate text in block 3.

## Block 4 - Second task list

- [ ] Task 2 (Block 4)
* [x] Task 3 (Block 4)
+ [ ] Task 4 (Block 4)

Another paragraph in block 5.

## Block 6 - Third task list

1. [ ] Task 5 (Block 6)
- [x] Task 6 (Block 6)
''';

        final tappedEvents = <(int, bool)>[];

        Widget buildView() {
          return MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 1200, // Large enough so all blocks are mounted
                child: MarkdownView(
                  content: content,
                  renderMode: MarkdownRenderMode.performance, // Force virtualized ListView
                  onCheckboxToggled: (index, val) {
                    tappedEvents.add((index, val));
                  },
                ),
              ),
            ),
          );
        }

        await tester.pumpWidget(buildView());
        await tester.pumpAndSettle();

        // Find all checkboxes rendered
        var cbFinders = find.byType(Checkbox);
        expect(cbFinders, findsNWidgets(7));

        // Initial values verification
        expect(tester.widget<Checkbox>(cbFinders.at(0)).value, isFalse); // Task 0
        expect(tester.widget<Checkbox>(cbFinders.at(1)).value, isTrue);  // Task 1
        expect(tester.widget<Checkbox>(cbFinders.at(2)).value, isFalse); // Task 2
        expect(tester.widget<Checkbox>(cbFinders.at(3)).value, isTrue);  // Task 3
        expect(tester.widget<Checkbox>(cbFinders.at(4)).value, isFalse); // Task 4
        expect(tester.widget<Checkbox>(cbFinders.at(5)).value, isFalse); // Task 5
        expect(tester.widget<Checkbox>(cbFinders.at(6)).value, isTrue);  // Task 6

        // 1. Tap Task 4 (in Block 4, index 4, currently false)
        await tester.tap(cbFinders.at(4));
        await tester.pumpAndSettle();

        expect(tappedEvents.last, equals((4, true)));

        // Update content via helper
        content = MarkdownCheckboxHelper.toggleCheckbox(
          content,
          targetIndex: 4,
          newValue: true,
        );

        await tester.pumpWidget(buildView());
        await tester.pumpAndSettle();

        cbFinders = find.byType(Checkbox);
        expect(tester.widget<Checkbox>(cbFinders.at(4)).value, isTrue);

        // 2. Tap Task 5 (in Block 6, index 5, currently false)
        await tester.tap(cbFinders.at(5));
        await tester.pumpAndSettle();

        expect(tappedEvents.last, equals((5, true)));

        content = MarkdownCheckboxHelper.toggleCheckbox(
          content,
          targetIndex: 5,
          newValue: true,
        );

        await tester.pumpWidget(buildView());
        await tester.pumpAndSettle();

        cbFinders = find.byType(Checkbox);
        expect(tester.widget<Checkbox>(cbFinders.at(5)).value, isTrue);

        // 3. Tap Task 1 (in Block 2, index 1, currently true -> should toggle to false)
        await tester.tap(cbFinders.at(1));
        await tester.pumpAndSettle();

        expect(tappedEvents.last, equals((1, false)));

        content = MarkdownCheckboxHelper.toggleCheckbox(
          content,
          targetIndex: 1,
          newValue: false,
        );

        await tester.pumpWidget(buildView());
        await tester.pumpAndSettle();

        cbFinders = find.byType(Checkbox);
        expect(tester.widget<Checkbox>(cbFinders.at(1)).value, isFalse);
        expect(tester.widget<Checkbox>(cbFinders.at(4)).value, isTrue);
        expect(tester.widget<Checkbox>(cbFinders.at(5)).value, isTrue);
      },
    );

    testWidgets(
      'Performance mode with viewport scrolling preserves checkbox indices when scrolled off-screen and back',
      (tester) async {
        // Construct a tall document with checkboxes spread far apart
        final buffer = StringBuffer();
        buffer.writeln('# Top Section\n');
        buffer.writeln('- [ ] Top task 0\n- [ ] Top task 1\n');

        // Add 30 filler paragraphs to ensure list virtualization occurs
        for (var i = 0; i < 30; i++) {
          buffer.writeln('### Section $i\n');
          buffer.writeln('Paragraph line $i with some body text.\n');
        }

        buffer.writeln('### Bottom Section\n');
        buffer.writeln('- [ ] Bottom task 2\n- [x] Bottom task 3\n');

        var docContent = buffer.toString();
        final scrollController = ScrollController();
        final tappedLog = <(int, bool)>[];

        Widget buildScrollableView() {
          return MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 400, // Small viewport to force scrolling & virtualization
                child: MarkdownView(
                  content: docContent,
                  scrollController: scrollController,
                  renderMode: MarkdownRenderMode.performance,
                  onCheckboxToggled: (index, val) {
                    tappedLog.add((index, val));
                  },
                ),
              ),
            ),
          );
        }

        await tester.pumpWidget(buildScrollableView());
        await tester.pumpAndSettle();

        // At the top, bottom checkboxes are NOT mounted
        expect(find.text('Bottom task 2'), findsNothing);

        // Tap top checkbox 1
        final topCheckboxes = find.byType(Checkbox);
        expect(topCheckboxes, findsNWidgets(2));
        await tester.tap(topCheckboxes.at(1));
        await tester.pumpAndSettle();

        expect(tappedLog.last, equals((1, true)));

        docContent = MarkdownCheckboxHelper.toggleCheckbox(
          docContent,
          targetIndex: 1,
          newValue: true,
        );

        await tester.pumpWidget(buildScrollableView());
        await tester.pumpAndSettle();

        // Scroll all the way to the bottom
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
        await tester.pumpAndSettle();

        // Now bottom checkboxes are mounted and top checkboxes are recycled
        expect(find.text('Bottom task 2'), findsOneWidget);

        final bottomCheckboxes = find.byType(Checkbox);
        expect(bottomCheckboxes, findsWidgets);

        // Tap Bottom task 2 (global index 2, initially false)
        await tester.tap(bottomCheckboxes.first);
        await tester.pumpAndSettle();

        expect(tappedLog.last, equals((2, true)));

        docContent = MarkdownCheckboxHelper.toggleCheckbox(
          docContent,
          targetIndex: 2,
          newValue: true,
        );

        await tester.pumpWidget(buildScrollableView());
        await tester.pumpAndSettle();

        // Scroll back to the top
        scrollController.jumpTo(0);
        await tester.pumpAndSettle();

        // Verify top checkbox 1 remained checked (true)
        final restoredTopCheckboxes = find.byType(Checkbox);
        expect(tester.widget<Checkbox>(restoredTopCheckboxes.at(1)).value, isTrue);

        // Tap top checkbox 0 (global index 0)
        await tester.tap(restoredTopCheckboxes.at(0));
        await tester.pumpAndSettle();

        expect(tappedLog.last, equals((0, true)));
      },
    );
  });
}

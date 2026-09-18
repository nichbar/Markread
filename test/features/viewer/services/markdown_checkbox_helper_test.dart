// test/features/viewer/services/markdown_checkbox_helper_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:markread/features/viewer/services/markdown_checkbox_helper.dart';

void main() {
  group('MarkdownCheckboxHelper', () {
    test('findCheckboxes detects various checkbox styles', () {
      const markdown = '''
# Heading

- [ ] Task 1
* [x] Task 2
+ [X] Task 3
1. [ ] Task 4
  - [x] Indented task
> - [ ] Quoted task
[ ] Standalone task
[x] Checked standalone
''';

      final checkboxes = MarkdownCheckboxHelper.findCheckboxes(markdown);
      expect(checkboxes.length, 8);

      expect(checkboxes[0].index, 0);
      expect(checkboxes[0].isChecked, isFalse);
      expect(checkboxes[0].lineText, '- [ ] Task 1');

      expect(checkboxes[1].index, 1);
      expect(checkboxes[1].isChecked, isTrue);
      expect(checkboxes[1].lineText, '* [x] Task 2');

      expect(checkboxes[2].index, 2);
      expect(checkboxes[2].isChecked, isTrue);
      expect(checkboxes[2].lineText, '+ [X] Task 3');

      expect(checkboxes[3].index, 3);
      expect(checkboxes[3].isChecked, isFalse);
      expect(checkboxes[3].lineText, '1. [ ] Task 4');

      expect(checkboxes[4].index, 4);
      expect(checkboxes[4].isChecked, isTrue);

      expect(checkboxes[5].index, 5);
      expect(checkboxes[5].isChecked, isFalse);

      expect(checkboxes[6].index, 6);
      expect(checkboxes[6].isChecked, isFalse);

      expect(checkboxes[7].index, 7);
      expect(checkboxes[7].isChecked, isTrue);
    });

    test('findCheckboxes ignores checkboxes inside code fences', () {
      const markdown = '''
# Before code

- [ ] Real Task 1

```dart
// Inside code fence
- [ ] Fake task in code
```

~~~markdown
- [x] Another fake in tilde fence
~~~

- [x] Real Task 2
''';

      final checkboxes = MarkdownCheckboxHelper.findCheckboxes(markdown);
      expect(checkboxes.length, 2);
      expect(checkboxes[0].lineText, '- [ ] Real Task 1');
      expect(checkboxes[1].lineText, '- [x] Real Task 2');
    });

    test('toggleCheckbox toggles unchecked to checked', () {
      const original = '''
# Notes

- [ ] Item 1
- [ ] Item 2
''';

      final updated = MarkdownCheckboxHelper.toggleCheckbox(
        original,
        targetIndex: 0,
        newValue: true,
      );

      expect(updated, '''
# Notes

- [x] Item 1
- [ ] Item 2
''');
    });

    test('toggleCheckbox toggles checked to unchecked', () {
      const original = '''
- [x] Item 1
- [X] Item 2
''';

      final updated0 = MarkdownCheckboxHelper.toggleCheckbox(
        original,
        targetIndex: 0,
        newValue: false,
      );
      expect(updated0, '''
- [ ] Item 1
- [X] Item 2
''');

      final updated1 = MarkdownCheckboxHelper.toggleCheckbox(
        original,
        targetIndex: 1,
        newValue: false,
      );
      expect(updated1, '''
- [x] Item 1
- [ ] Item 2
''');
    });

    test('toggleCheckbox handles CRLF line endings cleanly', () {
      const original = "# Title\r\n\r\n- [ ] Task 1\r\n- [x] Task 2\r\n";

      final updated = MarkdownCheckboxHelper.toggleCheckbox(
        original,
        targetIndex: 0,
        newValue: true,
      );

      expect(updated, "# Title\r\n\r\n- [x] Task 1\r\n- [x] Task 2\r\n");
    });

    test('toggleCheckbox returns unmodified string for out of bounds index', () {
      const original = '- [ ] Only item\n';
      expect(
        MarkdownCheckboxHelper.toggleCheckbox(original, targetIndex: -1, newValue: true),
        original,
      );
      expect(
        MarkdownCheckboxHelper.toggleCheckbox(original, targetIndex: 5, newValue: true),
        original,
      );
    });

    test('tagCheckboxes tags every checkbox with unique index and preserves content', () {
      const original = '''
# Heading

- [ ] Task 1
* [x] Task 2
+ [ ] Task 3
1. [x] Task 4

```
- [ ] Code block checkbox is not tagged
```
''';

      final tagged = MarkdownCheckboxHelper.tagCheckboxes(original);
      expect(tagged, contains('- \uE0030\uE004[ ] Task 1'));
      expect(tagged, contains('* \uE0031\uE004[x] Task 2'));
      expect(tagged, contains('+ \uE0032\uE004[ ] Task 3'));
      expect(tagged, contains('1. \uE0033\uE004[x] Task 4'));
      expect(tagged, contains('```\n- [ ] Code block checkbox is not tagged\n```'));

      final stripped = MarkdownCheckboxHelper.stripCheckboxTags(tagged);
      expect(stripped, original);
    });
  });
}

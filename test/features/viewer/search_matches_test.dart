import 'package:flutter_test/flutter_test.dart';
import 'package:markread/features/viewer/providers/viewer_provider.dart';

void main() {
  group('fencedCodeRanges', () {
    test('detects closed fence including markers', () {
      const text = 'Before\n\n```dart\nvoid main() {}\n```\n\nAfter\n';
      final ranges = fencedCodeRanges(text);
      expect(ranges.length, 1);
      final (start, end) = ranges.single;
      expect(text.substring(start, end), startsWith('```dart'));
      expect(text.substring(start, end).trimRight(), endsWith('```'));
      expect(text.substring(start, end), contains('void main()'));
    });

    test('unclosed fence runs to EOF', () {
      const text = 'Intro\n```\ncode only';
      final ranges = fencedCodeRanges(text);
      expect(ranges.length, 1);
      final (start, end) = ranges.single;
      expect(start, text.indexOf('```'));
      expect(end, text.length);
    });

    test('no fences', () {
      expect(fencedCodeRanges('plain text\n# heading'), isEmpty);
    });
  });

  group('inlineCodeRanges', () {
    test('detects inline code spans', () {
      const text = 'use `needle` and more';
      final ranges = inlineCodeRanges(text);
      expect(ranges.length, 1);
      final (start, end) = ranges.single;
      expect(text.substring(start, end), '`needle`');
    });

    test('ignores ticks inside fenced blocks', () {
      const text = '```\n`fake`\n```\nreal `ok`\n';
      final fenced = fencedCodeRanges(text);
      final inline = inlineCodeRanges(text, fencedRanges: fenced);
      expect(inline.length, 1);
      expect(text.substring(inline.single.$1, inline.single.$2), '`ok`');
    });
  });

  group('findSearchMatches', () {
    test('finds all case-insensitive matches without excludes', () {
      const text = 'Foo bar FOO baz foo';
      expect(findSearchMatches(text, 'foo'), [0, 8, 16]);
    });

    test('still finds matches inside fenced and inline code', () {
      const text = '''
needle outside and `needle inline`

```
needle inside
```

needle again
''';
      final all = findSearchMatches(text, 'needle');
      expect(all.length, 4);
    });

    test('optional excludeRanges can filter (used only for helpers/tests)', () {
      const text = 'a needle `needle` needle';
      final ranges = codeExcludeRanges(text);
      final filtered = findSearchMatches(
        text,
        'needle',
        excludeRanges: ranges,
      );
      expect(filtered.length, 2);
    });

    test('empty query yields no matches', () {
      expect(findSearchMatches('abc', ''), isEmpty);
    });
  });
}

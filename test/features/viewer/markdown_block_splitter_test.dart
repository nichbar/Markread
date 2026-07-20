import 'package:flutter_test/flutter_test.dart';
import 'package:markread/core/services/file_content_processor.dart';
import 'package:markread/features/viewer/services/markdown_block_splitter.dart';

void main() {
  group('splitMarkdownBlocks', () {
    test('simple paragraphs split on blank lines', () {
      const input = 'Hello world\n\nSecond paragraph\n\nThird';
      final blocks = splitMarkdownBlocks(input);

      expect(blocks.map((b) => b.text.trim()), [
        'Hello world',
        'Second paragraph',
        'Third',
      ]);
      expect(blocks.every((b) => b.headingIndex == null), isTrue);
    });

    test('headings each own block; headingIndex matches parseHeadings order', () {
      const input = '# Title\n\nBody\n\n## Section\n\nMore\n\n### Deep\n\n#### Skip level\n';
      final blocks = splitMarkdownBlocks(input);
      final headings = parseHeadings(input);

      final headingBlocks =
          blocks.where((b) => b.headingIndex != null).toList();
      expect(headingBlocks.length, headings.length);
      expect(headingBlocks.length, 3);

      for (var i = 0; i < headings.length; i++) {
        expect(headingBlocks[i].headingIndex, i);
        expect(headingBlocks[i].text.trim(), contains(headings[i].text));
      }

      // H4 is a block but has no TOC headingIndex.
      final h4 = blocks.where((b) => b.text.contains('#### Skip'));
      expect(h4.length, 1);
      expect(h4.first.headingIndex, isNull);
    });

    test('ordered list: each N. item is its own block; numbers preserved', () {
      const input = '## Day\n\n1. first item\n2. second item\n3. third item\n';
      final blocks = splitMarkdownBlocks(input);

      final items = blocks
          .where((b) => RegExp(r'^\d+\.\s').hasMatch(b.text.trimLeft()))
          .toList();
      expect(items.length, 3);
      expect(items[0].text, contains('1. first item'));
      expect(items[1].text, contains('2. second item'));
      expect(items[2].text, contains('3. third item'));
      expect(blocks.where((b) => b.headingIndex == 0).length, 1);
    });

    test('unordered list items each own block', () {
      const input = '- alpha\n* beta\n- gamma\n';
      final blocks = splitMarkdownBlocks(input);
      expect(blocks.length, 3);
      expect(blocks[0].text, contains('- alpha'));
      expect(blocks[1].text, contains('* beta'));
      expect(blocks[2].text, contains('- gamma'));
    });

    test('fenced code not split mid-fence', () {
      const input = 'Before\n\n```dart\nvoid main() {\n  print(1);\n}\n```\n\nAfter\n';
      final blocks = splitMarkdownBlocks(input);

      final fence = blocks.where((b) => b.text.contains('```dart')).toList();
      expect(fence.length, 1);
      expect(fence.single.text, contains('void main()'));
      expect(fence.single.text, contains('```'));
      expect(fence.single.text.trim().endsWith('```'), isTrue);
    });

    test('blockquote consecutive > lines stay one block', () {
      const input = 'Intro\n\n> line one\n> line two\n> line three\n\nOutro\n';
      final blocks = splitMarkdownBlocks(input);

      final quote = blocks.where((b) => b.text.contains('> line one')).toList();
      expect(quote.length, 1);
      expect(quote.single.text, contains('> line two'));
      expect(quote.single.text, contains('> line three'));
    });

    test('table multi-row stays one block', () {
      const input = '| a | b |\n| --- | --- |\n| 1 | 2 |\n| 3 | 4 |\n';
      final blocks = splitMarkdownBlocks(input);

      expect(blocks.length, 1);
      expect(blocks.single.text, contains('| a | b |'));
      expect(blocks.single.text, contains('| 3 | 4 |'));
    });

    test(r'\r\n normalized; offsets consistent', () {
      const input = '## Head\r\n\r\n1. item one\r\n2. item two\r\n';
      final blocks = splitMarkdownBlocks(input);

      expect(blocks.any((b) => b.text.contains('\r')), isFalse);
      for (final b in blocks) {
        expect(b.startOffset, lessThan(b.endOffset));
        // Offsets refer to normalized string reconstructed from blocks loosely.
        expect(b.text, isNotEmpty);
      }
      expect(blocks.where((b) => b.headingIndex != null).length, 1);
      expect(
        blocks.where((b) => b.text.trimLeft().startsWith(RegExp(r'\d+\.'))).length,
        2,
      );
    });

    test('v2ex shape fixture slice: heading + list items', () {
      const input = '''
# V2EX 热门帖子

## 2025-01-01

1. [国产笔记本，主要想性价比/高配置/不出问题，不在乎面子，选哪个？](https://www.v2ex.com/t/1101747)
2. [职业炒股几年脱离社会，如何破局？](https://www.v2ex.com/t/1101802)
3. [你喜欢使用 Java 下的哪个 web 框架？](https://www.v2ex.com/t/1101726)
4. [有见过国内只用微信支付从来不装支付宝的人么?](https://www.v2ex.com/t/1101711)
5. [新年第一天出了事故 我全责](https://www.v2ex.com/t/1101811)
6. [最近看到一个帖子在探讨个体户上架的问题？ 我有两句话要说](https://www.v2ex.com/t/1101786)
7. [京东车品类目的价格无底线乱搞](https://www.v2ex.com/t/1101740)

## 2025-01-02

8. [意外得到一笔钱， 100 万，那么问题来了](https://www.v2ex.com/t/1101896)
9. [2025, 留下你最近的烦恼吧](https://www.v2ex.com/t/1101874)
10. [postman 太臃肿，求推荐 mac 下的轻量替代品](https://www.v2ex.com/t/1101928)
''';

      final blocks = splitMarkdownBlocks(input);
      final headings = parseHeadings(input);
      final headingBlocks =
          blocks.where((b) => b.headingIndex != null).toList();
      final listBlocks = blocks
          .where((b) => RegExp(r'^\d+\.\s').hasMatch(b.text.trimLeft()))
          .toList();

      expect(headingBlocks.length, headings.length);
      expect(headingBlocks.length, 3); // # + two ##
      expect(listBlocks.length, 10);
      for (var i = 0; i < headingBlocks.length; i++) {
        expect(headingBlocks[i].headingIndex, i);
      }
      expect(listBlocks.first.text, contains('1. ['));
      expect(listBlocks.last.text, contains('10. ['));
    });

    test('display math stays atomic', () {
      const input = 'Before\n\n\\[\na + b\n\\]\n\nAfter\n';
      final blocks = splitMarkdownBlocks(input);
      final math = blocks.where((b) => b.text.contains(r'\[')).toList();
      expect(math.length, 1);
      expect(math.single.text, contains('a + b'));
      expect(math.single.text, contains(r'\]'));
    });

    test('search markers stay inside their line block', () {
      const input =
          '## Sec\n\n1. hello \uE0000\uE001world\uE002 there\n2. next\n';
      final blocks = splitMarkdownBlocks(input);
      final withMatch =
          blocks.where((b) => b.text.contains('\uE0000\uE001')).toList();
      expect(withMatch.length, 1);
      expect(withMatch.single.text, contains('1. hello'));
      expect(withMatch.single.text, isNot(contains('2. next')));
    });

    test('empty input yields empty list', () {
      expect(splitMarkdownBlocks(''), isEmpty);
      expect(splitMarkdownBlocks('\n\n'), isEmpty);
    });

    test('paragraph blanks set hasPrecedingParagraphBreak on B and C only', () {
      const input = 'A\n\nB\n\nC';
      final blocks = splitMarkdownBlocks(input);

      expect(blocks.map((b) => b.text.trim()), ['A', 'B', 'C']);
      expect(blocks[0].hasPrecedingParagraphBreak, isFalse);
      expect(blocks[1].hasPrecedingParagraphBreak, isTrue);
      expect(blocks[2].hasPrecedingParagraphBreak, isTrue);
    });

    test('multi-blank run collapses to a single break flag', () {
      const input = 'A\n\n\n\nB';
      final blocks = splitMarkdownBlocks(input);

      expect(blocks.length, 2);
      expect(blocks[0].hasPrecedingParagraphBreak, isFalse);
      expect(blocks[1].hasPrecedingParagraphBreak, isTrue);
    });

    test('dense ordered list has no preceding breaks', () {
      const input = '1. a\n2. b';
      final blocks = splitMarkdownBlocks(input);

      expect(blocks.length, 2);
      expect(blocks.every((b) => !b.hasPrecedingParagraphBreak), isTrue);
    });

    test('blank between ordered items flags only the second', () {
      const input = '1. a\n\n2. b';
      final blocks = splitMarkdownBlocks(input);

      expect(blocks.length, 2);
      expect(blocks[0].hasPrecedingParagraphBreak, isFalse);
      expect(blocks[1].hasPrecedingParagraphBreak, isTrue);
    });

    test('fence with internal blank is one block without mid-fence spacer', () {
      const input = 'Before\n\n```dart\nline1\n\nline2\n```\n\nAfter\n';
      final blocks = splitMarkdownBlocks(input);

      final fence = blocks.where((b) => b.text.contains('```dart')).toList();
      expect(fence.length, 1);
      expect(fence.single.text, contains('line1'));
      expect(fence.single.text, contains('line2'));
      // Fence itself follows a blank after Before.
      expect(fence.single.hasPrecedingParagraphBreak, isTrue);

      final after = blocks.where((b) => b.text.trim() == 'After').toList();
      expect(after.length, 1);
      expect(after.single.hasPrecedingParagraphBreak, isTrue);

      // No separate spacer blocks emitted for internal fence blanks.
      expect(blocks.length, 3);
    });

    test('leading and trailing blanks ignored for break flags', () {
      const input = '\n\nFirst\n\nSecond\n\n\n';
      final blocks = splitMarkdownBlocks(input);

      expect(blocks.map((b) => b.text.trim()), ['First', 'Second']);
      expect(blocks[0].hasPrecedingParagraphBreak, isFalse);
      expect(blocks[1].hasPrecedingParagraphBreak, isTrue);
    });

    test('heading indices still match parseHeadings order with breaks', () {
      const input = '# Title\n\nBody\n\n## Section\n\nMore\n';
      final blocks = splitMarkdownBlocks(input);
      final headings = parseHeadings(input);
      final headingBlocks =
          blocks.where((b) => b.headingIndex != null).toList();

      expect(headingBlocks.length, headings.length);
      for (var i = 0; i < headings.length; i++) {
        expect(headingBlocks[i].headingIndex, i);
      }
      // Body / More follow blanks.
      final body = blocks.firstWhere((b) => b.text.trim() == 'Body');
      final more = blocks.firstWhere((b) => b.text.trim() == 'More');
      expect(body.hasPrecedingParagraphBreak, isTrue);
      expect(more.hasPrecedingParagraphBreak, isTrue);
      // Second heading also follows a blank.
      expect(headingBlocks[1].hasPrecedingParagraphBreak, isTrue);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markread/features/viewer/widgets/search_code_highlight.dart';

void main() {
  group('buildQueryHighlightSpans', () {
    const style = TextStyle(fontSize: 14);
    const bg = Color(0xFFFFFF00);

    test('empty query is plain text', () {
      final spans = buildQueryHighlightSpans(
        text: 'hello world',
        query: '',
        style: style,
        highlightBg: bg,
      );
      expect(spans.length, 1);
      expect((spans.single as TextSpan).text, 'hello world');
    });

    test('highlights case-insensitive hits', () {
      final spans = buildQueryHighlightSpans(
        text: 'Foo bar FOO',
        query: 'foo',
        style: style,
        highlightBg: bg,
      );
      final texts = spans.map((s) => (s as TextSpan).text).toList();
      expect(texts, ['Foo', ' bar ', 'FOO']);
      expect((spans[0] as TextSpan).style?.backgroundColor, bg);
      expect((spans[1] as TextSpan).style?.backgroundColor, isNull);
      expect((spans[2] as TextSpan).style?.backgroundColor, bg);
    });

    test('no match keeps single span', () {
      final spans = buildQueryHighlightSpans(
        text: 'abc',
        query: 'z',
        style: style,
        highlightBg: bg,
      );
      expect(spans.length, 1);
      expect((spans.single as TextSpan).text, 'abc');
    });
  });

  testWidgets('SearchHighlightScope notifies on query change', (tester) async {
    String? seen;
    await tester.pumpWidget(
      MaterialApp(
        home: SearchHighlightScope(
          query: 'a',
          child: Builder(
            builder: (context) {
              seen = SearchHighlightScope.queryOf(context);
              return Text(seen ?? '');
            },
          ),
        ),
      ),
    );
    expect(seen, 'a');

    await tester.pumpWidget(
      MaterialApp(
        home: SearchHighlightScope(
          query: 'b',
          child: Builder(
            builder: (context) {
              seen = SearchHighlightScope.queryOf(context);
              return Text(seen ?? '');
            },
          ),
        ),
      ),
    );
    expect(seen, 'b');
  });
}

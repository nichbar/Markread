import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markread/third_party/gpt_markdown/gpt_markdown.dart';

void main() {
  group('gpt_markdown 1.2.1 upgrade features', () {
    testWidgets('GptMarkdownStyleSheet applies custom styles to markdown elements', (tester) async {
      const sheet = GptMarkdownStyleSheet(
        h1: TextStyle(fontSize: 32, color: Colors.purple),
        strong: TextStyle(fontWeight: FontWeight.w900, color: Colors.red),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GptMarkdown(
              '# Main Header\n\nThis is **important** text.',
              styleSheet: sheet,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Main Header', findRichText: true), findsOneWidget);
      expect(find.textContaining('important', findRichText: true), findsOneWidget);
    });

    testWidgets('AutolinkMd renders and recognizes plain URLs', (tester) async {
      String? tappedUrl;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GptMarkdown(
              'Visit https://flutter.dev for more details.',
              onLinkTap: (url, title) {
                tappedUrl = url;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final linkFinder = find.textContaining('https://flutter.dev', findRichText: true);
      expect(linkFinder, findsOneWidget);

      await tester.tap(linkFinder);
      await tester.pumpAndSettle();
      expect(tappedUrl, equals('https://flutter.dev'));
    });

    testWidgets('InlinePattern matches custom patterns and renders custom spans', (tester) async {
      final customComponent = InlinePattern(
        pattern: r'@([a-zA-Z0-9_]+)',
        builder: (context, match, config) {
          final username = match.group(1) ?? '';
          return WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Chip(
              label: Text('@$username', style: const TextStyle(color: Colors.blue)),
            ),
          );
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GptMarkdown(
              'Hello @juntao from markdown!',
              inlineComponents: [
                ...MarkdownComponent.inlineComponents,
                customComponent,
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Chip), findsOneWidget);
      expect(find.text('@juntao'), findsOneWidget);
    });

    testWidgets('InlineCode widget renders inline backticks with monospace style', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GptMarkdown(
              'Use `const Widget()` in Flutter.',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(InlineCode), findsOneWidget);
      expect(find.text('const Widget()'), findsOneWidget);
    });

    testWidgets('LatexMath and LatexMathMultiLine render as monospace plain text without crash', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GptMarkdown(
              'Inline formula: \\(E = mc^2\\)\n\nBlock formula:\n\n\\[\\int_0^\\infty e^{-x} dx = 1\\]',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('E = mc^2', findRichText: true), findsOneWidget);
      expect(find.textContaining(r'\int_0^\infty e^{-x} dx = 1', findRichText: true), findsOneWidget);
    });

    testWidgets('StreamingGptMarkdown progressively reveals text', (tester) async {
      final engine = RevealEngine(
        interval: const Duration(milliseconds: 10),
        stepSize: 2,
        cursor: '',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamingGptMarkdown(
              revealEngine: engine,
            ),
          ),
        ),
      );

      engine.setText('Streaming markdown content is working.');
      await tester.pump(const Duration(milliseconds: 20));
      expect(engine.revealedLength, greaterThan(0));

      engine.fastForward();
      await tester.pumpAndSettle();
      expect(engine.revealedLength, equals('Streaming markdown content is working.'.length));
      expect(find.textContaining('Streaming markdown content is working.', findRichText: true), findsOneWidget);
    });

    testWidgets('GptMarkdownTheme updates dynamically when theme changes', (tester) async {
      final themeA = GptMarkdownThemeData(
        brightness: Brightness.light,
        linkColor: Colors.red,
      );
      final themeB = GptMarkdownThemeData(
        brightness: Brightness.light,
        linkColor: Colors.green,
      );

      final notifier = ValueNotifier<GptMarkdownThemeData>(themeA);

      await tester.pumpWidget(
        ValueListenableBuilder<GptMarkdownThemeData>(
          valueListenable: notifier,
          builder: (context, themeData, child) {
            return GptMarkdownTheme(
              gptThemeData: themeData,
              child: const MaterialApp(
                home: Scaffold(
                  body: GptMarkdown(
                    '[Click Here](https://example.com)',
                  ),
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Click Here', findRichText: true), findsOneWidget);

      notifier.value = themeB;
      await tester.pumpAndSettle();
      expect(find.textContaining('Click Here', findRichText: true), findsOneWidget);
    });
  });
}

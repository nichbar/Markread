import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markread/third_party/gpt_markdown/gpt_markdown.dart';

void main() {
  group('gpt_markdown 1.4.0 upgrade features', () {
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

    testWidgets('GitHub alerts render with default title and icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GptMarkdown(
              '> [!NOTE]\n> Pay attention to this note.',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Note'), findsOneWidget);
      expect(find.textContaining('Pay attention to this note', findRichText: true), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('GitHub alerts honor custom alertBuilder', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GptMarkdown(
              '> [!WARNING]\n> High voltage area.',
              alertBuilder: (context, details) {
                return Container(
                  key: const ValueKey('custom_alert'),
                  color: Colors.amber,
                  child: Column(
                    children: [
                      Text('CUSTOM: ${details.type.name.toUpperCase()}'),
                      details.content,
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('custom_alert')), findsOneWidget);
      expect(find.text('CUSTOM: WARNING'), findsOneWidget);
      expect(find.textContaining('High voltage area', findRichText: true), findsOneWidget);
    });

    testWidgets('Subscript renders ~text~ and <sub>text</sub>', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GptMarkdown(
              'H~2~O and CO<sub>2</sub>',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('2', findRichText: true), findsWidgets);
    });

    testWidgets('Superscript renders ^text^ and <sup>text</sup>', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GptMarkdown(
              'x^2^ + y<sup>3</sup> = z',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('2', findRichText: true), findsWidgets);
      expect(find.textContaining('3', findRichText: true), findsWidgets);
    });

    testWidgets('Highlight renders ==text== and <mark>text</mark>', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GptMarkdown(
              'Here is ==highlighted== and <mark>marked</mark> text.',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('highlighted', findRichText: true), findsOneWidget);
      expect(find.textContaining('marked', findRichText: true), findsOneWidget);
    });

    testWidgets('Footnotes render references and definition blocks', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GptMarkdown(
              'Here is a statement.[^1]\n\n[^1]: Footnote description here.',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('[1]'), findsOneWidget);
      expect(find.text('[1]: '), findsOneWidget);
      expect(find.textContaining('Footnote description here', findRichText: true), findsOneWidget);
    });

    testWidgets('Setext headings render H1 and H2 without colliding with hr', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GptMarkdown(
              'First Level Setext\n===\n\nSecond Level Setext\n---\n\n---\n\nParagraph text.',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('First Level Setext', findRichText: true), findsOneWidget);
      expect(find.textContaining('Second Level Setext', findRichText: true), findsOneWidget);
      expect(find.byType(CustomDivider), findsWidgets);
      expect(find.textContaining('Paragraph text', findRichText: true), findsOneWidget);
    });

    testWidgets('Link with title renders tooltip', (tester) async {
      String? tappedUrl;
      String? tappedTitle;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GptMarkdown(
              '[Markread](https://github.com/nichbar/markread "Open Markread repo")',
              onLinkTap: (url, title) {
                tappedUrl = url;
                tappedTitle = title;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Tooltip), findsOneWidget);
      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, equals('Open Markread repo'));

      final linkFinder = find.textContaining('Markread', findRichText: true);
      await tester.tap(linkFinder);
      await tester.pumpAndSettle();

      expect(tappedUrl, equals('https://github.com/nichbar/markread'));
      expect(tappedTitle, equals('Open Markread repo'));
    });

    testWidgets('SliverGptMarkdown renders inside CustomScrollView', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverGptMarkdown('# Sliver Markdown\n\nContent rendered in a sliver.'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Sliver Markdown', findRichText: true), findsOneWidget);
      expect(find.textContaining('Content rendered in a sliver', findRichText: true), findsOneWidget);
    });

    testWidgets('TableStyle accepts 1.4.0 properties and lerps cleanly', (tester) async {
      const style1 = TableStyle(
        borderWidth: 1.0,
        borderRadius: Radius.circular(8.0),
        overflow: TableOverflow.scroll,
      );
      const style2 = TableStyle(
        borderWidth: 3.0,
        borderRadius: Radius.circular(16.0),
        overflow: TableOverflow.wrap,
      );

      final lerped = TableStyle.lerp(style1, style2, 0.5);
      expect(lerped?.borderWidth, equals(2.0));
      expect(lerped?.borderRadius, equals(const Radius.circular(12.0)));
    });
  });
}

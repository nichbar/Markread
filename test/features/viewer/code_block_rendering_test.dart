import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markread/features/viewer/widgets/github_code_style.dart';
import 'package:markread/features/viewer/widgets/source_code_view.dart';
import 'package:markread/third_party/gpt_markdown/gpt_markdown.dart';

void main() {
  group('Code block newline handling', () {
    testWidgets('GptMarkdown codeBuilder receives code without extra trailing newline', (tester) async {
      String? capturedCode;
      String? capturedName;
      bool? capturedClosed;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GptMarkdown(
              '```dart\nfinal x = 1;\n```',
              codeBuilder: (context, name, code, closed) {
                capturedName = name;
                capturedCode = code;
                capturedClosed = closed;
                return Text('Code: $code');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(capturedName, equals('dart'));
      expect(capturedCode, equals('final x = 1;'));
      expect(capturedClosed, isTrue);
    });

    testWidgets('GptMarkdown codeBuilder preserves multi-line code and internal blank lines', (tester) async {
      String? capturedCode;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GptMarkdown(
              '```dart\nfinal x = 1;\n\nfinal y = 2;\n```',
              codeBuilder: (context, name, code, closed) {
                capturedCode = code;
                return Text('Code: $code');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(capturedCode, equals('final x = 1;\n\nfinal y = 2;'));
    });

    testWidgets('githubCodeBlock renders code without trailing newline', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GptMarkdown(
              '```dart\nconst a = 100;\n```',
              codeBuilder: githubCodeBlock,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final selectableText = tester.widget<SelectableText>(find.byType(SelectableText));
      final textSpan = selectableText.textSpan;
      expect(textSpan, isNotNull);
      expect(textSpan!.toPlainText(), equals('const a = 100;'));
    });

    testWidgets('SourceCodeView strips file trailing newline to prevent extra blank line', (tester) async {
      const sourceContent = 'void main() {\n  print("hello");\n}\n';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SourceCodeView(
              content: sourceContent,
              language: 'dart',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final selectableText = tester.widget<SelectableText>(find.byType(SelectableText));
      final textSpan = selectableText.textSpan;
      expect(textSpan, isNotNull);
      expect(textSpan!.toPlainText(), equals('void main() {\n  print("hello");\n}'));
    });

    testWidgets('SourceCodeView preserves intentional internal blank lines', (tester) async {
      const sourceContent = 'void main() {\n\n  print("hello");\n}\n';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SourceCodeView(
              content: sourceContent,
              language: 'dart',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final selectableText = tester.widget<SelectableText>(find.byType(SelectableText));
      final textSpan = selectableText.textSpan;
      expect(textSpan, isNotNull);
      expect(textSpan!.toPlainText(), equals('void main() {\n\n  print("hello");\n}'));
    });
  });
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:markread/core/services/file_content_processor.dart';

void main() {
  group('processFileContent', () {
    test('markdown file parses headings and rendered mode', () {
      final text = '# Title\n\nHello\n\n## Section\n\nBody\n';
      final result = processFileContent(
        fileName: 'notes.md',
        bytes: Uint8List.fromList(utf8.encode(text)),
      );

      expect(result.fileName, 'notes.md');
      expect(result.fileContent, text);
      expect(result.isSourceCode, isFalse);
      expect(result.codeLanguage, isNull);
      expect(result.isBinary, isFalse);
      expect(result.viewMode, ProcessedViewMode.rendered);
      expect(result.warningMessage, isNull);
      expect(result.headings.length, 2);
      expect(result.headings[0].text, 'Title');
      expect(result.headings[0].level, 1);
      expect(result.headings[1].text, 'Section');
      expect(result.headings[1].level, 2);
    });

    test('known source extension is source code', () {
      final text = 'void main() {}';
      final result = processFileContent(
        fileName: 'main.dart',
        bytes: Uint8List.fromList(utf8.encode(text)),
      );

      expect(result.isSourceCode, isTrue);
      expect(result.codeLanguage, 'dart');
      expect(result.headings, isEmpty);
      expect(result.viewMode, ProcessedViewMode.rendered);
    });

    test('null bytes mark binary raw with warning', () {
      final bytes = Uint8List.fromList([0x00, 0x01, 0x02, 0x41]);
      final result = processFileContent(
        fileName: 'blob.bin',
        bytes: bytes,
      );

      expect(result.isBinary, isTrue);
      expect(result.viewMode, ProcessedViewMode.raw);
      expect(result.warningMessage, isNotNull);
    });

    test('empty content is fine', () {
      final result = processFileContent(
        fileName: 'empty.md',
        bytes: Uint8List(0),
      );

      expect(result.fileContent, isEmpty);
      expect(result.isBinary, isFalse);
      expect(result.headings, isEmpty);
    });
  });
}

// test/core/services/file_service_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:markread/core/services/file_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FileService', () {
    late FileService fileService;
    late Directory tempDir;

    setUp(() async {
      fileService = FileService();
      tempDir = await Directory.systemTemp.createTemp('markread_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('isMarkdownFile detects common markdown extensions', () {
      expect(fileService.isMarkdownFile('notes.md'), isTrue);
      expect(fileService.isMarkdownFile('DOC.MARKDOWN'), isTrue);
      expect(fileService.isMarkdownFile('guide.mdown'), isTrue);
      expect(fileService.isMarkdownFile('file.mkd'), isTrue);
      expect(fileService.isMarkdownFile('readme.txt'), isTrue);
      expect(fileService.isMarkdownFile('script.py'), isFalse);
      expect(fileService.isMarkdownFile('image.png'), isFalse);
    });

    test('detectLanguage maps extensions properly', () {
      expect(fileService.detectLanguage('main.dart'), 'dart');
      expect(fileService.detectLanguage('app.kt'), 'kotlin');
      expect(fileService.detectLanguage('index.js'), 'javascript');
      expect(fileService.detectLanguage('unknown.xyz'), isNull);
    });

    test('saveFile writes content directly to local filesystem path', () async {
      final testFile = File('${tempDir.path}/test_save.md');
      await fileService.saveFile(
        path: testFile.path,
        content: '# Test Title\n\nHello world',
      );

      expect(await testFile.exists(), isTrue);
      expect(await testFile.readAsString(), '# Test Title\n\nHello world');
    });

    test('saveFile overwrites existing content cleanly', () async {
      final testFile = File('${tempDir.path}/test_overwrite.md');
      await testFile.writeAsString('Original long content that should be replaced');

      await fileService.saveFile(
        path: testFile.path,
        content: 'Short',
      );

      expect(await testFile.readAsString(), 'Short');
    });

    test('ReadOnlyFileException has readable toString message', () {
      const ex = ReadOnlyFileException('Permission denied');
      expect(ex.toString(), contains('Permission denied'));
    });
  });
}

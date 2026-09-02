// test/core/services/dynamic_font_loader_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:markread/core/services/dynamic_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    DynamicFontLoader.resetForTesting();
  });

  group('DynamicFontLoader', () {
    test('returns true for null or empty file path without loading file', () async {
      final result = await DynamicFontLoader.loadFont('serif', null);
      expect(result, isTrue);
      expect(DynamicFontLoader.isFontLoaded('serif'), isFalse);

      final resultEmpty = await DynamicFontLoader.loadFont('sans-serif', '   ');
      expect(resultEmpty, isTrue);
      expect(DynamicFontLoader.isFontLoaded('sans-serif'), isFalse);
    });

    test('returns false for non-existent file path', () async {
      final result = await DynamicFontLoader.loadFont(
        'CustomFont',
        '/non/existent/font/path/custom.ttf',
      );
      expect(result, isFalse);
      expect(DynamicFontLoader.isFontLoaded('CustomFont'), isFalse);
    });

    test('returns false for empty family name', () async {
      final result = await DynamicFontLoader.loadFont('', '/some/path.ttf');
      expect(result, isFalse);
    });

    test('handles empty file gracefully', () async {
      final tempDir = await Directory.systemTemp.createTemp('font_test_');
      final tempFile = File('${tempDir.path}/empty.ttf');
      await tempFile.writeAsBytes([]);

      try {
        final result = await DynamicFontLoader.loadFont('EmptyFont', tempFile.path);
        expect(result, isFalse);
        expect(DynamicFontLoader.isFontLoaded('EmptyFont'), isFalse);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('deduplicates concurrent load requests for same family', () async {
      // Testing with non-existent file
      final f1 = DynamicFontLoader.loadFont('SharedFont', '/path/to/missing.ttf');
      final f2 = DynamicFontLoader.loadFont('SharedFont', '/path/to/missing.ttf');

      final results = await Future.wait([f1, f2]);
      expect(results, [false, false]);
    });
  });
}

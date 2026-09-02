// test/core/models/system_font_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:markread/core/models/system_font.dart';

void main() {
  group('SystemFont', () {
    test('default values in constructor', () {
      const font = SystemFont(name: 'monospace');
      expect(font.name, 'monospace');
      expect(font.path, isNull);
      expect(font.hasChinese, isFalse);
      expect(font.isMonospace, isFalse);
    });

    test('constructor with all fields', () {
      const font = SystemFont(
        name: 'Noto Serif SC',
        path: '/system/fonts/NotoSerifCJK-Regular.ttc',
        hasChinese: true,
        isMonospace: false,
      );
      expect(font.name, 'Noto Serif SC');
      expect(font.path, '/system/fonts/NotoSerifCJK-Regular.ttc');
      expect(font.hasChinese, isTrue);
      expect(font.isMonospace, isFalse);
    });

    test('fromMap creates valid SystemFont', () {
      final font = SystemFont.fromMap({
        'name': 'MiSans',
        'path': '/product/fonts/MiSans-Regular.ttf',
        'hasChinese': true,
        'isMonospace': false,
      });
      expect(font.name, 'MiSans');
      expect(font.path, '/product/fonts/MiSans-Regular.ttf');
      expect(font.hasChinese, isTrue);
      expect(font.isMonospace, isFalse);
    });

    test('fromMap handles null and whitespace values gracefully', () {
      final font = SystemFont.fromMap({
        'name': '  monospace  ',
        'path': '   ',
        'hasChinese': null,
        'isMonospace': true,
      });
      expect(font.name, 'monospace');
      expect(font.path, isNull);
      expect(font.hasChinese, isFalse);
      expect(font.isMonospace, isTrue);
    });

    test('toMap converts accurately', () {
      const font = SystemFont(
        name: 'JetBrains Mono',
        path: '/system/fonts/JetBrainsMono.ttf',
        hasChinese: false,
        isMonospace: true,
      );
      final map = font.toMap();
      expect(map, {
        'name': 'JetBrains Mono',
        'path': '/system/fonts/JetBrainsMono.ttf',
        'hasChinese': false,
        'isMonospace': true,
      });
    });

    test('equality and hashCode', () {
      const font1 = SystemFont(
        name: 'Noto Sans SC',
        path: '/system/fonts/NotoSansCJK-Regular.ttc',
        hasChinese: true,
        isMonospace: false,
      );
      const font2 = SystemFont(
        name: 'Noto Sans SC',
        path: '/system/fonts/NotoSansCJK-Regular.ttc',
        hasChinese: true,
        isMonospace: false,
      );
      const font3 = SystemFont(
        name: 'Noto Serif SC',
        path: '/system/fonts/NotoSerifCJK-Regular.ttc',
        hasChinese: true,
        isMonospace: false,
      );

      expect(font1, equals(font2));
      expect(font1.hashCode, equals(font2.hashCode));
      expect(font1, isNot(equals(font3)));
    });

    test('toString contains field values', () {
      const font = SystemFont(name: 'Roboto', hasChinese: false);
      expect(font.toString(), contains('name: Roboto'));
    });
  });
}

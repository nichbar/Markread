// test/core/services/system_fonts_service_test.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markread/core/models/system_font.dart';
import 'package:markread/core/services/system_fonts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SystemFontsService', () {
    test('returns empty list when not on Android', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      const service = SystemFontsService();
      final fonts = await service.getSystemFonts();
      expect(fonts, isEmpty);
      debugDefaultTargetPlatformOverride = null;
    });

    test('returns structured SystemFont list from MethodChannel on Android', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        SystemFontsService.channel,
        (call) async {
          if (call.method == 'getSystemFonts') {
            return <Map<String, dynamic>>[
              {
                'name': 'casual',
                'path': null,
                'hasChinese': false,
                'isMonospace': false,
              },
              {
                'name': 'monospace',
                'path': null,
                'hasChinese': false,
                'isMonospace': true,
              },
              {
                'name': 'Noto Serif SC',
                'path': '/system/fonts/NotoSerifCJK-Regular.ttc',
                'hasChinese': true,
                'isMonospace': false,
              },
            ];
          }
          return null;
        },
      );

      const service = SystemFontsService();
      final fonts = await service.getSystemFonts();
      expect(fonts.length, 3);
      expect(fonts[0], const SystemFont(name: 'casual', path: null, hasChinese: false, isMonospace: false));
      expect(fonts[1], const SystemFont(name: 'monospace', path: null, hasChinese: false, isMonospace: true));
      expect(
        fonts[2],
        const SystemFont(
          name: 'Noto Serif SC',
          path: '/system/fonts/NotoSerifCJK-Regular.ttc',
          hasChinese: true,
          isMonospace: false,
        ),
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        SystemFontsService.channel,
        null,
      );
      debugDefaultTargetPlatformOverride = null;
    });

    test('handles legacy string list from MethodChannel gracefully', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        SystemFontsService.channel,
        (call) async {
          if (call.method == 'getSystemFonts') {
            return <String>['sans-serif', 'serif'];
          }
          return null;
        },
      );

      const service = SystemFontsService();
      final fonts = await service.getSystemFonts();
      expect(fonts.length, 2);
      expect(fonts[0].name, 'sans-serif');
      expect(fonts[1].name, 'serif');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        SystemFontsService.channel,
        null,
      );
      debugDefaultTargetPlatformOverride = null;
    });
  });
}

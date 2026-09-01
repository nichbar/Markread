// test/core/services/system_fonts_service_test.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
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

    test('returns fonts list from MethodChannel on Android', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        SystemFontsService.channel,
        (call) async {
          if (call.method == 'getSystemFonts') {
            return <String>['casual', 'monospace', 'sans-serif', 'serif'];
          }
          return null;
        },
      );

      const service = SystemFontsService();
      final fonts = await service.getSystemFonts();
      expect(fonts, ['casual', 'monospace', 'sans-serif', 'serif']);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        SystemFontsService.channel,
        null,
      );
      debugDefaultTargetPlatformOverride = null;
    });
  });
}

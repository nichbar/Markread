// test/core/providers/preferences_provider_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markread/core/providers/preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PreferencesNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('updates and clears fontFamily', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(preferencesProvider.notifier);
      expect(container.read(preferencesProvider).fontFamily, isNull);

      await notifier.setFontFamily('Roboto');
      expect(container.read(preferencesProvider).fontFamily, 'Roboto');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('fontFamily'), 'Roboto');

      await notifier.setFontFamily(null);
      expect(container.read(preferencesProvider).fontFamily, isNull);
      expect(prefs.getString('fontFamily'), isNull);
    });

    test('updates and clears codeFontFamily', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(preferencesProvider.notifier);
      expect(container.read(preferencesProvider).codeFontFamily, isNull);

      await notifier.setCodeFontFamily('JetBrains Mono');
      expect(
        container.read(preferencesProvider).codeFontFamily,
        'JetBrains Mono',
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('codeFontFamily'), 'JetBrains Mono');

      await notifier.setCodeFontFamily(null);
      expect(container.read(preferencesProvider).codeFontFamily, isNull);
      expect(prefs.getString('codeFontFamily'), isNull);
    });
  });
}

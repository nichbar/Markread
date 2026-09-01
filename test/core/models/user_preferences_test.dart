// test/core/models/user_preferences_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:markread/core/models/user_preferences.dart';

void main() {
  group('UserPreferences', () {
    test('default values', () {
      const prefs = UserPreferences();
      expect(prefs.appThemeMode, AppThemeMode.system);
      expect(prefs.markdownTheme, MarkdownTheme.github);
      expect(prefs.markdownRenderMode, MarkdownRenderMode.auto);
      expect(prefs.fontSize, 16.0);
      expect(prefs.lineHeight, 1.6);
      expect(prefs.textAlignment, ReadingTextAlign.left);
      expect(prefs.fontFamily, isNull);
    });

    test('copyWith updates fontFamily and clearFontFamily clears it', () {
      const prefs = UserPreferences();
      final updated = prefs.copyWith(fontFamily: 'serif');
      expect(updated.fontFamily, 'serif');

      final cleared = updated.copyWith(clearFontFamily: true);
      expect(cleared.fontFamily, isNull);
    });
  });
}

// lib/core/providers/preferences_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_preferences.dart';

class PreferencesNotifier extends Notifier<UserPreferences> {
  static const _keyAppThemeMode = 'appThemeMode';
  static const _keyMarkdownTheme = 'markdownTheme';
  static const _keyMarkdownRenderMode = 'markdownRenderMode';
  static const _keyFontSize = 'fontSize';
  static const _keyLineHeight = 'lineHeight';
  static const _keyTextAlignment = 'textAlignment';

  // Removed preference keys (cleared on load so stale values do not linger).
  static const _legacyKeyReaderLightTheme = 'readerLightTheme';
  static const _legacyKeyReaderDarkTheme = 'readerDarkTheme';

  @override
  UserPreferences build() {
    _loadFromSharedPreferences();
    return const UserPreferences();
  }

  Future<void> _loadFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    // Drop removed reader palette prefs if present.
    await prefs.remove(_legacyKeyReaderLightTheme);
    await prefs.remove(_legacyKeyReaderDarkTheme);

    final appThemeModeIndex = prefs.getInt(_keyAppThemeMode) ?? 0;
    final appThemeMode = appThemeModeIndex < AppThemeMode.values.length
        ? AppThemeMode.values[appThemeModeIndex]
        : AppThemeMode.system;

    // Default product theme is GitHub when no key is stored.
    final markdownThemeIndex =
        prefs.getInt(_keyMarkdownTheme) ?? MarkdownTheme.github.index;
    final markdownTheme = markdownThemeIndex < MarkdownTheme.values.length
        ? MarkdownTheme.values[markdownThemeIndex]
        : MarkdownTheme.github;

    final markdownRenderModeIndex =
        prefs.getInt(_keyMarkdownRenderMode) ?? MarkdownRenderMode.auto.index;
    final markdownRenderMode =
        markdownRenderModeIndex < MarkdownRenderMode.values.length
            ? MarkdownRenderMode.values[markdownRenderModeIndex]
            : MarkdownRenderMode.auto;

    final fontSize = prefs.getDouble(_keyFontSize) ?? 16.0;
    final lineHeight = prefs.getDouble(_keyLineHeight) ?? 1.6;
    final textAlignmentIndex = prefs.getInt(_keyTextAlignment) ?? 0;
    final textAlignment =
        textAlignmentIndex < ReadingTextAlign.values.length
            ? ReadingTextAlign.values[textAlignmentIndex]
            : ReadingTextAlign.left;

    state = UserPreferences(
      appThemeMode: appThemeMode,
      markdownTheme: markdownTheme,
      markdownRenderMode: markdownRenderMode,
      fontSize: fontSize,
      lineHeight: lineHeight,
      textAlignment: textAlignment,
    );
  }

  Future<void> setAppThemeMode(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAppThemeMode, mode.index);
    state = state.copyWith(appThemeMode: mode);
  }

  Future<void> setMarkdownTheme(MarkdownTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyMarkdownTheme, theme.index);
    state = state.copyWith(markdownTheme: theme);
  }

  Future<void> setMarkdownRenderMode(MarkdownRenderMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyMarkdownRenderMode, mode.index);
    state = state.copyWith(markdownRenderMode: mode);
  }

  Future<void> setFontSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyFontSize, size);
    state = state.copyWith(fontSize: size);
  }

  Future<void> setLineHeight(double height) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyLineHeight, height);
    state = state.copyWith(lineHeight: height);
  }

  Future<void> setTextAlignment(ReadingTextAlign alignment) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTextAlignment, alignment.index);
    state = state.copyWith(textAlignment: alignment);
  }
}

final preferencesProvider = NotifierProvider<PreferencesNotifier, UserPreferences>(
  PreferencesNotifier.new,
);

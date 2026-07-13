// lib/core/models/user_preferences.dart
enum AppThemeMode { system, light, dark }

enum ReaderLightTheme { light, sepia }

enum ReaderDarkTheme { dark, amoled }

enum ReadingTextAlign { left, justified }

class UserPreferences {
  final AppThemeMode appThemeMode;
  final ReaderLightTheme readerLightTheme;
  final ReaderDarkTheme readerDarkTheme;
  final double fontSize;
  final double lineHeight;
  final ReadingTextAlign textAlignment;

  const UserPreferences({
    this.appThemeMode = AppThemeMode.system,
    this.readerLightTheme = ReaderLightTheme.light,
    this.readerDarkTheme = ReaderDarkTheme.dark,
    this.fontSize = 16.0,
    this.lineHeight = 1.6,
    this.textAlignment = ReadingTextAlign.left,
  });

  UserPreferences copyWith({
    AppThemeMode? appThemeMode,
    ReaderLightTheme? readerLightTheme,
    ReaderDarkTheme? readerDarkTheme,
    double? fontSize,
    double? lineHeight,
    ReadingTextAlign? textAlignment,
  }) {
    return UserPreferences(
      appThemeMode: appThemeMode ?? this.appThemeMode,
      readerLightTheme: readerLightTheme ?? this.readerLightTheme,
      readerDarkTheme: readerDarkTheme ?? this.readerDarkTheme,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      textAlignment: textAlignment ?? this.textAlignment,
    );
  }
}

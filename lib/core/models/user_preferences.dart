// lib/core/models/user_preferences.dart
enum AppThemeMode { system, light, dark }

enum ReaderLightTheme { light, sepia }

enum ReaderDarkTheme { dark, amoled }

enum ReadingTextAlign { left, justified }

/// Document chrome for rendered markdown (headings, links, HR, code, tables).
/// Reader surface colors still come from light/dark reader prefs.
enum MarkdownTheme { standard, github }

/// Markdown render implementation.
///
/// - [auto]: virtualize files ≥ 100KB; small docs use monolith
/// - [performance]: always use virtualized block ListView
/// - [standard]: always use single-widget monolith scroll
enum MarkdownRenderMode { auto, performance, standard }

class UserPreferences {
  final AppThemeMode appThemeMode;
  final ReaderLightTheme readerLightTheme;
  final ReaderDarkTheme readerDarkTheme;
  final MarkdownTheme markdownTheme;
  final MarkdownRenderMode markdownRenderMode;
  final double fontSize;
  final double lineHeight;
  final ReadingTextAlign textAlignment;

  const UserPreferences({
    this.appThemeMode = AppThemeMode.system,
    this.readerLightTheme = ReaderLightTheme.light,
    this.readerDarkTheme = ReaderDarkTheme.dark,
    this.markdownTheme = MarkdownTheme.github,
    this.markdownRenderMode = MarkdownRenderMode.auto,
    this.fontSize = 16.0,
    this.lineHeight = 1.6,
    this.textAlignment = ReadingTextAlign.left,
  });

  UserPreferences copyWith({
    AppThemeMode? appThemeMode,
    ReaderLightTheme? readerLightTheme,
    ReaderDarkTheme? readerDarkTheme,
    MarkdownTheme? markdownTheme,
    MarkdownRenderMode? markdownRenderMode,
    double? fontSize,
    double? lineHeight,
    ReadingTextAlign? textAlignment,
  }) {
    return UserPreferences(
      appThemeMode: appThemeMode ?? this.appThemeMode,
      readerLightTheme: readerLightTheme ?? this.readerLightTheme,
      readerDarkTheme: readerDarkTheme ?? this.readerDarkTheme,
      markdownTheme: markdownTheme ?? this.markdownTheme,
      markdownRenderMode: markdownRenderMode ?? this.markdownRenderMode,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      textAlignment: textAlignment ?? this.textAlignment,
    );
  }
}

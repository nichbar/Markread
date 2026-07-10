// lib/features/viewer/widgets/reader_theme.dart
import 'package:flutter/material.dart';
import '../../../core/models/user_preferences.dart';
import '../../../core/theme/app_theme.dart';

class ReaderColors {
  final Color surface;
  final Color content;
  final Color muted;
  final Color container;

  const ReaderColors({
    required this.surface,
    required this.content,
    required this.muted,
    required this.container,
  });
}

final _lightColors = ReaderColors(
  surface: lightColorScheme.surface,
  content: lightColorScheme.onSurface,
  muted: lightColorScheme.onSurfaceVariant,
  container: lightColorScheme.surfaceContainerHighest,
);

final _darkColors = ReaderColors(
  surface: darkColorScheme.surface,
  content: darkColorScheme.onSurface,
  muted: darkColorScheme.onSurfaceVariant,
  container: darkColorScheme.surfaceContainerHighest,
);

const _sepiaColors = ReaderColors(
  surface: Color(0xFFF6EDE3),
  content: Color(0xFF201A17),
  muted: Color(0xFF51443B),
  container: Color(0xFFF7DED0),
);

const _amoledColors = ReaderColors(
  surface: Color(0xFF000000),
  content: Color(0xFFE6E6EB),
  muted: Color(0xB8E6E6EB),
  container: Color(0x1FE6E6EB),
);

ReaderColors resolveReaderLightColors(ReaderLightTheme theme) {
  switch (theme) {
    case ReaderLightTheme.light:
      return _lightColors;
    case ReaderLightTheme.sepia:
      return _sepiaColors;
  }
}

ReaderColors resolveReaderDarkColors(ReaderDarkTheme theme) {
  switch (theme) {
    case ReaderDarkTheme.dark:
      return _darkColors;
    case ReaderDarkTheme.amoled:
      return _amoledColors;
  }
}

/// Resolves viewer chrome colors based on active reader theme and surface mode.
/// Mirrors Android's viewerChromeColors().
ReaderColors viewerChromeColors({
  required ReaderLightTheme readerLightTheme,
  required ReaderDarkTheme readerDarkTheme,
  required bool isSurfaceDark,
}) {
  if (isSurfaceDark) {
    return resolveReaderDarkColors(readerDarkTheme);
  } else {
    return resolveReaderLightColors(readerLightTheme);
  }
}

/// Resolves a pair of (light, dark) reader colors for the current preferences.
({ReaderColors light, ReaderColors dark}) resolveReaderColorPair({
  required ReaderLightTheme readerLightTheme,
  required ReaderDarkTheme readerDarkTheme,
}) {
  return (
    light: resolveReaderLightColors(readerLightTheme),
    dark: resolveReaderDarkColors(readerDarkTheme),
  );
}

// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';

const lightColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF5F6368),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFE3E4E6),
  onPrimaryContainer: Color(0xFF1C1D1F),
  secondary: Color(0xFF5F6368),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFE4E5E7),
  onSecondaryContainer: Color(0xFF1D1E20),
  tertiary: Color(0xFF6B6B74),
  onTertiary: Color(0xFFFFFFFF),
  tertiaryContainer: Color(0xFFE8E8F0),
  onTertiaryContainer: Color(0xFF25252E),
  error: Color(0xFFBA1A1A),
  errorContainer: Color(0xFFFFDAD6),
  onError: Color(0xFFFFFFFF),
  onErrorContainer: Color(0xFF410002),
  surface: Color(0xFFFCFCFC),
  onSurface: Color(0xFF1A1A1A),
  surfaceContainerHighest: Color(0xFFE1E2E4),
  onSurfaceVariant: Color(0xFF44474A),
  outline: Color(0xFF757780),
  onInverseSurface: Color(0xFFF2F2F2),
  inverseSurface: Color(0xFF2F2F2F),
  inversePrimary: Color(0xFFB8BCC2),
  shadow: Color(0xFF000000),
  surfaceTint: Color(0xFF5F6368),
  outlineVariant: Color(0xFFC5C6CA),
  scrim: Color(0xFF000000),
);

const darkColorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFFB8BCC2),
  onPrimary: Color(0xFF2F3032),
  primaryContainer: Color(0xFF46494C),
  onPrimaryContainer: Color(0xFFE3E4E6),
  secondary: Color(0xFFBCC0C4),
  onSecondary: Color(0xFF303236),
  secondaryContainer: Color(0xFF47494D),
  onSecondaryContainer: Color(0xFFE4E5E7),
  tertiary: Color(0xFFCACBD3),
  onTertiary: Color(0xFF3B3B44),
  tertiaryContainer: Color(0xFF525259),
  onTertiaryContainer: Color(0xFFE8E8F0),
  error: Color(0xFFFFB4AB),
  errorContainer: Color(0xFF93000A),
  onError: Color(0xFF690005),
  onErrorContainer: Color(0xFFFFDAD6),
  surface: Color(0xFF111111),
  onSurface: Color(0xFFE4E4E4),
  surfaceContainerHighest: Color(0xFF44474A),
  onSurfaceVariant: Color(0xFFC5C6CA),
  outline: Color(0xFF8F9195),
  onInverseSurface: Color(0xFF111111),
  inverseSurface: Color(0xFFE4E4E4),
  inversePrimary: Color(0xFF5F6368),
  shadow: Color(0xFF000000),
  surfaceTint: Color(0xFFB8BCC2),
  outlineVariant: Color(0xFF44474A),
  scrim: Color(0xFF000000),
);

ThemeData buildLightTheme() {
  return ThemeData(
    colorScheme: lightColorScheme,
    useMaterial3: true,
  );
}

ThemeData buildDarkTheme() {
  return ThemeData(
    colorScheme: darkColorScheme,
    useMaterial3: true,
  );
}

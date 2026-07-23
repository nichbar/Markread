// lib/features/viewer/widgets/reader_theme.dart
import 'package:flutter/material.dart';
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

/// Resolves reader surface colors from brightness only (app light/dark schemes).
ReaderColors resolveReaderColors({required bool isSurfaceDark}) {
  return isSurfaceDark ? _darkColors : _lightColors;
}

import 'package:material_ui/material_ui.dart';

/// Helper to lerp nullable [TextStyle]s safely.
TextStyle? lerpTextStyle(TextStyle? a, TextStyle? b, double t) {
  return TextStyle.lerp(a, b, t);
}

/// Interpolates between two optional doubles.
double? lerpDouble(double? a, double? b, double t) {
  if (a == null && b == null) {
    return null;
  }
  final start = a ?? b;
  final end = b ?? a;
  if (start == null || end == null) {
    return null;
  }
  return start + (end - start) * t;
}


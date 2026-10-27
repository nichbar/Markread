import 'package:material_ui/material_ui.dart';

/// Helper to lerp nullable [TextStyle]s safely.
TextStyle? lerpTextStyle(TextStyle? a, TextStyle? b, double t) {
  return TextStyle.lerp(a, b, t);
}

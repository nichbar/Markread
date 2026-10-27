import 'package:material_ui/material_ui.dart';
import 'style_lerp.dart';

/// How superscript and subscript text — `<sup>`, `<sub>`, `^sup^`, `~sub~` — is drawn.
@immutable
class ScriptStyle {
  /// Creates a ScriptStyle. Null fields defer to the default.
  const ScriptStyle({this.scale, this.color})
    : assert(scale == null || scale > 0);

  /// The text's size as a fraction of the surrounding text. Defaults to 0.75.
  final double? scale;

  /// The text colour. Defaults to the surrounding text's.
  final Color? color;

  /// The default [scale].
  static const double defaultScale = 0.75;

  /// This style, with any unset field taken from [other], field by field.
  ScriptStyle merge(ScriptStyle? other) {
    if (other == null) {
      return this;
    }
    return ScriptStyle(
      scale: scale ?? other.scale,
      color: color ?? other.color,
    );
  }

  /// A copy with the given fields replaced.
  ScriptStyle copyWith({double? scale, Color? color}) {
    return ScriptStyle(scale: scale ?? this.scale, color: color ?? this.color);
  }

  /// Linearly interpolates between two styles.
  static ScriptStyle? lerp(ScriptStyle? a, ScriptStyle? b, double t) {
    if (a == null && b == null) {
      return null;
    }
    if (a == null) {
      return t < 0.5 ? null : b;
    }
    if (b == null) {
      return t < 0.5 ? a : null;
    }
    return ScriptStyle(
      scale: lerpDouble(a.scale, b.scale, t),
      color: Color.lerp(a.color, b.color, t),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ScriptStyle && other.scale == scale && other.color == color;
  }

  @override
  int get hashCode => Object.hash(scale, color);
}

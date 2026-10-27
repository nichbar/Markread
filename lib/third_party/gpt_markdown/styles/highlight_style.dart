import 'package:material_ui/material_ui.dart';

/// How highlighted text — `<mark>` or `==highlight==` — is drawn.
@immutable
class HighlightStyle {
  /// Creates a HighlightStyle. Null fields defer to the default.
  const HighlightStyle({this.backgroundColor, this.color});

  /// The colour behind the text.
  final Color? backgroundColor;

  /// The text colour.
  final Color? color;

  /// This style, with any unset field taken from [other], field by field.
  HighlightStyle merge(HighlightStyle? other) {
    if (other == null) {
      return this;
    }
    return HighlightStyle(
      backgroundColor: backgroundColor ?? other.backgroundColor,
      color: color ?? other.color,
    );
  }

  /// This style with every remaining default filled in from [scheme].
  HighlightStyle resolve(ColorScheme scheme) {
    return HighlightStyle(
      backgroundColor: backgroundColor ?? scheme.tertiaryContainer,
      color:
          color ??
          (backgroundColor == null ? scheme.onTertiaryContainer : null),
    );
  }

  /// A copy with the given fields replaced.
  HighlightStyle copyWith({Color? backgroundColor, Color? color}) {
    return HighlightStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      color: color ?? this.color,
    );
  }

  /// Linearly interpolates between two styles.
  static HighlightStyle? lerp(HighlightStyle? a, HighlightStyle? b, double t) {
    if (a == null && b == null) {
      return null;
    }
    if (a == null) {
      return t < 0.5 ? null : b;
    }
    if (b == null) {
      return t < 0.5 ? a : null;
    }
    return HighlightStyle(
      backgroundColor: Color.lerp(a.backgroundColor, b.backgroundColor, t),
      color: Color.lerp(a.color, b.color, t),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is HighlightStyle &&
        other.backgroundColor == backgroundColor &&
        other.color == color;
  }

  @override
  int get hashCode => Object.hash(backgroundColor, color);
}

import 'package:flutter/material.dart';
import 'style_lerp.dart';

/// Style configuration for link markdown elements.
class LinkStyle {
  const LinkStyle({
    this.textStyle,
    this.hoverTextStyle,
    this.cursor,
    this.color,
  });

  final TextStyle? textStyle;
  final TextStyle? hoverTextStyle;
  final MouseCursor? cursor;
  final Color? color;

  LinkStyle copyWith({
    TextStyle? textStyle,
    TextStyle? hoverTextStyle,
    MouseCursor? cursor,
    Color? color,
  }) {
    return LinkStyle(
      textStyle: textStyle ?? this.textStyle,
      hoverTextStyle: hoverTextStyle ?? this.hoverTextStyle,
      cursor: cursor ?? this.cursor,
      color: color ?? this.color,
    );
  }

  static LinkStyle? lerp(
    LinkStyle? a,
    LinkStyle? b,
    double t,
  ) {
    if (a == null && b == null) return null;
    return LinkStyle(
      textStyle: lerpTextStyle(a?.textStyle, b?.textStyle, t),
      hoverTextStyle: lerpTextStyle(a?.hoverTextStyle, b?.hoverTextStyle, t),
      cursor: t < 0.5 ? a?.cursor : b?.cursor,
      color: Color.lerp(a?.color, b?.color, t),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LinkStyle &&
          runtimeType == other.runtimeType &&
          textStyle == other.textStyle &&
          hoverTextStyle == other.hoverTextStyle &&
          cursor == other.cursor &&
          color == other.color;

  @override
  int get hashCode => Object.hash(
        textStyle,
        hoverTextStyle,
        cursor,
        color,
      );
}

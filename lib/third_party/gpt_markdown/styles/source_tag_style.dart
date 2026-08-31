import 'package:flutter/material.dart';
import 'style_lerp.dart';

/// Style configuration for source tag markdown elements.
class SourceTagStyle {
  const SourceTagStyle({
    this.textStyle,
    this.backgroundColor,
    this.padding,
    this.borderRadius,
    this.border,
  });

  final TextStyle? textStyle;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Border? border;

  SourceTagStyle copyWith({
    TextStyle? textStyle,
    Color? backgroundColor,
    EdgeInsetsGeometry? padding,
    BorderRadius? borderRadius,
    Border? border,
  }) {
    return SourceTagStyle(
      textStyle: textStyle ?? this.textStyle,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      padding: padding ?? this.padding,
      borderRadius: borderRadius ?? this.borderRadius,
      border: border ?? this.border,
    );
  }

  static SourceTagStyle? lerp(
    SourceTagStyle? a,
    SourceTagStyle? b,
    double t,
  ) {
    if (a == null && b == null) return null;
    return SourceTagStyle(
      textStyle: lerpTextStyle(a?.textStyle, b?.textStyle, t),
      backgroundColor: Color.lerp(a?.backgroundColor, b?.backgroundColor, t),
      padding: EdgeInsetsGeometry.lerp(a?.padding, b?.padding, t),
      borderRadius: BorderRadius.lerp(a?.borderRadius, b?.borderRadius, t),
      border: Border.lerp(a?.border, b?.border, t),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SourceTagStyle &&
          runtimeType == other.runtimeType &&
          textStyle == other.textStyle &&
          backgroundColor == other.backgroundColor &&
          padding == other.padding &&
          borderRadius == other.borderRadius &&
          border == other.border;

  @override
  int get hashCode => Object.hash(
        textStyle,
        backgroundColor,
        padding,
        borderRadius,
        border,
      );
}

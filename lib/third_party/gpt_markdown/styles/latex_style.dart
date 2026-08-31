import 'package:flutter/material.dart';
import 'style_lerp.dart';

/// Style configuration for LaTeX math markdown elements.
class LatexStyle {
  const LatexStyle({
    this.textStyle,
    this.backgroundColor,
    this.padding,
    this.margin,
    this.displayMode,
    this.alignment,
  });

  final TextStyle? textStyle;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool? displayMode;
  final AlignmentGeometry? alignment;

  LatexStyle copyWith({
    TextStyle? textStyle,
    Color? backgroundColor,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    bool? displayMode,
    AlignmentGeometry? alignment,
  }) {
    return LatexStyle(
      textStyle: textStyle ?? this.textStyle,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      padding: padding ?? this.padding,
      margin: margin ?? this.margin,
      displayMode: displayMode ?? this.displayMode,
      alignment: alignment ?? this.alignment,
    );
  }

  static LatexStyle? lerp(
    LatexStyle? a,
    LatexStyle? b,
    double t,
  ) {
    if (a == null && b == null) return null;
    return LatexStyle(
      textStyle: lerpTextStyle(a?.textStyle, b?.textStyle, t),
      backgroundColor: Color.lerp(a?.backgroundColor, b?.backgroundColor, t),
      padding: EdgeInsetsGeometry.lerp(a?.padding, b?.padding, t),
      margin: EdgeInsetsGeometry.lerp(a?.margin, b?.margin, t),
      displayMode: t < 0.5 ? a?.displayMode : b?.displayMode,
      alignment: AlignmentGeometry.lerp(a?.alignment, b?.alignment, t),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LatexStyle &&
          runtimeType == other.runtimeType &&
          textStyle == other.textStyle &&
          backgroundColor == other.backgroundColor &&
          padding == other.padding &&
          margin == other.margin &&
          displayMode == other.displayMode &&
          alignment == other.alignment;

  @override
  int get hashCode => Object.hash(
        textStyle,
        backgroundColor,
        padding,
        margin,
        displayMode,
        alignment,
      );
}

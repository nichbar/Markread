import 'package:flutter/material.dart';
import 'style_lerp.dart';

/// Style configuration for code block markdown elements.
class CodeBlockStyle {
  const CodeBlockStyle({
    this.decoration,
    this.padding,
    this.margin,
    this.textStyle,
    this.languageTextStyle,
    this.copyIconColor,
    this.showCopyButton,
    this.border,
    this.borderRadius,
    this.backgroundColor,
  });

  final BoxDecoration? decoration;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final TextStyle? textStyle;
  final TextStyle? languageTextStyle;
  final Color? copyIconColor;
  final bool? showCopyButton;
  final Border? border;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;

  CodeBlockStyle copyWith({
    BoxDecoration? decoration,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    TextStyle? textStyle,
    TextStyle? languageTextStyle,
    Color? copyIconColor,
    bool? showCopyButton,
    Border? border,
    BorderRadius? borderRadius,
    Color? backgroundColor,
  }) {
    return CodeBlockStyle(
      decoration: decoration ?? this.decoration,
      padding: padding ?? this.padding,
      margin: margin ?? this.margin,
      textStyle: textStyle ?? this.textStyle,
      languageTextStyle: languageTextStyle ?? this.languageTextStyle,
      copyIconColor: copyIconColor ?? this.copyIconColor,
      showCopyButton: showCopyButton ?? this.showCopyButton,
      border: border ?? this.border,
      borderRadius: borderRadius ?? this.borderRadius,
      backgroundColor: backgroundColor ?? this.backgroundColor,
    );
  }

  static CodeBlockStyle? lerp(
    CodeBlockStyle? a,
    CodeBlockStyle? b,
    double t,
  ) {
    if (a == null && b == null) return null;
    return CodeBlockStyle(
      decoration: BoxDecoration.lerp(a?.decoration, b?.decoration, t),
      padding: EdgeInsetsGeometry.lerp(a?.padding, b?.padding, t),
      margin: EdgeInsetsGeometry.lerp(a?.margin, b?.margin, t),
      textStyle: lerpTextStyle(a?.textStyle, b?.textStyle, t),
      languageTextStyle: lerpTextStyle(a?.languageTextStyle, b?.languageTextStyle, t),
      copyIconColor: Color.lerp(a?.copyIconColor, b?.copyIconColor, t),
      showCopyButton: t < 0.5 ? a?.showCopyButton : b?.showCopyButton,
      border: Border.lerp(a?.border, b?.border, t),
      borderRadius: BorderRadius.lerp(a?.borderRadius, b?.borderRadius, t),
      backgroundColor: Color.lerp(a?.backgroundColor, b?.backgroundColor, t),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CodeBlockStyle &&
          runtimeType == other.runtimeType &&
          decoration == other.decoration &&
          padding == other.padding &&
          margin == other.margin &&
          textStyle == other.textStyle &&
          languageTextStyle == other.languageTextStyle &&
          copyIconColor == other.copyIconColor &&
          showCopyButton == other.showCopyButton &&
          border == other.border &&
          borderRadius == other.borderRadius &&
          backgroundColor == other.backgroundColor;

  @override
  int get hashCode => Object.hash(
        decoration,
        padding,
        margin,
        textStyle,
        languageTextStyle,
        copyIconColor,
        showCopyButton,
        border,
        borderRadius,
        backgroundColor,
      );
}

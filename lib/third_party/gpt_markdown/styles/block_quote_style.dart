import 'package:flutter/material.dart';
import 'style_lerp.dart';

/// Style configuration for blockquote markdown elements.
class BlockQuoteStyle {
  const BlockQuoteStyle({
    this.decoration,
    this.padding,
    this.margin,
    this.textStyle,
    this.border,
    this.borderRadius,
  });

  final BoxDecoration? decoration;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final TextStyle? textStyle;
  final Border? border;
  final BorderRadius? borderRadius;

  BlockQuoteStyle copyWith({
    BoxDecoration? decoration,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    TextStyle? textStyle,
    Border? border,
    BorderRadius? borderRadius,
  }) {
    return BlockQuoteStyle(
      decoration: decoration ?? this.decoration,
      padding: padding ?? this.padding,
      margin: margin ?? this.margin,
      textStyle: textStyle ?? this.textStyle,
      border: border ?? this.border,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }

  static BlockQuoteStyle? lerp(
    BlockQuoteStyle? a,
    BlockQuoteStyle? b,
    double t,
  ) {
    if (a == null && b == null) return null;
    return BlockQuoteStyle(
      decoration: BoxDecoration.lerp(a?.decoration, b?.decoration, t),
      padding: EdgeInsetsGeometry.lerp(a?.padding, b?.padding, t),
      margin: EdgeInsetsGeometry.lerp(a?.margin, b?.margin, t),
      textStyle: lerpTextStyle(a?.textStyle, b?.textStyle, t),
      border: Border.lerp(a?.border, b?.border, t),
      borderRadius: BorderRadius.lerp(a?.borderRadius, b?.borderRadius, t),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlockQuoteStyle &&
          runtimeType == other.runtimeType &&
          decoration == other.decoration &&
          padding == other.padding &&
          margin == other.margin &&
          textStyle == other.textStyle &&
          border == other.border &&
          borderRadius == other.borderRadius;

  @override
  int get hashCode => Object.hash(
        decoration,
        padding,
        margin,
        textStyle,
        border,
        borderRadius,
      );
}

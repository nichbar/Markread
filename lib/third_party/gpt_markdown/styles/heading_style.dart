import 'package:flutter/material.dart';
import 'style_lerp.dart';

/// Style configuration for markdown headings (h1 - h6).
class HeadingStyle {
  const HeadingStyle({
    this.h1,
    this.h2,
    this.h3,
    this.h4,
    this.h5,
    this.h6,
    this.color,
    this.fontFamily,
    this.fontWeight,
    this.padding,
    this.margin,
  });

  final TextStyle? h1;
  final TextStyle? h2;
  final TextStyle? h3;
  final TextStyle? h4;
  final TextStyle? h5;
  final TextStyle? h6;
  final Color? color;
  final String? fontFamily;
  final FontWeight? fontWeight;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  HeadingStyle copyWith({
    TextStyle? h1,
    TextStyle? h2,
    TextStyle? h3,
    TextStyle? h4,
    TextStyle? h5,
    TextStyle? h6,
    Color? color,
    String? fontFamily,
    FontWeight? fontWeight,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
  }) {
    return HeadingStyle(
      h1: h1 ?? this.h1,
      h2: h2 ?? this.h2,
      h3: h3 ?? this.h3,
      h4: h4 ?? this.h4,
      h5: h5 ?? this.h5,
      h6: h6 ?? this.h6,
      color: color ?? this.color,
      fontFamily: fontFamily ?? this.fontFamily,
      fontWeight: fontWeight ?? this.fontWeight,
      padding: padding ?? this.padding,
      margin: margin ?? this.margin,
    );
  }

  static HeadingStyle? lerp(
    HeadingStyle? a,
    HeadingStyle? b,
    double t,
  ) {
    if (a == null && b == null) return null;
    return HeadingStyle(
      h1: lerpTextStyle(a?.h1, b?.h1, t),
      h2: lerpTextStyle(a?.h2, b?.h2, t),
      h3: lerpTextStyle(a?.h3, b?.h3, t),
      h4: lerpTextStyle(a?.h4, b?.h4, t),
      h5: lerpTextStyle(a?.h5, b?.h5, t),
      h6: lerpTextStyle(a?.h6, b?.h6, t),
      color: Color.lerp(a?.color, b?.color, t),
      fontFamily: t < 0.5 ? a?.fontFamily : b?.fontFamily,
      fontWeight: FontWeight.lerp(a?.fontWeight, b?.fontWeight, t),
      padding: EdgeInsetsGeometry.lerp(a?.padding, b?.padding, t),
      margin: EdgeInsetsGeometry.lerp(a?.margin, b?.margin, t),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeadingStyle &&
          runtimeType == other.runtimeType &&
          h1 == other.h1 &&
          h2 == other.h2 &&
          h3 == other.h3 &&
          h4 == other.h4 &&
          h5 == other.h5 &&
          h6 == other.h6 &&
          color == other.color &&
          fontFamily == other.fontFamily &&
          fontWeight == other.fontWeight &&
          padding == other.padding &&
          margin == other.margin;

  @override
  int get hashCode => Object.hash(
        h1,
        h2,
        h3,
        h4,
        h5,
        h6,
        color,
        fontFamily,
        fontWeight,
        padding,
        margin,
      );
}

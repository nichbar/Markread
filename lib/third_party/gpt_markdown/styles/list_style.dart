import 'package:flutter/material.dart';
import 'style_lerp.dart';

/// Style configuration for list markdown elements (ordered and unordered).
class ListStyle {
  const ListStyle({
    this.markerColor,
    this.markerSpacing,
    this.indent,
    this.itemSpacing,
    this.markerTextStyle,
  });

  final Color? markerColor;
  final double? markerSpacing;
  final double? indent;
  final double? itemSpacing;
  final TextStyle? markerTextStyle;

  ListStyle copyWith({
    Color? markerColor,
    double? markerSpacing,
    double? indent,
    double? itemSpacing,
    TextStyle? markerTextStyle,
  }) {
    return ListStyle(
      markerColor: markerColor ?? this.markerColor,
      markerSpacing: markerSpacing ?? this.markerSpacing,
      indent: indent ?? this.indent,
      itemSpacing: itemSpacing ?? this.itemSpacing,
      markerTextStyle: markerTextStyle ?? this.markerTextStyle,
    );
  }

  static ListStyle? lerp(
    ListStyle? a,
    ListStyle? b,
    double t,
  ) {
    if (a == null && b == null) return null;
    return ListStyle(
      markerColor: Color.lerp(a?.markerColor, b?.markerColor, t),
      markerSpacing: a?.markerSpacing != null && b?.markerSpacing != null
          ? (a!.markerSpacing! + (b!.markerSpacing! - a.markerSpacing!) * t)
          : (t < 0.5 ? a?.markerSpacing : b?.markerSpacing),
      indent: a?.indent != null && b?.indent != null
          ? (a!.indent! + (b!.indent! - a.indent!) * t)
          : (t < 0.5 ? a?.indent : b?.indent),
      itemSpacing: a?.itemSpacing != null && b?.itemSpacing != null
          ? (a!.itemSpacing! + (b!.itemSpacing! - a.itemSpacing!) * t)
          : (t < 0.5 ? a?.itemSpacing : b?.itemSpacing),
      markerTextStyle: lerpTextStyle(a?.markerTextStyle, b?.markerTextStyle, t),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListStyle &&
          runtimeType == other.runtimeType &&
          markerColor == other.markerColor &&
          markerSpacing == other.markerSpacing &&
          indent == other.indent &&
          itemSpacing == other.itemSpacing &&
          markerTextStyle == other.markerTextStyle;

  @override
  int get hashCode => Object.hash(
        markerColor,
        markerSpacing,
        indent,
        itemSpacing,
        markerTextStyle,
      );
}

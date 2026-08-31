import 'package:flutter/material.dart';

/// Style configuration for horizontal rule (hr) markdown elements.
class HrStyle {
  const HrStyle({
    this.color,
    this.thickness,
    this.height,
    this.margin,
  });

  final Color? color;
  final double? thickness;
  final double? height;
  final EdgeInsetsGeometry? margin;

  HrStyle copyWith({
    Color? color,
    double? thickness,
    double? height,
    EdgeInsetsGeometry? margin,
  }) {
    return HrStyle(
      color: color ?? this.color,
      thickness: thickness ?? this.thickness,
      height: height ?? this.height,
      margin: margin ?? this.margin,
    );
  }

  static HrStyle? lerp(
    HrStyle? a,
    HrStyle? b,
    double t,
  ) {
    if (a == null && b == null) return null;
    return HrStyle(
      color: Color.lerp(a?.color, b?.color, t),
      thickness: a?.thickness != null && b?.thickness != null
          ? (a!.thickness! + (b!.thickness! - a.thickness!) * t)
          : (t < 0.5 ? a?.thickness : b?.thickness),
      height: a?.height != null && b?.height != null
          ? (a!.height! + (b!.height! - a.height!) * t)
          : (t < 0.5 ? a?.height : b?.height),
      margin: EdgeInsetsGeometry.lerp(a?.margin, b?.margin, t),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HrStyle &&
          runtimeType == other.runtimeType &&
          color == other.color &&
          thickness == other.thickness &&
          height == other.height &&
          margin == other.margin;

  @override
  int get hashCode => Object.hash(
        color,
        thickness,
        height,
        margin,
      );
}

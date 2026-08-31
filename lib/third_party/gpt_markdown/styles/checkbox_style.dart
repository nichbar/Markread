import 'package:flutter/material.dart';

/// Style configuration for checkbox markdown elements.
class CheckboxStyle {
  const CheckboxStyle({
    this.activeColor,
    this.checkColor,
    this.shape,
    this.side,
    this.size,
  });

  final Color? activeColor;
  final Color? checkColor;
  final OutlinedBorder? shape;
  final BorderSide? side;
  final double? size;

  CheckboxStyle copyWith({
    Color? activeColor,
    Color? checkColor,
    OutlinedBorder? shape,
    BorderSide? side,
    double? size,
  }) {
    return CheckboxStyle(
      activeColor: activeColor ?? this.activeColor,
      checkColor: checkColor ?? this.checkColor,
      shape: shape ?? this.shape,
      side: side ?? this.side,
      size: size ?? this.size,
    );
  }

  static CheckboxStyle? lerp(
    CheckboxStyle? a,
    CheckboxStyle? b,
    double t,
  ) {
    if (a == null && b == null) return null;
    return CheckboxStyle(
      activeColor: Color.lerp(a?.activeColor, b?.activeColor, t),
      checkColor: Color.lerp(a?.checkColor, b?.checkColor, t),
      shape: OutlinedBorder.lerp(a?.shape, b?.shape, t),
      side: BorderSide.lerp(
        a?.side ?? BorderSide.none,
        b?.side ?? BorderSide.none,
        t,
      ),
      size: a?.size != null && b?.size != null
          ? (a!.size! + (b!.size! - a.size!) * t)
          : (t < 0.5 ? a?.size : b?.size),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CheckboxStyle &&
          runtimeType == other.runtimeType &&
          activeColor == other.activeColor &&
          checkColor == other.checkColor &&
          shape == other.shape &&
          side == other.side &&
          size == other.size;

  @override
  int get hashCode => Object.hash(
        activeColor,
        checkColor,
        shape,
        side,
        size,
      );
}

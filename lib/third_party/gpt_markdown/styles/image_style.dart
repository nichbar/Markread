import 'package:flutter/material.dart';

/// Style configuration for markdown image elements.
class ImageStyle {
  const ImageStyle({
    this.width,
    this.height,
    this.fit,
    this.alignment,
    this.borderRadius,
    this.margin,
    this.errorWidget,
  });

  final double? width;
  final double? height;
  final BoxFit? fit;
  final AlignmentGeometry? alignment;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? margin;
  final Widget Function(BuildContext, Object, StackTrace?)? errorWidget;

  ImageStyle copyWith({
    double? width,
    double? height,
    BoxFit? fit,
    AlignmentGeometry? alignment,
    BorderRadius? borderRadius,
    EdgeInsetsGeometry? margin,
    Widget Function(BuildContext, Object, StackTrace?)? errorWidget,
  }) {
    return ImageStyle(
      width: width ?? this.width,
      height: height ?? this.height,
      fit: fit ?? this.fit,
      alignment: alignment ?? this.alignment,
      borderRadius: borderRadius ?? this.borderRadius,
      margin: margin ?? this.margin,
      errorWidget: errorWidget ?? this.errorWidget,
    );
  }

  static ImageStyle? lerp(
    ImageStyle? a,
    ImageStyle? b,
    double t,
  ) {
    if (a == null && b == null) return null;
    return ImageStyle(
      width: a?.width != null && b?.width != null
          ? (a!.width! + (b!.width! - a.width!) * t)
          : (t < 0.5 ? a?.width : b?.width),
      height: a?.height != null && b?.height != null
          ? (a!.height! + (b!.height! - a.height!) * t)
          : (t < 0.5 ? a?.height : b?.height),
      fit: t < 0.5 ? a?.fit : b?.fit,
      alignment: AlignmentGeometry.lerp(a?.alignment, b?.alignment, t),
      borderRadius: BorderRadius.lerp(a?.borderRadius, b?.borderRadius, t),
      margin: EdgeInsetsGeometry.lerp(a?.margin, b?.margin, t),
      errorWidget: t < 0.5 ? a?.errorWidget : b?.errorWidget,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageStyle &&
          runtimeType == other.runtimeType &&
          width == other.width &&
          height == other.height &&
          fit == other.fit &&
          alignment == other.alignment &&
          borderRadius == other.borderRadius &&
          margin == other.margin &&
          errorWidget == other.errorWidget;

  @override
  int get hashCode => Object.hash(
        width,
        height,
        fit,
        alignment,
        borderRadius,
        margin,
        errorWidget,
      );
}

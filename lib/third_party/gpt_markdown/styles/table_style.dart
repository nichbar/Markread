import 'package:flutter/material.dart';
import 'style_lerp.dart';

/// Style configuration for table markdown elements.
class TableStyle {
  const TableStyle({
    this.cellPadding,
    this.headerPadding,
    this.headerTextStyle,
    this.cellTextStyle,
    this.borderColor,
    this.headerBackgroundColor,
    this.alternateRowColor,
    this.border,
    this.rowColor,
  });

  final EdgeInsetsGeometry? cellPadding;
  final EdgeInsetsGeometry? headerPadding;
  final TextStyle? headerTextStyle;
  final TextStyle? cellTextStyle;
  final Color? borderColor;
  final Color? headerBackgroundColor;
  final Color? alternateRowColor;
  final TableBorder? border;
  final Color? rowColor;

  TableStyle copyWith({
    EdgeInsetsGeometry? cellPadding,
    EdgeInsetsGeometry? headerPadding,
    TextStyle? headerTextStyle,
    TextStyle? cellTextStyle,
    Color? borderColor,
    Color? headerBackgroundColor,
    Color? alternateRowColor,
    TableBorder? border,
    Color? rowColor,
  }) {
    return TableStyle(
      cellPadding: cellPadding ?? this.cellPadding,
      headerPadding: headerPadding ?? this.headerPadding,
      headerTextStyle: headerTextStyle ?? this.headerTextStyle,
      cellTextStyle: cellTextStyle ?? this.cellTextStyle,
      borderColor: borderColor ?? this.borderColor,
      headerBackgroundColor: headerBackgroundColor ?? this.headerBackgroundColor,
      alternateRowColor: alternateRowColor ?? this.alternateRowColor,
      border: border ?? this.border,
      rowColor: rowColor ?? this.rowColor,
    );
  }

  static TableStyle? lerp(
    TableStyle? a,
    TableStyle? b,
    double t,
  ) {
    if (a == null && b == null) return null;
    return TableStyle(
      cellPadding: EdgeInsetsGeometry.lerp(a?.cellPadding, b?.cellPadding, t),
      headerPadding: EdgeInsetsGeometry.lerp(a?.headerPadding, b?.headerPadding, t),
      headerTextStyle: lerpTextStyle(a?.headerTextStyle, b?.headerTextStyle, t),
      cellTextStyle: lerpTextStyle(a?.cellTextStyle, b?.cellTextStyle, t),
      borderColor: Color.lerp(a?.borderColor, b?.borderColor, t),
      headerBackgroundColor: Color.lerp(a?.headerBackgroundColor, b?.headerBackgroundColor, t),
      alternateRowColor: Color.lerp(a?.alternateRowColor, b?.alternateRowColor, t),
      border: TableBorder.lerp(a?.border, b?.border, t),
      rowColor: Color.lerp(a?.rowColor, b?.rowColor, t),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TableStyle &&
          runtimeType == other.runtimeType &&
          cellPadding == other.cellPadding &&
          headerPadding == other.headerPadding &&
          headerTextStyle == other.headerTextStyle &&
          cellTextStyle == other.cellTextStyle &&
          borderColor == other.borderColor &&
          headerBackgroundColor == other.headerBackgroundColor &&
          alternateRowColor == other.alternateRowColor &&
          border == other.border &&
          rowColor == other.rowColor;

  @override
  int get hashCode => Object.hash(
        cellPadding,
        headerPadding,
        headerTextStyle,
        cellTextStyle,
        borderColor,
        headerBackgroundColor,
        alternateRowColor,
        border,
        rowColor,
      );
}

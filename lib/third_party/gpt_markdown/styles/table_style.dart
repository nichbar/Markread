import 'package:material_ui/material_ui.dart';
import 'style_lerp.dart';

/// What a table does when it is wider than the space it is given.
enum TableOverflow {
  /// Keep every column at its content width and scroll the table sideways.
  scroll,

  /// Fit the table to the available width and wrap the text in its cells.
  wrap,
}

/// How a table is drawn.
@immutable
class TableStyle {
  /// Creates a TableStyle.
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
    this.borderWidth,
    this.borderRadius,
    this.headerBackground,
    this.rowStripeColor,
    this.columnWidth,
    this.overflow,
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

  /// Grid thickness. Defaults to 1.
  final double? borderWidth;

  /// Outer corner rounding. Defaults to square.
  final Radius? borderRadius;

  /// Header row fill.
  final Color? headerBackground;

  /// Optional width policy for every column.
  final TableColumnWidth? columnWidth;

  /// Fill for alternating rows.
  final Color? rowStripeColor;

  /// What a table wider than the available width does.
  final TableOverflow? overflow;

  /// Header background color resolving between legacy and new name.
  Color? get effectiveHeaderBackground =>
      headerBackground ?? headerBackgroundColor;

  /// Row stripe color resolving between legacy and new name.
  Color? get effectiveRowStripeColor =>
      rowStripeColor ?? alternateRowColor;

  /// This style, with any unset field taken from [other], field by field.
  TableStyle merge(TableStyle? other) {
    if (other == null) {
      return this;
    }
    return TableStyle(
      cellPadding: cellPadding ?? other.cellPadding,
      headerPadding: headerPadding ?? other.headerPadding,
      headerTextStyle: headerTextStyle ?? other.headerTextStyle,
      cellTextStyle: cellTextStyle ?? other.cellTextStyle,
      borderColor: borderColor ?? other.borderColor,
      headerBackgroundColor:
          headerBackgroundColor ?? other.headerBackgroundColor,
      alternateRowColor: alternateRowColor ?? other.alternateRowColor,
      border: border ?? other.border,
      rowColor: rowColor ?? other.rowColor,
      borderWidth: borderWidth ?? other.borderWidth,
      borderRadius: borderRadius ?? other.borderRadius,
      headerBackground: headerBackground ?? other.headerBackground,
      rowStripeColor: rowStripeColor ?? other.rowStripeColor,
      columnWidth: columnWidth ?? other.columnWidth,
      overflow: overflow ?? other.overflow,
    );
  }

  /// This style with every remaining default filled in from [scheme].
  TableStyle resolve(ColorScheme scheme) {
    return TableStyle(
      borderColor: borderColor ?? scheme.onSurface,
      borderWidth: borderWidth ?? 1,
      borderRadius: borderRadius,
      cellPadding:
          cellPadding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      headerPadding: headerPadding,
      headerTextStyle: headerTextStyle,
      cellTextStyle: cellTextStyle,
      headerBackground:
          headerBackground ?? headerBackgroundColor ?? scheme.surfaceContainerHighest,
      headerBackgroundColor:
          headerBackgroundColor ?? headerBackground ?? scheme.surfaceContainerHighest,
      rowStripeColor: rowStripeColor ?? alternateRowColor,
      alternateRowColor: alternateRowColor ?? rowStripeColor,
      border: border,
      rowColor: rowColor,
      columnWidth: columnWidth,
      overflow: overflow ?? TableOverflow.scroll,
    );
  }

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
    double? borderWidth,
    Radius? borderRadius,
    Color? headerBackground,
    Color? rowStripeColor,
    TableColumnWidth? columnWidth,
    TableOverflow? overflow,
  }) {
    return TableStyle(
      cellPadding: cellPadding ?? this.cellPadding,
      headerPadding: headerPadding ?? this.headerPadding,
      headerTextStyle: headerTextStyle ?? this.headerTextStyle,
      cellTextStyle: cellTextStyle ?? this.cellTextStyle,
      borderColor: borderColor ?? this.borderColor,
      headerBackgroundColor:
          headerBackgroundColor ?? this.headerBackgroundColor,
      alternateRowColor: alternateRowColor ?? this.alternateRowColor,
      border: border ?? this.border,
      rowColor: rowColor ?? this.rowColor,
      borderWidth: borderWidth ?? this.borderWidth,
      borderRadius: borderRadius ?? this.borderRadius,
      headerBackground: headerBackground ?? this.headerBackground,
      rowStripeColor: rowStripeColor ?? this.rowStripeColor,
      columnWidth: columnWidth ?? this.columnWidth,
      overflow: overflow ?? this.overflow,
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
      headerPadding:
          EdgeInsetsGeometry.lerp(a?.headerPadding, b?.headerPadding, t),
      headerTextStyle: lerpTextStyle(a?.headerTextStyle, b?.headerTextStyle, t),
      cellTextStyle: lerpTextStyle(a?.cellTextStyle, b?.cellTextStyle, t),
      borderColor: Color.lerp(a?.borderColor, b?.borderColor, t),
      headerBackgroundColor: Color.lerp(
        a?.headerBackgroundColor,
        b?.headerBackgroundColor,
        t,
      ),
      alternateRowColor:
          Color.lerp(a?.alternateRowColor, b?.alternateRowColor, t),
      border: TableBorder.lerp(a?.border, b?.border, t),
      rowColor: Color.lerp(a?.rowColor, b?.rowColor, t),
      borderWidth: lerpDouble(a?.borderWidth, b?.borderWidth, t),
      borderRadius: Radius.lerp(a?.borderRadius, b?.borderRadius, t),
      headerBackground:
          Color.lerp(a?.headerBackground, b?.headerBackground, t),
      rowStripeColor: Color.lerp(a?.rowStripeColor, b?.rowStripeColor, t),
      columnWidth: t < 0.5 ? a?.columnWidth : b?.columnWidth,
      overflow: t < 0.5 ? a?.overflow : b?.overflow,
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
          rowColor == other.rowColor &&
          borderWidth == other.borderWidth &&
          borderRadius == other.borderRadius &&
          headerBackground == other.headerBackground &&
          rowStripeColor == other.rowStripeColor &&
          columnWidth == other.columnWidth &&
          overflow == other.overflow;

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
        borderWidth,
        borderRadius,
        headerBackground,
        rowStripeColor,
        columnWidth,
        overflow,
      );
}

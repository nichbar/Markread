// lib/features/viewer/widgets/monospace_markdown_theme.dart
import 'package:flutter/material.dart';
import 'package:markread/third_party/gpt_markdown/custom_widgets/markdown_config.dart';
import 'package:markread/third_party/gpt_markdown/markdown_component.dart';
import 'package:markread/third_party/gpt_markdown/md_widget.dart';
import 'package:markread/third_party/gpt_markdown/theme.dart';

/// Monospace document chrome colors (headings, links, HR, tables).
///
/// Values from [typora-monospace-theme](https://github.com/typora/typora-monospace-theme):
/// light purple/blue headings; dark lavender/blue headings. Body font family
/// is applied separately in [MarkdownView].
class MonospaceMarkdownTokens {
  const MonospaceMarkdownTokens._({
    required this.fgMuted,
    required this.border,
    required this.borderMuted,
    required this.canvasSubtle,
    required this.accentFg,
    required this.tableHeaderBg,
    required this.hrColor,
    required this.h1to3,
    required this.h4to6,
  });

  final Color fgMuted;
  final Color border;
  final Color borderMuted;
  final Color canvasSubtle;
  final Color accentFg;
  final Color tableHeaderBg;
  final Color hrColor;
  final Color h1to3;
  final Color h4to6;

  factory MonospaceMarkdownTokens.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return const MonospaceMarkdownTokens._(
        // muted gray
        fgMuted: Color(0xFF979797),
        // table border #cbcbcb
        border: Color(0xFFCBCBCB),
        borderMuted: Color(0xFFCBCBCB),
        // subtle dark canvas
        canvasSubtle: Color(0xFF2A2A2A),
        // link #8ac9ff
        accentFg: Color(0xFF8AC9FF),
        // thead #263238
        tableHeaderBg: Color(0xFF263238),
        // hr muted
        hrColor: Color(0xFF606060),
        // h1–h3 #dbdbfd
        h1to3: Color(0xFFDBDBFD),
        // h4–h6 #549ad8
        h4to6: Color(0xFF549AD8),
      );
    }
    return const MonospaceMarkdownTokens._(
      // muted gray
      fgMuted: Color(0xFF979797),
      // table border #cbcbcb
      border: Color(0xFFCBCBCB),
      borderMuted: Color(0xFFCBCBCB),
      // light gray canvas #f5f5f5
      canvasSubtle: Color(0xFFF5F5F5),
      // link #005dad
      accentFg: Color(0xFF005DAD),
      // thead #e0e0e0
      tableHeaderBg: Color(0xFFE0E0E0),
      // hr muted #979797
      hrColor: Color(0xFF979797),
      // h1–h3 #6363ac
      h1to3: Color(0xFF6363AC),
      // h4–h6 #0e5796
      h4to6: Color(0xFF0E5796),
    );
  }
}

/// Builds [GptMarkdownThemeData] with Monospace heading / link / HR styling.
///
/// All headings use `fontFamily: monospace` (signature of this theme).
/// Scale: 2.0 / 1.6 / 1.3 / 1.2 / 1.1 / 1.0 em of body.
GptMarkdownThemeData buildMonospaceGptMarkdownTheme({
  required BuildContext context,
  required Color textColor,
  required double effectiveFontSize,
}) {
  final tokens = MonospaceMarkdownTokens.of(context);
  final base = GptMarkdownThemeData(
    brightness: Theme.of(context).brightness,
  );

  TextStyle heading(double em, Color color) {
    return TextStyle(
      color: color,
      fontFamily: 'monospace',
      fontSize: effectiveFontSize * em,
      fontWeight: FontWeight.bold,
      height: 1.25,
    );
  }

  return base.copyWith(
    highlightColor: tokens.canvasSubtle,
    h1: heading(2.0, tokens.h1to3),
    h2: heading(1.6, tokens.h1to3),
    h3: heading(1.3, tokens.h1to3),
    h4: heading(1.2, tokens.h4to6),
    h5: heading(1.1, tokens.h4to6),
    h6: heading(1.0, tokens.h4to6),
    // Solid approximation of CSS dash-string HR.
    hrLineThickness: 1,
    hrLineColor: tokens.hrColor,
    hrLinePadding: const EdgeInsets.symmetric(vertical: 12),
    linkColor: tokens.accentFg,
    linkHoverColor: tokens.accentFg,
    // Source-like: Typora monospace does not use a GitHub-style H1 rule.
    autoAddDividerLineAfterH1: false,
  );
}

/// Monospace table: bordered cells, gray header (GitHub layout structure).
Widget monospaceTableBuilder(
  BuildContext context,
  List<CustomTableRow> tableRows,
  TextStyle textStyle,
  GptMarkdownConfig config,
) {
  final tokens = MonospaceMarkdownTokens.of(context);
  if (tableRows.isEmpty) {
    return const SizedBox.shrink();
  }

  final maxCol = tableRows
      .map((r) => r.fields.length)
      .fold<int>(0, (a, b) => a > b ? a : b);
  if (maxCol == 0) return const SizedBox.shrink();

  final controller = ScrollController();
  return Scrollbar(
    controller: controller,
    child: SingleChildScrollView(
      controller: controller,
      scrollDirection: Axis.horizontal,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: tokens.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          border: TableBorder(
            horizontalInside: BorderSide(color: tokens.border, width: 1),
            verticalInside: BorderSide(color: tokens.border, width: 1),
          ),
          children: [
            for (final row in tableRows)
              TableRow(
                decoration: row.isHeader
                    ? BoxDecoration(color: tokens.tableHeaderBg)
                    : null,
                children: List.generate(maxCol, (index) {
                  final field =
                      index < row.fields.length ? row.fields[index] : null;
                  final data = field?.data ?? '';
                  final align = field?.alignment ?? TextAlign.left;

                  Widget content = Padding(
                    // Typora: padding .5em 1em
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: MdWidget(
                      context,
                      data.trim(),
                      false,
                      config: config,
                    ),
                  );

                  switch (align) {
                    case TextAlign.center:
                      content = Center(child: content);
                    case TextAlign.right:
                      content = Align(
                        alignment: Alignment.centerRight,
                        child: content,
                      );
                    default:
                      content = Align(
                        alignment: Alignment.centerLeft,
                        child: content,
                      );
                  }
                  return content;
                }),
              ),
          ],
        ),
      ),
    ),
  );
}

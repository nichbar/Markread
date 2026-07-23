// lib/features/viewer/widgets/blue_topaz_markdown_theme.dart
import 'package:flutter/material.dart';
import 'package:markread/third_party/gpt_markdown/custom_widgets/markdown_config.dart';
import 'package:markread/third_party/gpt_markdown/markdown_component.dart';
import 'package:markread/third_party/gpt_markdown/md_widget.dart';
import 'package:markread/third_party/gpt_markdown/theme.dart';

/// Blue Topaz document chrome colors (headings, links, HR, tables).
///
/// Values from [typora-blue-topaz-theme](https://github.com/qishaoyumu/typora-blue-topaz-theme):
/// light blue-cascade headings / dark rainbow headings.
class BlueTopazMarkdownTokens {
  const BlueTopazMarkdownTokens._({
    required this.fgMuted,
    required this.border,
    required this.borderMuted,
    required this.canvasSubtle,
    required this.accentFg,
    required this.primaryAccent,
    required this.tableHeaderBg,
    required this.tableRowEven,
    required this.tableRowOdd,
    required this.hrColor,
    required this.h1,
    required this.h2,
    required this.h3,
    required this.h4,
    required this.h5,
    required this.h6,
  });

  final Color fgMuted;
  final Color border;
  final Color borderMuted;
  final Color canvasSubtle;
  final Color accentFg;
  final Color primaryAccent;
  final Color tableHeaderBg;
  final Color tableRowEven;
  final Color tableRowOdd;
  final Color hrColor;
  final Color h1;
  final Color h2;
  final Color h3;
  final Color h4;
  final Color h5;
  final Color h6;

  factory BlueTopazMarkdownTokens.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return const BlueTopazMarkdownTokens._(
        // --md-char-color
        fgMuted: Color(0xFF5C6370),
        // --dark-border-color
        border: Color(0xFF343434),
        // --item-hover-bg-color / muted
        borderMuted: Color(0xFF2A2A2A),
        // --side-bar-bg-color
        canvasSubtle: Color(0xFF151515),
        // --link-color
        accentFg: Color(0xFF3A8CD4),
        // --primary-color rgb(45, 130, 204)
        primaryAccent: Color(0xFF2D82CC),
        // th: hsla(208, 64%, 49%, 0.1)
        tableHeaderBg: Color(0x1A2D82CC),
        // tbody tr #2f2f2f32
        tableRowEven: Color(0x322F2F2F),
        // odd #00000033
        tableRowOdd: Color(0x33000000),
        // hr #3f3f3f
        hrColor: Color(0xFF3F3F3F),
        // H1 hsl(78,62%,47%)
        h1: Color(0xFF95C22D),
        // H2 hsl(118,42%,49%)
        h2: Color(0xFF4BB148),
        // H3 hsl(180,53%,48%)
        h3: Color(0xFF39BBBB),
        // H4 hsl(216,69%,68%)
        h4: Color(0xFF75A2E5),
        // H5 hsl(258,79%,77%)
        h5: Color(0xFFB196F2),
        // H6 hsl(290,85%,81%)
        h6: Color(0xFFEAA5F7),
      );
    }
    return const BlueTopazMarkdownTokens._(
      // --meta-content-color
      fgMuted: Color(0xFF577A87),
      // --ui-border-color
      border: Color(0xFFDDDDDD),
      // table edge #e8e8e8
      borderMuted: Color(0xFFE8E8E8),
      // --side-bar-bg-color
      canvasSubtle: Color(0xFFFCFCFC),
      // --link-color
      accentFg: Color(0xFF1A79C6),
      // --primary-color
      primaryAccent: Color(0xFF2F93E4),
      // --primary-color-01: hsla(207, 77%, 54%, 0.1)
      tableHeaderBg: Color(0x1A2F93E4),
      // tbody tr #f1f1f176
      tableRowEven: Color(0x76F1F1F1),
      // odd #ffffff70
      tableRowOdd: Color(0x70FFFFFF),
      // hr #bfbfbf
      hrColor: Color(0xFFBFBFBF),
      // H1 hsl(216,88%,26%)
      h1: Color(0xFF07367C),
      // H2 hsl(212,100%,33%)
      h2: Color(0xFF004EA8),
      // H3 hsl(210,86%,39%)
      h3: Color(0xFF0D63B8),
      // H4 hsl(208,58%,49%)
      h4: Color(0xFF3481C5),
      // H5 hsl(209,70%,58%)
      h5: Color(0xFF4896DE),
      // H6 hsl(209,65%,58%)
      h6: Color(0xFF4E96D9),
    );
  }
}

/// Builds [GptMarkdownThemeData] with Blue Topaz heading / link / HR styling.
GptMarkdownThemeData buildBlueTopazGptMarkdownTheme({
  required BuildContext context,
  required Color textColor,
  required double effectiveFontSize,
}) {
  final tokens = BlueTopazMarkdownTokens.of(context);
  final base = GptMarkdownThemeData(
    brightness: Theme.of(context).brightness,
  );

  TextStyle heading(double em, Color color) {
    return TextStyle(
      color: color,
      fontSize: effectiveFontSize * em,
      fontWeight: FontWeight.w700,
      height: 1.25,
    );
  }

  return base.copyWith(
    // Used by default inline-code fallback; code path uses custom builder.
    highlightColor: tokens.canvasSubtle,
    // Same em scale as GitHub path; each level has Blue Topaz color.
    h1: heading(2.0, tokens.h1),
    h2: heading(1.5, tokens.h2),
    h3: heading(1.25, tokens.h3),
    h4: heading(1.0, tokens.h4),
    h5: heading(0.875, tokens.h5),
    h6: heading(0.85, tokens.h6),
    // Typora hr: height 2px, #bfbfbf / #3f3f3f
    hrLineThickness: 2,
    hrLineColor: tokens.hrColor,
    hrLinePadding: const EdgeInsets.symmetric(vertical: 8),
    linkColor: tokens.accentFg,
    linkHoverColor: tokens.accentFg,
    autoAddDividerLineAfterH1: true,
  );
}

/// Blue Topaz table: soft primary header, zebra rows, light borders.
Widget blueTopazTableBuilder(
  BuildContext context,
  List<CustomTableRow> tableRows,
  TextStyle textStyle,
  GptMarkdownConfig config,
) {
  final tokens = BlueTopazMarkdownTokens.of(context);
  if (tableRows.isEmpty) {
    return const SizedBox.shrink();
  }

  final maxCol = tableRows
      .map((r) => r.fields.length)
      .fold<int>(0, (a, b) => a > b ? a : b);
  if (maxCol == 0) return const SizedBox.shrink();

  // Precompute zebra row colors (body rows only).
  final rowColors = <Color?>[];
  var bodyIndex = 0;
  for (final row in tableRows) {
    if (row.isHeader) {
      rowColors.add(tokens.tableHeaderBg);
    } else {
      rowColors.add(
        bodyIndex.isEven ? tokens.tableRowEven : tokens.tableRowOdd,
      );
      bodyIndex++;
    }
  }

  final controller = ScrollController();
  return Scrollbar(
    controller: controller,
    child: SingleChildScrollView(
      controller: controller,
      scrollDirection: Axis.horizontal,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: tokens.borderMuted, width: 1),
            bottom: BorderSide(color: tokens.borderMuted, width: 1),
          ),
        ),
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          border: TableBorder(
            horizontalInside: BorderSide(color: tokens.borderMuted, width: 1),
            verticalInside: BorderSide(color: tokens.borderMuted, width: 1),
          ),
          children: [
            for (var i = 0; i < tableRows.length; i++)
              TableRow(
                decoration: BoxDecoration(color: rowColors[i]),
                children: List.generate(maxCol, (index) {
                  final row = tableRows[i];
                  final field =
                      index < row.fields.length ? row.fields[index] : null;
                  final data = field?.data ?? '';
                  final align = field?.alignment ?? TextAlign.left;

                  Widget content = Padding(
                    // Typora: padding 4px 10px
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
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

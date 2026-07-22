// lib/features/viewer/widgets/github_markdown_theme.dart
import 'package:flutter/material.dart';
import 'package:markread/third_party/gpt_markdown/custom_widgets/markdown_config.dart';
import 'package:markread/third_party/gpt_markdown/markdown_component.dart';
import 'package:markread/third_party/gpt_markdown/md_widget.dart';
import 'package:markread/third_party/gpt_markdown/theme.dart';

/// Primer/GitHub colors that style markdown nodes beyond code blocks.
class GithubMarkdownTokens {
  const GithubMarkdownTokens._({
    required this.fgMuted,
    required this.border,
    required this.borderMuted,
    required this.canvasSubtle,
    required this.accentFg,
    required this.tableHeaderBg,
  });

  final Color fgMuted;
  final Color border;
  final Color borderMuted;
  final Color canvasSubtle;
  final Color accentFg;
  final Color tableHeaderBg;

  factory GithubMarkdownTokens.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return const GithubMarkdownTokens._(
        // #9198a1
        fgMuted: Color(0xFF9198A1),
        // #3d444d
        border: Color(0xFF3D444D),
        // #21262d
        borderMuted: Color(0xFF21262D),
        // #161b22
        canvasSubtle: Color(0xFF161B22),
        // #4493f8
        accentFg: Color(0xFF4493F8),
        // #161b22
        tableHeaderBg: Color(0xFF161B22),
      );
    }
    return const GithubMarkdownTokens._(
      // #59636e
      fgMuted: Color(0xFF59636E),
      // #d1d9e0
      border: Color(0xFFD1D9E0),
      // #d8dee4
      borderMuted: Color(0xFFD8DEE4),
      // #f6f8fa
      canvasSubtle: Color(0xFFF6F8FA),
      // #0969da
      accentFg: Color(0xFF0969DA),
      // #f6f8fa
      tableHeaderBg: Color(0xFFF6F8FA),
    );
  }
}

/// Builds [GptMarkdownThemeData] with GitHub heading / link / HR styling.
///
/// Heading sizes track [effectiveFontSize] the same way as the default path.
GptMarkdownThemeData buildGithubGptMarkdownTheme({
  required BuildContext context,
  required Color textColor,
  required double effectiveFontSize,
}) {
  final tokens = GithubMarkdownTokens.of(context);
  final base = GptMarkdownThemeData(
    brightness: Theme.of(context).brightness,
  );

  TextStyle heading(double em, {Color? color}) {
    return TextStyle(
      color: color ?? textColor,
      fontSize: effectiveFontSize * em,
      fontWeight: FontWeight.w600,
      height: 1.25,
    );
  }

  return base.copyWith(
    highlightColor: tokens.canvasSubtle,
    // GitHub heading scale: 2 / 1.5 / 1.25 / 1 / 0.875 / 0.85
    h1: heading(2.0),
    h2: heading(1.5),
    h3: heading(1.25),
    h4: heading(1.0),
    h5: heading(0.875),
    h6: heading(0.85, color: tokens.fgMuted),
    hrLineThickness: 1,
    hrLineColor: tokens.borderMuted,
    hrLinePadding: const EdgeInsets.symmetric(vertical: 8),
    linkColor: tokens.accentFg,
    linkHoverColor: tokens.accentFg,
    autoAddDividerLineAfterH1: true,
  );
}

/// GitHub-style markdown table (bordered, muted header).
Widget githubTableBuilder(
  BuildContext context,
  List<CustomTableRow> tableRows,
  TextStyle textStyle,
  GptMarkdownConfig config,
) {
  final tokens = GithubMarkdownTokens.of(context);
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
          borderRadius: BorderRadius.circular(6),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 6,
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

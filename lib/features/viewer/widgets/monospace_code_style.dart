// lib/features/viewer/widgets/monospace_code_style.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'search_code_highlight.dart';

/// Monospace markdown code colors and builders for gpt_markdown.
///
/// Colors match [typora-monospace-theme](https://github.com/typora/typora-monospace-theme):
/// - Light inline: `#949415` (olive), ~0.9em
/// - Dark inline: `#caca16` (yellow-olive), ~0.9em
/// - Fence (light + dark): Material `#263238` bg, `#e9eded` fg, radius 3
///
/// No syntax highlighting. Search highlights via [SearchHighlightScope].
class MonospaceCodeTokens {
  const MonospaceCodeTokens._({
    required this.inlineBg,
    required this.inlineFg,
    required this.blockBg,
    required this.blockFg,
    required this.headerBg,
    required this.mutedFg,
  });

  final Color inlineBg;
  final Color inlineFg;
  final Color blockBg;
  final Color blockFg;
  final Color headerBg;
  final Color mutedFg;

  factory MonospaceCodeTokens.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return const MonospaceCodeTokens._(
        // subtle dark chip
        inlineBg: Color(0x14CCCCCC),
        // #caca16
        inlineFg: Color(0xFFCACA16),
        // Material fence #263238 (same light/dark)
        blockBg: Color(0xFF263238),
        // #e9eded
        blockFg: Color(0xFFE9EDED),
        // slightly lifted header over fence
        headerBg: Color(0xFF1E2A30),
        // gutter-like #537f7e
        mutedFg: Color(0xFF537F7E),
      );
    }
    return const MonospaceCodeTokens._(
      // very subtle chip (CSS is color-only)
      inlineBg: Color(0x14CCCCCC),
      // #949415
      inlineFg: Color(0xFF949415),
      // Material fence #263238
      blockBg: Color(0xFF263238),
      // #e9eded
      blockFg: Color(0xFFE9EDED),
      // slightly lifted header over fence
      headerBg: Color(0xFF1E2A30),
      // gutter-like #537f7e
      mutedFg: Color(0xFF537F7E),
    );
  }
}

double _resolveBaseFontSize(BuildContext context, TextStyle? style) {
  return style?.fontSize ??
      DefaultTextStyle.of(context).style.fontSize ??
      16.0;
}

/// Monospace inline code: olive monospace (~0.9em).
Widget monospaceInlineCode(BuildContext context, String text, TextStyle style) {
  return _MonospaceInlineCode(text: text, style: style);
}

class _MonospaceInlineCode extends StatelessWidget {
  const _MonospaceInlineCode({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final tokens = MonospaceCodeTokens.of(context);
    final baseSize = _resolveBaseFontSize(context, style);
    final query = SearchHighlightScope.queryOf(context);
    // Typora: font-size 0.9em; color only (no bold)
    final baseStyle = style.copyWith(
      fontFamily: 'monospace',
      fontSize: baseSize * 0.9,
      fontWeight: FontWeight.normal,
      color: tokens.inlineFg,
      height: 1.2,
      leadingDistribution: TextLeadingDistribution.even,
      background: null,
      backgroundColor: null,
    );
    final highlightBg =
        searchHighlightBackground(Theme.of(context).brightness);

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 1, 4, 1),
      decoration: BoxDecoration(
        color: tokens.inlineBg,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text.rich(
        buildQueryHighlightTextSpan(
          text: text,
          query: query,
          style: baseStyle,
          highlightBg: highlightBg,
        ),
        textHeightBehavior: const TextHeightBehavior(
          applyHeightToFirstAscent: false,
          applyHeightToLastDescent: false,
        ),
      ),
    );
  }
}

/// Monospace fenced code: Material dark pre, language + copy header.
Widget monospaceCodeBlock(
  BuildContext context,
  String name,
  String code,
  bool closed,
) {
  return _MonospaceCodeBlock(name: name.trim(), codes: code);
}

class _MonospaceCodeBlock extends StatefulWidget {
  const _MonospaceCodeBlock({required this.name, required this.codes});

  final String name;
  final String codes;

  @override
  State<_MonospaceCodeBlock> createState() => _MonospaceCodeBlockState();
}

class _MonospaceCodeBlockState extends State<_MonospaceCodeBlock> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.codes));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = MonospaceCodeTokens.of(context);
    final baseSize = _resolveBaseFontSize(context, null);
    final headerSize = baseSize * 0.75;
    // Typora fences use ~0.9em for code body relative to body.
    final codeSize = baseSize * 0.9;
    final label = widget.name.isEmpty ? 'Code' : widget.name;
    final hPad = (12.0 * baseSize / 16.0).clamp(8.0, 20.0);
    final vPad = (6.0 * baseSize / 16.0).clamp(4.0, 12.0);
    final iconSize = (14.0 * baseSize / 16.0).clamp(12.0, 22.0);
    final btnMinHeight = (28.0 * baseSize / 16.0).clamp(24.0, 40.0);
    final bodyPadH = (16.0 * baseSize / 16.0).clamp(10.0, 24.0);
    final bodyPadV = (12.0 * baseSize / 16.0).clamp(8.0, 20.0);

    return Container(
      margin: EdgeInsets.symmetric(
        vertical: (12.0 * baseSize / 16.0).clamp(6.0, 16.0),
      ),
      decoration: BoxDecoration(
        color: tokens.blockBg,
        // Typora: border: none; border-radius: 3px
        borderRadius: BorderRadius.circular(3),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // App chrome (language + copy) — not in Typora CSS, kept for UX.
          Container(
            color: tokens.headerBg,
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: headerSize,
                      color: tokens.mutedFg,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: tokens.mutedFg,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.symmetric(horizontal: hPad * 0.67),
                    minimumSize: Size(0, btnMinHeight),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: TextStyle(
                      fontSize: headerSize,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  onPressed: _copy,
                  icon: Icon(
                    _copied ? Icons.done : Icons.content_copy_outlined,
                    size: iconSize,
                  ),
                  label: Text(_copied ? 'Copied!' : 'Copy'),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: bodyPadH,
              vertical: bodyPadV,
            ),
            child: SelectableText.rich(
              buildQueryHighlightTextSpan(
                text: widget.codes,
                query: SearchHighlightScope.queryOf(context),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: codeSize,
                  height: 1.45,
                  color: tokens.blockFg,
                ),
                highlightBg: searchHighlightBackground(
                  Theme.of(context).brightness,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

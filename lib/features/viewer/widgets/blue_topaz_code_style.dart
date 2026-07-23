// lib/features/viewer/widgets/blue_topaz_code_style.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'search_code_highlight.dart';

/// Blue Topaz markdown code colors and builders for gpt_markdown.
///
/// Colors match [typora-blue-topaz-theme](https://github.com/qishaoyumu/typora-blue-topaz-theme):
/// - Light inline: `#b34800` on `#cccccc62`, bold, ~0.825em
/// - Dark inline: `#f49200` on `#4c4c4cb0`
/// - Light fence: `#f5f5f5`, no border, 5px radius
/// - Dark fence: `#1a1a1a` (`--dark-surface-2`)
///
/// No syntax highlighting (same as GitHub path). Search highlights via
/// [SearchHighlightScope].
class BlueTopazCodeTokens {
  const BlueTopazCodeTokens._({
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

  factory BlueTopazCodeTokens.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return const BlueTopazCodeTokens._(
        // #4c4c4cb0 from dark `#write code`
        inlineBg: Color(0xB04C4C4C),
        // #f49200
        inlineFg: Color(0xFFF49200),
        // --dark-surface-2 / .md-fences
        blockBg: Color(0xFF1A1A1A),
        // --text-color
        blockFg: Color(0xFFC6C6C6),
        // slightly lifted header on same surface family
        headerBg: Color(0xFF222222),
        // --md-char-color
        mutedFg: Color(0xFF5C6370),
      );
    }
    return const BlueTopazCodeTokens._(
      // #cccccc62 from light `#write code`
      inlineBg: Color(0x62CCCCCC),
      // #b34800
      inlineFg: Color(0xFFB34800),
      // .md-fences background
      blockBg: Color(0xFFF5F5F5),
      // --text-color
      blockFg: Color(0xFF0E0E0E),
      // soft lift over fence body for language/copy row
      headerBg: Color(0xFFEEEEEE),
      // --meta-content-color
      mutedFg: Color(0xFF577A87),
    );
  }
}

double _resolveBaseFontSize(BuildContext context, TextStyle? style) {
  return style?.fontSize ??
      DefaultTextStyle.of(context).style.fontSize ??
      16.0;
}

/// Blue Topaz inline code: orange monospace chip (~0.825em, bold).
Widget blueTopazInlineCode(BuildContext context, String text, TextStyle style) {
  return _BlueTopazInlineCode(text: text, style: style);
}

class _BlueTopazInlineCode extends StatelessWidget {
  const _BlueTopazInlineCode({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final tokens = BlueTopazCodeTokens.of(context);
    final baseSize = _resolveBaseFontSize(context, style);
    final query = SearchHighlightScope.queryOf(context);
    // Typora: font-size 0.825em; font-weight bold; padding ~2px; radius 3px
    final baseStyle = style.copyWith(
      fontFamily: 'monospace',
      fontSize: baseSize * 0.825,
      fontWeight: FontWeight.bold,
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

/// Blue Topaz fenced code: borderless gray pre, language + copy header.
Widget blueTopazCodeBlock(
  BuildContext context,
  String name,
  String code,
  bool closed,
) {
  return _BlueTopazCodeBlock(name: name.trim(), codes: code);
}

class _BlueTopazCodeBlock extends StatefulWidget {
  const _BlueTopazCodeBlock({required this.name, required this.codes});

  final String name;
  final String codes;

  @override
  State<_BlueTopazCodeBlock> createState() => _BlueTopazCodeBlockState();
}

class _BlueTopazCodeBlockState extends State<_BlueTopazCodeBlock> {
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
    final tokens = BlueTopazCodeTokens.of(context);
    final baseSize = _resolveBaseFontSize(context, null);
    // Typora fences use ~0.825em for code body.
    final headerSize = baseSize * 0.75;
    final codeSize = baseSize * 0.825;
    final label = widget.name.isEmpty ? 'Code' : widget.name;
    final hPad = (12.0 * baseSize / 16.0).clamp(8.0, 20.0);
    final vPad = (6.0 * baseSize / 16.0).clamp(4.0, 12.0);
    final iconSize = (14.0 * baseSize / 16.0).clamp(12.0, 22.0);
    final btnMinHeight = (28.0 * baseSize / 16.0).clamp(24.0, 40.0);
    // Typora: padding 1em 1.5em
    final bodyPadH = (24.0 * baseSize / 16.0).clamp(12.0, 32.0);
    final bodyPadV = (16.0 * baseSize / 16.0).clamp(10.0, 24.0);

    return Container(
      margin: EdgeInsets.symmetric(
        vertical: (12.0 * baseSize / 16.0).clamp(6.0, 16.0),
      ),
      decoration: BoxDecoration(
        color: tokens.blockBg,
        // Typora: border: none; border-radius: 5px
        borderRadius: BorderRadius.circular(5),
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

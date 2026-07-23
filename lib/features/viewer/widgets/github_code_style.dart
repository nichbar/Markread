// lib/features/viewer/widgets/github_code_style.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'search_code_highlight.dart';

/// Primer/GitHub markdown code colors and builders for gpt_markdown.
///
/// Inline: chip with muted bg (existing highlight style).
/// Fenced: bordered pre block with language header + copy control.
class GithubCodeTokens {
  const GithubCodeTokens._({
    required this.inlineBg,
    required this.inlineFg,
    required this.blockBg,
    required this.blockFg,
    required this.border,
    required this.headerBg,
    required this.mutedFg,
  });

  final Color inlineBg;
  final Color inlineFg;
  final Color blockBg;
  final Color blockFg;
  final Color border;
  final Color headerBg;
  final Color mutedFg;

  /// Light: Primer canvas default; dark: Primer dark.
  factory GithubCodeTokens.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return const GithubCodeTokens._(
        // #6e7681 @ ~40%
        inlineBg: Color(0x666E7681),
        // #e6edf3
        inlineFg: Color(0xFFE6EDF3),
        // #0d1117
        blockBg: Color(0xFF0D1117),
        blockFg: Color(0xFFE6EDF3),
        // #3d444d
        border: Color(0xFF3D444D),
        // #161b22
        headerBg: Color(0xFF161B22),
        // #9198a1
        mutedFg: Color(0xFF9198A1),
      );
    }
    return const GithubCodeTokens._(
      // #afb8c1 @ ~20%
      inlineBg: Color(0x33AFB8C1),
      // #1f2328
      inlineFg: Color(0xFF1F2328),
      // #f6f8fa
      blockBg: Color(0xFFF6F8FA),
      blockFg: Color(0xFF1F2328),
      // #d1d9e0
      border: Color(0xFFD1D9E0),
      // #ffffff (header slightly lifted)
      headerBg: Color(0xFFFFFFFF),
      // #59636e
      mutedFg: Color(0xFF59636E),
    );
  }
}

double _resolveBaseFontSize(BuildContext context, TextStyle? style) {
  return style?.fontSize ??
      DefaultTextStyle.of(context).style.fontSize ??
      16.0;
}

/// GitHub-style inline code (`code`): monospace, ~0.85em, padded rounded chip.
///
/// Reads size from [style] first, then ambient [DefaultTextStyle], so pinch /
/// preference scale applied either on config.style or the surrounding tree
/// both work. Implemented as a small widget so InheritedWidget updates
/// re-resolve size even if gpt_markdown reuses a WidgetSpan child instance.
Widget githubInlineCode(BuildContext context, String text, TextStyle style) {
  return _GithubInlineCode(text: text, style: style);
}

class _GithubInlineCode extends StatelessWidget {
  const _GithubInlineCode({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final tokens = GithubCodeTokens.of(context);
    final baseSize = _resolveBaseFontSize(context, style);
    final query = SearchHighlightScope.queryOf(context);
    // Keep height tight so inherited body line-height (e.g. 1.5–1.6) does
    // not push glyphs down inside the padded WidgetSpan chip.
    final baseStyle = style.copyWith(
      fontFamily: 'monospace',
      fontSize: baseSize * 0.85,
      fontWeight: FontWeight.normal,
      color: tokens.inlineFg,
      height: 1.2,
      leadingDistribution: TextLeadingDistribution.even,
      // Avoid double-painting if parent style carried a background Paint.
      background: null,
      backgroundColor: null,
    );
    final highlightBg =
        searchHighlightBackground(Theme.of(context).brightness);

    return Container(
      // Slightly more top than bottom: monospace optical center sits a hair low.
      padding: const EdgeInsets.fromLTRB(5, 1, 5, 2),
      decoration: BoxDecoration(
        color: tokens.inlineBg,
        borderRadius: BorderRadius.circular(6),
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

/// GitHub-style fenced code block for gpt_markdown [codeBuilder].
///
/// Layout matches GitHub's pre/code chrome: 1px border, 6px radius, muted
/// header with language + copy, monospace body at ~85% size. No syntax
/// highlighting (no extra dependency).
Widget githubCodeBlock(
  BuildContext context,
  String name,
  String code,
  bool closed,
) {
  return _GithubCodeBlock(name: name.trim(), codes: code);
}

class _GithubCodeBlock extends StatefulWidget {
  const _GithubCodeBlock({required this.name, required this.codes});

  final String name;
  final String codes;

  @override
  State<_GithubCodeBlock> createState() => _GithubCodeBlockState();
}

class _GithubCodeBlockState extends State<_GithubCodeBlock> {
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
    final tokens = GithubCodeTokens.of(context);
    // Prefer ambient scaled body size (config/DefaultTextStyle). WidgetSpan
    // children still inherit DefaultTextStyle from the markdown tree.
    final baseSize = _resolveBaseFontSize(context, null);
    final headerSize = baseSize * 0.75;
    final codeSize = baseSize * 0.85;
    final label = widget.name.isEmpty ? 'Code' : widget.name;
    // Scale chrome with body so language/copy header tracks pinch scale.
    final hPad = (12.0 * baseSize / 16.0).clamp(8.0, 20.0);
    final vPad = (6.0 * baseSize / 16.0).clamp(4.0, 12.0);
    final iconSize = (14.0 * baseSize / 16.0).clamp(12.0, 22.0);
    final btnMinHeight = (28.0 * baseSize / 16.0).clamp(24.0, 40.0);
    final bodyPad = (16.0 * baseSize / 16.0).clamp(10.0, 24.0);

    return Container(
      margin: EdgeInsets.symmetric(vertical: (8.0 * baseSize / 16.0).clamp(4.0, 14.0)),
      decoration: BoxDecoration(
        color: tokens.blockBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: tokens.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          Divider(height: 1, thickness: 1, color: tokens.border),
          fencedCodeBody(
            wrap: CodeBlockWrapScope.wrapOf(context),
            padding: EdgeInsets.all(bodyPad),
            textSpan: buildQueryHighlightTextSpan(
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
        ],
      ),
    );
  }
}

/// Default-theme inline code with paint-time search highlights.
Widget defaultInlineCode(BuildContext context, String text, TextStyle style) {
  final query = SearchHighlightScope.queryOf(context);
  final baseSize = _resolveBaseFontSize(context, style);
  final theme = Theme.of(context);
  final chipBg = theme.colorScheme.onSurfaceVariant.withAlpha(40);
  final baseStyle = style.copyWith(
    fontFamily: 'monospace',
    fontSize: baseSize * 0.9,
    height: 1.2,
    leadingDistribution: TextLeadingDistribution.even,
    background: null,
    backgroundColor: null,
  );
  return Container(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 1),
    decoration: BoxDecoration(
      color: chipBg,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text.rich(
      buildQueryHighlightTextSpan(
        text: text,
        query: query,
        style: baseStyle,
        highlightBg: searchHighlightBackground(theme.brightness),
      ),
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: false,
        applyHeightToLastDescent: false,
      ),
    ),
  );
}

/// Default-theme fenced code with paint-time search highlights.
Widget defaultCodeBlock(
  BuildContext context,
  String name,
  String code,
  bool closed,
) {
  return _DefaultCodeBlock(name: name.trim(), codes: code);
}

class _DefaultCodeBlock extends StatelessWidget {
  const _DefaultCodeBlock({required this.name, required this.codes});

  final String name;
  final String codes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseSize = _resolveBaseFontSize(context, null);
    final query = SearchHighlightScope.queryOf(context);
    final style = TextStyle(
      fontFamily: 'monospace',
      fontSize: baseSize * 0.9,
      height: 1.4,
      color: theme.colorScheme.onSurface,
    );
    return Material(
      color: theme.colorScheme.onInverseSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (name.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(name, style: theme.textTheme.labelMedium),
            ),
          if (name.isNotEmpty) const Divider(height: 1),
          fencedCodeBody(
            wrap: CodeBlockWrapScope.wrapOf(context),
            padding: const EdgeInsets.all(16),
            textSpan: buildQueryHighlightTextSpan(
              text: codes,
              query: query,
              style: style,
              highlightBg: searchHighlightBackground(theme.brightness),
            ),
          ),
        ],
      ),
    );
  }
}

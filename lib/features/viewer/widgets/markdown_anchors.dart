// lib/features/viewer/widgets/markdown_anchors.dart
import 'package:flutter/material.dart';
import 'package:markread/third_party/gpt_markdown/custom_widgets/markdown_config.dart';
import 'package:markread/third_party/gpt_markdown/markdown_component.dart';

/// Private-use delimiters for search matches.
/// Format: `\uE000{index}\uE001{text}\uE002`
const String _kSearchStart = '\uE000';
const String _kSearchMid = '\uE001';
const String _kSearchEnd = '\uE002';

/// Wrap a search match with private-use delimiters so [SearchMatchMd] can
/// render a keyed, highlighted [WidgetSpan].
String wrapSearchMatch(int index, String text) {
  return '$_kSearchStart$index$_kSearchMid$text$_kSearchEnd';
}

/// Matches `\uE000{index}\uE001{text}\uE002`.
final RegExp searchMatchExp = RegExp(
  '$_kSearchStart(\\d+)$_kSearchMid([\\s\\S]*?)$_kSearchEnd',
);

/// Inline component that highlights search matches and attaches a [GlobalKey]
/// so the viewer can scroll to them accurately.
class SearchMatchMd extends InlineMd {
  SearchMatchMd(this.matchKeys);

  final List<GlobalKey> matchKeys;

  @override
  RegExp get exp => searchMatchExp;

  @override
  InlineSpan span(
    BuildContext context,
    String text,
    GptMarkdownConfig config,
  ) {
    final match = exp.firstMatch(text);
    if (match == null) {
      return TextSpan(text: text, style: config.style);
    }

    final index = int.tryParse(match.group(1) ?? '') ?? -1;
    final matchText = match.group(2) ?? '';
    final baseStyle = config.style ?? const TextStyle();
    final brightness = Theme.of(context).brightness;
    final highlightBg = brightness == Brightness.dark
        ? const Color(0xFFB8860B).withValues(alpha: 0.55)
        : const Color(0xFFFFEB3B).withValues(alpha: 0.75);
    final highlightStyle = baseStyle.copyWith(
      fontWeight: FontWeight.bold,
      backgroundColor: highlightBg,
    );

    final child = Text(matchText, style: highlightStyle);
    final keyed = (index >= 0 && index < matchKeys.length)
        ? KeyedSubtree(key: matchKeys[index], child: child)
        : child;

    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: keyed,
    );
  }
}

/// Heading component that attaches a [GlobalKey] to H1–H3 (non-empty title),
/// matching [parseHeadings] index order.
class AnchoredHTag extends HTag {
  AnchoredHTag(this.headingKeys);

  final List<GlobalKey> headingKeys;

  /// Mutable parse-order counter. Reset by building a fresh instance each
  /// [MarkdownView] build.
  int _nextIndex = 0;

  @override
  Widget build(
    BuildContext context,
    String text,
    GptMarkdownConfig config,
  ) {
    final child = super.build(context, text, config);

    final match = exp.firstMatch(text.trim());
    if (match == null) return child;

    final hash = match.namedGroup('hash') ?? '';
    final data = (match.namedGroup('data') ?? '').trim();
    final level = hash.length;

    // Mirror parseHeadings: levels 1–3, non-empty title.
    if (level < 1 || level > 3 || data.isEmpty) {
      return child;
    }

    final index = _nextIndex;
    _nextIndex++;
    if (index < 0 || index >= headingKeys.length) {
      return child;
    }

    return KeyedSubtree(key: headingKeys[index], child: child);
  }
}

/// Stock block components with [AnchoredHTag] substituted for [HTag].
List<MarkdownComponent> buildAnchoredComponents(List<GlobalKey> headingKeys) {
  return [
    CodeBlockMd(),
    LatexMathMultiLine(),
    NewLines(),
    BlockQuote(),
    TableMd(),
    AnchoredHTag(headingKeys),
    UnOrderedList(),
    OrderedList(),
    RadioButtonMd(),
    CheckBoxMd(),
    HrLine(),
    IndentMd(),
  ];
}

/// Stock inline components with [SearchMatchMd] prepended so it wins over
/// Bold/Italic and other inline parsers.
List<MarkdownComponent> buildAnchoredInlineComponents(
  List<GlobalKey> matchKeys,
) {
  return [
    SearchMatchMd(matchKeys),
    ATagMd(),
    ImageMd(),
    TableMd(),
    StrikeMd(),
    BoldMd(),
    ItalicMd(),
    UnderLineMd(),
    LatexMath(),
    LatexMathMultiLine(),
    HighlightedText(),
    SourceTag(),
  ];
}

// lib/features/viewer/widgets/search_code_highlight.dart
import 'package:flutter/material.dart';

/// Provides the active search query to nested code widgets so they can paint
/// match backgrounds without injecting markers into markdown source.
class SearchHighlightScope extends InheritedWidget {
  const SearchHighlightScope({
    super.key,
    required this.query,
    required super.child,
  });

  final String query;

  static SearchHighlightScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SearchHighlightScope>();
  }

  static String queryOf(BuildContext context) {
    return maybeOf(context)?.query ?? '';
  }

  @override
  bool updateShouldNotify(SearchHighlightScope oldWidget) {
    return query != oldWidget.query;
  }
}

/// Same yellow family as [SearchMatchMd] body highlights.
Color searchHighlightBackground(Brightness brightness) {
  return brightness == Brightness.dark
      ? const Color(0xFFB8860B).withValues(alpha: 0.55)
      : const Color(0xFFFFEB3B).withValues(alpha: 0.75);
}

/// Case-insensitive local scan; returns base-styled spans with [highlightBg]
/// on each hit. Empty [query] yields a single plain span.
List<InlineSpan> buildQueryHighlightSpans({
  required String text,
  required String query,
  required TextStyle style,
  required Color highlightBg,
}) {
  if (text.isEmpty) {
    return [TextSpan(text: text, style: style)];
  }
  if (query.isEmpty) {
    return [TextSpan(text: text, style: style)];
  }

  final lowerText = text.toLowerCase();
  final lowerQuery = query.toLowerCase();
  if (lowerQuery.isEmpty) {
    return [TextSpan(text: text, style: style)];
  }

  final highlightStyle = style.copyWith(
    backgroundColor: highlightBg,
    fontWeight: FontWeight.bold,
  );

  final spans = <InlineSpan>[];
  var start = 0;
  while (true) {
    final index = lowerText.indexOf(lowerQuery, start);
    if (index == -1) break;
    if (index > start) {
      spans.add(TextSpan(text: text.substring(start, index), style: style));
    }
    spans.add(TextSpan(
      text: text.substring(index, index + query.length),
      style: highlightStyle,
    ));
    start = index + query.length;
  }
  if (start < text.length) {
    spans.add(TextSpan(text: text.substring(start), style: style));
  }
  if (spans.isEmpty) {
    spans.add(TextSpan(text: text, style: style));
  }
  return spans;
}

/// Convenience [Text.rich] / [SelectableText.rich] root for code surfaces.
TextSpan buildQueryHighlightTextSpan({
  required String text,
  required String query,
  required TextStyle style,
  required Color highlightBg,
}) {
  final children = buildQueryHighlightSpans(
    text: text,
    query: query,
    style: style,
    highlightBg: highlightBg,
  );
  if (children.length == 1 && children.first is TextSpan) {
    return children.first as TextSpan;
  }
  return TextSpan(style: style, children: children);
}

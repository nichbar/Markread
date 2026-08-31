import 'package:flutter/material.dart';

import '../markdown_component.dart';
import '../styles/gpt_markdown_style_sheet.dart';
import 'bidi_rich_text.dart';
import 'selectable_adapter.dart';

/// A builder function for the ordered list.
typedef OrderedListBuilder =
    Widget Function(
      BuildContext context,
      String no,
      Widget child,
      GptMarkdownConfig config,
    );
typedef OrderedListWrapper = OrderedListBuilder;

/// A builder function for the unordered list.
typedef UnOrderedListBuilder =
    Widget Function(
      BuildContext context,
      Widget child,
      GptMarkdownConfig config,
    );
typedef UnOrderedListWrapper = UnOrderedListBuilder;

/// A builder function for the source tag.
typedef SourceTagBuilder =
    Widget Function(BuildContext context, String content, TextStyle textStyle);
typedef SourceTagWrapper = SourceTagBuilder;

/// A builder function for the code block.
typedef CodeBlockBuilder =
    Widget Function(
      BuildContext context,
      String name,
      String code,
      bool closed,
    );
typedef CodeWrapper = CodeBlockBuilder;

/// A builder function for the link.
typedef LinkBuilder =
    Widget Function(
      BuildContext context,
      InlineSpan text,
      String url,
      TextStyle style,
    );
typedef LinkWrapper = LinkBuilder;

/// A builder function for the table.
typedef TableBuilder =
    Widget Function(
      BuildContext context,
      List<CustomTableRow> tableRows,
      TextStyle textStyle,
      GptMarkdownConfig config,
    );
typedef TableWrapper = TableBuilder;

/// A builder function for the highlight.
typedef HighlightBuilder =
    Widget Function(BuildContext context, String text, TextStyle style);
typedef HighlightWrapper = HighlightBuilder;

/// A builder function for the image.
typedef ImageBuilder =
    Widget Function(
      BuildContext context,
      String imageUrl,
      double? width,
      double? height,
    );
typedef ImageWrapper = ImageBuilder;

/// A builder function for latex math expressions.
typedef LatexBuilder =
    Widget Function(
      BuildContext context,
      String latex,
      TextStyle textStyle,
      bool inline,
    );
typedef LatexWrapper = LatexBuilder;

/// A configuration class for the GPT Markdown component.
class GptMarkdownConfig {
  const GptMarkdownConfig({
    this.style,
    this.styleSheet,
    this.textDirection = TextDirection.ltr,
    this.onLinkTap,
    this.onLinkTab,
    this.textAlign,
    this.textScaler,
    this.followLinkColor = false,
    this.codeBuilder,
    this.sourceTagBuilder,
    this.highlightBuilder,
    this.orderedListBuilder,
    this.unOrderedListBuilder,
    this.linkBuilder,
    this.imageBuilder,
    this.latexBuilder,
    this.maxLines,
    this.overflow,
    this.components,
    this.inlineComponents,
    this.tableBuilder,
    this.selectable = false,
  });

  /// The direction of the text.
  final TextDirection textDirection;

  /// The style of the text.
  final TextStyle? style;

  /// The style sheet.
  final GptMarkdownStyleSheet? styleSheet;

  /// The alignment of the text.
  final TextAlign? textAlign;

  /// The text scaler.
  final TextScaler? textScaler;

  /// The callback function to handle link clicks.
  final void Function(String url, String title)? onLinkTap;

  /// Alias for [onLinkTap].
  final void Function(String url, String title)? onLinkTab;

  /// The source tag builder.
  final SourceTagBuilder? sourceTagBuilder;

  /// Whether to follow the link color.
  final bool followLinkColor;

  /// The code builder.
  final CodeBlockBuilder? codeBuilder;

  /// The Ordered List builder.
  final OrderedListBuilder? orderedListBuilder;

  /// The Unordered List builder.
  final UnOrderedListBuilder? unOrderedListBuilder;

  /// The maximum number of lines.
  final int? maxLines;

  /// The overflow.
  final TextOverflow? overflow;

  /// The highlight builder.
  final HighlightBuilder? highlightBuilder;

  /// The link builder.
  final LinkBuilder? linkBuilder;

  /// The image builder.
  final ImageBuilder? imageBuilder;

  /// The latex builder.
  final LatexBuilder? latexBuilder;

  /// The list of components.
  final List<MarkdownComponent>? components;

  /// The list of inline components.
  final List<MarkdownComponent>? inlineComponents;

  /// The table builder.
  final TableBuilder? tableBuilder;

  /// Whether the text should be selectable.
  final bool selectable;

  /// A copy of the configuration with the specified parameters.
  GptMarkdownConfig copyWith({
    TextStyle? style,
    GptMarkdownStyleSheet? styleSheet,
    TextDirection? textDirection,
    void Function(String url, String title)? onLinkTap,
    void Function(String url, String title)? onLinkTab,
    TextAlign? textAlign,
    TextScaler? textScaler,
    SourceTagBuilder? sourceTagBuilder,
    bool? followLinkColor,
    CodeBlockBuilder? codeBuilder,
    int? maxLines,
    TextOverflow? overflow,
    HighlightBuilder? highlightBuilder,
    LinkBuilder? linkBuilder,
    ImageBuilder? imageBuilder,
    LatexBuilder? latexBuilder,
    OrderedListBuilder? orderedListBuilder,
    UnOrderedListBuilder? unOrderedListBuilder,
    List<MarkdownComponent>? components,
    List<MarkdownComponent>? inlineComponents,
    TableBuilder? tableBuilder,
    bool? selectable,
  }) {
    return GptMarkdownConfig(
      style: style ?? this.style,
      styleSheet: styleSheet ?? this.styleSheet,
      textDirection: textDirection ?? this.textDirection,
      onLinkTap: onLinkTap ?? this.onLinkTap,
      onLinkTab: onLinkTab ?? this.onLinkTab,
      textAlign: textAlign ?? this.textAlign,
      textScaler: textScaler ?? this.textScaler,
      followLinkColor: followLinkColor ?? this.followLinkColor,
      codeBuilder: codeBuilder ?? this.codeBuilder,
      sourceTagBuilder: sourceTagBuilder ?? this.sourceTagBuilder,
      maxLines: maxLines ?? this.maxLines,
      overflow: overflow ?? this.overflow,
      highlightBuilder: highlightBuilder ?? this.highlightBuilder,
      linkBuilder: linkBuilder ?? this.linkBuilder,
      imageBuilder: imageBuilder ?? this.imageBuilder,
      latexBuilder: latexBuilder ?? this.latexBuilder,
      orderedListBuilder: orderedListBuilder ?? this.orderedListBuilder,
      unOrderedListBuilder: unOrderedListBuilder ?? this.unOrderedListBuilder,
      components: components ?? this.components,
      inlineComponents: inlineComponents ?? this.inlineComponents,
      tableBuilder: tableBuilder ?? this.tableBuilder,
      selectable: selectable ?? this.selectable,
    );
  }

  /// A method to get a rich text widget from an inline span.
  Widget getRich(InlineSpan span) {
    final child = BidiRichText(
      textSpan: span,
      textDirection: textDirection,
      textScaler: textScaler,
      textAlign: textAlign ?? TextAlign.start,
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );

    if (selectable) {
      return SelectableAdapter(
        selectable: true,
        child: child,
      );
    }
    return child;
  }

  /// A method to check if the configuration is the same.
  ///
  /// Includes custom builders and styleSheet so remounts/rebuilds that only swap chrome
  /// (code / table / highlight / link) still regenerate spans.
  bool isSame(GptMarkdownConfig other) {
    return style == other.style &&
        styleSheet == other.styleSheet &&
        textAlign == other.textAlign &&
        textScaler == other.textScaler &&
        maxLines == other.maxLines &&
        overflow == other.overflow &&
        followLinkColor == other.followLinkColor &&
        selectable == other.selectable &&
        textDirection == other.textDirection &&
        codeBuilder == other.codeBuilder &&
        highlightBuilder == other.highlightBuilder &&
        tableBuilder == other.tableBuilder &&
        linkBuilder == other.linkBuilder &&
        imageBuilder == other.imageBuilder &&
        latexBuilder == other.latexBuilder &&
        sourceTagBuilder == other.sourceTagBuilder &&
        orderedListBuilder == other.orderedListBuilder &&
        unOrderedListBuilder == other.unOrderedListBuilder;
  }
}

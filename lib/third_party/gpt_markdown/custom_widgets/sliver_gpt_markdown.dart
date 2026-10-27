import 'package:material_ui/material_ui.dart';

import '../gpt_markdown.dart';

/// Viewport-lazy Markdown sliver for placing inside [CustomScrollView.slivers].
class SliverGptMarkdown extends StatelessWidget {
  const SliverGptMarkdown(
    this.data, {
    super.key,
    this.style,
    this.styleSheet,
    this.followLinkColor = false,
    this.textDirection = TextDirection.ltr,
    this.textAlign,
    this.imageBuilder,
    this.textScaler,
    this.onLinkTap,
    this.onLinkTab,
    this.codeBuilder,
    this.sourceTagBuilder,
    this.highlightBuilder,
    this.linkBuilder,
    this.latexBuilder,
    this.alertBuilder,
    this.maxLines,
    this.overflow,
    this.orderedListBuilder,
    this.unOrderedListBuilder,
    this.tableBuilder,
    this.components,
    this.inlineComponents,
    this.selectable = false,
    this.onCheckboxTap,
    this.checkboxStartIndex = 0,
    this.useDollarSignsForLatex = false,
  });

  final String data;
  final TextDirection? textDirection;
  final TextStyle? style;
  final GptMarkdownStyleSheet? styleSheet;
  final TextAlign? textAlign;
  final TextScaler? textScaler;
  final void Function(String url, String title)? onLinkTap;
  final void Function(String url, String title)? onLinkTab;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool followLinkColor;
  final CodeBlockBuilder? codeBuilder;
  final SourceTagBuilder? sourceTagBuilder;
  final HighlightBuilder? highlightBuilder;
  final LinkBuilder? linkBuilder;
  final ImageBuilder? imageBuilder;
  final LatexBuilder? latexBuilder;
  final AlertBuilder? alertBuilder;
  final OrderedListBuilder? orderedListBuilder;
  final UnOrderedListBuilder? unOrderedListBuilder;
  final bool selectable;
  final TableBuilder? tableBuilder;
  final List<MarkdownComponent>? components;
  final List<MarkdownComponent>? inlineComponents;
  final void Function(int index, bool value)? onCheckboxTap;
  final int checkboxStartIndex;
  final bool useDollarSignsForLatex;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: GptMarkdown(
        data,
        style: style,
        styleSheet: styleSheet,
        followLinkColor: followLinkColor,
        textDirection: textDirection,
        textAlign: textAlign,
        imageBuilder: imageBuilder,
        textScaler: textScaler,
        onLinkTap: onLinkTap,
        onLinkTab: onLinkTab,
        codeBuilder: codeBuilder,
        sourceTagBuilder: sourceTagBuilder,
        highlightBuilder: highlightBuilder,
        linkBuilder: linkBuilder,
        latexBuilder: latexBuilder,
        alertBuilder: alertBuilder,
        maxLines: maxLines,
        overflow: overflow,
        orderedListBuilder: orderedListBuilder,
        unOrderedListBuilder: unOrderedListBuilder,
        tableBuilder: tableBuilder,
        components: components,
        inlineComponents: inlineComponents,
        selectable: selectable,
        onCheckboxTap: onCheckboxTap,
        checkboxStartIndex: checkboxStartIndex,
      ),
    );
  }
}

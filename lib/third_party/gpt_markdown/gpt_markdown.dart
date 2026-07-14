import 'package:flutter/material.dart';

import 'custom_widgets/markdown_config.dart';
import 'markdown_component.dart';
import 'md_widget.dart';

/// This widget create a full markdown widget as a column view.
class GptMarkdown extends StatelessWidget {
  const GptMarkdown(
    this.data, {
    super.key,
    this.style,
    this.followLinkColor = false,
    this.textDirection = TextDirection.ltr,
    this.textAlign,
    this.imageBuilder,
    this.textScaler,
    this.onLinkTap,
    this.codeBuilder,
    this.sourceTagBuilder,
    this.highlightBuilder,
    this.linkBuilder,
    this.maxLines,
    this.overflow,
    this.orderedListBuilder,
    this.unOrderedListBuilder,
    this.tableBuilder,
    this.components,
    this.inlineComponents,
    this.selectable = false,
  });

  /// The direction of the text.
  final TextDirection textDirection;

  /// The data to be displayed.
  final String data;

  /// The style of the text.
  final TextStyle? style;

  /// The alignment of the text.
  final TextAlign? textAlign;

  /// The text scaler.
  final TextScaler? textScaler;

  /// The callback function to handle link clicks.
  final void Function(String url, String title)? onLinkTap;

  final int? maxLines;

  /// The overflow.
  final TextOverflow? overflow;

  /// Whether to follow the link color.
  final bool followLinkColor;

  /// The code builder.
  final CodeBlockBuilder? codeBuilder;

  /// The source tag builder.
  final SourceTagBuilder? sourceTagBuilder;

  /// The highlight builder.
  final HighlightBuilder? highlightBuilder;

  /// The link builder.
  final LinkBuilder? linkBuilder;

  /// The image builder.
  final ImageBuilder? imageBuilder;

  /// The ordered list builder.
  final OrderedListBuilder? orderedListBuilder;

  /// The unordered list builder.
  final UnOrderedListBuilder? unOrderedListBuilder;

  /// Whether the text should be selectable.
  final bool selectable;

  /// The table builder.
  final TableBuilder? tableBuilder;

  /// The list of components.
  final List<MarkdownComponent>? components;

  /// The list of inline components.
  final List<MarkdownComponent>? inlineComponents;

  @override
  Widget build(BuildContext context) {
    final text = data.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
    return ClipRRect(
      child: MdWidget(
        context,
        text,
        true,
        config: GptMarkdownConfig(
          textDirection: textDirection,
          style: style,
          onLinkTap: onLinkTap,
          textAlign: textAlign,
          textScaler: textScaler,
          followLinkColor: followLinkColor,
          codeBuilder: codeBuilder,
          maxLines: maxLines,
          overflow: overflow,
          sourceTagBuilder: sourceTagBuilder,
          highlightBuilder: highlightBuilder,
          linkBuilder: linkBuilder,
          imageBuilder: imageBuilder,
          orderedListBuilder: orderedListBuilder,
          unOrderedListBuilder: unOrderedListBuilder,
          components: components,
          inlineComponents: inlineComponents,
          tableBuilder: tableBuilder,
          selectable: selectable,
        ),
      ),
    );
  }
}

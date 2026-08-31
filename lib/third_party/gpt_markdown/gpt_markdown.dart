import 'package:flutter/material.dart';

import 'custom_widgets/markdown_config.dart';
import 'markdown_component.dart';
import 'md_widget.dart';
import 'styles/gpt_markdown_style_sheet.dart';

export 'autolink.dart';
export 'custom_widgets/bidi_rich_text.dart';
export 'custom_widgets/inline_code.dart';
export 'custom_widgets/markdown_config.dart';
export 'custom_widgets/selectable_adapter.dart';
export 'inline_pattern.dart';
export 'markdown_component.dart';
export 'streaming/reveal_engine.dart';
export 'streaming/stream_split.dart';
export 'streaming/streaming_markdown.dart';
export 'styles/block_quote_style.dart';
export 'styles/checkbox_style.dart';
export 'styles/code_block_style.dart';
export 'styles/gpt_markdown_style_sheet.dart';
export 'styles/heading_style.dart';
export 'styles/hr_style.dart';
export 'styles/image_style.dart';
export 'styles/latex_style.dart';
export 'styles/link_style.dart';
export 'styles/list_style.dart';
export 'styles/source_tag_style.dart';
export 'styles/table_style.dart';
export 'theme.dart';

/// Full markdown rendering widget.
class GptMarkdown extends StatelessWidget {
  const GptMarkdown(
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
    this.maxLines,
    this.overflow,
    this.orderedListBuilder,
    this.unOrderedListBuilder,
    this.tableBuilder,
    this.components,
    this.inlineComponents,
    this.selectable = false,
  });

  /// The data to be displayed.
  final String data;

  /// The direction of the text.
  final TextDirection? textDirection;

  /// The style of the text.
  final TextStyle? style;

  /// The markdown style sheet.
  final GptMarkdownStyleSheet? styleSheet;

  /// The alignment of the text.
  final TextAlign? textAlign;

  /// The text scaler.
  final TextScaler? textScaler;

  /// The callback function to handle link clicks.
  final void Function(String url, String title)? onLinkTap;

  /// Alias for [onLinkTap].
  final void Function(String url, String title)? onLinkTab;

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

  /// The latex math builder.
  final LatexBuilder? latexBuilder;

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
          textDirection: textDirection ?? TextDirection.ltr,
          style: style,
          styleSheet: styleSheet,
          onLinkTap: onLinkTap ?? onLinkTab,
          onLinkTab: onLinkTab ?? onLinkTap,
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
          latexBuilder: latexBuilder,
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

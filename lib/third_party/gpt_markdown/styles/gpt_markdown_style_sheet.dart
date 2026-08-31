import 'package:flutter/material.dart';

import 'block_quote_style.dart';
import 'checkbox_style.dart';
import 'code_block_style.dart';
import 'heading_style.dart';
import 'hr_style.dart';
import 'image_style.dart';
import 'latex_style.dart';
import 'link_style.dart';
import 'list_style.dart';
import 'source_tag_style.dart';
import 'style_lerp.dart';
import 'table_style.dart';

/// Complete style sheet for configuring gpt_markdown elements.
class GptMarkdownStyleSheet {
  const GptMarkdownStyleSheet({
    this.h1,
    this.h2,
    this.h3,
    this.h4,
    this.h5,
    this.h6,
    this.p,
    this.strong,
    this.em,
    this.del,
    this.sub,
    this.sup,
    this.inlineCode,
    this.codeBlock,
    this.blockQuote,
    this.table,
    this.tableHeader,
    this.tableBody,
    this.link,
    this.linkHover,
    this.sourceTag,
    this.headingStyle,
    this.blockQuoteStyle,
    this.codeBlockStyle,
    this.tableStyle,
    this.linkStyle,
    this.listStyle,
    this.hrStyle,
    this.imageStyle,
    this.checkboxStyle,
    this.latexStyle,
    this.sourceTagStyle,
    this.textScaleFactor,
    this.textAlign,
  });

  final TextStyle? h1;
  final TextStyle? h2;
  final TextStyle? h3;
  final TextStyle? h4;
  final TextStyle? h5;
  final TextStyle? h6;
  final TextStyle? p;
  final TextStyle? strong;
  final TextStyle? em;
  final TextStyle? del;
  final TextStyle? sub;
  final TextStyle? sup;
  final TextStyle? inlineCode;
  final TextStyle? codeBlock;
  final TextStyle? blockQuote;
  final TextStyle? table;
  final TextStyle? tableHeader;
  final TextStyle? tableBody;
  final TextStyle? link;
  final TextStyle? linkHover;
  final TextStyle? sourceTag;

  final HeadingStyle? headingStyle;
  final BlockQuoteStyle? blockQuoteStyle;
  final CodeBlockStyle? codeBlockStyle;
  final TableStyle? tableStyle;
  final LinkStyle? linkStyle;
  final ListStyle? listStyle;
  final HrStyle? hrStyle;
  final ImageStyle? imageStyle;
  final CheckboxStyle? checkboxStyle;
  final LatexStyle? latexStyle;
  final SourceTagStyle? sourceTagStyle;

  final double? textScaleFactor;
  final TextAlign? textAlign;

  /// Creates a style sheet from a Flutter [ThemeData].
  factory GptMarkdownStyleSheet.fromTheme(ThemeData theme) {
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return GptMarkdownStyleSheet(
      p: textTheme.bodyMedium,
      h1: textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
      h2: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
      h3: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
      h4: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      h5: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      h6: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
      strong: const TextStyle(fontWeight: FontWeight.bold),
      em: const TextStyle(fontStyle: FontStyle.italic),
      del: const TextStyle(decoration: TextDecoration.lineThrough),
      inlineCode: TextStyle(
        fontFamily: 'monospace',
        backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
      codeBlock: const TextStyle(fontFamily: 'monospace'),
      blockQuote: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
        fontStyle: FontStyle.italic,
      ),
      link: TextStyle(
        color: colorScheme.primary,
        decoration: TextDecoration.underline,
      ),
      linkHover: TextStyle(
        color: colorScheme.primary,
        decoration: TextDecoration.underline,
      ),
      headingStyle: HeadingStyle(
        h1: textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
        h2: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        h3: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        h4: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        h5: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        h6: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
      codeBlockStyle: CodeBlockStyle(
        backgroundColor: colorScheme.surfaceContainerHighest,
        textStyle: const TextStyle(fontFamily: 'monospace'),
      ),
      blockQuoteStyle: BlockQuoteStyle(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: colorScheme.outlineVariant,
              width: 4.0,
            ),
          ),
        ),
        padding: const EdgeInsets.only(left: 12.0, top: 4.0, bottom: 4.0),
        textStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      tableStyle: TableStyle(
        borderColor: colorScheme.outlineVariant,
        headerBackgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        cellPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        headerPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      ),
      hrStyle: HrStyle(
        color: colorScheme.outlineVariant,
        thickness: 1.0,
        height: 16.0,
      ),
    );
  }

  GptMarkdownStyleSheet copyWith({
    TextStyle? h1,
    TextStyle? h2,
    TextStyle? h3,
    TextStyle? h4,
    TextStyle? h5,
    TextStyle? h6,
    TextStyle? p,
    TextStyle? strong,
    TextStyle? em,
    TextStyle? del,
    TextStyle? sub,
    TextStyle? sup,
    TextStyle? inlineCode,
    TextStyle? codeBlock,
    TextStyle? blockQuote,
    TextStyle? table,
    TextStyle? tableHeader,
    TextStyle? tableBody,
    TextStyle? link,
    TextStyle? linkHover,
    TextStyle? sourceTag,
    HeadingStyle? headingStyle,
    BlockQuoteStyle? blockQuoteStyle,
    CodeBlockStyle? codeBlockStyle,
    TableStyle? tableStyle,
    LinkStyle? linkStyle,
    ListStyle? listStyle,
    HrStyle? hrStyle,
    ImageStyle? imageStyle,
    CheckboxStyle? checkboxStyle,
    LatexStyle? latexStyle,
    SourceTagStyle? sourceTagStyle,
    double? textScaleFactor,
    TextAlign? textAlign,
  }) {
    return GptMarkdownStyleSheet(
      h1: h1 ?? this.h1,
      h2: h2 ?? this.h2,
      h3: h3 ?? this.h3,
      h4: h4 ?? this.h4,
      h5: h5 ?? this.h5,
      h6: h6 ?? this.h6,
      p: p ?? this.p,
      strong: strong ?? this.strong,
      em: em ?? this.em,
      del: del ?? this.del,
      sub: sub ?? this.sub,
      sup: sup ?? this.sup,
      inlineCode: inlineCode ?? this.inlineCode,
      codeBlock: codeBlock ?? this.codeBlock,
      blockQuote: blockQuote ?? this.blockQuote,
      table: table ?? this.table,
      tableHeader: tableHeader ?? this.tableHeader,
      tableBody: tableBody ?? this.tableBody,
      link: link ?? this.link,
      linkHover: linkHover ?? this.linkHover,
      sourceTag: sourceTag ?? this.sourceTag,
      headingStyle: headingStyle ?? this.headingStyle,
      blockQuoteStyle: blockQuoteStyle ?? this.blockQuoteStyle,
      codeBlockStyle: codeBlockStyle ?? this.codeBlockStyle,
      tableStyle: tableStyle ?? this.tableStyle,
      linkStyle: linkStyle ?? this.linkStyle,
      listStyle: listStyle ?? this.listStyle,
      hrStyle: hrStyle ?? this.hrStyle,
      imageStyle: imageStyle ?? this.imageStyle,
      checkboxStyle: checkboxStyle ?? this.checkboxStyle,
      latexStyle: latexStyle ?? this.latexStyle,
      sourceTagStyle: sourceTagStyle ?? this.sourceTagStyle,
      textScaleFactor: textScaleFactor ?? this.textScaleFactor,
      textAlign: textAlign ?? this.textAlign,
    );
  }

  GptMarkdownStyleSheet merge(GptMarkdownStyleSheet? other) {
    if (other == null) return this;
    return copyWith(
      h1: other.h1 ?? h1,
      h2: other.h2 ?? h2,
      h3: other.h3 ?? h3,
      h4: other.h4 ?? h4,
      h5: other.h5 ?? h5,
      h6: other.h6 ?? h6,
      p: other.p ?? p,
      strong: other.strong ?? strong,
      em: other.em ?? em,
      del: other.del ?? del,
      sub: other.sub ?? sub,
      sup: other.sup ?? sup,
      inlineCode: other.inlineCode ?? inlineCode,
      codeBlock: other.codeBlock ?? codeBlock,
      blockQuote: other.blockQuote ?? blockQuote,
      table: other.table ?? table,
      tableHeader: other.tableHeader ?? tableHeader,
      tableBody: other.tableBody ?? tableBody,
      link: other.link ?? link,
      linkHover: other.linkHover ?? linkHover,
      sourceTag: other.sourceTag ?? sourceTag,
      headingStyle: other.headingStyle ?? headingStyle,
      blockQuoteStyle: other.blockQuoteStyle ?? blockQuoteStyle,
      codeBlockStyle: other.codeBlockStyle ?? codeBlockStyle,
      tableStyle: other.tableStyle ?? tableStyle,
      linkStyle: other.linkStyle ?? linkStyle,
      listStyle: other.listStyle ?? listStyle,
      hrStyle: other.hrStyle ?? hrStyle,
      imageStyle: other.imageStyle ?? imageStyle,
      checkboxStyle: other.checkboxStyle ?? checkboxStyle,
      latexStyle: other.latexStyle ?? latexStyle,
      sourceTagStyle: other.sourceTagStyle ?? sourceTagStyle,
      textScaleFactor: other.textScaleFactor ?? textScaleFactor,
      textAlign: other.textAlign ?? textAlign,
    );
  }

  static GptMarkdownStyleSheet? lerp(
    GptMarkdownStyleSheet? a,
    GptMarkdownStyleSheet? b,
    double t,
  ) {
    if (a == null && b == null) return null;
    return GptMarkdownStyleSheet(
      h1: lerpTextStyle(a?.h1, b?.h1, t),
      h2: lerpTextStyle(a?.h2, b?.h2, t),
      h3: lerpTextStyle(a?.h3, b?.h3, t),
      h4: lerpTextStyle(a?.h4, b?.h4, t),
      h5: lerpTextStyle(a?.h5, b?.h5, t),
      h6: lerpTextStyle(a?.h6, b?.h6, t),
      p: lerpTextStyle(a?.p, b?.p, t),
      strong: lerpTextStyle(a?.strong, b?.strong, t),
      em: lerpTextStyle(a?.em, b?.em, t),
      del: lerpTextStyle(a?.del, b?.del, t),
      sub: lerpTextStyle(a?.sub, b?.sub, t),
      sup: lerpTextStyle(a?.sup, b?.sup, t),
      inlineCode: lerpTextStyle(a?.inlineCode, b?.inlineCode, t),
      codeBlock: lerpTextStyle(a?.codeBlock, b?.codeBlock, t),
      blockQuote: lerpTextStyle(a?.blockQuote, b?.blockQuote, t),
      table: lerpTextStyle(a?.table, b?.table, t),
      tableHeader: lerpTextStyle(a?.tableHeader, b?.tableHeader, t),
      tableBody: lerpTextStyle(a?.tableBody, b?.tableBody, t),
      link: lerpTextStyle(a?.link, b?.link, t),
      linkHover: lerpTextStyle(a?.linkHover, b?.linkHover, t),
      sourceTag: lerpTextStyle(a?.sourceTag, b?.sourceTag, t),
      headingStyle: HeadingStyle.lerp(a?.headingStyle, b?.headingStyle, t),
      blockQuoteStyle: BlockQuoteStyle.lerp(a?.blockQuoteStyle, b?.blockQuoteStyle, t),
      codeBlockStyle: CodeBlockStyle.lerp(a?.codeBlockStyle, b?.codeBlockStyle, t),
      tableStyle: TableStyle.lerp(a?.tableStyle, b?.tableStyle, t),
      linkStyle: LinkStyle.lerp(a?.linkStyle, b?.linkStyle, t),
      listStyle: ListStyle.lerp(a?.listStyle, b?.listStyle, t),
      hrStyle: HrStyle.lerp(a?.hrStyle, b?.hrStyle, t),
      imageStyle: ImageStyle.lerp(a?.imageStyle, b?.imageStyle, t),
      checkboxStyle: CheckboxStyle.lerp(a?.checkboxStyle, b?.checkboxStyle, t),
      latexStyle: LatexStyle.lerp(a?.latexStyle, b?.latexStyle, t),
      sourceTagStyle: SourceTagStyle.lerp(a?.sourceTagStyle, b?.sourceTagStyle, t),
      textScaleFactor: a?.textScaleFactor != null && b?.textScaleFactor != null
          ? (a!.textScaleFactor! + (b!.textScaleFactor! - a.textScaleFactor!) * t)
          : (t < 0.5 ? a?.textScaleFactor : b?.textScaleFactor),
      textAlign: t < 0.5 ? a?.textAlign : b?.textAlign,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GptMarkdownStyleSheet &&
          runtimeType == other.runtimeType &&
          h1 == other.h1 &&
          h2 == other.h2 &&
          h3 == other.h3 &&
          h4 == other.h4 &&
          h5 == other.h5 &&
          h6 == other.h6 &&
          p == other.p &&
          strong == other.strong &&
          em == other.em &&
          del == other.del &&
          sub == other.sub &&
          sup == other.sup &&
          inlineCode == other.inlineCode &&
          codeBlock == other.codeBlock &&
          blockQuote == other.blockQuote &&
          table == other.table &&
          tableHeader == other.tableHeader &&
          tableBody == other.tableBody &&
          link == other.link &&
          linkHover == other.linkHover &&
          sourceTag == other.sourceTag &&
          headingStyle == other.headingStyle &&
          blockQuoteStyle == other.blockQuoteStyle &&
          codeBlockStyle == other.codeBlockStyle &&
          tableStyle == other.tableStyle &&
          linkStyle == other.linkStyle &&
          listStyle == other.listStyle &&
          hrStyle == other.hrStyle &&
          imageStyle == other.imageStyle &&
          checkboxStyle == other.checkboxStyle &&
          latexStyle == other.latexStyle &&
          sourceTagStyle == other.sourceTagStyle &&
          textScaleFactor == other.textScaleFactor &&
          textAlign == other.textAlign;

  @override
  int get hashCode => Object.hashAll([
        h1,
        h2,
        h3,
        h4,
        h5,
        h6,
        p,
        strong,
        em,
        del,
        sub,
        sup,
        inlineCode,
        codeBlock,
        blockQuote,
        table,
        tableHeader,
        tableBody,
        link,
        linkHover,
        sourceTag,
        headingStyle,
        blockQuoteStyle,
        codeBlockStyle,
        tableStyle,
        linkStyle,
        listStyle,
        hrStyle,
        imageStyle,
        checkboxStyle,
        latexStyle,
        sourceTagStyle,
        textScaleFactor,
        textAlign,
      ]);
}

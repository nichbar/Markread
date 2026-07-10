// lib/features/viewer/widgets/markdown_view.dart
import 'package:flutter/material.dart';
import 'package:markread/third_party/gpt_markdown/gpt_markdown.dart';
import 'package:markread/third_party/gpt_markdown/theme.dart';
import '../../../core/models/user_preferences.dart';
import 'zoomable_area.dart';

class MarkdownView extends StatelessWidget {
  final String content;
  final double fontSize;
  final double lineHeight;
  final ReadingTextAlign textAlignment;
  final ReadingFont readingFont;
  final bool isWordWrapEnabled;
  final ScrollController? scrollController;
  final Color? textColor;
  final void Function(String url, String title)? onLinkTap;
  final double fontScale;
  final ValueChanged<double>? onFontScaleChanged;

  const MarkdownView({
    super.key,
    required this.content,
    this.fontSize = 16.0,
    this.lineHeight = 1.6,
    this.textAlignment = ReadingTextAlign.left,
    this.readingFont = ReadingFont.merriweather,
    this.isWordWrapEnabled = true,
    this.scrollController,
    this.textColor,
    this.onLinkTap,
    this.fontScale = 1.0,
    this.onFontScaleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textAlign = textAlignment == ReadingTextAlign.justified
        ? TextAlign.justify
        : TextAlign.left;

    final fontFamily = readingFont == ReadingFont.merriweather
        ? 'Merriweather'
        : null;

    final parentStyle = DefaultTextStyle.of(context).style;
    final resolvedColor = textColor ?? parentStyle.color;
    // Strip color to prevent MdWidget re-parsing on every animation frame
    // during AnimatedDefaultTextStyle transitions. Color is inherited via
    // DefaultTextStyle and heading theme overrides.
    final stableStyle = parentStyle.copyWith(color: null);

    // Build a GptMarkdownTheme that injects the reader's text color
    // into heading styles so that HTag components inherit it regardless
    // of how DefaultTextStyle propagates through WidgetSpan children.
    final baseTheme = GptMarkdownThemeData(
      brightness: Theme.of(context).brightness,
    );
    final gptTheme = baseTheme.copyWith(
      h1: baseTheme.h1?.copyWith(color: resolvedColor),
      h2: baseTheme.h2?.copyWith(color: resolvedColor),
      h3: baseTheme.h3?.copyWith(color: resolvedColor),
      h4: baseTheme.h4?.copyWith(color: resolvedColor),
      h5: baseTheme.h5?.copyWith(color: resolvedColor),
      h6: baseTheme.h6?.copyWith(color: resolvedColor),
    );

    final effectiveFontSize = fontSize * fontScale;

    final textWidget = DefaultTextStyle(
      style: TextStyle(
        fontSize: effectiveFontSize,
        height: lineHeight,
        fontFamily: fontFamily,
      ),
      textAlign: textAlign,
      child: SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        child: RepaintBoundary(
          child: GptMarkdownTheme(
            gptThemeData: gptTheme,
            child: GptMarkdown(content, style: stableStyle, onLinkTap: onLinkTap),
          ),
        ),
      ),
    );

    Widget result;
    if (!isWordWrapEnabled) {
      result = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 800,
          child: textWidget,
        ),
      );
    } else {
      result = textWidget;
    }

    return ZoomableArea(
      scale: fontScale,
      onScaleChanged: onFontScaleChanged,
      child: result,
    );
  }
}

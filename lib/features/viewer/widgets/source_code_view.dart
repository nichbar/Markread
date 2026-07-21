// lib/features/viewer/widgets/source_code_view.dart
import 'package:flutter/material.dart';
import 'package:markread/third_party/gpt_markdown/gpt_markdown.dart';
import 'github_code_style.dart';
import 'zoomable_area.dart';

class SourceCodeView extends StatelessWidget {
  final String content;
  final String language;
  final double fontSize;
  final double lineHeight;
  final bool isWordWrapEnabled;
  final ScrollController? scrollController;
  final void Function(String url, String title)? onLinkTap;
  final double fontScale;
  final ValueChanged<double>? onFontScaleChanged;

  const SourceCodeView({
    super.key,
    required this.content,
    required this.language,
    this.fontSize = 16.0,
    this.lineHeight = 1.6,
    this.isWordWrapEnabled = true,
    this.scrollController,
    this.onLinkTap,
    this.fontScale = 1.0,
    this.onFontScaleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final wrapped = '```$language\n$content\n```';

    final effectiveFontSize = fontSize * fontScale;
    final stableStyle = DefaultTextStyle.of(context).style.copyWith(
      color: null,
      fontSize: effectiveFontSize,
      height: lineHeight,
      fontFamily: 'monospace',
    );

    final codeWidget = DefaultTextStyle(
      style: TextStyle(
        fontSize: effectiveFontSize,
        height: lineHeight,
        fontFamily: 'monospace',
      ),
      child: SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        child: GptMarkdown(
          wrapped,
          style: stableStyle,
          onLinkTap: onLinkTap,
          highlightBuilder: githubInlineCode,
          codeBuilder: githubCodeBlock,
        ),
      ),
    );

    if (!isWordWrapEnabled) {
      return ZoomableArea(
        scale: fontScale,
        onScaleChanged: onFontScaleChanged,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 800,
            child: codeWidget,
          ),
        ),
      );
    }

    return ZoomableArea(
      scale: fontScale,
      onScaleChanged: onFontScaleChanged,
      child: codeWidget,
    );
  }
}

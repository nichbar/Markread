import 'package:flutter/material.dart';
import 'custom_widgets/markdown_config.dart';
import 'markdown_component.dart';

/// A custom inline pattern component that can be added to [GptMarkdown].
class InlinePattern extends InlineMd {
  InlinePattern({
    required this.pattern,
    required this.builder,
    this.tag,
  });

  final String pattern;
  final InlineSpan Function(
    BuildContext context,
    Match match,
    GptMarkdownConfig config,
  ) builder;
  final String? tag;

  @override
  RegExp get exp => RegExp(pattern);

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
    return builder(context, match, config);
  }
}

import 'package:flutter/material.dart';

import 'custom_widgets/link_button.dart';
import 'custom_widgets/markdown_config.dart';
import 'markdown_component.dart';
import 'theme.dart';

/// Autolink inline markdown component for detecting raw URLs and email addresses.
class AutolinkMd extends InlineMd {
  AutolinkMd();

  static const String _urlPattern =
      r'(?:https?:\/\/|ftp:\/\/|www\.)[a-zA-Z0-9][-a-zA-Z0-9+&@#\/%?=~_|!:,.;]*[a-zA-Z0-9+&@#\/%=~_|]';
  static const String _emailPattern =
      r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}';

  static final RegExp _regex = RegExp(
    '(?:$_urlPattern)|(?:$_emailPattern)',
    caseSensitive: false,
  );

  @override
  RegExp get exp => _regex;

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

    final rawUrl = match.group(0) ?? '';
    String destination = rawUrl;
    if (rawUrl.startsWith('www.')) {
      destination = 'https://$rawUrl';
    } else if (rawUrl.contains('@') && !rawUrl.contains('://')) {
      destination = 'mailto:$rawUrl';
    }

    final theme = GptMarkdownTheme.of(context);
    final linkColor = theme.linkColor;
    final hoverColor = theme.linkHoverColor;

    final linkStyle = (config.style ?? const TextStyle()).copyWith(
      color: linkColor,
      decoration: TextDecoration.underline,
      decorationColor: linkColor,
    );

    void onTap() {
      config.onLinkTap?.call(destination, rawUrl);
      config.onLinkTab?.call(destination, rawUrl);
    }

    if (config.linkBuilder != null) {
      return WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: GestureDetector(
          onTap: onTap,
          child: config.linkBuilder!(
            context,
            TextSpan(text: rawUrl, style: linkStyle),
            destination,
            config.style ?? const TextStyle(),
          ),
        ),
      );
    }

    final child = WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: LinkButton(
        text: rawUrl,
        url: destination,
        config: config,
        color: linkColor,
        hoverColor: hoverColor,
        onPressed: onTap,
        spanBuilder: (color) {
          final spanStyle = (config.style ?? const TextStyle()).copyWith(
            color: color,
            decoration: TextDecoration.underline,
            decorationColor: color,
          );
          return TextSpan(
            text: rawUrl,
            style: spanStyle,
          );
        },
      ),
    );

    return child;
  }
}

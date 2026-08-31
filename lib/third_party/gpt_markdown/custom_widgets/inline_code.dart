import 'package:flutter/material.dart';

/// Widget that renders inline code with styling.
class InlineCode extends StatelessWidget {
  const InlineCode({
    super.key,
    required this.code,
    this.style,
    this.backgroundColor,
    this.padding,
    this.borderRadius,
    this.border,
  });

  final String code;
  final TextStyle? style;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBg = backgroundColor ??
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6);
    final effectiveStyle = (style ?? const TextStyle()).copyWith(
      fontFamily: 'monospace',
    );

    return Container(
      padding: padding ??
          const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: borderRadius ?? BorderRadius.circular(4.0),
        border: border,
      ),
      child: Text(
        code,
        style: effectiveStyle,
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// RichText wrapper that handles text directionality and bidi embedding cleanly.
class BidiRichText extends StatelessWidget {
  const BidiRichText({
    super.key,
    required this.textSpan,
    this.textDirection,
    this.textAlign = TextAlign.start,
    this.softWrap = true,
    this.overflow = TextOverflow.clip,
    this.maxLines,
    this.textScaler,
  });

  final InlineSpan textSpan;
  final TextDirection? textDirection;
  final TextAlign textAlign;
  final bool softWrap;
  final TextOverflow overflow;
  final int? maxLines;
  final TextScaler? textScaler;

  @override
  Widget build(BuildContext context) {
    final direction = textDirection ?? Directionality.maybeOf(context) ?? TextDirection.ltr;

    return Directionality(
      textDirection: direction,
      child: Text.rich(
        textSpan,
        textAlign: textAlign,
        textDirection: direction,
        softWrap: softWrap,
        overflow: overflow,
        maxLines: maxLines,
        textScaler: textScaler,
      ),
    );
  }
}

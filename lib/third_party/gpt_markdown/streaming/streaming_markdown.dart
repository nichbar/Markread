import 'dart:async';
import 'package:flutter/material.dart';

import '../gpt_markdown.dart';

/// Animated streaming widget for progressively revealing markdown text.
class StreamingGptMarkdown extends StatefulWidget {
  const StreamingGptMarkdown({
    super.key,
    this.text,
    this.stream,
    this.revealEngine,
    this.style,
    this.styleSheet,
    this.textAlign = TextAlign.start,
    this.textDirection,
    this.onLinkTap,
    this.onLinkTab,
    this.selectable = false,
    this.onComplete,
    this.codeBuilder,
    this.imageBuilder,
    this.tableBuilder,
    this.linkBuilder,
    this.sourceTagBuilder,
  });

  final String? text;
  final Stream<String>? stream;
  final RevealEngine? revealEngine;
  final TextStyle? style;
  final GptMarkdownStyleSheet? styleSheet;
  final TextAlign textAlign;
  final TextDirection? textDirection;
  final void Function(String url, String title)? onLinkTap;
  final void Function(String url, String title)? onLinkTab;
  final bool selectable;
  final VoidCallback? onComplete;
  final CodeWrapper? codeBuilder;
  final ImageWrapper? imageBuilder;
  final TableWrapper? tableBuilder;
  final LinkWrapper? linkBuilder;
  final SourceTagWrapper? sourceTagBuilder;

  @override
  State<StreamingGptMarkdown> createState() => _StreamingGptMarkdownState();
}

class _StreamingGptMarkdownState extends State<StreamingGptMarkdown> {
  late RevealEngine _engine;
  bool _ownsEngine = false;
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    if (widget.revealEngine != null) {
      _engine = widget.revealEngine!;
      _ownsEngine = false;
    } else {
      _engine = RevealEngine(onComplete: widget.onComplete);
      _ownsEngine = true;
    }
    _engine.addListener(_onEngineTick);

    if (widget.stream != null) {
      _sub = widget.stream!.listen(
        (chunk) => _engine.appendText(chunk),
        onDone: () => _engine.appendText('', isFinished: true),
      );
    } else if (widget.text != null) {
      _engine.setText(widget.text!);
    }
  }

  @override
  void didUpdateWidget(StreamingGptMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text && widget.text != null) {
      _engine.setText(widget.text!);
    }
  }

  void _onEngineTick() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _engine.removeListener(_onEngineTick);
    if (_ownsEngine) {
      _engine.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GptMarkdown(
      _engine.currentText,
      style: widget.style,
      styleSheet: widget.styleSheet,
      textAlign: widget.textAlign,
      textDirection: widget.textDirection ?? TextDirection.ltr,
      onLinkTap: widget.onLinkTap,
      onLinkTab: widget.onLinkTab,
      selectable: widget.selectable,
      codeBuilder: widget.codeBuilder,
      imageBuilder: widget.imageBuilder,
      tableBuilder: widget.tableBuilder,
      linkBuilder: widget.linkBuilder,
      sourceTagBuilder: widget.sourceTagBuilder,
    );
  }
}

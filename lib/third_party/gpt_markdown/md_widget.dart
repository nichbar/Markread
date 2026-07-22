import 'dart:math';

import 'package:flutter/material.dart';

import 'custom_widgets/markdown_config.dart';
import 'markdown_component.dart';
import 'theme.dart';

/// It creates a markdown widget closed to each other.
class MdWidget extends StatefulWidget {
  const MdWidget(
    this.context,
    this.exp,
    this.includeGlobalComponents, {
    super.key,
    required this.config,
  });

  /// The expression to be displayed.
  final String exp;
  final BuildContext context;

  /// Whether to include global components.
  final bool includeGlobalComponents;

  /// The configuration of the markdown widget.
  final GptMarkdownConfig config;

  @override
  State<MdWidget> createState() => _MdWidgetState();
}

class _MdWidgetState extends State<MdWidget> {
  List<InlineSpan> list = [];
  GptMarkdownThemeData? _lastTheme;

  void _regenerate() {
    list = MarkdownComponent.generate(
      context,
      widget.exp,
      widget.config,
      widget.includeGlobalComponents,
    );
    _lastTheme = GptMarkdownTheme.of(context);
  }

  @override
  void initState() {
    super.initState();
    // Theme/inherited widgets are safe after the first frame of dependencies;
    // generate here and refresh in didChangeDependencies when theme shifts.
    list = MarkdownComponent.generate(
      widget.context,
      widget.exp,
      widget.config,
      widget.includeGlobalComponents,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = GptMarkdownTheme.of(context);
    // Headings/links/HR bake GptMarkdownTheme into spans at generate time.
    // Re-parse when ambient markdown theme changes (e.g. Settings → Markdown
    // theme while ViewerScreen is still under the route stack).
    if (_lastTheme == null) {
      _lastTheme = theme;
      // initState used widget.context; ensure first dependency-scoped parse.
      list = MarkdownComponent.generate(
        context,
        widget.exp,
        widget.config,
        widget.includeGlobalComponents,
      );
      return;
    }
    if (!_lastTheme!.isSame(theme)) {
      _regenerate();
    }
  }

  @override
  void didUpdateWidget(covariant MdWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exp != widget.exp ||
        !oldWidget.config.isSame(widget.config)) {
      _regenerate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.config.getRich(
      TextSpan(children: list, style: widget.config.style?.copyWith()),
    );
  }
}

/// A custom table column width.
class CustomTableColumnWidth extends TableColumnWidth {
  @override
  double maxIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    double width = 50;
    for (var each in cells) {
      each.layout(const BoxConstraints(), parentUsesSize: true);
      width = max(width, each.size.width);
    }
    return min(containerWidth, width);
  }

  @override
  double minIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    return 50;
  }
}

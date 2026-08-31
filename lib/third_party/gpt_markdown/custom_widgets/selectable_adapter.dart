import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Wraps a markdown widget with a [SelectionArea] if [selectable] is true.
class SelectableAdapter extends StatelessWidget {
  const SelectableAdapter({
    super.key,
    required this.child,
    this.selectable = false,
    this.focusNode,
    this.selectionControls,
    this.onSelectionChanged,
  });

  final Widget child;
  final bool selectable;
  final FocusNode? focusNode;
  final TextSelectionControls? selectionControls;
  final ValueChanged<SelectedContent?>? onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    if (!selectable) {
      return child;
    }
    return SelectionArea(
      focusNode: focusNode,
      selectionControls: selectionControls,
      onSelectionChanged: onSelectionChanged,
      child: child,
    );
  }
}

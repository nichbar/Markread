// lib/features/viewer/widgets/search_bar.dart
import 'package:flutter/material.dart';
import 'reader_theme.dart';

class ViewerSearchBar extends StatefulWidget {
  final String query;
  final int matchIndex;
  final int matchCount;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onClear;
  final VoidCallback onBack;
  final String modeLabel;
  final ReaderColors chromeColors;

  const ViewerSearchBar({
    super.key,
    required this.query,
    required this.matchIndex,
    required this.matchCount,
    required this.onQueryChanged,
    required this.onNext,
    required this.onPrevious,
    required this.onClear,
    required this.onBack,
    required this.modeLabel,
    required this.chromeColors,
  });

  @override
  State<ViewerSearchBar> createState() => _ViewerSearchBarState();
}

class _ViewerSearchBarState extends State<ViewerSearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
    _controller.selection =
        TextSelection.collapsed(offset: widget.query.length);
  }

  @override
  void didUpdateWidget(covariant ViewerSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync text when query changes externally (e.g. onClear), but not
    // while the user is actively typing (controller already has latest).
    if (widget.query != oldWidget.query &&
        widget.query != _controller.text) {
      _controller.text = widget.query;
      _controller.selection =
          TextSelection.collapsed(offset: widget.query.length);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasMatches = widget.matchCount > 0;

    return SafeArea(
      bottom: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: TextField(
              autofocus: true,
              controller: _controller,
              onChanged: widget.onQueryChanged,
              style: TextStyle(color: widget.chromeColors.content),
              cursorColor: widget.chromeColors.content,
              decoration: InputDecoration(
                filled: true,
                fillColor: widget.chromeColors.container,
                hintText: 'Search in document',
                hintStyle: TextStyle(
                  color: widget.chromeColors.content.withAlpha(140),
                ),
                prefixIcon: IconButton(
                  icon: Icon(Icons.arrow_back,
                      color: widget.chromeColors.content),
                  onPressed: widget.onBack,
                ),
                suffixIcon: widget.query.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close,
                            color: widget.chromeColors.content),
                        onPressed: widget.onClear,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => widget.onNext(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Chip(
                  backgroundColor: widget.chromeColors.container,
                  label: Text(
                    '${widget.modeLabel} \u2022 ${hasMatches ? '${widget.matchIndex + 1} of ${widget.matchCount}' : 'No matches'}',
                    style: TextStyle(
                        color: widget.chromeColors.content, fontSize: 12),
                  ),
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                ),
                const Spacer(),
                IconButton(
                  onPressed: hasMatches ? widget.onPrevious : null,
                  icon: Icon(Icons.keyboard_arrow_up,
                      color: hasMatches
                          ? widget.chromeColors.content
                          : widget.chromeColors.muted),
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    backgroundColor: widget.chromeColors.container,
                    disabledBackgroundColor:
                        widget.chromeColors.container.withAlpha(150),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: hasMatches ? widget.onNext : null,
                  icon: Icon(Icons.keyboard_arrow_down,
                      color: hasMatches
                          ? widget.chromeColors.content
                          : widget.chromeColors.muted),
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    backgroundColor: widget.chromeColors.container,
                    disabledBackgroundColor:
                        widget.chromeColors.container.withAlpha(150),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: widget.chromeColors.container.withAlpha(127),
          ),
        ],
      ),
    );
  }
}

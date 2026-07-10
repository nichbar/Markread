// lib/features/viewer/widgets/toc_sheet.dart
import 'package:flutter/material.dart';
import '../providers/viewer_provider.dart';
import 'reader_theme.dart';

class TocSheet extends StatefulWidget {
  final List<HeadingItem> headings;
  final int activeHeadingIndex;
  final ReaderColors chromeColors;
  final ValueChanged<int> onHeadingSelected;

  const TocSheet({
    super.key,
    required this.headings,
    required this.activeHeadingIndex,
    required this.chromeColors,
    required this.onHeadingSelected,
  });

  @override
  State<TocSheet> createState() => _TocSheetState();
}

class _TocSheetState extends State<TocSheet> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollToActiveHeading();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToActiveHeading() {
    final activeIndex = widget.activeHeadingIndex;
    final headings = widget.headings;

    if (activeIndex < 0 || activeIndex >= headings.length) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      const estimatedItemHeight = 52.0;
      final targetOffset = activeIndex * estimatedItemHeight;
      final maxScroll = _scrollController.position.maxScrollExtent;
      final clampedOffset = targetOffset.clamp(0.0, maxScroll);

      _scrollController.jumpTo(clampedOffset);
    });
  }

  String _currentHeadingText(String text) {
    if (text.length <= 18) return text;
    return text.substring(0, 18);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Table of Contents',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: widget.chromeColors.content,
                      ),
                    ),
                    Text(
                      '${widget.headings.length} heading${widget.headings.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.chromeColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close, color: widget.chromeColors.content),
                style: IconButton.styleFrom(
                  backgroundColor: widget.chromeColors.container,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        if (widget.headings.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No headings found.',
              style: TextStyle(color: widget.chromeColors.content),
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Chip(
                    backgroundColor: widget.chromeColors.container,
                    label: Text(
                      'Jump to section',
                      style: TextStyle(color: widget.chromeColors.content, fontSize: 12),
                    ),
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                  ),
                  if (widget.activeHeadingIndex >= 0 &&
                      widget.activeHeadingIndex < widget.headings.length) ...[
                    const SizedBox(width: 8),
                    Chip(
                      backgroundColor: widget.chromeColors.container,
                      label: Text(
                        'Current: ${_currentHeadingText(widget.headings[widget.activeHeadingIndex].text)}',
                        style: TextStyle(color: widget.chromeColors.content, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ],
              ),
            ),
          ),
          Flexible(
            child: ListView.builder(
              controller: _scrollController,
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              itemCount: widget.headings.length,
              itemBuilder: (context, index) {
                final heading = widget.headings[index];
                final isActive = index == widget.activeHeadingIndex;
                final indent = heading.level == 1
                    ? 0.0
                    : heading.level == 2
                        ? 12.0
                        : 24.0;

                return Padding(
                  padding: EdgeInsets.only(left: indent),
                  child: Material(
                    color: isActive
                        ? widget.chromeColors.container
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        widget.onHeadingSelected(heading.offset);
                        Navigator.of(context).pop();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: widget.chromeColors.container,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'H${heading.level}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: widget.chromeColors.content,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                heading.text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: widget.chromeColors.content,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

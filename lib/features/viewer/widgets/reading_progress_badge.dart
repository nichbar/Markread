// lib/features/viewer/widgets/reading_progress_badge.dart
import 'package:flutter/material.dart';
import 'reader_theme.dart';

/// Semi-transparent percentage pill shown while the reader is scrolling.
/// Mirrors the visual language of the zoom scale badge in [ZoomableArea].
class ReadingProgressBadge extends StatelessWidget {
  final int percent; // 0–100
  final bool visible;
  final ReaderColors colors;

  const ReadingProgressBadge({
    super.key,
    required this.percent,
    required this.visible,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colors.container.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$percent%',
            style: TextStyle(
              color: colors.content,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

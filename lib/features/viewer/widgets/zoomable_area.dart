// lib/features/viewer/widgets/zoomable_area.dart
import 'dart:async';
import 'package:flutter/material.dart';

/// Detects pinch-to-zoom gestures without competing with inner scroll views.
///
/// Uses [Listener] for raw multi-touch detection so single-finger scroll
/// events pass through to [SingleChildScrollView] uninterrupted.
///
/// Reports scale changes via [onScaleChanged]; the parent is responsible
/// for applying the scale (e.g. by adjusting font size).
///
/// Shows a percentage indicator overlay during pinch gestures that fades
/// out 1.5s after the last finger lifts.
class ZoomableArea extends StatefulWidget {
  final Widget child;
  final double scale;
  final ValueChanged<double>? onScaleChanged;
  final double maxScale;
  final double minScale;

  const ZoomableArea({
    super.key,
    required this.child,
    this.scale = 1.0,
    this.onScaleChanged,
    this.maxScale = 3.0,
    this.minScale = 0.5,
  });

  @override
  State<ZoomableArea> createState() => _ZoomableAreaState();
}

class _ZoomableAreaState extends State<ZoomableArea> {
  final Map<int, Offset> _pointers = {};
  double? _initialPinchDistance;
  double _pinchStartScale = 1.0;

  bool _showIndicator = false;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.position;
    if (_pointers.length == 2) {
      final positions = _pointers.values.toList();
      _initialPinchDistance = (positions[0] - positions[1]).distance;
      _pinchStartScale = widget.scale;
    }
    if (_pointers.length >= 2) {
      _hideTimer?.cancel();
      _showIndicator = true;
      if (mounted) setState(() {});
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.position;

    if (_pointers.length >= 2 && _initialPinchDistance != null) {
      final positions = _pointers.values.toList();
      final distance = (positions[0] - positions[1]).distance;
      if (_initialPinchDistance! > 0) {
        final newScale =
            (_pinchStartScale * distance / _initialPinchDistance!)
                .clamp(widget.minScale, widget.maxScale);
        if ((newScale - widget.scale).abs() > 0.001) {
          widget.onScaleChanged?.call(newScale);
        }
      }
    }
  }

  void _onPointerUp(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.length < 2) {
      _initialPinchDistance = null;
      _hideTimer?.cancel();
      _hideTimer = Timer(const Duration(milliseconds: 1500), () {
        _showIndicator = false;
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerUp,
          child: widget.child,
        ),
        Positioned(
          top: 16,
          right: 16,
          child: AnimatedOpacity(
            opacity: _showIndicator ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: GestureDetector(
              onTap: () => widget.onScaleChanged?.call(1.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(widget.scale * 100).round()}%',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

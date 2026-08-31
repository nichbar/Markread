import 'dart:async';
import 'package:flutter/material.dart';

/// Engine that coordinates progressive character/word reveal animations.
class RevealEngine extends ChangeNotifier {
  RevealEngine({
    this.interval = const Duration(milliseconds: 20),
    this.stepSize = 1,
    this.cursor = '▌',
    this.onComplete,
  });

  final Duration interval;
  final int stepSize;
  final String? cursor;
  final VoidCallback? onComplete;

  Timer? _timer;
  String _targetText = '';
  int _revealedLength = 0;
  bool _isStreaming = false;

  String get targetText => _targetText;
  int get revealedLength => _revealedLength;
  bool get isCompleted => _revealedLength >= _targetText.length && !_isStreaming;

  String get currentText {
    final sub = _targetText.substring(0, _revealedLength);
    if (!isCompleted && cursor != null && cursor!.isNotEmpty) {
      return '$sub$cursor';
    }
    return sub;
  }

  void appendText(String newChunk, {bool isFinished = false}) {
    _targetText += newChunk;
    _isStreaming = !isFinished;
    _startTimerIfNeeded();
    notifyListeners();
  }

  void setText(String fullText, {bool animate = true}) {
    _targetText = fullText;
    _isStreaming = false;
    if (!animate) {
      _revealedLength = _targetText.length;
      _stopTimer();
      notifyListeners();
      onComplete?.call();
    } else {
      _startTimerIfNeeded();
      notifyListeners();
    }
  }

  void fastForward() {
    _revealedLength = _targetText.length;
    _stopTimer();
    notifyListeners();
    onComplete?.call();
  }

  void _startTimerIfNeeded() {
    if (_timer != null && _timer!.isActive) return;
    _timer = Timer.periodic(interval, _onTick);
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _onTick(Timer timer) {
    if (_revealedLength < _targetText.length) {
      _revealedLength = (_revealedLength + stepSize).clamp(0, _targetText.length);
      notifyListeners();
      if (isCompleted) {
        _stopTimer();
        onComplete?.call();
      }
    } else if (!_isStreaming) {
      _stopTimer();
      onComplete?.call();
    }
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}

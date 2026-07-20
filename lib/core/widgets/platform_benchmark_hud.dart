// lib/core/widgets/platform_benchmark_hud.dart
// Temporary diagnostic HUD for cross-device scroll / display A/B tests.
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'process_memory_stub.dart'
    if (dart.library.io) 'process_memory_io.dart' as process_memory;

/// Live platform metrics overlay.
///
/// Updates via [ValueNotifier] only — never forces the host document tree to
/// rebuild. Uses [SchedulerBinding.addTimingsCallback] for UI/raster costs and
/// [FlutterView.display.refreshRate] for the reported display Hz.
///
/// Also samples process RSS (VM) and Flutter [ImageCache] usage so memory
/// pressure can be compared across devices.
///
/// Intended for temporary performance investigations.
class PlatformBenchmarkHud extends StatefulWidget {
  /// Optional label shown on the first line (e.g. "text-only" / "markdown").
  final String? label;

  /// When false, the HUD is hidden.
  final bool visible;

  /// Corner placement.
  final Alignment alignment;

  const PlatformBenchmarkHud({
    super.key,
    this.label,
    this.visible = true,
    this.alignment = Alignment.topRight,
  });

  @override
  State<PlatformBenchmarkHud> createState() => _PlatformBenchmarkHudState();
}

class _HudSnapshot {
  final int fps;
  final double uiMs;
  final double rasterMs;
  final double totalMs;
  final double displayHz;
  final double dpr;
  final Size physicalSize;
  final String platform;
  final bool janky;
  final int? rssBytes;
  final int imageCacheBytes;
  final int imageCacheCount;

  const _HudSnapshot({
    required this.fps,
    required this.uiMs,
    required this.rasterMs,
    required this.totalMs,
    required this.displayHz,
    required this.dpr,
    required this.physicalSize,
    required this.platform,
    required this.janky,
    required this.rssBytes,
    required this.imageCacheBytes,
    required this.imageCacheCount,
  });

  static const empty = _HudSnapshot(
    fps: 0,
    uiMs: 0,
    rasterMs: 0,
    totalMs: 0,
    displayHz: 0,
    dpr: 0,
    physicalSize: Size.zero,
    platform: '?',
    janky: false,
    rssBytes: null,
    imageCacheBytes: 0,
    imageCacheCount: 0,
  );
}

class _PlatformBenchmarkHudState extends State<PlatformBenchmarkHud> {
  final ValueNotifier<_HudSnapshot> _snap = ValueNotifier(_HudSnapshot.empty);

  final List<FrameTiming> _window = <FrameTiming>[];
  static const _windowMs = 500;

  // Session extremes for markdown deep-dive (reset when label changes).
  double _maxUiMs = 0;
  double _maxRasterMs = 0;
  double _maxTotalMs = 0;
  int _framesSeen = 0;
  int _jankyFrames = 0;
  String? _sessionLabel;
  Duration _lastDeepLog = Duration.zero;
  static const _deepLogInterval = Duration(milliseconds: 1000);

  TimingsCallback? _timingsCallback;
  bool _registered = false;

  // Memory is cheaper to poll on a timer-ish cadence inside timings, but
  // timings can be sparse when idle; also refresh on a light periodic tick.
  Duration _lastMemorySample = Duration.zero;
  static const _memorySampleInterval = Duration(milliseconds: 750);
  int? _rssBytes;
  int _imageCacheBytes = 0;
  int _imageCacheCount = 0;

  @override
  void initState() {
    super.initState();
    _sampleMemory(force: true);
    _register();
    // Keep memory numbers alive even when frames are rare (idle).
    WidgetsBinding.instance.addPostFrameCallback(_idleMemoryTick);
  }

  @override
  void didUpdateWidget(covariant PlatformBenchmarkHud oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !_registered) {
      _register();
    } else if (!widget.visible && _registered) {
      _unregister();
    }
  }

  @override
  void dispose() {
    _unregister();
    _snap.dispose();
    super.dispose();
  }

  void _register() {
    if (_registered) return;
    _registered = true;
    _timingsCallback = _onTimings;
    SchedulerBinding.instance.addTimingsCallback(_timingsCallback!);
  }

  void _unregister() {
    if (!_registered) return;
    _registered = false;
    if (_timingsCallback != null) {
      SchedulerBinding.instance.removeTimingsCallback(_timingsCallback!);
    }
    _timingsCallback = null;
  }

  void _idleMemoryTick(Duration timestamp) {
    if (!mounted || !widget.visible) return;
    _sampleMemory(now: timestamp);
    // Slow idle refresh so RSS doesn't freeze when not scrolling.
    Future<void>.delayed(const Duration(seconds: 1), () {
      if (!mounted || !widget.visible) return;
      WidgetsBinding.instance.addPostFrameCallback(_idleMemoryTick);
      // Nudge a frame so the callback runs.
      SchedulerBinding.instance.scheduleFrame();
    });
  }

  void _sampleMemory({Duration? now, bool force = false}) {
    final ts = now ?? Duration.zero;
    if (!force &&
        _lastMemorySample != Duration.zero &&
        ts - _lastMemorySample < _memorySampleInterval) {
      return;
    }
    if (ts != Duration.zero) {
      _lastMemorySample = ts;
    }

    _rssBytes = process_memory.sampleProcessRssBytes();
    final cache = PaintingBinding.instance.imageCache;
    _imageCacheBytes = cache.currentSizeBytes;
    _imageCacheCount = cache.currentSize;
  }

  void _onTimings(List<FrameTiming> timings) {
    if (!mounted || !widget.visible) return;
    if (timings.isEmpty) return;

    // Reset session extremes when HUD label changes (text-only vs markdown).
    final label = widget.label ?? '-';
    if (_sessionLabel != label) {
      _sessionLabel = label;
      _maxUiMs = 0;
      _maxRasterMs = 0;
      _maxTotalMs = 0;
      _framesSeen = 0;
      _jankyFrames = 0;
      _lastDeepLog = Duration.zero;
    }

    // Per-frame extremes (not window-averaged).
    for (final t in timings) {
      final ui = t.buildDuration.inMicroseconds / 1000.0;
      final raster = t.rasterDuration.inMicroseconds / 1000.0;
      final total = t.totalSpan.inMicroseconds / 1000.0;
      _framesSeen += 1;
      if (ui > _maxUiMs) _maxUiMs = ui;
      if (raster > _maxRasterMs) _maxRasterMs = raster;
      if (total > _maxTotalMs) _maxTotalMs = total;
      if (total > 12.0) _jankyFrames += 1;

      // Log individual catastrophic frames (>100ms) immediately.
      if (total >= 100.0) {
        debugPrint(
          '[bench-frame] $label '
          'ui=${ui.toStringAsFixed(1)} '
          'rast=${raster.toStringAsFixed(1)} '
          'tot=${total.toStringAsFixed(1)} '
          'vsyncOverhead=${(total - ui - raster).toStringAsFixed(1)}',
        );
      }
    }

    _window.addAll(timings);
    final newest =
        timings.last.timestampInMicroseconds(FramePhase.rasterFinish);
    final cutoff = newest - _windowMs * 1000;
    _window.removeWhere(
      (t) => t.timestampInMicroseconds(FramePhase.rasterFinish) < cutoff,
    );
    if (_window.isEmpty) return;

    var uiSum = 0.0;
    var rasterSum = 0.0;
    var totalSum = 0.0;
    var jank = 0;
    var winMaxUi = 0.0;
    var winMaxTot = 0.0;
    for (final t in _window) {
      final ui = t.buildDuration.inMicroseconds / 1000.0;
      final raster = t.rasterDuration.inMicroseconds / 1000.0;
      final total = t.totalSpan.inMicroseconds / 1000.0;
      uiSum += ui;
      rasterSum += raster;
      totalSum += total;
      if (ui > winMaxUi) winMaxUi = ui;
      if (total > winMaxTot) winMaxTot = total;
      // Miss a ~90Hz budget hard.
      if (total > 12.0) jank++;
    }
    final n = _window.length;
    final spanUs = newest -
        _window.first.timestampInMicroseconds(FramePhase.rasterFinish);
    final spanMs = spanUs <= 0 ? _windowMs.toDouble() : spanUs / 1000.0;
    final fps = spanMs > 0 ? (n * 1000 / spanMs).round() : 0;

    final views = WidgetsBinding.instance.platformDispatcher.views;
    final view = views.isNotEmpty ? views.first : null;
    final displayHz = view?.display.refreshRate ?? 0.0;
    final dpr = view?.devicePixelRatio ?? 0.0;
    final physical = view?.physicalSize ?? Size.zero;

    final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;

    _sampleMemory(
      now: Duration(microseconds: newest),
    );

    final next = _HudSnapshot(
      fps: fps,
      uiMs: uiSum / n,
      rasterMs: rasterSum / n,
      totalMs: totalSum / n,
      displayHz: displayHz,
      dpr: dpr,
      physicalSize: physical,
      platform: platform,
      janky: jank > n * 0.2,
      rssBytes: _rssBytes,
      imageCacheBytes: _imageCacheBytes,
      imageCacheCount: _imageCacheCount,
    );

    final prev = _snap.value;
    final shouldUpdateHud = !(prev.fps == next.fps &&
        (prev.uiMs - next.uiMs).abs() < 0.15 &&
        (prev.rasterMs - next.rasterMs).abs() < 0.15 &&
        (prev.displayHz - next.displayHz).abs() < 0.5 &&
        prev.janky == next.janky &&
        prev.rssBytes == next.rssBytes &&
        prev.imageCacheBytes == next.imageCacheBytes &&
        prev.imageCacheCount == next.imageCacheCount);
    if (shouldUpdateHud) {
      _snap.value = next;
    }

    // Temporary: emit metrics for adb logcat A/B while driving scrolls.
    final rssMb = next.rssBytes == null
        ? 'n/a'
        : (next.rssBytes! / (1024 * 1024)).toStringAsFixed(1);
    if (shouldUpdateHud) {
      debugPrint(
        '[bench] $label '
        'fps=${next.fps} hz=${next.displayHz.toStringAsFixed(0)} '
        'ui=${next.uiMs.toStringAsFixed(1)} '
        'rast=${next.rasterMs.toStringAsFixed(1)} '
        'tot=${next.totalMs.toStringAsFixed(1)} '
        'rss=${rssMb}MB '
        'janky=${next.janky}',
      );
    }

    // Periodic deep summary: window max + session max + jank rate.
    final now = Duration(microseconds: newest);
    if (_lastDeepLog == Duration.zero ||
        now - _lastDeepLog >= _deepLogInterval) {
      _lastDeepLog = now;
      final jankRate =
          _framesSeen == 0 ? 0.0 : (100.0 * _jankyFrames / _framesSeen);
      debugPrint(
        '[bench-deep] $label '
        'fps=${next.fps} hz=${next.displayHz.toStringAsFixed(0)} '
        'winMaxUi=${winMaxUi.toStringAsFixed(1)} '
        'winMaxTot=${winMaxTot.toStringAsFixed(1)} '
        'sessMaxUi=${_maxUiMs.toStringAsFixed(1)} '
        'sessMaxRast=${_maxRasterMs.toStringAsFixed(1)} '
        'sessMaxTot=${_maxTotalMs.toStringAsFixed(1)} '
        'frames=$_framesSeen janky=$_jankyFrames '
        'jankRate=${jankRate.toStringAsFixed(1)}% '
        'rss=${rssMb}MB',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();

    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: widget.alignment,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: ValueListenableBuilder<_HudSnapshot>(
              valueListenable: _snap,
              builder: (context, s, _) => _HudCard(
                label: widget.label,
                snap: s,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HudCard extends StatelessWidget {
  final String? label;
  final _HudSnapshot snap;

  const _HudCard({required this.label, required this.snap});

  Color _fpsColor(int fps, double displayHz) {
    final target = displayHz > 0 ? displayHz : 60;
    if (fps >= target * 0.9) return const Color(0xFF69F0AE);
    if (fps >= target * 0.6) return const Color(0xFFFFD740);
    return const Color(0xFFFF5252);
  }

  Color _msColor(double ms, double budgetMs) {
    if (ms <= budgetMs * 0.7) return const Color(0xFF69F0AE);
    if (ms <= budgetMs) return const Color(0xFFFFD740);
    return const Color(0xFFFF5252);
  }

  String _fmtBytes(int? bytes) {
    if (bytes == null) return 'n/a';
    if (bytes < 1024) return '${bytes}B';
    final kb = bytes / 1024.0;
    if (kb < 1024) return '${kb.toStringAsFixed(0)}KB';
    final mb = kb / 1024.0;
    if (mb < 1024) return '${mb.toStringAsFixed(1)}MB';
    final gb = mb / 1024.0;
    return '${gb.toStringAsFixed(2)}GB';
  }

  Color _rssColor(int? bytes) {
    if (bytes == null) return Colors.white54;
    final mb = bytes / (1024 * 1024);
    // Soft thresholds for a reader app; red means "look here", not OOM.
    if (mb < 250) return const Color(0xFF69F0AE);
    if (mb < 500) return const Color(0xFFFFD740);
    return const Color(0xFFFF5252);
  }

  @override
  Widget build(BuildContext context) {
    final hz = snap.displayHz;
    final budget = hz > 0 ? 1000.0 / hz : 16.67;
    final physW = snap.physicalSize.width.round();
    final physH = snap.physicalSize.height.round();
    final logicalW =
        snap.dpr > 0 ? (snap.physicalSize.width / snap.dpr).round() : 0;
    final logicalH =
        snap.dpr > 0 ? (snap.physicalSize.height / snap.dpr).round() : 0;

    const style = TextStyle(
      fontFamily: 'monospace',
      fontSize: 11,
      height: 1.25,
      color: Colors.white,
      fontFeatures: [FontFeature.tabularFigures()],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: snap.janky
              ? const Color(0xFFFF5252).withValues(alpha: 0.8)
              : Colors.white24,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: DefaultTextStyle(
          style: style,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (label != null)
                Text(
                  label!,
                  style: style.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                ),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'fps  '),
                    TextSpan(
                      text: '${snap.fps}'.padLeft(3),
                      style: TextStyle(color: _fpsColor(snap.fps, hz)),
                    ),
                    TextSpan(
                      text: ' / ${hz > 0 ? hz.toStringAsFixed(0) : '?'}Hz',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'ui   '),
                    TextSpan(
                      text: '${snap.uiMs.toStringAsFixed(1).padLeft(4)}ms',
                      style: TextStyle(color: _msColor(snap.uiMs, budget)),
                    ),
                  ],
                ),
              ),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'rast '),
                    TextSpan(
                      text:
                          '${snap.rasterMs.toStringAsFixed(1).padLeft(4)}ms',
                      style: TextStyle(color: _msColor(snap.rasterMs, budget)),
                    ),
                  ],
                ),
              ),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'tot  '),
                    TextSpan(
                      text: '${snap.totalMs.toStringAsFixed(1).padLeft(4)}ms',
                      style: TextStyle(color: _msColor(snap.totalMs, budget)),
                    ),
                    TextSpan(
                      text: '  bud ${budget.toStringAsFixed(1)}ms',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'rss  '),
                    TextSpan(
                      text: _fmtBytes(snap.rssBytes).padLeft(7),
                      style: TextStyle(color: _rssColor(snap.rssBytes)),
                    ),
                    TextSpan(
                      text:
                          '  img ${_fmtBytes(snap.imageCacheBytes)}/${snap.imageCacheCount}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Text(
                'px   ${physW}x$physH  dpr ${snap.dpr.toStringAsFixed(2)}',
                style: style.copyWith(color: Colors.white70),
              ),
              Text(
                'dp   ${logicalW}x$logicalH  ${snap.platform}',
                style: style.copyWith(color: Colors.white54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wraps [child] in a [Stack] and paints [PlatformBenchmarkHud] on top.
class BenchmarkHudHost extends StatelessWidget {
  final Widget child;
  final String? label;
  final bool visible;
  final Alignment alignment;

  const BenchmarkHudHost({
    super.key,
    required this.child,
    this.label,
    this.visible = true,
    this.alignment = Alignment.topRight,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return child;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        PlatformBenchmarkHud(
          label: label,
          visible: visible,
          alignment: alignment,
        ),
      ],
    );
  }
}

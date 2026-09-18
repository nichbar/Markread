// lib/core/services/dynamic_font_loader_io.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Mobile/Desktop IO implementation of [DynamicFontLoader] using [FontLoader].
class DynamicFontLoader {
  const DynamicFontLoader._();

  static const int _maxConcurrentLoads = 3;
  static int _activeLoads = 0;
  static final List<Future<void> Function()> _queue =
      <Future<void> Function()>[];

  static final Set<String> _loadedFamilies = <String>{};
  static final Map<String, Future<bool>> _loadingFutures =
      <String, Future<bool>>{};

  /// Built-in platform system fonts that must not be dynamically loaded via [FontLoader],
  /// as registering a single raw font file under these names would override the platform's
  /// multi-weight font family (regular, medium, bold, etc.) with a single regular weight.
  static bool isPlatformSystemFont(String familyName) {
    final lower = familyName.trim().toLowerCase();
    return lower == 'roboto' ||
        lower == 'sans-serif' ||
        lower == 'sans-serif-medium' ||
        lower == 'sans-serif-condensed' ||
        lower == 'sans-serif-light' ||
        lower == 'serif' ||
        lower == 'monospace' ||
        lower == 'casual' ||
        lower == 'cursive';
  }

  /// Asynchronously loads a font file into Flutter's FontLoader engine under [familyName].
  ///
  /// Returns `true` if the font is loaded successfully or was already loaded,
  /// or if [filePath] is null/empty (built-in platform alias), or if it is a built-in
  /// platform system font.
  static Future<bool> loadFont(String familyName, String? filePath) async {
    final trimmedName = familyName.trim();
    if (trimmedName.isEmpty) return false;

    if (filePath == null ||
        filePath.trim().isEmpty ||
        isPlatformSystemFont(trimmedName)) {
      return true;
    }

    if (_loadedFamilies.contains(trimmedName)) {
      return true;
    }

    if (_loadingFutures.containsKey(trimmedName)) {
      return await _loadingFutures[trimmedName]!;
    }

    final completer = Completer<bool>();
    _loadingFutures[trimmedName] = completer.future;

    _enqueue(() async {
      try {
        final result = await _loadFontInternal(trimmedName, filePath.trim());
        completer.complete(result);
      } catch (e, stack) {
        debugPrint(
            '[DynamicFontLoader] Error loading font "$trimmedName" from "$filePath": $e\n$stack');
        completer.complete(false);
      } finally {
        _loadingFutures.remove(trimmedName);
      }
    });

    return await completer.future;
  }

  static void _enqueue(Future<void> Function() task) {
    if (_activeLoads < _maxConcurrentLoads) {
      _runTask(task);
    } else {
      _queue.add(task);
    }
  }

  static void _runTask(Future<void> Function() task) async {
    _activeLoads++;
    try {
      await task();
    } finally {
      if (_activeLoads > 0) {
        _activeLoads--;
      }
      if (_queue.isNotEmpty) {
        final next = _queue.removeAt(0);
        _runTask(next);
      }
    }
  }

  static Future<bool> _loadFontInternal(String familyName, String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('[DynamicFontLoader] Font file does not exist: $filePath');
        return false;
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        debugPrint('[DynamicFontLoader] Font file is empty: $filePath');
        return false;
      }

      final byteData = ByteData.view(
        bytes.buffer,
        bytes.offsetInBytes,
        bytes.lengthInBytes,
      );

      final fontLoader = FontLoader(familyName);
      fontLoader.addFont(Future.value(byteData));
      await fontLoader.load();

      _loadedFamilies.add(familyName);
      return true;
    } catch (e, stack) {
      debugPrint('[DynamicFontLoader] Error loading font "$familyName" from "$filePath": $e\n$stack');
      return false;
    }
  }

  /// Checks whether [familyName] has already been loaded via [FontLoader].
  static bool isFontLoaded(String familyName) {
    return _loadedFamilies.contains(familyName.trim());
  }

  /// Returns an unmodifiable set of all loaded font families.
  static Set<String> get loadedFamilies => Set.unmodifiable(_loadedFamilies);

  @visibleForTesting
  static void resetForTesting() {
    _loadedFamilies.clear();
    _loadingFutures.clear();
    _queue.clear();
    _activeLoads = 0;
  }
}

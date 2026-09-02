// lib/core/services/dynamic_font_loader_io.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Mobile/Desktop IO implementation of [DynamicFontLoader] using [FontLoader].
class DynamicFontLoader {
  const DynamicFontLoader._();

  static final Set<String> _loadedFamilies = <String>{};
  static final Map<String, Future<bool>> _loadingFutures = <String, Future<bool>>{};

  /// Asynchronously loads a font file into Flutter's FontLoader engine under [familyName].
  ///
  /// Returns `true` if the font is loaded successfully or was already loaded,
  /// or if [filePath] is null/empty (built-in platform alias).
  static Future<bool> loadFont(String familyName, String? filePath) async {
    final trimmedName = familyName.trim();
    if (trimmedName.isEmpty) return false;

    if (filePath == null || filePath.trim().isEmpty) {
      return true;
    }

    if (_loadedFamilies.contains(trimmedName)) {
      return true;
    }

    if (_loadingFutures.containsKey(trimmedName)) {
      return await _loadingFutures[trimmedName]!;
    }

    final future = _loadFontInternal(trimmedName, filePath.trim());
    _loadingFutures[trimmedName] = future;

    try {
      return await future;
    } finally {
      _loadingFutures.remove(trimmedName);
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
  }
}

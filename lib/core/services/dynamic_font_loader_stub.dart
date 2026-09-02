// lib/core/services/dynamic_font_loader_stub.dart
import 'package:flutter/foundation.dart';

/// Web & non-IO stub implementation of [DynamicFontLoader].
class DynamicFontLoader {
  const DynamicFontLoader._();

  /// No-op on Web / platforms without direct file system font access.
  static Future<bool> loadFont(String familyName, String? filePath) async {
    return true;
  }

  /// Always returns false on Web / stub platform.
  static bool isFontLoaded(String familyName) {
    return false;
  }

  /// Returns an empty set on Web / stub platform.
  static Set<String> get loadedFamilies => const <String>{};

  @visibleForTesting
  static void resetForTesting() {}
}

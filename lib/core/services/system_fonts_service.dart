// lib/core/services/system_fonts_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/system_font.dart';

class SystemFontsService {
  static const MethodChannel _channel =
      MethodChannel('now.link.markread/system_fonts');

  @visibleForTesting
  static MethodChannel get channel => _channel;

  const SystemFontsService();

  /// Fetches the list of available system fonts on the device with structured metadata.
  ///
  /// Returns an empty list on non-Android platforms (e.g. Web) or if fetching fails.
  Future<List<SystemFont>> getSystemFonts() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const <SystemFont>[];
    }

    try {
      final result = await _channel.invokeListMethod<dynamic>('getSystemFonts');
      if (result == null) return const <SystemFont>[];

      final fonts = <SystemFont>[];
      for (final item in result) {
        if (item is Map) {
          final font = SystemFont.fromMap(item);
          if (font.name.isNotEmpty) {
            fonts.add(font);
          }
        } else if (item is String) {
          final trimmed = item.trim();
          if (trimmed.isNotEmpty) {
            fonts.add(SystemFont(name: trimmed));
          }
        }
      }

      return List.unmodifiable(fonts);
    } on MissingPluginException {
      return const <SystemFont>[];
    } on PlatformException catch (e) {
      debugPrint('[SystemFontsService] Failed to load system fonts: $e');
      return const <SystemFont>[];
    } catch (e) {
      debugPrint('[SystemFontsService] Unexpected error loading system fonts: $e');
      return const <SystemFont>[];
    }
  }
}

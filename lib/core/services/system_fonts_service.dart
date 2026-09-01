// lib/core/services/system_fonts_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SystemFontsService {
  static const MethodChannel _channel =
      MethodChannel('now.link.markread/system_fonts');

  @visibleForTesting
  static MethodChannel get channel => _channel;

  const SystemFontsService();

  /// Fetches the list of available system fonts on the device.
  ///
  /// Returns an empty list on non-Android platforms (e.g. Web) or if fetching fails.
  Future<List<String>> getSystemFonts() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const <String>[];
    }

    try {
      final result = await _channel.invokeListMethod<String>('getSystemFonts');
      if (result == null) return const <String>[];
      return result.where((font) => font.trim().isNotEmpty).toList(growable: false);
    } on MissingPluginException {
      return const <String>[];
    } on PlatformException catch (e) {
      debugPrint('[SystemFontsService] Failed to load system fonts: $e');
      return const <String>[];
    } catch (e) {
      debugPrint('[SystemFontsService] Unexpected error loading system fonts: $e');
      return const <String>[];
    }
  }
}

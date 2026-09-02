// lib/core/providers/system_fonts_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/system_font.dart';
import '../services/dynamic_font_loader.dart';
import '../services/system_fonts_service.dart';
import 'preferences_provider.dart';

final systemFontsServiceProvider = Provider<SystemFontsService>((ref) {
  return const SystemFontsService();
});

final systemFontsProvider = FutureProvider<List<SystemFont>>((ref) async {
  final service = ref.watch(systemFontsServiceProvider);
  return service.getSystemFonts();
});

/// Automatically loads active content and code fonts into Flutter's FontLoader
/// when system fonts and user preferences are loaded or updated.
final activeFontLoaderProvider = FutureProvider<void>((ref) async {
  final fontsAsync = ref.watch(systemFontsProvider);
  final prefs = ref.watch(preferencesProvider);

  final fonts = fontsAsync.value;
  if (fonts == null || fonts.isEmpty) return;

  final targetFamilies = <String>{
    if (prefs.fontFamily != null && prefs.fontFamily!.isNotEmpty)
      prefs.fontFamily!,
    if (prefs.codeFontFamily != null && prefs.codeFontFamily!.isNotEmpty)
      prefs.codeFontFamily!,
  };

  for (final target in targetFamilies) {
    final matched = fonts.cast<SystemFont?>().firstWhere(
          (f) => f?.name.toLowerCase() == target.toLowerCase(),
          orElse: () => null,
        );
    if (matched != null && matched.path != null) {
      await DynamicFontLoader.loadFont(matched.name, matched.path);
    }
  }
});

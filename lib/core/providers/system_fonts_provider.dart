// lib/core/providers/system_fonts_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/system_fonts_service.dart';

final systemFontsServiceProvider = Provider<SystemFontsService>((ref) {
  return const SystemFontsService();
});

final systemFontsProvider = FutureProvider<List<String>>((ref) async {
  final service = ref.watch(systemFontsServiceProvider);
  return service.getSystemFonts();
});

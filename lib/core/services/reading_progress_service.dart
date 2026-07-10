// lib/core/services/reading_progress_service.dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/reading_progress.dart';

class ReadingProgressService {
  static const prefsKey = 'reading_progress_v1';
  static const maxEntries = 50;

  /// Optional injection for tests; defaults to SharedPreferences.getInstance().
  final Future<SharedPreferences> Function()? prefsFactory;

  ReadingProgressService({this.prefsFactory});

  Future<SharedPreferences> _prefs() async {
    if (prefsFactory != null) return prefsFactory!();
    return SharedPreferences.getInstance();
  }

  static String entryKey(String fileName, int byteLength) =>
      '$fileName::$byteLength';

  Future<void> save({
    required String fileName,
    required int byteLength,
    required int charOffset,
  }) async {
    final prefs = await _prefs();
    final map = await _loadMap(prefs);
    final key = entryKey(fileName, byteLength);
    final now = DateTime.now().millisecondsSinceEpoch;

    map[key] = ReadingProgress(
      fileName: fileName,
      byteLength: byteLength,
      charOffset: charOffset,
      updatedAtMs: now,
    );

    if (map.length > maxEntries) {
      final sorted = map.entries.toList()
        ..sort((a, b) => a.value.updatedAtMs.compareTo(b.value.updatedAtMs));
      final toRemove = sorted.length - maxEntries;
      for (var i = 0; i < toRemove; i++) {
        map.remove(sorted[i].key);
      }
    }

    await _writeMap(prefs, map);
  }

  Future<ReadingProgress?> get(String fileName, int byteLength) async {
    final prefs = await _prefs();
    final map = await _loadMap(prefs);
    return map[entryKey(fileName, byteLength)];
  }

  Future<Map<String, ReadingProgress>> _loadMap(SharedPreferences prefs) async {
    final raw = prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) return {};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};

      final result = <String, ReadingProgress>{};
      for (final entry in decoded.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (value is Map) {
          result[key] = ReadingProgress.fromJson(
            Map<String, dynamic>.from(value),
          );
        }
      }
      return result;
    } catch (_) {
      // Corrupt JSON → treat as empty; next save rewrites.
      return {};
    }
  }

  Future<void> _writeMap(
    SharedPreferences prefs,
    Map<String, ReadingProgress> map,
  ) async {
    final encoded = <String, dynamic>{
      for (final e in map.entries) e.key: e.value.toJson(),
    };
    await prefs.setString(prefsKey, jsonEncode(encoded));
  }
}

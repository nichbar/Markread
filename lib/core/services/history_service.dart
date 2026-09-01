// lib/core/services/history_service.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/history_item.dart';

class HistoryService {
  static const prefsKey = 'history_items_v1';
  static const maxEntries = 50;

  /// Optional injection for tests; defaults to SharedPreferences.getInstance().
  final Future<SharedPreferences> Function()? prefsFactory;

  HistoryService({this.prefsFactory});

  bool get isAndroidSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<SharedPreferences> _prefs() async {
    if (prefsFactory != null) return prefsFactory!();
    return SharedPreferences.getInstance();
  }

  Future<List<HistoryItem>> loadHistory() async {
    if (!isAndroidSupported) return const [];
    final prefs = await _prefs();
    final raw = prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final items = <HistoryItem>[];
      for (final element in decoded) {
        if (element is Map) {
          items.add(HistoryItem.fromJson(Map<String, dynamic>.from(element)));
        }
      }
      items.sort((a, b) => b.lastOpenedMs.compareTo(a.lastOpenedMs));
      return items;
    } catch (_) {
      // Corrupt JSON → treat as empty.
      return const [];
    }
  }

  Future<List<HistoryItem>> addOrUpdate(HistoryItem item) async {
    if (!isAndroidSupported) return const [];
    final prefs = await _prefs();
    final items = (await loadHistory()).toList();

    final existingIndex = items.indexWhere((existing) {
      if (item.filePath != null &&
          item.filePath!.isNotEmpty &&
          existing.filePath != null &&
          existing.filePath!.isNotEmpty) {
        return existing.filePath == item.filePath;
      }
      return existing.fileName == item.fileName;
    });

    if (existingIndex != -1) {
      final existing = items.removeAt(existingIndex);
      final updated = existing.copyWith(
        fileName: item.fileName,
        filePath: item.filePath ?? existing.filePath,
        byteLength: item.byteLength > 0 ? item.byteLength : existing.byteLength,
        lastOpenedMs: item.lastOpenedMs,
        charOffset: item.charOffset > 0 ? item.charOffset : existing.charOffset,
      );
      items.insert(0, updated);
    } else {
      items.insert(0, item);
    }

    if (items.length > maxEntries) {
      items.removeRange(maxEntries, items.length);
    }

    await _saveList(prefs, items);
    return items;
  }

  Future<List<HistoryItem>> updateProgress({
    required String fileName,
    required int byteLength,
    required int charOffset,
  }) async {
    if (!isAndroidSupported) return const [];
    final prefs = await _prefs();
    final items = (await loadHistory()).toList();

    final index = items.indexWhere((item) =>
        item.fileName == fileName &&
        (byteLength <= 0 ||
            item.byteLength == 0 ||
            item.byteLength == byteLength));

    if (index != -1) {
      final existing = items[index];
      items[index] = existing.copyWith(
        byteLength: byteLength > 0 ? byteLength : existing.byteLength,
        charOffset: charOffset,
      );
      await _saveList(prefs, items);
    }

    return items;
  }

  Future<List<HistoryItem>> remove(HistoryItem item) async {
    if (!isAndroidSupported) return const [];
    final prefs = await _prefs();
    final items = (await loadHistory()).toList();

    items.removeWhere((existing) {
      if (item.filePath != null &&
          item.filePath!.isNotEmpty &&
          existing.filePath != null &&
          existing.filePath!.isNotEmpty) {
        return existing.filePath == item.filePath;
      }
      return existing.fileName == item.fileName &&
          existing.lastOpenedMs == item.lastOpenedMs;
    });

    await _saveList(prefs, items);
    return items;
  }

  Future<void> clearAll() async {
    if (!isAndroidSupported) return;
    final prefs = await _prefs();
    await prefs.remove(prefsKey);
  }

  Future<void> _saveList(
    SharedPreferences prefs,
    List<HistoryItem> items,
  ) async {
    final jsonList = items.map((item) => item.toJson()).toList();
    await prefs.setString(prefsKey, jsonEncode(jsonList));
  }
}

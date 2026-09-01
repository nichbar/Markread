// test/core/services/history_service_test.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markread/core/models/history_item.dart';
import 'package:markread/core/services/history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = null;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('HistoryService Platform Gating', () {
    test('returns empty list and does nothing on non-Android platform (e.g. iOS / macOS / Linux)', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final service = HistoryService();

      expect(service.isAndroidSupported, isFalse);

      final initial = await service.loadHistory();
      expect(initial, isEmpty);

      final added = await service.addOrUpdate(
        const HistoryItem(fileName: 'test.md', lastOpenedMs: 1000),
      );
      expect(added, isEmpty);

      final progress = await service.updateProgress(
        fileName: 'test.md',
        byteLength: 100,
        charOffset: 50,
      );
      expect(progress, isEmpty);

      final removed = await service.remove(
        const HistoryItem(fileName: 'test.md', lastOpenedMs: 1000),
      );
      expect(removed, isEmpty);

      await service.clearAll();
    });
  });

  group('HistoryService on Android', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
    });

    test('loadHistory returns empty list when no data is saved', () async {
      final service = HistoryService();
      final items = await service.loadHistory();
      expect(items, isEmpty);
    });

    test('loadHistory sorts items by lastOpenedMs descending', () async {
      final item1 = const HistoryItem(fileName: 'first.md', lastOpenedMs: 1000);
      final item2 = const HistoryItem(fileName: 'second.md', lastOpenedMs: 2000);
      final item3 = const HistoryItem(fileName: 'third.md', lastOpenedMs: 1500);

      SharedPreferences.setMockInitialValues({
        HistoryService.prefsKey: jsonEncode([item1.toJson(), item2.toJson(), item3.toJson()]),
      });

      final service = HistoryService();
      final items = await service.loadHistory();

      expect(items.length, 3);
      expect(items[0].fileName, 'second.md');
      expect(items[1].fileName, 'third.md');
      expect(items[2].fileName, 'first.md');
    });

    test('corrupt JSON is treated as empty list', () async {
      SharedPreferences.setMockInitialValues({
        HistoryService.prefsKey: 'invalid-json-{[]',
      });

      final service = HistoryService();
      final items = await service.loadHistory();
      expect(items, isEmpty);
    });

    test('addOrUpdate inserts new items at index 0', () async {
      final service = HistoryService();

      final list1 = await service.addOrUpdate(
        const HistoryItem(fileName: 'first.md', lastOpenedMs: 1000),
      );
      expect(list1.length, 1);
      expect(list1[0].fileName, 'first.md');

      final list2 = await service.addOrUpdate(
        const HistoryItem(fileName: 'second.md', lastOpenedMs: 2000),
      );
      expect(list2.length, 2);
      expect(list2[0].fileName, 'second.md');
      expect(list2[1].fileName, 'first.md');
    });

    test('addOrUpdate moves existing file to top and updates metadata', () async {
      final service = HistoryService();

      await service.addOrUpdate(
        const HistoryItem(
          fileName: 'a.md',
          filePath: '/path/a.md',
          byteLength: 100,
          lastOpenedMs: 1000,
          charOffset: 25,
        ),
      );
      await service.addOrUpdate(
        const HistoryItem(
          fileName: 'b.md',
          filePath: '/path/b.md',
          byteLength: 200,
          lastOpenedMs: 2000,
        ),
      );

      final updated = await service.addOrUpdate(
        const HistoryItem(
          fileName: 'a.md',
          filePath: '/path/a.md',
          byteLength: 120,
          lastOpenedMs: 3000,
        ),
      );

      expect(updated.length, 2);
      expect(updated[0].fileName, 'a.md');
      expect(updated[0].lastOpenedMs, 3000);
      expect(updated[0].byteLength, 120);
      expect(updated[0].charOffset, 25); // preserved charOffset
      expect(updated[1].fileName, 'b.md');
    });

    test('LRU eviction trims oldest items beyond maxEntries (50)', () async {
      final service = HistoryService();

      for (var i = 0; i < HistoryService.maxEntries; i++) {
        await service.addOrUpdate(
          HistoryItem(
            fileName: 'file_$i.md',
            filePath: '/path/file_$i.md',
            lastOpenedMs: 1000 + i,
          ),
        );
      }

      final fullList = await service.loadHistory();
      expect(fullList.length, 50);
      expect(fullList.first.fileName, 'file_49.md');
      expect(fullList.last.fileName, 'file_0.md');

      // Adding the 51st item drops the oldest (file_0.md)
      final overflowList = await service.addOrUpdate(
        const HistoryItem(
          fileName: 'file_new.md',
          filePath: '/path/file_new.md',
          lastOpenedMs: 9999,
        ),
      );

      expect(overflowList.length, 50);
      expect(overflowList.first.fileName, 'file_new.md');
      expect(overflowList.any((item) => item.fileName == 'file_0.md'), isFalse);
      expect(overflowList.any((item) => item.fileName == 'file_1.md'), isTrue);
    });

    test('updateProgress updates charOffset for matching item', () async {
      final service = HistoryService();

      await service.addOrUpdate(
        const HistoryItem(
          fileName: 'doc.md',
          filePath: '/path/doc.md',
          byteLength: 1000,
          lastOpenedMs: 1000,
          charOffset: 0,
        ),
      );

      final updated = await service.updateProgress(
        fileName: 'doc.md',
        byteLength: 1000,
        charOffset: 450,
      );

      expect(updated.length, 1);
      expect(updated[0].charOffset, 450);
      expect(updated[0].progressPercent, 45);
    });

    test('remove removes matching item', () async {
      final service = HistoryService();

      final item1 = const HistoryItem(fileName: 'a.md', filePath: '/path/a.md', lastOpenedMs: 1000);
      final item2 = const HistoryItem(fileName: 'b.md', filePath: '/path/b.md', lastOpenedMs: 2000);

      await service.addOrUpdate(item1);
      await service.addOrUpdate(item2);

      final afterRemove = await service.remove(item1);
      expect(afterRemove.length, 1);
      expect(afterRemove[0].fileName, 'b.md');
    });

    test('clearAll clears all history entries from SharedPreferences', () async {
      final service = HistoryService();

      await service.addOrUpdate(
        const HistoryItem(fileName: 'a.md', lastOpenedMs: 1000),
      );
      await service.addOrUpdate(
        const HistoryItem(fileName: 'b.md', lastOpenedMs: 2000),
      );

      expect((await service.loadHistory()).length, 2);

      await service.clearAll();

      expect((await service.loadHistory()), isEmpty);
    });
  });
}

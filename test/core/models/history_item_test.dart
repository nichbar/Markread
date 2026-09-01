// test/core/models/history_item_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:markread/core/models/history_item.dart';

void main() {
  group('HistoryItem', () {
    test('default values and constructor', () {
      const item = HistoryItem(
        fileName: 'README.md',
        lastOpenedMs: 1700000000000,
      );

      expect(item.fileName, 'README.md');
      expect(item.filePath, isNull);
      expect(item.byteLength, 0);
      expect(item.lastOpenedMs, 1700000000000);
      expect(item.charOffset, 0);
    });

    test('toJson and fromJson round-trip', () {
      const item = HistoryItem(
        fileName: 'notes.md',
        filePath: '/storage/emulated/0/Documents/notes.md',
        byteLength: 2048,
        lastOpenedMs: 1710000000000,
        charOffset: 512,
      );

      final json = item.toJson();
      final restored = HistoryItem.fromJson(json);

      expect(restored.fileName, item.fileName);
      expect(restored.filePath, item.filePath);
      expect(restored.byteLength, item.byteLength);
      expect(restored.lastOpenedMs, item.lastOpenedMs);
      expect(restored.charOffset, item.charOffset);
      expect(restored, equals(item));
    });

    test('fromJson handles null / missing values gracefully', () {
      final item = HistoryItem.fromJson(const {});
      expect(item.fileName, '');
      expect(item.filePath, isNull);
      expect(item.byteLength, 0);
      expect(item.lastOpenedMs, 0);
      expect(item.charOffset, 0);
    });

    group('formattedSize', () {
      test('formats 0 or negative bytes', () {
        expect(const HistoryItem(fileName: 'a', lastOpenedMs: 0, byteLength: 0).formattedSize, '0 B');
        expect(const HistoryItem(fileName: 'a', lastOpenedMs: 0, byteLength: -5).formattedSize, '0 B');
      });

      test('formats bytes', () {
        expect(const HistoryItem(fileName: 'a', lastOpenedMs: 0, byteLength: 512).formattedSize, '512 B');
        expect(const HistoryItem(fileName: 'a', lastOpenedMs: 0, byteLength: 1023).formattedSize, '1023 B');
      });

      test('formats kilobytes', () {
        expect(const HistoryItem(fileName: 'a', lastOpenedMs: 0, byteLength: 1024).formattedSize, '1.0 KB');
        expect(const HistoryItem(fileName: 'a', lastOpenedMs: 0, byteLength: 46284).formattedSize, '45.2 KB');
      });

      test('formats megabytes', () {
        expect(const HistoryItem(fileName: 'a', lastOpenedMs: 0, byteLength: 1024 * 1024).formattedSize, '1.0 MB');
        expect(HistoryItem(fileName: 'a', lastOpenedMs: 0, byteLength: (1.4 * 1024 * 1024).round()).formattedSize, '1.4 MB');
      });

      test('formats gigabytes', () {
        expect(const HistoryItem(fileName: 'a', lastOpenedMs: 0, byteLength: 1024 * 1024 * 1024).formattedSize, '1.0 GB');
      });
    });

    group('formattedLastOpened', () {
      final baseNow = DateTime(2026, 9, 1, 12, 0, 0);

      test('returns "Just now" for times within the last minute or negative diff', () {
        final item = HistoryItem(
          fileName: 'a',
          lastOpenedMs: baseNow.subtract(const Duration(seconds: 30)).millisecondsSinceEpoch,
        );
        expect(item.formattedLastOpened(baseNow), 'Just now');

        final futureItem = HistoryItem(
          fileName: 'a',
          lastOpenedMs: baseNow.add(const Duration(minutes: 5)).millisecondsSinceEpoch,
        );
        expect(futureItem.formattedLastOpened(baseNow), 'Just now');
      });

      test('returns minutes ago', () {
        final item = HistoryItem(
          fileName: 'a',
          lastOpenedMs: baseNow.subtract(const Duration(minutes: 5)).millisecondsSinceEpoch,
        );
        expect(item.formattedLastOpened(baseNow), '5m ago');
      });

      test('returns hours ago', () {
        final item = HistoryItem(
          fileName: 'a',
          lastOpenedMs: baseNow.subtract(const Duration(hours: 3)).millisecondsSinceEpoch,
        );
        expect(item.formattedLastOpened(baseNow), '3h ago');
      });

      test('returns Yesterday', () {
        final item = HistoryItem(
          fileName: 'a',
          lastOpenedMs: baseNow.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
        );
        expect(item.formattedLastOpened(baseNow), 'Yesterday');
      });

      test('returns days ago within 7 days', () {
        final item = HistoryItem(
          fileName: 'a',
          lastOpenedMs: baseNow.subtract(const Duration(days: 4)).millisecondsSinceEpoch,
        );
        expect(item.formattedLastOpened(baseNow), '4d ago');
      });

      test('returns formatted date for older dates', () {
        final item = HistoryItem(
          fileName: 'a',
          lastOpenedMs: DateTime(2026, 8, 15, 10, 0, 0).millisecondsSinceEpoch,
        );
        expect(item.formattedLastOpened(baseNow), '2026-08-15');
      });
    });

    group('progressPercent', () {
      test('returns 0 when byteLength is 0 or charOffset is 0', () {
        expect(const HistoryItem(fileName: 'a', lastOpenedMs: 0, byteLength: 0, charOffset: 100).progressPercent, 0);
        expect(const HistoryItem(fileName: 'a', lastOpenedMs: 0, byteLength: 100, charOffset: 0).progressPercent, 0);
      });

      test('calculates correct percentage and clamps', () {
        expect(const HistoryItem(fileName: 'a', lastOpenedMs: 0, byteLength: 1000, charOffset: 450).progressPercent, 45);
        expect(const HistoryItem(fileName: 'a', lastOpenedMs: 0, byteLength: 1000, charOffset: 1500).progressPercent, 100);
      });
    });

    test('copyWith updates fields', () {
      const item = HistoryItem(
        fileName: 'a.md',
        filePath: '/path/a.md',
        byteLength: 100,
        lastOpenedMs: 1000,
        charOffset: 10,
      );

      final updated = item.copyWith(
        fileName: 'b.md',
        byteLength: 200,
        charOffset: 20,
      );
      expect(updated.fileName, 'b.md');
      expect(updated.filePath, '/path/a.md');
      expect(updated.byteLength, 200);
      expect(updated.charOffset, 20);

      final clearedPath = updated.copyWith(clearFilePath: true);
      expect(clearedPath.filePath, isNull);
    });

    test('equality and hashCode', () {
      const item1 = HistoryItem(fileName: 'a.md', filePath: '/p', byteLength: 10, lastOpenedMs: 10, charOffset: 1);
      const item2 = HistoryItem(fileName: 'a.md', filePath: '/p', byteLength: 10, lastOpenedMs: 10, charOffset: 1);
      const item3 = HistoryItem(fileName: 'b.md', filePath: '/p', byteLength: 10, lastOpenedMs: 10, charOffset: 1);

      expect(item1, equals(item2));
      expect(item1.hashCode, equals(item2.hashCode));
      expect(item1, isNot(equals(item3)));
    });
  });
}

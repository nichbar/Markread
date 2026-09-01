// test/core/providers/history_provider_test.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markread/core/providers/history_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = null;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('HistoryNotifier on Android', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
    });

    test('initial state loads empty history', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initial = await container.read(historyProvider.future);
      expect(initial, isEmpty);
    });

    test('recordFileOpen records file and updates state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(historyProvider.notifier);

      await notifier.recordFileOpen(
        fileName: 'readme.md',
        filePath: '/storage/readme.md',
        byteLength: 1024,
      );

      final items = container.read(historyProvider).value;
      expect(items, isNotNull);
      expect(items!.length, 1);
      expect(items.first.fileName, 'readme.md');
      expect(items.first.filePath, '/storage/readme.md');
      expect(items.first.byteLength, 1024);
    });

    test('updateProgress updates progress in state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(historyProvider.notifier);

      await notifier.recordFileOpen(
        fileName: 'readme.md',
        filePath: '/storage/readme.md',
        byteLength: 1000,
      );

      await notifier.updateProgress(
        fileName: 'readme.md',
        byteLength: 1000,
        charOffset: 500,
      );

      final items = container.read(historyProvider).value;
      expect(items, isNotNull);
      expect(items!.first.charOffset, 500);
      expect(items.first.progressPercent, 50);
    });

    test('removeItem removes item from state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(historyProvider.notifier);

      await notifier.recordFileOpen(
        fileName: 'first.md',
        filePath: '/storage/first.md',
        byteLength: 100,
      );
      await notifier.recordFileOpen(
        fileName: 'second.md',
        filePath: '/storage/second.md',
        byteLength: 200,
      );

      var items = container.read(historyProvider).value!;
      expect(items.length, 2);

      final itemToRemove = items.firstWhere((i) => i.fileName == 'first.md');
      await notifier.removeItem(itemToRemove);

      items = container.read(historyProvider).value!;
      expect(items.length, 1);
      expect(items.first.fileName, 'second.md');
    });

    test('clearAll removes all items', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(historyProvider.notifier);

      await notifier.recordFileOpen(
        fileName: 'first.md',
        filePath: '/storage/first.md',
      );
      await notifier.recordFileOpen(
        fileName: 'second.md',
        filePath: '/storage/second.md',
      );

      expect(container.read(historyProvider).value?.length, 2);

      await notifier.clearAll();

      expect(container.read(historyProvider).value, isEmpty);
    });
  });

  group('HistoryNotifier on non-Android', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    });

    test('recordFileOpen does not record anything', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(historyProvider.notifier);

      await notifier.recordFileOpen(
        fileName: 'readme.md',
        filePath: '/storage/readme.md',
        byteLength: 1024,
      );

      final items = await container.read(historyProvider.future);
      expect(items, isEmpty);
    });
  });
}

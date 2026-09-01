// lib/core/providers/history_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/history_item.dart';
import '../services/history_service.dart';

final historyServiceProvider = Provider<HistoryService>(
  (ref) => HistoryService(),
);

class HistoryNotifier extends AsyncNotifier<List<HistoryItem>> {
  @override
  Future<List<HistoryItem>> build() async {
    final service = ref.watch(historyServiceProvider);
    return service.loadHistory();
  }

  Future<void> recordFileOpen({
    required String fileName,
    String? filePath,
    int byteLength = 0,
    int charOffset = 0,
  }) async {
    final service = ref.read(historyServiceProvider);
    if (!service.isAndroidSupported) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final item = HistoryItem(
      fileName: fileName,
      filePath: filePath,
      byteLength: byteLength,
      lastOpenedMs: now,
      charOffset: charOffset,
    );
    final updated = await service.addOrUpdate(item);
    state = AsyncData(updated);
  }

  Future<void> updateProgress({
    required String fileName,
    required int byteLength,
    required int charOffset,
  }) async {
    final service = ref.read(historyServiceProvider);
    if (!service.isAndroidSupported) return;

    final updated = await service.updateProgress(
      fileName: fileName,
      byteLength: byteLength,
      charOffset: charOffset,
    );
    state = AsyncData(updated);
  }

  Future<void> removeItem(HistoryItem item) async {
    final service = ref.read(historyServiceProvider);
    if (!service.isAndroidSupported) return;

    final updated = await service.remove(item);
    state = AsyncData(updated);
  }

  Future<void> clearAll() async {
    final service = ref.read(historyServiceProvider);
    if (!service.isAndroidSupported) return;

    await service.clearAll();
    state = const AsyncData([]);
  }
}

final historyProvider =
    AsyncNotifierProvider<HistoryNotifier, List<HistoryItem>>(
  HistoryNotifier.new,
);

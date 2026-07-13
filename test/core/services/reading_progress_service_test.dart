import 'package:flutter_test/flutter_test.dart';
import 'package:markread/core/services/reading_progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('save and get round-trip', () async {
    final service = ReadingProgressService();

    await service.save(
      fileName: 'notes.md',
      byteLength: 4096,
      charOffset: 1200,
    );

    final progress = await service.get('notes.md', 4096);
    expect(progress, isNotNull);
    expect(progress!.fileName, 'notes.md');
    expect(progress.byteLength, 4096);
    expect(progress.charOffset, 1200);
    expect(progress.updatedAtMs, greaterThan(0));
  });

  test('different byteLength is a miss', () async {
    final service = ReadingProgressService();

    await service.save(
      fileName: 'notes.md',
      byteLength: 4096,
      charOffset: 100,
    );

    final miss = await service.get('notes.md', 100);
    expect(miss, isNull);

    final hit = await service.get('notes.md', 4096);
    expect(hit, isNotNull);
    expect(hit!.charOffset, 100);
  });

  test('LRU eviction drops oldest when over maxEntries', () async {
    final service = ReadingProgressService();

    // Sequential saves: equal timestamps still drop oldest by stable
    // insertion order under LRU sort.
    for (var i = 0; i < ReadingProgressService.maxEntries; i++) {
      await service.save(
        fileName: 'file_$i.md',
        byteLength: i + 1,
        charOffset: i,
      );
    }

    // All should be present
    final first = await service.get('file_0.md', 1);
    expect(first, isNotNull);

    // One more save should drop the oldest
    await service.save(
      fileName: 'new.md',
      byteLength: 999,
      charOffset: 50,
    );

    final evicted = await service.get('file_0.md', 1);
    expect(evicted, isNull);

    final kept = await service.get('file_1.md', 2);
    expect(kept, isNotNull);

    final newest = await service.get('new.md', 999);
    expect(newest, isNotNull);
    expect(newest!.charOffset, 50);
  });

  test('corrupt JSON is treated as empty map', () async {
    SharedPreferences.setMockInitialValues({
      ReadingProgressService.prefsKey: '{not-valid-json',
    });

    final service = ReadingProgressService();
    final miss = await service.get('a.md', 1);
    expect(miss, isNull);

    await service.save(
      fileName: 'a.md',
      byteLength: 10,
      charOffset: 3,
    );

    final hit = await service.get('a.md', 10);
    expect(hit, isNotNull);
    expect(hit!.charOffset, 3);

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(ReadingProgressService.prefsKey);
    expect(raw, isNotNull);
    expect(raw!.startsWith('{'), isTrue);
  });

  test('upsert updates existing entry', () async {
    final service = ReadingProgressService();

    await service.save(
      fileName: 'a.md',
      byteLength: 100,
      charOffset: 10,
    );
    await service.save(
      fileName: 'a.md',
      byteLength: 100,
      charOffset: 50,
    );

    final progress = await service.get('a.md', 100);
    expect(progress, isNotNull);
    expect(progress!.charOffset, 50);
  });
}

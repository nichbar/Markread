import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markread/core/services/file_service.dart';
import 'package:markread/features/viewer/providers/viewer_provider.dart';

void main() {
  test('beginLoad sets ViewerStatus.loading with fileName', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Ensure build completed
    await container.read(viewerProvider.future);

    container.read(viewerProvider.notifier).beginLoad(fileName: 'notes.md');

    final asyncValue = container.read(viewerProvider);
    expect(asyncValue.hasValue, isTrue);
    expect(asyncValue.isLoading, isFalse);
    final state = asyncValue.requireValue;
    expect(state.status, ViewerStatus.loading);
    expect(state.fileName, 'notes.md');
  });

  test('completeLoad from bytes yields loaded markdown state', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(viewerProvider.future);

    final notifier = container.read(viewerProvider.notifier);
    notifier.beginLoad();

    final content = '# Hi\n\nbody\n';
    final file = PlatformFile(
      name: 'a.md',
      size: content.length,
      bytes: Uint8List.fromList(utf8.encode(content)),
    );

    await notifier.completeLoad(file, FileService());

    final asyncValue = container.read(viewerProvider);
    expect(asyncValue.hasValue, isTrue);
    final state = asyncValue.requireValue;
    expect(state.status, ViewerStatus.loaded);
    expect(state.fileName, 'a.md');
    expect(state.fileContent, content);
    expect(state.fileByteLength, utf8.encode(content).length);
    expect(state.headings, isNotEmpty);
  });

  test('completeLoad uses actual bytes.length when PlatformFile.size is 0',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(viewerProvider.future);

    final notifier = container.read(viewerProvider.notifier);
    notifier.beginLoad();

    final content = '# Intent\n\nbody\n';
    final bytes = Uint8List.fromList(utf8.encode(content));
    final file = PlatformFile(
      name: 'intent.md',
      size: 0,
      bytes: bytes,
    );

    await notifier.completeLoad(file, FileService());

    final state = container.read(viewerProvider).requireValue;
    expect(state.status, ViewerStatus.loaded);
    expect(state.fileByteLength, bytes.length);
    expect(state.fileByteLength, isNot(0));
  });

  test('completeLoad missing path and bytes yields error state', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(viewerProvider.future);

    final notifier = container.read(viewerProvider.notifier);
    notifier.beginLoad();

    final file = PlatformFile(name: 'missing.md', size: 0);
    await notifier.completeLoad(file, FileService());

    final state = container.read(viewerProvider).requireValue;
    expect(state.status, ViewerStatus.error);
    expect(state.errorMessage, isNotNull);
  });
}

# File Open Loading Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After file pick/intent, set Viewer to loading before navigation, yield a frame, then decode/classify/parse off the UI isolate so large files show Viewer loading instead of freezing Home.

**Architecture:** Split open into (1) synchronous `beginLoad()` → `AsyncLoading`, (2) navigate to `/viewer`, (3) post-frame `completeLoad` that reads bytes then runs pure processing via `Isolate.run` (with a same-pipeline fallback path if isolate is undesirable for a given call). Pure helpers and a sendable result DTO live in core/services so unit tests can run without Flutter widgets.

**Tech Stack:** Flutter, Riverpod 3.x (`AsyncNotifier`), GoRouter, `dart:isolate` / `Isolate.run`, `cross_file`/`file_picker`, `flutter_test`

**Spec:** `docs/superpowers/specs/2026-07-13-file-open-loading-design.md`

---

## File map

| File | Role |
|------|------|
| `lib/core/services/file_content_processor.dart` | **Create.** Pure, isolate-safe: process `Uint8List` + file name → sendable result DTO; heading parse; re-export/wrap type detection used in isolate. |
| `lib/core/services/file_service.dart` | **Modify.** Add `readFileAsBytes`; keep `isMarkdownFile` / `detectLanguage` / `isProbablyBinary` usable from processor (call static/top-level style from processor, or move pure maps into processor and thin-wrap in FileService). |
| `lib/features/viewer/providers/viewer_provider.dart` | **Modify.** `beginLoad()`, unified `completeLoad`/`loadFile` using bytes + `Isolate.run` + DTO → `ViewerState`; remove duplicated inline decode path; fold or delete unused `loadFileFromBytes` into shared pipeline. |
| `lib/features/home/screens/home_screen.dart` | **Modify.** Capture notifier → `beginLoad` → `go` → post-frame `completeLoad` for picker and intent. |
| `test/core/services/file_content_processor_test.dart` | **Create.** Unit tests for pure processing (markdown, source, binary, empty, headings). |
| `test/features/viewer/viewer_load_pipeline_test.dart` | **Create.** Provider tests: `beginLoad` sets loading; complete yields loaded/error without requiring full widget tree if possible. |

No Viewer UI redesign. No Home spinner.

---

### Task 1: Pure file content processor + unit tests

**Files:**
- Create: `lib/core/services/file_content_processor.dart`
- Create: `test/core/services/file_content_processor_test.dart`
- Modify: `lib/core/services/file_service.dart` (only if helpers need to be shared/static without instance)

- [ ] **Step 1: Write failing unit tests for pure processing**

Create `test/core/services/file_content_processor_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:markread/core/services/file_content_processor.dart';

void main() {
  group('processFileContent', () {
    test('markdown file parses headings and rendered mode', () {
      final text = '# Title\n\nHello\n\n## Section\n\nBody\n';
      final result = processFileContent(
        fileName: 'notes.md',
        bytes: Uint8List.fromList(utf8.encode(text)),
      );

      expect(result.fileName, 'notes.md');
      expect(result.fileContent, text);
      expect(result.isSourceCode, isFalse);
      expect(result.codeLanguage, isNull);
      expect(result.isBinary, isFalse);
      expect(result.viewMode, ProcessedViewMode.rendered);
      expect(result.warningMessage, isNull);
      expect(result.headings.length, 2);
      expect(result.headings[0].text, 'Title');
      expect(result.headings[0].level, 1);
      expect(result.headings[1].text, 'Section');
      expect(result.headings[1].level, 2);
    });

    test('known source extension is source code', () {
      final text = 'void main() {}';
      final result = processFileContent(
        fileName: 'main.dart',
        bytes: Uint8List.fromList(utf8.encode(text)),
      );

      expect(result.isSourceCode, isTrue);
      expect(result.codeLanguage, 'dart');
      expect(result.headings, isEmpty);
      expect(result.viewMode, ProcessedViewMode.rendered);
    });

    test('null bytes mark binary raw with warning', () {
      final bytes = Uint8List.fromList([0x00, 0x01, 0x02, 0x41]);
      final result = processFileContent(
        fileName: 'blob.bin',
        bytes: bytes,
      );

      expect(result.isBinary, isTrue);
      expect(result.viewMode, ProcessedViewMode.raw);
      expect(result.warningMessage, isNotNull);
    });

    test('empty content is fine', () {
      final result = processFileContent(
        fileName: 'empty.md',
        bytes: Uint8List(0),
      );

      expect(result.fileContent, isEmpty);
      expect(result.isBinary, isFalse);
      expect(result.headings, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run tests — expect FAIL (library missing)**

Run:

```bash
flutter test test/core/services/file_content_processor_test.dart
```

Expected: FAIL — cannot find `file_content_processor.dart` / `processFileContent`.

- [ ] **Step 3: Implement processor**

Create `lib/core/services/file_content_processor.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'file_service.dart';

/// Isolate-sendable view mode (maps to viewer ViewMode on UI isolate).
enum ProcessedViewMode { rendered, raw }

class ProcessedHeading {
  final String text;
  final int level;
  final int offset;

  const ProcessedHeading({
    required this.text,
    required this.level,
    required this.offset,
  });
}

/// Plain data only — safe for Isolate.run return values.
class ProcessedFileContent {
  final String fileName;
  final String fileContent;
  final bool isSourceCode;
  final String? codeLanguage;
  final bool isBinary;
  final ProcessedViewMode viewMode;
  final String? warningMessage;
  final List<ProcessedHeading> headings;

  const ProcessedFileContent({
    required this.fileName,
    required this.fileContent,
    required this.isSourceCode,
    required this.codeLanguage,
    required this.isBinary,
    required this.viewMode,
    required this.warningMessage,
    required this.headings,
  });
}

/// Top-level entry for Isolate.run / unit tests.
ProcessedFileContent processFileContent({
  required String fileName,
  required Uint8List bytes,
}) {
  final fileService = FileService();
  final content = utf8.decode(bytes, allowMalformed: true);

  final isMarkdown = fileService.isMarkdownFile(fileName);
  String? codeLanguage;
  var isSourceCode = false;

  if (!isMarkdown) {
    codeLanguage = fileService.detectLanguage(fileName);
    if (codeLanguage != null) {
      isSourceCode = true;
    }
  }

  final isBinary = fileService.isProbablyBinary(content);
  var viewMode = ProcessedViewMode.rendered;
  String? warningMessage;
  List<ProcessedHeading> headings = const [];

  if (isBinary) {
    viewMode = ProcessedViewMode.raw;
    warningMessage =
        'This file looks binary or malformed. Showing raw text.';
  } else if (isSourceCode) {
    viewMode = ProcessedViewMode.rendered;
  } else {
    headings = parseHeadings(content);
  }

  return ProcessedFileContent(
    fileName: fileName,
    fileContent: content,
    isSourceCode: isSourceCode,
    codeLanguage: codeLanguage,
    isBinary: isBinary,
    viewMode: viewMode,
    warningMessage: warningMessage,
    headings: headings,
  );
}

List<ProcessedHeading> parseHeadings(String markdown) {
  final headings = <ProcessedHeading>[];
  final lines = markdown.split('\n');
  var offset = 0;
  for (final line in lines) {
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('#')) {
      final level = trimmed.indexOf(' ');
      if (level >= 1 && level <= 3) {
        final text = trimmed.substring(level + 1).trim();
        if (text.isNotEmpty) {
          headings.add(ProcessedHeading(
            text: text,
            level: level,
            offset: offset,
          ));
        }
      }
    }
    offset += line.length + 1;
  }
  return headings;
}
```

Notes:
- Keep behavior aligned with current `ViewerNotifier` (markdown vs language map, binary warning string, heading levels 1–3).
- `FileService` instance construction in isolate is fine if methods are pure (no plugin calls). Do **not** call `pickFile` from the processor.
- Prefer `utf8.decode(..., allowMalformed: true)` only if it matches product intent; if current code uses strict decode, match existing `utf8.decode` behavior and let failures surface as errors in the notifier.

- [ ] **Step 4: Run tests — expect PASS**

```bash
flutter test test/core/services/file_content_processor_test.dart
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/file_content_processor.dart test/core/services/file_content_processor_test.dart
git commit -m "feat: add isolate-safe file content processor"
```

---

### Task 2: Byte read API on FileService

**Files:**
- Modify: `lib/core/services/file_service.dart`
- Optional test: extend processor tests only if needed; IO hard to unit test without fakes — skip heavy IO tests.

- [ ] **Step 1: Add `readFileAsBytes`**

In `lib/core/services/file_service.dart`, add:

```dart
import 'dart:typed_data';
// existing imports...

Future<Uint8List> readFileAsBytes(PlatformFile file) async {
  if (file.bytes != null) {
    return file.bytes is Uint8List
        ? file.bytes as Uint8List
        : Uint8List.fromList(file.bytes!);
  }
  if (file.path != null) {
    final xfile = XFile(file.path!);
    return xfile.readAsBytes();
  }
  throw Exception('Unable to read file: no path or bytes available');
}
```

Keep existing `readFileBytes` for now **or** implement it as decode of `readFileAsBytes` to avoid two code paths:

```dart
Future<String> readFileBytes(PlatformFile file) async {
  final bytes = await readFileAsBytes(file);
  return utf8.decode(bytes);
}
```

- [ ] **Step 2: Analyze**

```bash
flutter analyze lib/core/services/file_service.dart
```

Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add lib/core/services/file_service.dart
git commit -m "feat: read PlatformFile as bytes for load pipeline"
```

---

### Task 3: ViewerNotifier beginLoad + isolate completeLoad

**Files:**
- Modify: `lib/features/viewer/providers/viewer_provider.dart`
- Create: `test/features/viewer/viewer_load_pipeline_test.dart`

- [ ] **Step 1: Write failing provider tests**

Create `test/features/viewer/viewer_load_pipeline_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markread/core/services/file_service.dart';
import 'package:markread/features/viewer/providers/viewer_provider.dart';

void main() {
  test('beginLoad sets AsyncLoading', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Ensure build completed
    await container.read(viewerProvider.future);

    container.read(viewerProvider.notifier).beginLoad();

    expect(container.read(viewerProvider).isLoading, isTrue);
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
    expect(state.headings, isNotEmpty);
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
```

Adjust API names if implementation chooses `loadFile` with deferred body instead of `completeLoad` — but **prefer** the names in this plan for clarity.

- [ ] **Step 2: Run tests — expect FAIL**

```bash
flutter test test/features/viewer/viewer_load_pipeline_test.dart
```

Expected: FAIL — `beginLoad` / `completeLoad` missing.

- [ ] **Step 3: Implement notifier pipeline**

In `lib/features/viewer/providers/viewer_provider.dart`:

1. Import `dart:isolate`, `dart:typed_data`, and `file_content_processor.dart`.
2. Add:

```dart
void beginLoad() {
  state = const AsyncLoading();
}
```

3. Replace body of `loadFile` with shared completion logic, and add `completeLoad` as the main entry (or make `loadFile` call `beginLoad` then complete — Home will call them separately).

Recommended shape:

```dart
Future<void> completeLoad(PlatformFile file, FileService fileService) async {
  // If caller forgot beginLoad, still enter loading (safe).
  if (!state.isLoading) {
    state = const AsyncLoading();
  }

  try {
    final bytes = await fileService.readFileAsBytes(file);
    final name = file.name;

    final processed = await Isolate.run(() {
      return processFileContent(fileName: name, bytes: bytes);
    });

    state = AsyncData(_viewerStateFromProcessed(processed));
  } catch (e) {
    state = AsyncData(ViewerState(
      fileName: file.name,
      status: ViewerStatus.error,
      errorMessage: 'Could not read file: ${e.toString()}',
    ));
  }
}

ViewerState _viewerStateFromProcessed(ProcessedFileContent p) {
  return ViewerState(
    fileName: p.fileName,
    fileContent: p.fileContent,
    status: ViewerStatus.loaded,
    isSourceCode: p.isSourceCode,
    codeLanguage: p.codeLanguage,
    viewMode: p.viewMode == ProcessedViewMode.raw
        ? ViewMode.raw
        : ViewMode.rendered,
    headings: [
      for (final h in p.headings)
        HeadingItem(text: h.text, level: h.level, offset: h.offset),
    ],
    isBinary: p.isBinary,
    warningMessage: p.warningMessage,
  );
}

/// Convenience for call sites that still want one method (sets loading then completes).
/// Prefer beginLoad + navigate + completeLoad from Home.
Future<void> loadFile(PlatformFile file, FileService fileService) async {
  beginLoad();
  // Yield so a listening UI can paint loading if already on Viewer.
  await Future<void>.delayed(Duration.zero);
  await completeLoad(file, fileService);
}
```

4. Remove private `_parseHeadings` from notifier (moved to processor) **or** keep as thin deprecated wrapper unused — delete to avoid drift.
5. Fold `loadFileFromBytes` into:

```dart
Future<void> loadFileFromBytes(
  PlatformFile file,
  List<int> bytes,
  FileService fileService,
) async {
  beginLoad();
  await Future<void>.delayed(Duration.zero);
  try {
    final uint8 = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    final processed = await Isolate.run(() {
      return processFileContent(fileName: file.name, bytes: uint8);
    });
    state = AsyncData(_viewerStateFromProcessed(processed));
  } catch (e) {
    state = AsyncData(ViewerState(
      fileName: file.name,
      status: ViewerStatus.error,
      errorMessage: 'Could not read file: ${e.toString()}',
    ));
  }
}
```

Or delete `loadFileFromBytes` if unused (grep first). Spec allows fold/delete.

6. **Web note:** `Isolate.run` works on web with limitations; if analyze/runtime complains, gate with:

```dart
import 'package:flutter/foundation.dart' show kIsWeb;

Future<ProcessedFileContent> _process(String name, Uint8List bytes) async {
  if (kIsWeb) {
    // Still after yield from caller; keeps pipeline identical.
    return processFileContent(fileName: name, bytes: bytes);
  }
  return Isolate.run(() => processFileContent(fileName: name, bytes: bytes));
}
```

Use `_process` from `completeLoad` / `loadFileFromBytes`.

- [ ] **Step 4: Run provider tests — expect PASS**

```bash
flutter test test/features/viewer/viewer_load_pipeline_test.dart
```

Expected: PASS. If isolate in tests is flaky on some hosts, tests still should pass with real `Isolate.run` for VM.

- [ ] **Step 5: Run processor tests again**

```bash
flutter test test/core/services/file_content_processor_test.dart test/features/viewer/viewer_load_pipeline_test.dart
```

Expected: All PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/viewer/providers/viewer_provider.dart test/features/viewer/viewer_load_pipeline_test.dart
git commit -m "feat: load files via beginLoad and background processing"
```

---

### Task 4: HomeScreen navigate-first open sequence

**Files:**
- Modify: `lib/features/home/screens/home_screen.dart`

- [ ] **Step 1: Update `_openFile`**

Replace with:

```dart
Future<void> _openFile() async {
  final fileService = FileService();
  final file = await fileService.pickFile();
  if (file == null) return;
  if (!mounted) return;

  final notifier = ref.read(viewerProvider.notifier);
  notifier.beginLoad();
  context.go('/viewer?name=${Uri.encodeComponent(file.name)}');

  WidgetsBinding.instance.addPostFrameCallback((_) {
    notifier.completeLoad(file, fileService);
  });
}
```

- [ ] **Step 2: Update `_openIntentFile`**

Replace with:

```dart
void _openIntentFile(IntentFile intentFile) {
  final fileService = FileService();
  final file = PlatformFile(
    name: intentFile.name,
    path: intentFile.path,
    size: 0,
  );

  final notifier = ref.read(viewerProvider.notifier);
  notifier.beginLoad();
  if (mounted) {
    context.go('/viewer?name=${Uri.encodeComponent(intentFile.name)}');
  }

  WidgetsBinding.instance.addPostFrameCallback((_) {
    notifier.completeLoad(file, fileService);
  });
}
```

Critical:
- Capture `notifier` **before** `go`.
- `beginLoad()` **before** or same sync turn as `go`.
- No `loadFile` before navigation.
- Do not use `ref` inside post-frame if Home may be disposed — use captured `notifier`.

- [ ] **Step 3: Analyze home + provider**

```bash
flutter analyze lib/features/home/screens/home_screen.dart lib/features/viewer/providers/viewer_provider.dart lib/core/services/
```

Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add lib/features/home/screens/home_screen.dart
git commit -m "fix: set loading and navigate before heavy file open work"
```

---

### Task 5: Verification (project contract)

**Files:** none (commands only)

- [ ] **Step 1: Full unit tests**

```bash
flutter test
```

Expected: All tests PASS.

- [ ] **Step 2: Analyze**

```bash
flutter analyze
```

Expected: No issues (or only pre-existing unrelated).

- [ ] **Step 3: Build web**

```bash
flutter build web
```

Expected: Success.

- [ ] **Step 4: Build Android debug**

```bash
flutter build apk --debug
```

Expected: Success.

- [ ] **Step 5: Manual on-device checklist** (when device available)

```bash
flutter devices
flutter run -d <device-id>
```

Checklist:
- [ ] Large markdown: Home does not freeze; Viewer loading shows; then content.
- [ ] Tiny file: still feels quick.
- [ ] Cancel picker: stay on Home.
- [ ] Open second file after first: no flash of first file’s content.
- [ ] Non-md source / binary still behave as before.

- [ ] **Step 6: Final commit if any verification fixes**

Only if fixes were needed during verification; otherwise skip empty commit.

---

## Execution notes

- **TDD order:** Task 1 → 2 → 3 → 4 → 5. Do not skip failing-test steps for Tasks 1 and 3.
- **YAGNI:** No Home spinner, no cancel tokens, no search isolate.
- **Drift guard:** Single heading parser in `file_content_processor.dart` only.
- **If `completeLoad` name conflicts with taste:** rename consistently in Home + tests + provider; keep begin/complete split semantics.

## Done when

- Spec sequence is implemented: loading before nav → Viewer loading paint → isolate process → content/error.
- Unit tests cover processor + beginLoad/completeLoad happy and error paths.
- `flutter analyze`, `flutter test`, `flutter build web`, `flutter build apk --debug` succeed.

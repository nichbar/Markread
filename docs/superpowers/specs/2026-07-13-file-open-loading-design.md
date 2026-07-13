# File Open Loading — Design

**Date:** 2026-07-13
**Status:** Approved for planning
**Scope:** Navigate-first open flow + background isolate for heavy file work

## Problem

When opening a file large enough to take a couple of seconds, the app stays frozen on `HomeScreen` and then jumps straight into `ViewerScreen` with content already loaded. The Viewer loading UI (`AsyncLoading` + spinner + filename) is rarely visible.

### Root cause

In `HomeScreen._openFile` / `_openIntentFile`:

1. `loadFile(...)` is started (not awaited) **before or tightly coupled with** navigation.
2. Heavy work runs on the UI isolate: obtaining bytes, `utf8.decode`, binary heuristics, heading parse.
3. Flutter cannot paint the Viewer route until that work yields, so the user never sees Viewer loading.

Viewer already has a correct loading branch; the open pipeline never gives it a frame.

## Goal

After the user picks a file (or opens via intent):

1. Leave Home immediately.
2. Land on Viewer with its **existing** loading UI.
3. Load content without multi-second freezes on Home or during Viewer loading.

### Non-goals

- Home-screen spinner / “Opening…” state
- Redesign of Viewer loading chrome
- Recent files / caching
- Cancelling in-flight loads with a token (v1)
- Moving search/highlight work off-isolate (follow-up if needed)

## User flow

1. User confirms a file in the system picker (or app receives an intent file).
2. App sets `viewerProvider` to `AsyncLoading` **before** navigation (or in the same synchronous turn as `go`), so the first Viewer frame cannot show a previous file’s `AsyncData`.
3. App navigates to `/viewer?name=...` **before** heavy work.
4. Viewer paints loading (route `fileName` + spinner) for at least one frame.
5. Bytes are obtained; decode + type classification + heading parse run **off the UI isolate** (Android primary; web best-effort).
6. Viewer shows content or the existing error UI.

## Architecture

### Ownership

| Piece | Responsibility |
|-------|----------------|
| `HomeScreen` | Pick / receive file; mark loading; navigate; schedule heavy load. No loading UI. |
| `ViewerScreen` | Sole loading surface via `viewerProvider` → `AsyncLoading`. |
| `ViewerNotifier` | Expose begin-load (`AsyncLoading`) + complete load: bytes → isolate → `AsyncData` / error. |
| `FileService` | Pick file; read raw bytes; pure helpers for type detection (isolate-safe). |

### Navigation-first sequence

```text
pick / receive PlatformFile
  → capture ViewerNotifier (e.g. ref.read(viewerProvider.notifier)) before go
  → notifier.beginLoad() / set AsyncLoading   // MUST be before or same sync turn as go
  → context.go('/viewer?name=${Uri.encodeComponent(name)}')
  → after current frame (addPostFrameCallback / equivalent)
       → notifier.completeLoad(file, fileService)  // bytes + isolate only; no second “flash” of old data
```

Apply the same order to:

- `_openFile` (picker)
- `_openIntentFile` (intent / open-with)

**Loading vs heavy work (required):**

- `AsyncLoading` must be set **before** Viewer can paint after navigation. If loading is only set inside a post-frame `loadFile`, first paint can show prior `AsyncData` (previous file) or a blank non-loading state — that violates the goal.
- Acceptable shapes:
  - Split API: `beginLoad()` then post-frame `loadFile`/`completeLoad` that assumes already loading; or
  - Single `loadFile` that sets `AsyncLoading` synchronously at the start, called **before** `go`, with **all** byte read / decode / parse deferred with `await Future<void>.delayed(Duration.zero)` / post-frame / isolate so it cannot block the navigation frame.
- **Do not** run decode/parse/heading work before `go`.
- If the post-frame callback still lives on `HomeScreen`, capture the notifier (or container) **before** `go`; do not rely on `ref`/`context` after Home may be disposed.

**Why yield after loading + `go`:** Viewer route uses a ~300ms fade. Deferring only heavy work until after the next frame guarantees the loading branch can paint before CPU-heavy work starts.

### Background processing

Split completion of load into three phases (after `AsyncLoading` is already visible):

1. **UI isolate (light)**
   - Obtain raw `Uint8List` (from `file.bytes` or path via a thin `readFileAsBytes` API). Prefer async IO that yields; avoid long sync work on this isolate.

2. **Background (`Isolate.run` preferred; `compute` acceptable)**
   Pure work only:
   - `utf8.decode`
   - markdown vs source-language classification from **file name** (pass name into isolate payload)
   - `isProbablyBinary`
   - `_parseHeadings` when needed
   Return a small **isolate-sendable** result DTO (plain data only — no Flutter types, no `BuildContext`, no plugin objects), e.g.:
   - `fileName`, `fileContent`
   - `isSourceCode`, `codeLanguage`
   - `isBinary`, `viewMode`, `warningMessage`
   - `headings` as plain fields (`text`, `level`, `offset`) mappable to `HeadingItem` on the UI isolate

3. **UI isolate**
   - Map DTO → `ViewerState`; `state = AsyncData(...)` or error `ViewerState`.

Helpers used in the isolate entrypoint must be **top-level or static** and free of Flutter/`BuildContext`/plugin instance state. Prefer adapting `FileService` pure methods (or extracting them) so both UI and isolate share one implementation.

### API consolidation

- Prefer one load pipeline that always works from bytes after a thin read.
- `loadFile` and `loadFileFromBytes` (if kept) must share the same background pipeline so picker, intent, and web do not diverge.
- Add or adapt `FileService` to expose **bytes** (`Uint8List`) rather than only decoded `String` for the hot path.

### Platform notes

| Platform | Behavior |
|----------|----------|
| Android | Navigate-first + yield + isolate for decode/classify/parse. |
| Web | Navigate-first + yield always. Use isolate when useful; if not, process after yield on main so loading still appears. |
| Path vs bytes | If only `path` is set, read bytes on UI (or existing async IO), then hand `Uint8List` to isolate for decode/parse. |

## Error handling

| Case | Behavior |
|------|----------|
| User cancels picker | No navigation, no load |
| Missing path and bytes | Viewer error state |
| IO / decode / isolate failure | Existing pattern: `AsyncData(ViewerState(status: error, errorMessage: ...))` so Viewer error UI works; never leave provider stuck in `AsyncLoading` |
| Empty file | Navigate → load → existing empty-file UI |
| Binary / malformed | Background sets raw mode + warning; Viewer unchanged |
| Intent while already on Viewer | Set `AsyncLoading` again (clear previous content), navigate / re-go, complete load; latest completion wins |
| Rapid re-open | No cancel token in v1; last completed load sets state |
| Re-open after a prior file | Must not flash previous content; `AsyncLoading` before first Viewer paint of the new open |

Home does not surface open errors after navigation; Viewer owns them.

## UI

- **No** new Home loading indicator.
- Reuse existing Viewer loading UI (icon + filename + small `CircularProgressIndicator`).
- Brief flash of loading on tiny files is acceptable.

## Testing / verification

### Manual

- Open a multi‑MB markdown from Home: Home must not freeze; Viewer loading must show for a beat; then content.
- Open a tiny file: still feels instant (loading may flash).
- Cancel picker: stay on Home.
- Intent / open-with when available: same navigate-first behavior.
- Binary / non-markdown source file: correct mode after load.

### Automated / CI gates (project contract)

- `flutter analyze`
- `flutter build web`
- `flutter build apk --debug`
- After major changes: `flutter run -d <device-id>` for on-device check

## Implementation sketch (non-binding)

1. `FileService`: add byte-oriented read; keep pure type helpers isolate-safe.
2. `ViewerNotifier`: ensure `AsyncLoading` can be set before nav; extract pure “process bytes + name → sendable DTO”; run via `Isolate.run` after yield.
3. `HomeScreen`: set loading → `go` → post-frame complete load (capture notifier before `go`) for picker and intent.
4. Align any other call sites that start load before navigation or leave prior `AsyncData` visible.
5. Analyze + web/Android builds; manual large-file check on device; re-open a second file and confirm no flash of the first.

## Risks & follow-ups

| Risk | Mitigation |
|------|------------|
| Isolate startup cost on tiny files | Accept small overhead; UX win is on large files |
| Web isolate limitations | Navigate-first still fixed; main-thread after yield |
| Concurrent opens race | Document last-write-wins; cancel token later if needed |
| Residual jank from markdown **render** after load | Out of scope; separate from open pipeline |

## Decision summary

- **Chosen approach:** Navigate first + Viewer loading + background isolate for decode/classify/parse (Approach 3 from brainstorm).
- **Rejected:** Home-only spinner (masks freeze, wrong loading surface); navigate-first without isolate alone (loading may show but UI can still hitch for seconds on large files).

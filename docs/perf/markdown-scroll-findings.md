# Large-markdown scroll findings (A15 + A16)

Date: 2026-07-15
Sample: `assets/v2ex-hot-all.md` (~231 KB, 3,261 lines, ~153k chars)
Build: **profile**, Skia forced (`EnableImpeller=false`), optional `--dart-define=MARKREAD_AUTO_BENCH=true`

This document merges earlier A15 scroll notes, A16 scroll notes, A16 markdown deep-dive, and A15 natural-fling deep-dive.

## TL;DR

Markdown scroll pain is **not** primarily GPU, Impeller, or RSS.

It is a **full-document, non-virtualized widget tree**:

| Metric (after first layout) | Value |
|---|---:|
| Content size | **~377 × 76,9xx** dp |
| `maxScrollExtent` | **~76k** px |
| Element tree under `MarkdownView` | **63,858** |
| Stateful elements | **7,116** |
| RenderBoxes | **63,858** |
| Max element depth | **54** |
| Headings mounted | **277 / 277** (all live) |
| First real frame UI | **~1.17–1.41 s** |
| `MarkdownView.build()` wall time | **~0 ms** (cost is layout, not build method) |

| Path | A15 (PKX110) | A16 (24129PN74C) |
|---|---|---|
| Text-only monolith `Text` | **~120–123 fps @ 120Hz** | **~120–143 fps @ 120Hz** when flinging |
| Markdown open UI | **~1.3–1.4 s** | **~1.17–1.41 s** |
| Markdown tree | 63,858 / 7,116 stateful | **same** |
| Flutter HUD hz after open | often **60** (early runs) / **120** reported in natural fling | **stays 120** |
| SF `mActiveRenderFrameRate` after load | **60** | often **60** in dumpsys |
| Steady natural fling fps | **med ~31, max ~55** | teens–30s common; occasional 60–120 peaks (auto/monkey style runs) |
| Markdown RSS (Flutter HUD) | ~512–550 MB | ~515–590 MB |
| Text-only RSS | ~360 MB | ~360–380 MB |

**Conclusion:** Both OS versions share the same architecture bug. A16 is slightly more willing to keep Flutter’s reported 120Hz, but open cost and scroll under motion remain broken. A15 additionally demotes the SurfaceFlinger active render rate to 60 under this load and settles around **~30 fps-class** natural flings.

## Devices / build

| | A15 | A16 |
|---|---|---|
| Model | **PKX110** | **24129PN74C** |
| Serial | `854f4e38` | `b1921595` |
| Android | **15 (API 35)** | **16 (API 36)** |
| Physical size | 1216×2640 | 1200×2670 |
| Density | phys 560 / override 476 | phys 520 / override 470 |
| Display modes | 60 / 90 / 120 | 24 / 30 / 40 / 60 / 90 / 120 (VRR) |
| Flutter | 3.44.6 stable, Dart 3.12.2 | same app build family |
| Package | `now.link.markread` | same |

### Temporary diagnostic switches (as of this write-up)

| Switch | Location |
|---|---|
| Force Skia | `android/app/src/main/AndroidManifest.xml` `EnableImpeller=false` |
| Benchmark HUD | `lib/core/widgets/platform_benchmark_hud.dart` → `[bench]` / `[bench-deep]` / `[bench-frame]` |
| Markdown open/tree probe | `lib/features/viewer/widgets/markdown_view.dart` → `[bench-md]` |
| Scroll + natural fling driver | `lib/features/viewer/screens/viewer_screen.dart` → `[bench-scroll]`, `MARKREAD_AUTO_BENCH` |
| Text-only A/B | Home → **Open v2ex text-only** (`/text-only`) |
| Markdown sample | Home → **Open v2ex sample** |

### Automation constraints

| Device | `adb shell input` | Notes |
|---|---|---|
| A15 | usually allowed | `bench_scroll.sh` uses adb tap for open |
| A16 | often **blocked** (`INJECT_EVENTS`) | Same script falls back to one-tap monkey; also often blocks `WRITE_SETTINGS` |

Scrolling is never injected: both use in-app `goBallistic` via `MARKREAD_AUTO_BENCH`.

## Document shape (drives the tree)

| Feature | Count |
|---|---:|
| Lines | 3,261 |
| Chars | ~153k |
| `##` headings | 276 (+1 `#`) → **277** total |
| Ordered list items | **2,369** |
| Markdown links | **2,336** |
| Code / tables / images | 0 |

Almost every line is `N. [title](url)` → each becomes nested **WidgetSpan + OrderedListView + MdWidget + stateful LinkButton**.

Rough live-tree ratios:

- **~26.9 elements / list item**
- **~3.0 stateful / list item**
- All kept alive for the full **~76k dp** height inside one `SingleChildScrollView`
- Plus 277 heading `GlobalKey`s always mounted for TOC/progress mapping

## Architecture of the expensive path

```text
MarkdownView
  └─ SingleChildScrollView          ← no virtualization
       └─ GptMarkdown(full string)  ← entire document
            per list item:
              WidgetSpan
                OrderedListView (Row + number + Flexible)
                  nested MdWidget re-parse of item body
                    Link → stateful LinkButton
                      (MouseRegion + GestureDetector + hover setState)
```

## What is *not* the bottleneck

| Hypothesis | Evidence |
|---|---|
| Impeller-only | Still bad on forced Skia; pipeline log: `Pipeline=Skia (Vulkan)` |
| GPU fill primary | Open: rast 11–23 ms vs ui **1.2s+**; scroll rast elevated but secondary |
| File I/O / isolate | Pain is post-open layout |
| `MarkdownView.build` CPU | `buildMethodMs=0` |
| Memory OOM primary | Scroll dies with stable RSS; text-only fine at lower RSS |
| “Device cannot 120Hz” | Text-only holds ~120 fps on **both** A15 and A16 |

## Instrumentation tags

| Tag | Source | Meaning |
|---|---|---|
| `[bench]` | HUD | 500ms-window fps / ui / rast / tot / hz / rss |
| `[bench-deep]` | HUD | session max UI/raster/total, jank rate, frame count |
| `[bench-frame]` | HUD | individual frames with `tot ≥ 100ms` (+ vsync overhead) |
| `[bench-md]` | `MarkdownView` | open arm, build timing, size/tree stats, probe frames |
| `[bench-scroll]` | `ViewerScreen` | offset / max / % / velocity |

## Open path (both devices)

### A16 Run A (monkey after open)

```text
[bench-frame] ui=1412.3 rast=23.4 tot=1436.0 vsyncOverhead=0.3
[bench-md] frame1 size=377x76936 maxExtent=76163
  elements=63858 stateful=7116 renderBoxes=63858 depth=54 walkMs=10
```

### A16 Run B (auto-bench)

```text
[bench-frame] ui=1172.1 rast=11.3 tot=1188.9 vsyncOverhead=5.5
[bench-md] frame1 size=377x76936 maxExtent=76163
  elements=63858 stateful=7116 depth=54
[bench-md] build pass=1 buildMethodMs=0
```

### A15 natural-fling open (same architecture)

```text
[bench-frame] ui=1362.1 rast=16.7 tot=1379.2 vsyncOverhead=0.3
[bench-md] size=377x76985 maxExtent=76231
  elements=63858 stateful=7116 renderBoxes=63858 depth=54
  mountedHeadings=277/277
  buildMethodMs=0
```

**Interpretation**

1. **UI thread owns the cliff** (`ui ≈ tot`; rast secondary; vsync overhead tiny).
2. Cost is **first layout/paint of ~64k nodes**, not the Dart `build()` method body.
3. **Every heading key is mounted** → no virtualization.
4. Tree walk itself is cheap (~10–20 ms) once built; building/laying out is the killer.

## Text-only baseline

### A15 · Monolith Text (40 samples)

| Metric | min | median | max |
|---|---:|---:|---:|
| fps | 2 | 101.5 | 123 |
| hz | 120 | **120** | 120 |
| ui ms | 0.1 | 0.3 | 11.8 |
| rast ms | 0.9 | 1.5 | 3.0 |
| tot ms | 1.6 | 2.3 | 13.9 |
| rss MB | 338 | 361 | 417 |

Steady fling: **fps 120–123**, **ui 0.1**, **rast ~1.2–1.5**.

### A16 · Monolith Text (dense fling)

| Metric | min | median | max |
|---|---:|---:|---:|
| fps | 2 | 21* | **143** |
| hz | **120** | **120** | **120** |
| ui ms | 0.4 | 1.0 | 19.2 |
| rast ms | 1.2 | 2.0 | 3.8 |
| tot ms | 2.1 | 4.6 | 22.7 |
| rss MB | 358 | 363 | 381 |

\* Median depressed by open + inter-fling gaps. Continuous fling samples hit **120–132 fps**.

## Markdown scroll path

### A15 · early runs (adb flings, surface demotion)

Markdown run (61 samples, open included in aggregate):

| Metric | min | median | max |
|---|---:|---:|---:|
| fps | 2 | 121* | 173* |
| hz | **60** | **60** | **60** |
| ui ms | 0.1 | 0.3 | **1275.6** |
| rast ms | 1.5 | 2.8 | 26.3 |
| tot ms | 1.9 | 3.7 | **1302.2** |
| rss MB | 518 | 530 | 556 |

\* High medians after settle are misleading: surface already **60Hz**. First ~10 samples: fps med **~33.5**, ui max **1275.6**.

Forcing system peak/min 120 did **not** keep SF at 120 while markdown was open:

```text
mActiveModeId=2
mActiveRenderFrameRate=60.0
```

Open spike again **ui max ~1421 ms**; early scroll fps **~11–17** in worst samples.

### A15 · natural ballistic flings (goBallistic)

Motion: in-app `ScrollPositionWithSingleContext.goBallistic` only.
Only adb action: one tap on “Open v2ex sample”.
Log: `docs/perf/logs/a15_md_natural_fling.log`

Coverage (8 down + 4 up + 4 extra down):

| Phase | Landed offset | % of max |
|---|---:|---:|
| after down #0 (v=4500) | 2646 | 3.5% |
| after down #7 | 46716 | 61.3% |
| after up #3 | 24844 | 32.6% |
| end of extras | ~50542 | **~66%** |

Velocities from `[bench-scroll]`: peaks **~4–7.5k px/s**, decaying to rest.

Steady `[bench]` (257 samples; open `ui>100` excluded):

| Metric | min | med | max |
|---|---:|---:|---:|
| fps | 2 | **31** | **55** |
| hz (Flutter) | 120 | 120 | 120 |
| ui ms | 0.3 | **0.8** | 2.4 |
| rast ms | 2.3 | **4.4–4.5** | 8.3 |
| tot ms | 3.5 | **7.4–7.5** | 11.2 |
| rss MB | 512 | 536 | 550 |

FPS histogram (steady): majority **30–45**; peaks only **45–55**; **none ≥60** during natural fling window.

`[bench-deep]` end of session: **frames=1027, janky=48 (~4.7%)**, sessMax still the open cliff.

After scenario dumpsys still:

```text
mActiveModeId=2
mActiveRenderFrameRate=60.0
```

### A16 · markdown (monkey + auto-bench)

Monkey run aggregate (90 samples):

| Metric | min | median | max |
|---|---:|---:|---:|
| fps | 2 | 14.5* | 121 |
| hz | **120** | **120** | **120** |
| ui ms | 0.3 | 1.0 | **1213.9** |
| rast ms | 1.7 | 2.8 | 15.0 |
| tot ms | 2.7 | 4.3 | **1229.2** |
| rss MB | 515 | 529 | 569 |

\* Median low: first 1–2s after open stays single-digit / low-teens fps.

Open cliff:

```text
[bench] markdown · rendered fps=2 hz=120 ui=1213.9 rast=15.0 tot=1229.2 rss=533.3MB janky=true
```

Early scroll stretch (~1–3s): fps ≈ **9–16**. Later recovery peaks when already built: **116–121 fps** samples exist (unlike A15 natural fling window).

Auto-bench after settle (jump/animate coverage of full extent):

| Metric | min | med | max |
|---|---:|---:|---:|
| fps | 2 | ~24–29 | ~88–119 |
| ui ms | 0.2 | ~0.8 | ~4 |
| rast ms | 1.3 | **~5.6–5.7** | **~12** |
| tot ms | 2.1 | ~7 | ~16 |
| rss MB | ~545 | ~560–575 | ~590 |

Notes:

- After open, **per-frame UI is usually fine** (`ui < 2ms` median).
- Under motion, **raster rises** (~6–12 ms) more than UI — enough to miss 120Hz budget often.
- Windowed **fps frequently teens–30s** during long sweeps; occasional peaks near 100+.
- `[bench-deep]`: sessMaxUi stays the open cliff; later sessMaxRast ~25 ms; jank ~**8–15%** of timed frames.
- Mid-animate stretches sometimes show **sparse FrameTimings** while offset advances (“slideshow” feel).

Monkey-only flings barely moved the viewport (max offset ~613/76163); programmatic auto-scroll and natural `goBallistic` are required for real coverage.

## Display / VRR

| Signal | A15 | A16 |
|---|---|---|
| Flutter HUD `hz` during markdown | often **60** (early adb runs); **120** reported in natural-fling run | **120** throughout measured runs |
| SF `mActiveRenderFrameRate` after load | **60** | often **60** |
| Can hold 120 on text-only | **yes** | **yes** |

Treat Android SF active rate and `FlutterView.display.refreshRate` as **related but not identical** on these OEM/VRR stacks. Product acceptance should use **windowed fps + open UI ms + element count**, not HUD hz alone.

## Memory

| | A15 markdown | A16 markdown | Text-only (both) |
|---|---:|---:|---:|
| Flutter HUD RSS | ~512–550 MB | ~540–590 MB | ~360–380 MB |
| dumpsys TOTAL PSS (example) | ~432 MB | ~464 MB | — |
| TOTAL RSS (example) | ~604 MB | ~621 MB | — |
| Native heap private | ~183 MB | ~195 MB | — |
| Graphics (EGL/GL) | ~72 MB | ~44 MB | — |

Native heap + giant element tree explain the markdown RSS delta better than image cache (images=0 in this file). Memory is **real but secondary** to the open layout cliff.

## Side-by-side comparison

| | A15 natural fling | A16 deep runs |
|---|---|---|
| Open UI | **1362 ms** | **1172–1412 ms** |
| Tree | 63858 / 7116 stateful | **same** |
| Flutter hz | 120 reported (natural) / 60 earlier | 120 reported |
| SF active rate after | **60** | often **60** |
| Steady fling fps | **med ~31, max ~55** | often teens–30s; occasional higher peaks |
| Steady ui | ~0.8 ms | ~0.8 ms |
| Steady rast | ~4.5 ms (peaks ~8) | ~5.6 ms (peaks ~12) |
| Root cause | non-virtualized tree | **same** |

A16 does not remove the architecture bug; it only reports refresh rate differently and can show higher recovery peaks when the tree is already built.

### A14 note (manual only)

Older higher-res A14 was **not** re-driven by automation. User-reported: text-only and normal markdown both felt ~120 fps. That does **not** make the architecture good — A15/A16 expose the same cost more clearly.

## Product implications (priority)

1. **Virtualize by block**
   Parse once → block model → `ListView.builder` / slivers. Target: O(viewport) elements, not O(document).

2. **Lite link/list path for large docs**
   Prefer `TextSpan` + `TapGestureRecognizer` over per-link `LinkButton` widgets when content length or list count exceeds a threshold.

3. **Chunk first paint**
   Even with virtualization, avoid a single 1s+ UI frame: first screen first, then fill.

4. **Optional shape fast-path**
   This V2EX dump is almost pure `heading + ordered link list` — a specialized renderer would dominate general markdown polish.

5. **Keep measurement hooks until fix lands**
   Acceptance criteria:
   - open `ui` max ≪ 50 ms (profile)
   - elements on screen ≪ 2–3k, not 64k
   - steady fling fps near display Hz

## How to reproduce

```bash
# Finds adb device, builds profile+MARKREAD_AUTO_BENCH, installs, runs natural flings
./scripts/bench_scroll.sh                  # MODE=markdown (default)
./scripts/bench_scroll.sh <serial>
MODE=text ./scripts/bench_scroll.sh
MODE=both WAIT_SEC=40 ./scripts/bench_scroll.sh
SKIP_BUILD=1 ./scripts/bench_scroll.sh     # reuse already-installed APK

# Summarize
python3 scripts/summarize_bench_log.py /tmp/markread_bench_*.log
adb logcat -v time '*:S' flutter:V | rg '\[bench'
```

| Script | Role |
|---|---|
| `scripts/bench_scroll.sh` | Device discovery + profile build/install + open tap + natural flings |
| `scripts/run_profile.sh` | Interactive `flutter run --profile`; `AUTO_BENCH=1` passes the define |
| `scripts/summarize_bench_log.py` | Aggregate `[bench*]` lines |

Open-tap only is injected (adb `input` when allowed; one-tap monkey when `INJECT_EVENTS` is blocked). **Scrolling is never adb/monkey swipe** — `MARKREAD_AUTO_BENCH` drives `goBallistic` on both markdown and text-only screens. Device must be **unlocked** before the run.

## Files

| File | Role |
|---|---|
| `lib/features/viewer/widgets/markdown_view.dart` | Non-virtualized host + `[bench-md]` tree probe |
| `lib/features/viewer/screens/viewer_screen.dart` | Scroll probes + `MARKREAD_AUTO_BENCH` driver |
| `lib/features/viewer/screens/text_only_viewer_screen.dart` | Plain-text baseline |
| `lib/core/widgets/platform_benchmark_hud.dart` | `[bench]` / `[bench-deep]` / `[bench-frame]` |
| `lib/core/widgets/process_memory_io.dart` | RSS sampling (VM) |
| `lib/third_party/gpt_markdown/**` | WidgetSpan list/link expansion |
| `android/app/src/main/AndroidManifest.xml` | Impeller disabled (temporary A/B) |

## Raw logs

| Log | Contents |
|---|---|
| `docs/perf/logs/a15_bench_run1_profile_skia.log` | A15 early markdown/text profile |
| `docs/perf/logs/a15_bench_run2_forced120.log` | A15 forced system 120 settings |
| `docs/perf/logs/a15_md_natural_fling.log` | A15 natural goBallistic deep run |
| `docs/perf/logs/a16_bench_run1_profile.log` | A16 monkey profile run |
| `docs/perf/logs/a16_bench_text_steady.log` | A16 text-only steady |
| `docs/perf/logs/a16_md_deep_open.log` | A16 open + tree stats |
| `docs/perf/logs/a16_md_auto_scroll.log` | A16 auto-scroll coverage |

## Follow-ups

- [ ] Implement virtualized / lite markdown path; re-run `./scripts/bench_scroll.sh` on A15 + A16
- [ ] Re-test with Impeller re-enabled after virtualization
- [ ] Remove temporary Skia force + home benchmark buttons + auto-bench before release
- [ ] Re-run numeric tables on A14 for side-by-side

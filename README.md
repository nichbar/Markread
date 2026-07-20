# MarkRead

A minimal, read-only Markdown reader for Android and web.

Good open-source Markdown readers are hard to find on Android. Existing apps tend to have either poor UI or poor scrolling performance.

[MarkReader](https://github.com/usamaiqb/mark-reader) is one of the few that gets the UI right, but beneath it lies the outdated Markwon library, which holds back its file rendering. This project was born to fill that gap — powered by the much more modern [gpt_markdown](https://pub.dev/packages/gpt_markdown) rendering library, while inheriting MarkReader's polished UI (with a few improvements along the way).

Since this is a Flutter app, the APK size will be larger than [MarkReader](https://github.com/usamaiqb/mark-reader). If you're size-sensitive, stick with the original.

## Features

- **Markdown rendering** with full formatting support (headings, tables, code blocks, images)
- **Source code view** with syntax highlighting and language detection
- **Raw text view** for plain text reading
- **Search** within open documents
- **Table of contents** with heading navigation
- **Zoomable text** with pinch-to-zoom
- **Reading themes**: Light, Sepia, Dark, AMOLED — with independent light/dark reader surface toggle
- **Customizable reading**: font size, line height, text alignment
- **Word wrap** and **code block wrap** toggles
- **Android intent support**: open markdown files from other apps via "Open with..."
- **Material 3** design with light, dark, and system theme modes

## Getting Started

### Prerequisites

- Flutter SDK (^3.11.0-296.4.beta)
- Android SDK (for Android builds)

### Install dependencies

```bash
flutter pub get
```

### Run on device

```bash
# List available devices
flutter devices

# Run on a connected Android device
flutter run -d <device-id>

# Run on web
flutter run -d chrome
```

### Build

```bash
# Android debug APK
flutter build apk --debug

# Android release APK (arm64 only, minified — ~20 MB)
flutter build apk --release --target-platform android-arm64

# Full release (APK + AAB, with analysis)
./release.sh

# Web
flutter build web
```

> **Note:** The release APK targets `android-arm64` only, dropping armeabi-v7a and x86_64. This cuts APK size from ~57 MB to ~20 MB. R8 minification and resource shrinking are enabled in `android/app/build.gradle.kts`.

### Scroll benchmark (large markdown)

Profile-mode natural-fling bench for heavy markdown (open cost + scroll FPS). Device must be unlocked.

The FPS HUD is **hidden by default**. It auto-shows when built with `MARKREAD_AUTO_BENCH=true` (as the script does), or toggle **Show FPS HUD** from the viewer overflow menu.

```bash
./scripts/bench_scroll.sh              # find device, build profile+auto-bench, run
./scripts/bench_scroll.sh <serial>
SKIP_BUILD=1 ./scripts/bench_scroll.sh # reuse installed APK
```

After launch, open a large markdown file on-device (Open File / share). Auto-flings start once the viewer loads.

Findings: [`docs/perf/markdown-scroll-findings.md`](docs/perf/markdown-scroll-findings.md)

## Architecture

- **State management**: Riverpod 3.x (`Notifier`/`AsyncNotifier` pattern, no code generation)
- **Navigation**: GoRouter with route parameters
- **Markdown rendering**: `gpt_markdown` 1.1.7
- **Design**: Material 3 with `ColorScheme` manual configuration

```
lib/
├── main.dart                    # Entry point
├── app.dart                     # App widget, router, theme setup
├── core/
│   ├── models/                  # Data models (UserPreferences, etc.)
│   ├── providers/               # Shared providers (preferences)
│   ├── services/                # File I/O, intent handling
│   └── theme/                   # Light/dark theme definitions
└── features/
    ├── home/                    # Home screen with file picker
    ├── viewer/                  # Markdown/Source/Raw viewer
    │   ├── screens/
    │   ├── providers/
    │   └── widgets/             # MarkdownView, SourceCodeView, SearchBar, TOC, Zoom
    └── settings/                # Appearance and reading preferences
```

## Credits

The original Android version of this app: [mark-reader](https://github.com/usamaiqb/mark-reader) by [usamaiqb](https://github.com/usamaiqb).

## License

MIT

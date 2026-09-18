<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/logo/markread_logo_dark.svg">
    <img alt="Markread Logo" src="assets/logo/markread_logo.svg" width="160">
  </picture>
</p>

<h1 align="center">Markread</h1>

<p align="center">
  A minimal, read-focused Markdown reader for Android and web.
</p>

<p align="center">
  <a href="https://github.com/nichbar/Markread/releases/latest"><img src="https://img.shields.io/github/v/release/nichbar/Markread?logo=github&label=Release" alt="Latest Release"></a>
  <a href="https://md.hellmo.de"><img src="https://img.shields.io/badge/Web%20App-md.hellmo.de-blue" alt="Web App"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-AGPL--3.0-blue.svg" alt="License"></a>
</p>

Good open-source Markdown readers are hard to find on Android. Existing apps tend to have either poor UI or poor scrolling performance.

[MarkReader](https://github.com/usamaiqb/mark-reader) is one of the few that gets the UI right, but beneath it lies the outdated Markwon library, which holds back its file rendering. This project was born to fill that gap — powered by the much more modern [gpt_markdown](https://pub.dev/packages/gpt_markdown) rendering library, while inheriting MarkReader's polished UI (with a few improvements along the way).

Since this is a Flutter app, the APK size will be larger than [MarkReader](https://github.com/usamaiqb/mark-reader). If you're size-sensitive, stick with the original.

## Screenshots

<p align="center">
  <img src="screenshots/front.jpg" width="260" alt="Home" />
  &nbsp;&nbsp;
  <img src="screenshots/light.jpg" width="260" alt="Light theme" />
  &nbsp;&nbsp;
  <img src="screenshots/dark.jpg" width="260" alt="Dark theme" />
</p>

<p align="center">
  <em>Home</em>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
  <em>Light</em>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
  <em>Dark</em>
</p>

## Download

Pre-built releases are available on the **[GitHub Releases](https://github.com/nichbar/Markread/releases/latest)** page.

| Package | Architecture | Description |
| :--- | :--- | :--- |
| `Markread.v*.apk` | **arm64-v8a** | **Recommended** for modern Android devices (~20 MB) |
| `Markread.v*-universal.apk` | **Universal** | Compatible with `arm64-v8a`, `armeabi-v7a`, and `x86_64` |

### Web App

Markread is also accessible directly in the browser:
- **Live web app**: [md.hellmo.de](https://md.hellmo.de)
- **Offline / Self-hosting**: Download `web-release.zip` from [GitHub Releases](https://github.com/nichbar/Markread/releases/latest)

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

# Android universal APK (armeabi-v7a + arm64-v8a + x86_64)
flutter build apk --release --target-platform android-arm,android-arm64,android-x64

# Full release (APK + AAB, with analysis)
./release.sh

# Web
flutter build web
```

## Architecture

- **State management**: Riverpod 3.x (`Notifier`/`AsyncNotifier` pattern, no code generation)
- **Navigation**: GoRouter with route parameters
- **Markdown rendering**: `gpt_markdown` 1.2.1
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

Markdown theme **Blue Topaz** is adapted from [typora-blue-topaz-theme](https://github.com/qishaoyumu/typora-blue-topaz-theme) by [qishaoyumu](https://github.com/qishaoyumu) (MIT; upstream Obsidian Blue Topaz by whyt-byte).

Markdown theme **Monospace** is adapted from [typora-monospace-theme](https://github.com/typora/typora-monospace-theme) by [typora](https://github.com/typora) (MIT).

## License

This project is licensed under the [GNU Affero General Public License v3.0](LICENSE) (AGPL-3.0-only).

Third-party dependencies and adapted themes retain their original licenses (see [Credits](#credits)).

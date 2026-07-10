# Project Contract

## Build And Test

- Analyze: `flutter analyze`
- Build web: `flutter build web`
- Build Android: `flutter build apk --debug`
- Run on device: `flutter run -d <device-id>`
- List devices: `flutter devices`

## Architecture Boundaries

- Core models live in `lib/core/models/`
- Services (file I/O) live in `lib/core/services/`
- Shared providers live in `lib/core/providers/`
- Theme lives in `lib/core/theme/`
- Feature code lives in `lib/features/<feature>/` with subdirectories: `providers/`, `screens/`, `widgets/`
- Do not put feature-specific logic in `lib/core/`
- State management: Riverpod 3.x manual API (`Notifier`/`AsyncNotifier` + `NotifierProvider`/`AsyncNotifierProvider`)

## Coding Conventions

- Use Riverpod `Notifier`/`AsyncNotifier` pattern (no code generation)
- Use GoRouter for navigation with route parameters
- Use `gpt_markdown` 1.1.7 for markdown rendering (no `selectable` parameter — it does not exist)
- Use `FilePicker.pickFiles()` (not `FilePicker.platform.pickFiles()`) for file_picker v11 compatibility
- Feature-based modular structure: each feature is self-contained
- Prefer `const` constructors where possible
- Use Material 3 with `ColorScheme.fromSeed`

## Safety Rails

## NEVER

- Modify `.env`, lockfiles, or CI secrets without explicit approval
- Add code generation for Riverpod (no `riverpod_annotation`, `riverpod_generator`, `build_runner`)
- Import `dart:io` unconditionally in code that runs on web (check platform guards)
- Add new dependencies without explicit approval
- Commit secrets or auth tokens

## ALWAYS

- Show diff before committing
- Run `flutter analyze` before committing
- Verify builds for both web and Android before claiming completion
- Follow the feature-based file structure

## Verification

- App changes: `flutter analyze` + `flutter build web` + `flutter build apk --debug`
- Provider changes: verify all consuming screens still build
- Theme changes: check both light and dark modes
- After any major code changes: launch on connected Android device via `flutter run -d <device-id>` so the user can manually verify on-device

## Compact Instructions

Preserve:

1. Architecture decisions (NEVER summarize)
2. Modified files and key changes
3. Current verification status (pass/fail commands)
4. Open risks, TODOs, rollback notes

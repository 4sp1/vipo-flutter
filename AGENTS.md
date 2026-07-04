# Vipo — Flutter Pomodoro Timer

## Commands

```bash
flutter pub get          # Install dependencies
flutter run              # Run the app (defaults to connected device)
flutter run -d macos     # Run on macOS specifically
flutter run -d iphone    # Run on iOS simulator
flutter analyze          # Lint/static analysis (uses flutter_lints)
flutter test             # Run widget tests
dart fix --apply         # Auto-fix lint issues
flutter build macos      # Build macOS release
flutter build ios        # Build iOS release
```

SDK requirement: Dart ^3.10.4

## Architecture

Single-screen Cupertino (iOS-style) app with no routing:

```
main.dart           → VipoApp (CupertinoApp, dark theme)
                      └─ TimerScreen (StatefulWidget — all state lives here)
                           ├─ DonutTimer (displays circular progress, MM:SS, hint text)
                           └─ ModeSwitch (CupertinoSegmentedControl for Work/Short/Long)
notifications.dart  → Module-level notifications plugin + init/show helpers
models/
  timer_mode.dart   → TimerMode enum (work=20min, shortBreak=5min, longBreak=15min)
widgets/
  donut_timer.dart  → DonutTimer widget + _DonutPainter (CustomPainter)
  mode_switch.dart  → ModeSwitch widget
```

**State flow**: `TimerScreen` owns all timer state (`_remainingSeconds`, `_isRunning`, `_isComplete`, `_currentMode`). It passes callbacks down to `DonutTimer` (tap/longPress) and `ModeSwitch` (mode changed). Timer completion triggers vibration + local notification.

## Key Patterns & Conventions

- **Cupertino-only**: No Material widgets except in the skeleton test. The app uses `CupertinoApp`, `CupertinoPageScaffold`, `CupertinoSegmentedControl`, `CupertinoDynamicColor`, etc.
- **Dark theme**: `CupertinoThemeData(brightness: Brightness.dark)` is hardcoded in `main.dart`.
- **TimerMode enum**: Enhanced enum with fields (`duration`, `label`, `color`). Color is `CupertinoDynamicColor` — must be resolved with `CupertinoDynamicColor.resolve()` before passing to `_DonutPainter`.
- **flutter_animate**: Used via `.animate()` chain on `CustomPaint` in `DonutTimer`. Animations are simple fade+scale on build, not state-driven.
- **Notification initialization**: `main()` calls `notifications.initialize()` before `runApp()`. Platform-specific permission requests for macOS and iOS are in `notifications.dart`.
- **Vibration**: Uses the `vibration` package; guarded by `Vibration.hasVibrator()` check (macOS doesn't vibrate).

## Gotchas

- **Stale test file**: `test/widget_test.dart` references `MyApp` and Material `Icons.add` — it's the default Flutter template, not updated for Vipo. It will fail if run as-is.
- **Debug print in notifications**: `notifications.dart` uses `print()` for debug logging (initialization status, errors). These would trigger the `avoid_print` lint if enabled.
- **Notification in initState**: `TimerScreen.initState()` calls `notifications.show(title: 'hi', body: 'there')` — this is a debug/test notification that fires every time the app starts. Remove before shipping.
- **No Android support**: Only `ios/` and `macos/` platform directories exist. No `android/` folder. The pubspec has `flutter_launcher_icons` configured for iOS/macOS/Web/Windows but not Android.
- **State is ephemeral**: No persistence. Timer state is lost on hot restart or app close.
- **Single notification ID**: `notifications.show()` always uses `id: 0`, so each new notification replaces the previous one.

## Project Structure Conventions

- Models go in `lib/models/`
- Reusable widgets go in `lib/widgets/`
- Feature-level modules (like notifications) are standalone Dart files in `lib/`
- No routing, no state management library — pure `StatefulWidget` + `setState`
- Icon asset: `assets/icon/icon.png` (source) → generated via `flutter_launcher_icons`

## Generated API Client (`lib/data/api/`)

The typed dio HTTP client is generated from `tooling/openapi.json` (vipo-go tag
`v1.0.0-api`) and lives under `lib/data/api/`. **Never hand-edit any file
under `lib/data/api/`** except the hand-authored guard
`.openapi-generator-ignore`. Re-run the generator instead.

### Regenerate

```bash
./tooling/generate_api.sh
```

What the script does (in order):
1. `openapi-generator generate -i tooling/openapi.json -g dart-dio` with
   `serializationLibrary=json_serializable`, `dateLibrary=core`,
   `pubName=vipo_api`, `pubLibrary=vipo.api` into a temp dir.
2. Flattens `<tmp>/lib/*` into `lib/data/api/` (dart-dio always nests output
   under `lib/`).
3. Rewrites internal `package:vipo_api/` imports to `package:vipo/data/api/`
   (no-op when the generator emits relative imports).
4. Prepends `// ignore_for_file: type=lint` to every generated `.dart` so
   `flutter analyze` stays warning-free.
5. `flutter pub get` then `dart run build_runner build --delete-conflicting-outputs`
   to produce the `*.g.dart` part files.

### Prereqs (macOS)
- `brew install openapi-generator` (needs a JDK)
- Flutter on PATH (`flutter pub get` + `dart run build_runner`)

### Configuring the API base URL
- Default: `http://localhost:8080` (from `lib/data/api_config.dart`).
- Override at launch: `flutter run --dart-define=API_BASE_URL=https://api.example`
- Tests/services obtain the client via `buildApiClient()` in
  `lib/data/api_client.dart`; never construct `VipoApi` directly with a
  hard-coded base URL.
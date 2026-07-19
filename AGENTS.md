# Vipo — Flutter Pomodoro Timer

## Commands

```bash
flutter pub get          # Install dependencies
flutter run              # Run the app (defaults to connected device)
flutter run -d macos     # Run on macOS specifically
flutter run -d iphone    # Run on iOS simulator
flutter analyze          # Lint/static analysis (uses flutter_lints)
flutter test             # Run unit tests: BLoCs, repositories, services, mappers
dart fix --apply         # Auto-fix lint issues
flutter build macos      # Build macOS release
flutter build ios        # Build iOS release

# Regenerate API client (requires openapi-generator + JDK on macOS)
./tooling/generate_api.sh
```

SDK requirement: Dart ^3.10.4

`flutter test` runs the full unit suite against BLoCs (`bloc_test`), repositories (mock services, assert `Result<T>` success/failure), services (mocked generated API clients, verify delegation + mapping), mappers (round-trip domain ↔ API for all enum cases), `Result<T>` (sealed switch on `Success`/`Failure`), and a `VipoApp` smoke test. No real HTTP is made.

## Architecture

MVVM + `flutter_bloc`. Two screens, no routing — navigation is a stateless push from `TimerScreen` to `NotesScreen`. UI is dumb: it reads state from ambient BLoCs and dispatches events; no `setState`-owned business state, no `context.read` for logic inside BLoCs.

```
main.dart           → VipoApp (StatelessWidget, CupertinoApp, dark theme)
                      └─ MultiRepositoryProvider (LogsRepository, NotesRepository)
                           └─ MultiBlocProvider (LogsBloc, TimerBloc, NotesBloc)
                                ├─ TimerScreen (StatelessWidget — BlocBuilder/BlocSelector/BlocListener only)
                                │    ├─ DonutTimer (unchanged)
                                │    └─ ModeSwitch (unchanged)
                                └─ NotesScreen (StatefulWidget — BlocBuilder; initState issues NotesFetchRequested)
di.dart             → AppDeps — wires Dio → generated LogsApi/NotesApi → services → repositories → BLoCs (constructor DI, no service locator)
data/
  api/                      → Generated OpenAPI client (dart-dio) — NEVER hand-edit
  api_config.dart          → const kApiBaseUrl (override via --dart-define=API_BASE_URL=...)
  api_client.dart          → buildApiClient() helper — single entry point for tests/services
  services/
    logs_service.dart      → Thin wrapper over generated LogsApi
    notes_service.dart     → Thin wrapper over generated NotesApi
domain/
  models/
    timer_mode.dart        → TimerMode enum (work, shortBreak, longBreak)
    log_action.dart        → LogAction enum (start, pause, resume, complete, switch_mode, reset)
    log_entry.dart         → LogEntry domain model
    note.dart              → Note domain model
  mappers/
    pomodoro_state_mapper.dart  → TimerMode ↔ PomodoroState (generated enum)
    log_entry_mapper.dart       → API LogEntry ↔ domain LogEntry
    note_mapper.dart            → API Note ↔ domain Note
  result.dart              → Result<T> sealed class (Success / Failure) + domain failure exceptions
repositories/
  logs_repository.dart     → Source of truth for logs; returns Result<T>
  notes_repository.dart    → Source of truth for notes; returns Result<T>
blocs/
  timer/                   → TimerBloc, TimerEvent, TimerState (owns the 1-second ticker StreamSubscription)
  logs/                    → LogsBloc, LogsEvent, LogsState
  notes/                   → NotesBloc, NotesEvent, NotesState
screens/
  timer_screen.dart        → StatelessWidget — BlocBuilder/BlocSelector/BlocListener, no setState
  notes_screen.dart        → StatefulWidget — BlocBuilder; initState dispatches NotesFetchRequested; push from TimerScreen
widgets/
  donut_timer.dart         → Unchanged
  mode_switch.dart         → Unchanged
notifications.dart   → Module-level notifications plugin + init/show helpers (unchanged)
```

## Data flow

- **Unidirectional**: UI → Event → BLoC → State → UI. The screens dispatch `*Event`s; BLoCs own the state transitions and emit `*State`s; the screens rebuild via `BlocBuilder`/`BlocSelector`. No screen holds business state in `setState`.
- **BLoC-to-BLoC**: `TimerBloc` is constructed with `LogsBloc` as a dependency (`TimerBloc(this._logsBloc)` in `di.dart`). On `TimerStarted`/`TimerPaused`/`TimerCompleted`/`TimerModeChanged` it dispatches `LogCreated` events to the shared `LogsBloc` (fire-and-forget). `LogsBloc` is created **before** `TimerBloc` in `AppDeps` for this reason.
- **Error boundary**: Repositories return `Result.success(value)` or `Result.failure(exception)`. BLoCs `switch` on the `Result` and emit corresponding states (`*LoadFailure`, etc.). `DioException` is normalized into a domain failure (`LogCreateFailure`, `LogRetrievalFailure`, `NoteCreateFailure`, `NoteRetrievalFailure`) inside the repository layer; no BLoC ever imports `package:dio/dio.dart`.
- **Platform side effects**: Vibration + local notification fire once on `TimerComplete`, in `TimerScreen`'s `BlocListener`. BLoCs do not import `vibration` or `flutter_local_notifications`.

## Key Patterns & Conventions

- **Cupertino-only**: No Material widgets. The app uses `CupertinoApp`, `CupertinoPageScaffold`, `CupertinoSegmentedControl`, `CupertinoDynamicColor`. Enforced by lint convention, not a custom lint rule.
- **Dark theme**: `CupertinoThemeData(brightness: Brightness.dark)` is hardcoded in `main.dart`.
- **flutter_bloc + equatable**: All BLoC events and states extend `equatable`'s `Equatable` for value equality. Tested with the `bloc_test` package.
- **Result<T>**: Repository methods return `Result<T>`. Callers `switch` on `Success`/`Failure`. Sealed: exhaustiveness checks catch missing branches at compile time. The four domain failures live alongside `Result` in `lib/domain/result.dart`.
- **Constructor DI**: All BLoCs and services receive dependencies via constructor — there is no `get_it`, no service locator, and no `context.read<>()` inside BLoCs. `context.read` is used only inside widget event handlers (e.g. `NotesScreen._showAddNoteDialog`) to obtain an already-provided BLoC. The entire dependency graph is built in `AppDeps` (`lib/di.dart`) in a single constructor: `Dio` → `LogsApi`/`NotesApi` (generated) → `LogsService`/`NotesService` → `LogsRepository`/`NotesRepository` → `LogsBloc` → `TimerBloc`, then `NotesBloc`.
- **TimerMode enum**: Enhanced enum with fields (`duration`, `label`, `color`). Color is `CupertinoDynamicColor` — must be resolved with `CupertinoDynamicColor.resolve()` before passing to `_DonutPainter`.
- **flutter_animate**: Used via `.animate()` chain on `CustomPaint` in `DonutTimer`. Animations are simple fade+scale on build, not state-driven.
- **Notification initialization**: `main()` calls `notifications.initialize()` before `runApp()`. Platform-specific permission requests for macOS and iOS are in `notifications.dart`.
- **Vibration**: Uses the `vibration` package; guarded by `Vibration.hasVibrator()` check (macOS doesn't vibrate).
- **Generated code is off-limits**: Files under `lib/data/api/` are auto-generated from `tooling/openapi.json`. Never hand-edit them — even small fixes. Re-run `./tooling/generate_api.sh` instead (see the **Generated API Client** section below).
- **API base URL**: Configured via `const kApiBaseUrl` in `lib/data/api_config.dart` (reads `String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8080')`). Override at launch: `flutter run --dart-define=API_BASE_URL=https://api.example`. Tests/services obtain the client via `buildApiClient()` in `lib/data/api_client.dart`; `AppDeps` constructs its own `Dio` with `baseUrl: kApiBaseUrl` directly (the generated `LogsApi`/`NotesApi` accept a configured `Dio`).

## Testing

- **BLoC tests** (`test/blocs/{timer,logs,notes}/`): built with the `bloc_test` package. Repositories are mocked with `mocktail`. `timer_bloc_test.dart` injects a real `LogsBloc` backed by a `MockLogsRepository` (stronger than spying on `LogsBloc.add` — proves `LogCreated` flows end-to-end through the repository).
- **Repository tests** (`test/repositories/`): mock the service layer, assert `Result.success` carries the mapped value and `Result.failure` carries the correct domain failure (`LogCreateFailure`, `NoteRetrievalFailure`, etc.). Cover both happy path and `DioException`-throwing path.
- **Service tests** (`test/data/services/`): mock the generated `LogsApi`/`NotesApi`, verify delegation and API↔domain mapping round-trips for every enum case.
- **Mapper tests** (`test/domain/`): round-trip tests covering every `TimerMode` ↔ `PomodoroState` pair and every `LogAction` × `TimerMode` combination for `log_entry_mapper.dart`; full `Note` ↔ API `Note` for `note_mapper.dart`.
- **Model tests**: `log_entry_model_test.dart`, `note_model_test.dart`, `log_action_test.dart`, `timer_mode_test.dart`, `result_test.dart` (sealed switch + the four domain failure exceptions).
- **Smoke tests**: `test/widget_test.dart` pumps `VipoApp(deps: AppDeps())` and asserts `TimerScreen` renders. `test/data/api_smoke_test.dart` constructs a `VipoApi` without making a network call. `test/di_test.dart` asserts `AppDeps` builds the full graph and exposes every getter.
- **No real HTTP**: every unit test mocks the layer below. Only smoke tests instantiate `AppDeps` or `VipoApi`, and none make network calls.
- Run: `flutter test`

## Gotchas

- **Generated code**: Never edit `lib/data/api/`. Regenerate via `./tooling/generate_api.sh`. The only hand-authored file in that tree is `.openapi-generator-ignore`.
- **No Android support**: Only `ios/` and `macos/` platform directories exist. No `android/` folder. The pubspec has `flutter_launcher_icons` configured for iOS/macOS/Web/Windows but not Android.
- **State is ephemeral**: No local persistence. Timer state lives in `TimerBloc`'s in-memory state; it is lost on hot restart or app close.
- **Single notification ID**: `notifications.show()` always uses `id: 0`, so each new notification replaces the previous one.
- **Debug print in notifications**: `notifications.dart` uses `print()` for debug logging (initialization status, errors). These would trigger the `avoid_print` lint if enabled — it is not.
- **Timer ticker is a `StreamSubscription`**: `TimerBloc` cancels its ticker `StreamSubscription` on `close()` and on every `_startTicker` call. Tests that pump multiple `TimerStarted` events don't leak subscriptions.
- **NotesScreen is a StatefulWidget** (not a `StatelessWidget`): the `_NotesScreenState.initState` dispatches `NotesFetchRequested` once. The push from `TimerScreen` is a plain `CupertinoPageRoute`, not a named route — there is no router in this app.

## Project Structure Conventions

- Models go in `lib/domain/models/`
- Mappers (domain ↔ API) go in `lib/domain/mappers/`
- `Result<T>` and domain failure exceptions go in `lib/domain/result.dart`
- Repositories (source of truth, return `Result<T>`) go in `lib/repositories/`
- BLoCs go in `lib/blocs/<feature>/` (one subdirectory per feature: `timer/`, `logs/`, `notes/`)
- Screens go in `lib/screens/`
- Reusable widgets go in `lib/widgets/`
- Thin service wrappers over generated API clients go in `lib/data/services/`
- Feature-level modules (like notifications) are standalone Dart files in `lib/`
- Dependency wiring lives in `lib/di.dart` (`AppDeps`)
- No routing, no service locator — `MultiRepositoryProvider` + `MultiBlocProvider` in `main.dart`
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
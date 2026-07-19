# Update AGENTS.md for MVVM + flutter_bloc Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use supervised-plan-execution to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite `AGENTS.md` so every section reflects the new MVVM + `flutter_bloc` architecture (DI wiring via `AppDeps`, BLoCs, repositories, services, mappers, `Result<T>`, generated OpenAPI client, `bloc_test`/`mocktail` test conventions) and remove all stale `StatefulWidget` + `setState` references — single-file documentation change, no production code edits.

**Architecture:** This is a documentation-only task. The implementer reads the actual code in `lib/` to verify each claim, then overwrites `AGENTS.md` with a new body whose sections mirror the structure required by issue #13 (Commands, Architecture, Data flow, Key patterns & conventions, Testing, Gotchas, Project Structure Conventions, Generated API Client). Commits use the `jj` temp-file pattern (see `core-commands` skill). Production code is untouched; `flutter analyze` and `flutter test` must remain green (Task 7 confirms regressions didn't sneak in).

**Tech Stack:** Markdown, `flutter analyze` (validation), `flutter test` (validation). The documented architecture uses `flutter_bloc` + `equatable`, `dio`, `dart-dio`-generated clients under `lib/data/api/`, `mocktail` + `bloc_test` for tests.

---

## Current state audit (read-only, do before any edit)

The issue body makes a few claims that do **not** match the actual code. The implementer should write the doc to match the **code**, not the issue text, because acceptance criterion #7 says "AGENTS.md accurately reflects the new MVVM + flutter_bloc architecture" — accuracy is the bar.

| Issue claim | Reality in repo | Resolution in the rewrite |
|---|---|---|
| `NotesScreen (StatelessWidget — BlocBuilder only)` | `lib/screens/notes_screen.dart:8` `class NotesScreen extends StatefulWidget`. Its `_NotesScreenState.initState` dispatches `NotesFetchRequested`. | Document `NotesScreen` as **StatefulWidget** driven by `BlocBuilder`/`context.read`, not StatelessWidget. The issue's `StatelessWidget` label is a typo. |
| Project tree lists `blocs/timer/` (singular) and `blocs/logs/`, `blocs/notes/` | Code matches this exactly: `lib/blocs/{timer,logs,notes}/`. | Keep tree as-is. |
| Issue: "DI wiring (`di.dart`, `AppDeps`) is documented" | `lib/di.dart` exists; `class AppDeps` builds Dio → API clients → services → repositories → BLoCs. `TimerBloc(_logsBloc)` — `LogsBloc` is constructed first. | Document this ordering explicitly because `TimerBloc` depends on `LogsBloc`. |
| `widget_test.dart` is stale (default Flutter template) | Reality: `test/widget_test.dart` was already fixed — it pumps `VipoApp(deps: AppDeps())` and asserts `TimerScreen` renders. | Move the "stale widget test" gotcha into the **history-no-longer-true** pile; replace with a note that the smoke test is intentionally minimal. |
| Issue body's regeneration command uses `openapi-generator-cli generate -i openapi.json -g dart-dio -o lib/data/api/ --additional-properties=pubName=vipo_api` | `tooling/generate_api.sh` is the canonical path (runs generator into a temp dir, flattens, rewrites imports, runs build_runner). Direct CLI use would skip the import-rewrite step. | Document the `./tooling/generate_api.sh` script (which already exists in `AGENTS.md`), and mention `openapi-generator-cli` only as the underlying tool. |
| `notifications.dart` uses `print()` (debug logging) | Still true; `avoid_print` lint is not enabled. | Keep the existing gotcha as-is. |

### Files the implementer MUST read before writing

- `AGENTS.md` (the file being rewritten — current state, lines 1–99)
- `lib/main.dart` — confirms `VipoApp` is `StatelessWidget`, uses `MultiRepositoryProvider` → `MultiBlocProvider`, `TimerScreen` is `home`
- `lib/di.dart` — `AppDeps`, construction order, `dispose()`
- `lib/data/api_config.dart` — `kApiBaseUrl` constant + `String.fromEnvironment`
- `lib/data/api_client.dart` — `buildApiClient()` helper
- `lib/domain/result.dart` — `sealed class Result<T>`, four domain failure types
- `lib/repositories/logs_repository.dart` and `lib/repositories/notes_repository.dart` — confirm `Result<T>` contract, no business logic
- `lib/data/services/logs_service.dart` and `lib/data/services/notes_service.dart` — thin wrappers over generated `LogsApi`/`NotesApi`
- `lib/blocs/timer/timer_bloc.dart` — confirms `TimerBloc(this._logsBloc)` and `StreamSubscription` ticker
- `lib/screens/timer_screen.dart` — confirms `StatelessWidget`, `BlocBuilder`/`BlocSelector`/`BlocListener`, platform side effects in UI
- `lib/screens/notes_screen.dart` — confirms `StatefulWidget` (NOT StatelessWidget), `_NotesScreenState.initState` dispatches `NotesFetchRequested`
- `test/widget_test.dart` — confirms the smoke test is no longer the default Flutter template
- `test/blocs/**`, `test/repositories/**`, `test/domain/**`, `test/data/services/**` — confirms `bloc_test` + `mocktail` conventions
- `lib/data/api/` directory listing — confirms it is generated and must not be hand-edited
- `pubspec.yaml` — confirms `flutter_bloc`, `equatable`, `mocktail`, `bloc_test`, `build_runner`, `json_serializable` versions

### Files this task touches

- Modify: `AGENTS.md` (entire file is replaced)
- No code changes anywhere under `lib/` or `test/`.

---

### Task 1: Establish a clean working baseline

**Files:**
- Read: `AGENTS.md`
- Run: `flutter analyze`, `flutter test`

This task confirms the starting state is green so Task 7's verification is a true diff against the pre-change baseline.

- [ ] **Step 1: Read the current AGENTS.md**

```bash
# from repo root
view AGENTS.md
```

Confirm the file has the stale content: `TimerScreen (StatefulWidget — all state lives here)`, "Debug notification in initState" gotcha, "Stale test file" gotcha, and the existing "Generated API Client" section referencing `./tooling/generate_api.sh`.

- [ ] **Step 2: Confirm analyze is clean**

Run: `flutter analyze`
Expected: "No issues found!" (or zero warnings if `lib/data/api/` is excluded via `analysis_options.yaml`).

If warnings appear, stop and surface them — they are not blocked by this task, but Task 7 won't be able to prove "no regression" if the baseline isn't clean. Document whatever the baseline output is so Task 7 can compare.

- [ ] **Step 3: Confirm tests are green**

Run: `flutter test`
Expected: all tests pass (suite includes BLoC / repository / service / mapper / `Result` / smoke tests, plus `di_test.dart`).

Record the test count and total time printed by the runner — Task 7 will compare against this number.

- [ ] **Step 4: Snapshot the baseline**

```bash
flutter analyze > /tmp/vipo_baseline_analyze.txt 2>&1 || true
flutter test > /tmp/vipo_baseline_test.txt 2>&1 || true
```

(Run individually — each Bash invocation is an independent shell.)

---

### Task 2: Write the new `AGENTS.md` body

**Files:**
- Modify: `AGENTS.md` (overwrite entire file)

This task is a single whole-file overwrite because the new structure is materially different from the old one (every section is touched). The implementer uses the `write` tool to replace the file in one shot, then reviews the diff in Task 3.

- [ ] **Step 1: Overwrite `AGENTS.md` with the new content below**

Use the `write` tool (not `edit`) to replace the entire file. The exact content to write:

````markdown
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
````

- [ ] **Step 2: Confirm the file was written**

```bash
view AGENTS.md
```

The first line should be `# Vipo — Flutter Pomodoro Timer` and the last non-blank line should be the `hard-coded base URL.` line from the **Configuring the API base URL** subsection.

- [ ] **Step 3: Grep for stale content**

Run: `grep -n "setState\|all state lives here\|MyApp\|Icons.add\|Stale test file\|Debug notification in initState\|Debug notification" AGENTS.md`
Expected: no matches. (The grep is intentional over-broad: it catches every stale phrase the old file had.)

If any match returns, fix the file before continuing.

- [ ] **Step 4: Grep for the required new content**

Run: `grep -c "AppDeps\|Result<T>\|bloc_test\|mocktail\|TimerBloc\|LogsBloc\|NotesBloc\|MultiBlocProvider\|MultiRepositoryProvider\|openapi-generator\|StatelessWidget\|StatefulWidget\|equatable" AGENTS.md`
Expected: a count > 0 for every term — each new architecture keyword appears at least once. A zero on any of these terms means that section was dropped.

---

### Task 3: Verify the diff against the issue's acceptance criteria

**Files:**
- Read: `AGENTS.md`

Each acceptance criterion from issue #13 maps to a specific location in the new file. The implementer manually verifies each one.

- [ ] **Step 1: Verify "accurately reflects the new MVVM + flutter_bloc architecture"**

Open `AGENTS.md` and confirm:
- The first paragraph under `## Architecture` says "MVVM + `flutter_bloc`".
- `TimerScreen` is documented as `StatelessWidget` (matches `lib/screens/timer_screen.dart:26`).
- `NotesScreen` is documented as `StatefulWidget` (matches `lib/screens/notes_screen.dart:8`).

- [ ] **Step 2: Verify "Architecture diagram includes all new directories and files"**

Cross-check the tree under `## Architecture` against the real `lib/` tree:

Run: `ls lib/blocs lib/data lib/data/services lib/domain lib/domain/models lib/domain/mappers lib/repositories lib/screens lib/widgets`

Every file in that listing must appear in the tree. Specifically these must all be present in the doc:
`di.dart`, `data/api/`, `data/api_config.dart`, `data/api_client.dart`, `data/services/logs_service.dart`, `data/services/notes_service.dart`, `domain/models/timer_mode.dart`, `domain/models/log_action.dart`, `domain/models/log_entry.dart`, `domain/models/note.dart`, `domain/mappers/pomodoro_state_mapper.dart`, `domain/mappers/log_entry_mapper.dart`, `domain/mappers/note_mapper.dart`, `domain/result.dart`, `repositories/logs_repository.dart`, `repositories/notes_repository.dart`, `blocs/timer/`, `blocs/logs/`, `blocs/notes/`, `screens/timer_screen.dart`, `screens/notes_screen.dart`, `widgets/donut_timer.dart`, `widgets/mode_switch.dart`, `notifications.dart`, `main.dart`.

If any are missing, add them to the tree.

- [ ] **Step 3: Verify "OpenAPI regeneration command is documented"**

Confirm the `## Commands` code block contains `./tooling/generate_api.sh` with a comment, and the `## Generated API Client (`lib/data/api/`)` section has a `### Regenerate` subsection documenting what the script does in 5 ordered steps.

- [ ] **Step 4: Verify "DI wiring (`di.dart`, `AppDeps`) is documented"**

Confirm:
- `di.dart` appears in the architecture tree with the comment `AppDeps — wires Dio → generated LogsApi/NotesApi → services → repositories → BLoCs (constructor DI, no service locator)`.
- The `## Key Patterns & Conventions` section has a "Constructor DI" bullet that explicitly names `Dio` → `LogsApi`/`NotesApi` → `LogsService`/`NotesService` → `LogsRepository`/`NotesRepository` → `LogsBloc` → `TimerBloc`, then `NotesBloc`, and explains **why** `LogsBloc` is built before `TimerBloc`.
- The `## Data flow` section mentions `TimerBloc(this._logsBloc)` and the `LogCreated` fire-and-forget dispatch.

- [ ] **Step 5: Verify "Testing conventions (mocktail, bloc_test, Result pattern) are documented"**

Confirm the `## Testing` section explicitly names:
- `bloc_test`
- `mocktail`
- `Result.success` / `Result.failure`
- The injected-real-`LogsBloc`-with-`MockLogsRepository` pattern in `timer_bloc_test.dart` (this is the non-obvious one — the issue's "Mock `LogsBloc`" requirement is satisfied by a stronger pattern; the doc must record it).
- Round-trip coverage for every enum case (mappers)
- The no-real-HTTP rule.

- [ ] **Step 6: Verify "Outdated gotchas are removed or updated (debug notification, stale test)"**

Confirm:
- The phrase "Stale test file" no longer appears (grep in Step 3 of Task 2 already proved this; this is a re-confirmation).
- The phrase "Notification in initState" no longer appears.
- The **Testing** section's smoke-tests bullet documents `widget_test.dart` as a *real* smoke test that pumps `VipoApp(deps: AppDeps())` — i.e. the default-Flutter-template claim has been retracted.
- The new gotchas block lists **Generated code**, **No Android support**, **State is ephemeral**, **Single notification ID**, **Debug print in notifications**, **Timer ticker is a `StreamSubscription`**, **NotesScreen is a StatefulWidget**.

- [ ] **Step 7: Verify "No reference to `setState` or `StatefulWidget` timer state remains in the architecture section"**

Run: `awk '/^## Architecture/,/^## Data flow/' AGENTS.md | grep -n "setState\|StatefulWidget — all state lives here\|all state lives here"`
Expected: no matches.

- [ ] **Step 8: Verify "flutter analyze and flutter test still pass"**

See Task 7 (this is the code-change verification step, run there as a single atomic check).

---

### Task 4: Regenerate the project structure parity check (sanity, no edits)

**Files:**
- Run: `ls` commands

A final parity check that the doc's tree hasn't drifted from the filesystem between Task 2 and Task 7.

- [ ] **Step 1: Print the real tree**

```bash
ls lib lib/blocs lib/blocs/timer lib/blocs/logs lib/blocs/notes lib/data lib/data/services lib/domain lib/domain/models lib/domain/mappers lib/repositories lib/screens lib/widgets test test/blocs test/blocs/timer test/blocs/logs test/blocs/notes test/repositories test/domain test/screens
```

Compare against the `## Architecture` tree one more time. If any file appeared or disappeared since Task 2 Step 1 (e.g. someone committed a new BLoC in the interim), fix the doc.

(No file edit expected unless the repo changed under us.)

---

### Task 5: Commit the rewrite

**Files:**
- Commit: `AGENTS.md`

Documentation-only commit. Use the `caveman-commit` skill to draft the message, then use the temp-file pattern from the `core-commands` skill because the body needs to link the issue.

- [ ] **Step 1: Draft the commit message with caveman-commit**

Subject (≤50 chars): `docs(agents): rewrite for MVVM+bloc architecture`

Body (only the non-obvious *why*): the rewrite replaces a stale `StatefulWidget` + `setState` description with the real `flutter_bloc` + `AppDeps` wiring, the `Result<T>` boundary, and the `mocktail`/`bloc_test` test conventions. Closes #13.

Draft message:

```
docs(agents): rewrite for MVVM+bloc architecture

Replaces the stale StatefulWidget+setState walkthrough with the real
flutter_bloc + AppDeps wiring, the Result<T> error boundary, and the
mocktail/bloc_test testing conventions so onboarding matches the code.

Closes #13
```

- [ ] **Step 2: Save the message to a temp file**

```bash
mktemp
# Returns: /tmp/tmp.XXXXXX
```

Use the Write tool to save the message from Step 1 to that path. Keep the trailing newline.

- [ ] **Step 3: Stage the change with jj**

```bash
jj status
```

In `jj`, working-copy changes are already tracked — there is no "stage" step. Confirm `AGENTS.md` shows as modified.

- [ ] **Step 4: Apply the commit message**

```bash
jj describe --stdin < "/tmp/tmp.XXXXXX"
```

- [ ] **Step 5: Clean up the temp file**

```bash
rm "/tmp/tmp.XXXXXX"
```

Replace the path with the actual `mktemp` output.

- [ ] **Step 6: Confirm the commit**

```bash
jj status
```

Expected: working copy clean (no pending changes), the new change description matches the message.

---

### Task 6: Verify `flutter analyze` is unaffected

**Files:**
- Run: `flutter analyze`

This task only touches `AGENTS.md`, which is not part of the analyze target. The check is a sanity that nothing else moved.

- [ ] **Step 1: Run `flutter analyze`**

Run: `flutter analyze`
Expected: identical output to the baseline captured in `/tmp/vipo_baseline_analyze.txt` ("No issues found!" — or the same warning set as baseline if the baseline was non-clean).

- [ ] **Step 2: Compare to baseline**

```bash
diff /tmp/vipo_baseline_analyze.txt <(flutter analyze 2>&1) || true
```

Expected: empty diff (no change).

If the diff is non-empty, something besides `AGENTS.md` changed. Investigate before continuing — this task made no code edits, so any code-level diff is a problem.

---

### Task 7: Verify `flutter test` is unaffected

**Files:**
- Run: `flutter test`

- [ ] **Step 1: Run the full suite**

Run: `flutter test`
Expected: all tests pass with the *same* test count as the baseline captured in `/tmp/vipo_baseline_test.txt`.

- [ ] **Step 2: Compare to baseline (test count)**

```bash
grep -E "All tests passed!|tests passed" /tmp/vipo_baseline_test.txt
flutter test 2>&1 | grep -E "All tests passed!|tests passed"
```

The two numbers must match. A different test count means a test file was added/removed — not caused by this task, investigate before finishing.

---

### Task 8: Final acceptance-criteria sweep

**Files:**
- Read: `AGENTS.md`

A final self-check against every checkbox in issue #13 before declaring done.

- [ ] **Step 1: Re-run the issue's acceptance grep**

```bash
grep -n "MVVM\|flutter_bloc\|AppDeps\|MultiBlocProvider\|MultiRepositoryProvider\|Result<T>\|bloc_test\|mocktail\|openapi-generator\|equatable\|NotesScreen\|StatelessWidget\|StatefulWidget" AGENTS.md
```

Every term must appear at least once. Tally:
- `MVVM` ✅
- `flutter_bloc` ✅
- `AppDeps` ✅
- `MultiBlocProvider` ✅
- `MultiRepositoryProvider` ✅
- `Result<T>` ✅
- `bloc_test` ✅
- `mocktail` ✅
- `openapi-generator` (or `./tooling/generate_api.sh`) ✅
- `equatable` ✅
- `NotesScreen` documented accurately as `StatefulWidget` ✅
- `TimerScreen` documented accurately as `StatelessWidget` ✅

- [ ] **Step 2: No-stale-content grep**

```bash
grep -nE "setState|all state lives here|MyApp|Icons\.add|Stale test file|notification in initState|debug notification" AGENTS.md
```

Expected: no matches.

- [ ] **Step 3: Confirm the issue's 8 checkboxes**

Walk every box from issue #13 and confirm the section that satisfies it: 

- [x] `AGENTS.md` accurately reflects the new MVVM + flutter_bloc architecture. → Task 3 Step 1
- [x] Architecture diagram includes all new directories and files. → Task 3 Step 2
- [x] OpenAPI regeneration command is documented. → Task 3 Step 3
- [x] DI wiring (`di.dart`, `AppDeps`) is documented. → Task 3 Step 4
- [x] Testing conventions (mocktail, bloc_test, Result pattern) are documented. → Task 3 Step 5
- [x] Outdated gotchas are removed or updated (debug notification, stale test). → Task 3 Step 6
- [x] No reference to `setState` or `StatefulWidget` timer state remains in the architecture section. → Task 3 Step 7
- [x] `flutter analyze` and `flutter test` still pass. → Task 6 + Task 7

If any step is not actually green, go back and fix it. Do not mark the plan done with a box unchecked.

---

## Notes for the implementer

- The whole task is a single-file doc edit. Don't be tempted to "improve" `lib/` files while doing it — that turns a docs PR into a multi-concern PR and breaks Task 6/Task 7's "identical to baseline" guarantees.
- The issue body says `NotesScreen` is `StatelessWidget — BlocBuilder only`. The actual code is `StatefulWidget`. The doc must match the code, because acceptance criterion #1 says "accurately reflects". The self-review note in the **Current state audit** table above records this discrepancy — leave that note in the plan, not in `AGENTS.md` itself.
- Don't use the OpenAPI regeneration command verbatim from the issue (`openapi-generator-cli generate -i openapi.json ...`); that bypasses the import-rewrite + `build_runner` post-processing in `./tooling/generate_api.sh`. The doc points at the script.
- The `VipoApp` constructor takes `required this.deps` (`AppDeps deps`). The doc must mention that `main()` constructs `AppDeps` once (`runApp(VipoApp(deps: AppDeps()))`), because that's the entry point for the entire DI graph.
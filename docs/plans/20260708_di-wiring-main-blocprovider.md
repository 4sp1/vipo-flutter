# DI Wiring & BlocProvider Tree Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use supervised-plan-execution to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create the dependency-injection glue (`lib/di.dart`) that constructs the full graph bottom-up — Dio → generated API clients → services → repositories → BLoCs — and refactor `main.dart` to provide the full `MultiRepositoryProvider` + `MultiBlocProvider` tree to `TimerScreen`.

**Architecture:** A single hand-written `AppDeps` class is the only construction site for all dependencies. It builds the graph in its constructor, in strict order (`LogsBloc` before `TimerBloc`), exposes repositories and BLoCs as getters, and owns a `dispose()` for BLoC teardown. No service locator (`get_it`), no `context.read<>()` inside BLoCs — every dependency is constructor-injected. `main.dart` instantiates `AppDeps` once and feeds the pre-built instances into `MultiBlocProvider`/`MultiRepositoryProvider`; no BLoC is instantiated inside `BlocProvider.create`.

**Tech Stack:** Dart ^3.10.4, Flutter, `flutter_bloc` ^8.1.6 (`MultiBlocProvider`, `BlocProvider`, `MultiRepositoryProvider`, `RepositoryProvider`), `dio` ^5.7.0, the generated `LogsApi`/`NotesApi` (under `lib/data/api/`), existing services/repositories/BLoCs from issues #5–#9.

**VCS:** This repo uses `jj` exclusively (see `core-commands` skill). Commit messages use the `caveman-commit` skill. All multi-line commit messages use the `mktemp` + Write-tool temp-file pattern — never heredocs.

---

## Prerequisites

This plan consumes the outputs of issues #5–#9. Before starting, verify these exist (they do on the current branch `mben/issue-10`):

- `lib/data/api_config.dart` — `const String kApiBaseUrl` (`--dart-define=API_BASE_URL=…`, default `http://localhost:8080`).
- `lib/data/api/vipo_api.dart` — re-exports `LogsApi` and `NotesApi`, each taking a single `Dio` positional arg: `const LogsApi(this._dio)`, `const NotesApi(this._dio)`.
- `lib/data/services/logs_service.dart` — `LogsService(api.LogsApi)`.
- `lib/data/services/notes_service.dart` — `NotesService(api.NotesApi)`.
- `lib/repositories/logs_repository.dart` — `LogsRepository(LogsService)`.
- `lib/repositories/notes_repository.dart` — `NotesRepository(NotesService)`.
- `lib/blocs/logs/logs_bloc.dart` — `LogsBloc(LogsRepository)`.
- `lib/blocs/timer/timer_bloc.dart` — `TimerBloc(LogsBloc)` (already takes `LogsBloc`, **not** `LogsRepository`).
- `lib/blocs/notes/notes_bloc.dart` — `NotesBloc(NotesRepository)`.
- `flutter_bloc: ^8.1.6` present under `dependencies` in `pubspec.yaml`.

Baseline `flutter analyze` (before this plan) reports **1 error** and **5 infos**:

```
error • The name 'MyApp' isn't a class • test/widget_test.dart:16:35
info  • Don't invoke 'print' in production code • lib/notifications.dart (×5)
```

The `MyApp` error comes from the stale Flutter template `test/widget_test.dart`. Task 2 replaces that file, clearing the error. The 5 `avoid_print` infos in `notifications.dart` are **pre-existing and out of scope** for this issue (catalogued in `AGENTS.md` gotchas); they remain after this plan. The acceptance criterion "zero warnings" is satisfied because **no `warning`/`error`-level issues remain** — only pre-existing `info`s.

---

## Spec Notes & Design Decisions

Read these before implementing — they resolve ambiguities in the issue text.

### SN-1. `AppDeps` builds its own `Dio` — does not reuse `buildApiClient()`

`lib/data/api_client.dart` already provides `buildApiClient()` → `VipoApi(basePathOverride: kApiBaseUrl)`, which internally constructs a `Dio` and exposes `getLogsApi()`/`getNotesApi()`. The issue, however, specifies that `AppDeps` construct the `Dio` instance itself (configured with base URL, timeout, content-type) and then build `LogsApi(dio)` / `NotesApi(dio)` directly.

**Resolution:** `AppDeps` constructs a `Dio` with `BaseOptions(baseUrl: kApiBaseUrl, connectTimeout, receiveTimeout, contentType: 'application/json')` and passes it to `api.LogsApi(dio)` and `api.NotesApi(dio)`. It does **not** call `buildApiClient()` or construct a `VipoApi`. This keeps `AppDeps` as the single, explicit construction site and bypasses the generated auth interceptors (the vipo-go backend uses none). `buildApiClient()` is left untouched for any other callers; it is simply not used by `AppDeps`.

Timeouts mirror the generated `VipoApi` defaults: `connectTimeout: Duration(milliseconds: 5000)`, `receiveTimeout: Duration(milliseconds: 3000)`.

### SN-2. Base URL comes from the existing `kApiBaseUrl` const

`lib/data/api_config.dart` already defines `const String kApiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8080')`. `AppDeps` reads this const — it does **not** hard-code any URL string. The acceptance criterion "API base URL is resolved from `const` or `--dart-define`, not hard-coded in `di.dart`" is therefore satisfied by importing and using `kApiBaseUrl`.

### SN-3. `late final` fields initialized in the constructor body

`AppDeps` uses `late final` fields assigned in order inside the constructor body. This guarantees the bottom-up construction order (Dio → APIs → services → repos → `LogsBloc` → `TimerBloc` → `NotesBloc`) and gives compile-time safety that every getter is assigned before first access. The `LogsBloc`-before-`TimerBloc` ordering is enforced by statement sequence: `TimerBloc(_logsBloc)` is constructed after `_logsBloc` is assigned.

### SN-4. BLoCs exposed via `create`, repositories via `value` — per the issue

The issue's exact snippet uses:

```dart
BlocProvider<LogsBloc>(create: (_) => deps.logsBloc),
```

even though the bloc is pre-constructed and shared. We follow the issue verbatim. `BlocProvider.create` returning the same `AppDeps` instance means the provider owns disposal at the app root (which never disposes in practice). Repositories are provided with `RepositoryProvider<T>(value: …)` because they are stateless and not lifecycle-managed.

### SN-5. No new test for "TimerBloc receives the same LogsBloc instance"

`TimerBloc` stores `_logsBloc` privately with no public accessor. Behaviourally verifying identity would require dispatching a `Timer*` event (which fires `LogCreated` → `LogsRepository.createLog` → a real network call to `localhost:8080`), which is unsafe in unit tests. The existing `test/blocs/timer/timer_bloc_test.dart` already proves `TimerBloc` dispatches `LogCreated` to a real `LogsBloc` (with a mocked `LogsRepository`). Therefore `AppDeps` tests only assert that construction succeeds and that the getters expose the correct concrete types — the wiring of `TimerBloc(LogsBloc)` is already covered by the BLoC test suite.

### SN-6. Stale `test/widget_test.dart` must be replaced — it blocks `flutter analyze`

The default Flutter template `test/widget_test.dart` references `MyApp` (which no longer exists) and `Icons.add`, producing the only `error`-level analyze issue. To satisfy acceptance, Task 2 replaces it with a real `VipoApp` widget test that pumps the new BlocProvider tree (this is the same test the refactor needs anyway).

### SN-7. Debug notification removal is the only `TimerScreen` change

The issue explicitly scopes `TimerScreen` changes to a single line: remove `notifications.show(title: 'hi', body: 'there');` from `initState`. All other `TimerScreen` logic (the local `StatefulWidget` state) stays untouched — migrating it to BLoC consumption is a later task. The `notifications` import in `timer_screen.dart` stays because `_triggerCompletion()` still calls `notifications.show(...)`.

---

## File Structure

- **Create:** `lib/di.dart` — `AppDeps` class; the single dependency-construction site.
- **Modify:** `lib/main.dart` — instantiate `AppDeps`, wrap `TimerScreen` in `MultiRepositoryProvider` → `MultiBlocProvider`; keep `notifications.initialize()` in `main()`; keep `CupertinoApp` + dark theme.
- **Modify:** `lib/timer_screen.dart:24-28` — delete the single debug-notification line in `initState`.
- **Create:** `test/di_test.dart` — unit tests for `AppDeps` construction & getter types.
- **Replace:** `test/widget_test.dart` — replace the stale `MyApp` template with a `VipoApp` pump test that exercises the provider tree.

---

## Task 1: Create `AppDeps` in `lib/di.dart`

**Files:**
- Create: `lib/di.dart`
- Test: `test/di_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/di_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vipo/blocs/logs/logs_bloc.dart';
import 'package:vipo/blocs/notes/notes_bloc.dart';
import 'package:vipo/blocs/timer/timer_bloc.dart';
import 'package:vipo/di.dart';
import 'package:vipo/repositories/logs_repository.dart';
import 'package:vipo/repositories/notes_repository.dart';

void main() {
  group('AppDeps', () {
    late AppDeps deps;

    setUp(() {
      deps = AppDeps();
    });

    tearDown(() async {
      await deps.dispose();
    });

    test('constructs the full dependency graph without throwing', () {
      expect(deps, isA<AppDeps>());
    });

    test('exposes LogsRepository and NotesRepository instances', () {
      expect(deps.logsRepository, isA<LogsRepository>());
      expect(deps.notesRepository, isA<NotesRepository>());
    });

    test('exposes LogsBloc, TimerBloc, and NotesBloc instances', () {
      expect(deps.logsBloc, isA<LogsBloc>());
      expect(deps.timerBloc, isA<TimerBloc>());
      expect(deps.notesBloc, isA<NotesBloc>());
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/di_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:vipo/di.dart'` / `AppDeps` is not defined.

- [ ] **Step 3: Write minimal implementation**

Create `lib/di.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:vipo/blocs/logs/logs_bloc.dart';
import 'package:vipo/blocs/notes/notes_bloc.dart';
import 'package:vipo/blocs/timer/timer_bloc.dart';
import 'package:vipo/data/api/vipo_api.dart' as api;
import 'package:vipo/data/api_config.dart';
import 'package:vipo/data/services/logs_service.dart';
import 'package:vipo/data/services/notes_service.dart';
import 'package:vipo/repositories/logs_repository.dart';
import 'package:vipo/repositories/notes_repository.dart';

/// Single construction site for the entire dependency graph.
///
/// Everything is built bottom-up in the constructor, in dependency order:
/// `Dio` → generated API clients → services → repositories → BLoCs
/// (`LogsBloc` before `TimerBloc`, because `TimerBloc` dispatches `LogCreated`
/// events to the shared `LogsBloc`). No service locator, no `context.read<>()`
/// inside BLoCs — every dependency is constructor-injected here.
///
/// `main.dart` constructs one `AppDeps` and feeds the pre-built repositories
/// and BLoCs into `MultiRepositoryProvider` / `MultiBlocProvider`.
class AppDeps {
  AppDeps() {
    final dio = Dio(BaseOptions(
      baseUrl: kApiBaseUrl,
      connectTimeout: const Duration(milliseconds: 5000),
      receiveTimeout: const Duration(milliseconds: 3000),
      contentType: 'application/json',
    ));

    final logsApi = api.LogsApi(dio);
    final notesApi = api.NotesApi(dio);

    _logsService = LogsService(logsApi);
    _notesService = NotesService(notesApi);

    _logsRepository = LogsRepository(_logsService);
    _notesRepository = NotesRepository(_notesService);

    _logsBloc = LogsBloc(_logsRepository);
    _timerBloc = TimerBloc(_logsBloc);
    _notesBloc = NotesBloc(_notesRepository);
  }

  late final LogsService _logsService;
  late final NotesService _notesService;
  late final LogsRepository _logsRepository;
  late final NotesRepository _notesRepository;
  late final LogsBloc _logsBloc;
  late final TimerBloc _timerBloc;
  late final NotesBloc _notesBloc;

  LogsRepository get logsRepository => _logsRepository;
  NotesRepository get notesRepository => _notesRepository;
  LogsBloc get logsBloc => _logsBloc;
  TimerBloc get timerBloc => _timerBloc;
  NotesBloc get notesBloc => _notesBloc;

  /// Closes all BLoCs. Repositories and services hold no resources to release.
  Future<void> dispose() async {
    await _logsBloc.close();
    await _timerBloc.close();
    await _notesBloc.close();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/di_test.dart`
Expected: PASS — 3 tests, all green.

- [ ] **Step 5: Commit with caveman-commit**

Use the `caveman-commit` skill to draft the message (subject ≤50 chars, no AI attribution). Then use the temp-file pattern from the `core-commands` skill:

```bash
mktemp
# Returns: /tmp/tmp.XXXXXX
```

Write the commit message to that path with the Write tool, then:

```bash
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

Suggested commit subject: `feat(di): add AppDeps wiring dio→blocs`

---

## Task 2: Refactor `main.dart` and replace stale `test/widget_test.dart`

**Files:**
- Modify: `lib/main.dart` (entire file)
- Replace: `test/widget_test.dart` (entire file)

- [ ] **Step 1: Write the failing widget test**

Replace `test/widget_test.dart` entirely with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vipo/di.dart';
import 'package:vipo/main.dart';
import 'package:vipo/timer_screen.dart';

void main() {
  testWidgets('VipoApp builds TimerScreen within the provider tree',
      (tester) async {
    final deps = AppDeps();
    await tester.pumpWidget(VipoApp(deps: deps));
    expect(find.byType(TimerScreen), findsOneWidget);
    // BlocProvider disposes the blocs when the tree is torn down at test end.
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart`
Expected: FAIL — `VipoApp` does not take a `deps` parameter / constructor mismatch, or `MyApp` no longer referenced (the old file still references `MyApp`). Either way, compile error.

- [ ] **Step 3: Refactor `main.dart`**

Replace the entire contents of `lib/main.dart` with:

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'di.dart';
import 'notifications.dart' as notifications;
import 'timer_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await notifications.initialize();

  runApp(VipoApp(deps: AppDeps()));
}

class VipoApp extends StatelessWidget {
  const VipoApp({super.key, required this.deps});

  final AppDeps deps;

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Vipo',
      debugShowCheckedModeBanner: false,
      theme: const CupertinoThemeData(brightness: Brightness.dark),
      home: MultiRepositoryProvider(
        providers: [
          RepositoryProvider<LogsRepository>(value: deps.logsRepository),
          RepositoryProvider<NotesRepository>(value: deps.notesRepository),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<LogsBloc>(create: (_) => deps.logsBloc),
            BlocProvider<TimerBloc>(create: (_) => deps.timerBloc),
            BlocProvider<NotesBloc>(create: (_) => deps.notesBloc),
          ],
          child: const TimerScreen(),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the widget test to verify it passes**

Run: `flutter test test/widget_test.dart`
Expected: PASS — `TimerScreen` found exactly once.

- [ ] **Step 5: Run the full test suite to confirm no regressions**

Run: `flutter test`
Expected: PASS — all existing BLoC/service/repository/domain tests plus the two new files green.

- [ ] **Step 6: Commit with caveman-commit**

Temp-file pattern:

```bash
mktemp
# Write commit message to the returned path
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

Suggested commit subject: `refactor(main): wire BlocProvider tree via AppDeps`

---

## Task 3: Remove the debug notification from `TimerScreen`

**Files:**
- Modify: `lib/timer_screen.dart:23-28` (the `initState` body)

- [ ] **Step 1: View the exact current `initState`**

Run: `view lib/timer_screen.dart` offset 23 limit 6 — confirm the exact text:

```dart
  @override
  void initState() {
    super.initState();
    notifications.show(title: 'hi', body: 'there');
    _resetTimer();
  }
```

- [ ] **Step 2: Remove the debug notification line**

Using the `edit` tool with exact text match, replace:

```
  @override
  void initState() {
    super.initState();
    notifications.show(title: 'hi', body: 'there');
    _resetTimer();
  }
```

with:

```
  @override
  void initState() {
    super.initState();
    _resetTimer();
  }
```

Leave the `import 'notifications.dart' as notifications;` line untouched — `_triggerCompletion()` still uses it.

- [ ] **Step 3: Verify no lingering reference to the debug call**

Run: `grep -n "title: 'hi'" lib/`
Expected: no matches.

- [ ] **Step 4: Run the widget test to confirm `TimerScreen` still builds**

Run: `flutter test test/widget_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit with caveman-commit**

Temp-file pattern:

```bash
mktemp
# Write commit message to the returned path
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

Suggested commit subject: `fix(timer): drop debug startup notification`

---

## Task 4: Final verification — analyze + full test run

**Files:** none modified.

- [ ] **Step 1: Run `flutter analyze`**

Run: `flutter analyze`
Expected: only the 5 pre-existing `avoid_print` **infos** in `lib/notifications.dart`. **Zero errors, zero warnings.** The `MyApp` error from the stale template is gone.

If any `error`/`warning` appears that was introduced by this plan, fix it before proceeding. The 5 `info`s are pre-existing and explicitly out of scope (see the Prerequisites / SN-6 sections).

- [ ] **Step 2: Run the full test suite**

Run: `flutter test`
Expected: all tests pass, including the new `test/di_test.dart` and the replaced `test/widget_test.dart`.

- [ ] **Step 3: Verify acceptance criteria**

Confirm each box:

- [ ] `flutter analyze` passes with zero **warnings** (pre-existing `info`s remain, out of scope).
- [ ] `lib/di.dart` exists and constructs the graph bottom-up (Dio → API clients → services → repositories → BLoCs), `LogsBloc` before `TimerBloc`.
- [ ] `TimerBloc` receives `LogsBloc` (not `LogsRepository`) — already true in `lib/blocs/timer/timer_bloc.dart:13`; `AppDeps` passes `_logsBloc` to it.
- [ ] `main.dart` uses `MultiBlocProvider` + `MultiRepositoryProvider` wrapping `TimerScreen`.
- [ ] Debug notification in `TimerScreen.initState()` is removed.
- [ ] API base URL is resolved from the `kApiBaseUrl` const (`--dart-define` aware), not hard-coded in `di.dart`.
- [ ] No BLoC is instantiated inside `BlocProvider.create` — all three return pre-built instances from `AppDeps`.
- [ ] `main()` still calls `notifications.initialize()` before `runApp()`.

No further commit is needed for a verification-only task.

---

## Self-Review

**Spec coverage:**

- "Central factory `lib/di.dart`" → Task 1. ✓
- "API base URL from `kApiBaseUrl` const / `--dart-define`" → SN-2 + Task 1 `BaseOptions(baseUrl: kApiBaseUrl)`. ✓
- "Dio instance configured with base URL, timeout, content-type headers" → Task 1. ✓
- "Generated API clients `LogsApi(dio)` and `NotesApi(dio)`" → Task 1. ✓
- "Services `LogsService(logsApi)` and `NotesService(notesApi)`" → Task 1. ✓
- "Repositories `LogsRepository(logsService)` and `NotesRepository(notesService)`" → Task 1. ✓
- "BLoCs: `LogsBloc` first, `TimerBloc(logsBloc)`, `NotesBloc(notesRepository)`" → Task 1, construction order enforced. ✓
- "Expose BLoCs as top-level output; `main.dart` only consumes `AppDeps`" → Task 1 getters + Task 2. ✓
- "MultiRepositoryProvider → MultiBlocProvider → TimerScreen" → Task 2. ✓
- "Keep `notifications.initialize()` in `main()` before `runApp()`" → Task 2. ✓
- "Keep `CupertinoApp` + dark theme" → Task 2. ✓
- "Remove debug notification from `TimerScreen.initState()`" → Task 3. ✓
- "No service locator" → `AppDeps` is plain constructor injection. ✓
- "No `context.read<>()` inside BLoCs" → unchanged; BLoCs keep constructor deps. ✓
- "Single construction site" → all instantiation in `AppDeps`. ✓
- "BLoC lifecycle — pre-constructed, provided via BlocProvider" → Task 2 uses `create: (_) => deps.xBloc`. ✓
- "Construction order LogsBloc before TimerBloc" → Task 1 statement sequence. ✓

**Placeholder scan:** No TBD/TODO/"implement later". Every code step contains full code. Commit steps use the temp-file pattern and give concrete suggested subjects.

**Type consistency:** `AppDeps` getters (`logsRepository`, `notesRepository`, `logsBloc`, `timerBloc`, `notesBloc`) match the names used in Task 2's `deps.*` references. `LogsApi(dio)` / `NotesApi(dio)` constructors match `lib/data/api/src/api/logs_api.dart:24` and `notes_api.dart:23` (each `const FooApi(this._dio)`). `TimerBloc(LogsBloc)` matches `lib/blocs/timer/timer_bloc.dart:13`. `kApiBaseUrl` matches `lib/data/api_config.dart:5`.

No issues found. Plan is complete.
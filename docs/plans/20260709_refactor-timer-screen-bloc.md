# Refactor TimerScreen from StatefulWidget setState to BlocBuilder/BlocListener Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use supervised-plan-execution to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace all `setState` calls and local `StatefulWidget` state in `TimerScreen` with `BlocBuilder`, `BlocListener`, and `BlocSelector` consuming `TimerBloc`, turning the screen into a pure view (layout + animation references + event dispatching, zero business logic).

**Architecture:** `TimerScreen` becomes a `StatelessWidget`. It reads timer state from the already-provided `BlocProvider<TimerBloc>` (wired in `main.dart` via `AppDeps`, issue #10). `BlocBuilder<TimerBloc, TimerState>` drives the `DonutTimer` presentational props; `BlocSelector<TimerBloc, TimerState, TimerMode>` selects the current mode for `ModeSwitch`; `BlocListener<TimerBloc, TimerState>` fires the existing `notifications.dart` + `vibration` side effects exactly once on the transition to `TimerComplete`. User interactions dispatch `TimerStarted` / `TimerPaused` / `TimerResumed` / `TimerReset` / `TimerModeChanged` events via `context.read<TimerBloc>()` inside callbacks only. `DonutTimer` and `ModeSwitch` files stay byte-for-byte unchanged. The screen file moves to `lib/screens/timer_screen.dart` to match the issue's stated acceptance boundary.

**Tech Stack:** Dart ^3.10.4, Flutter, `flutter_bloc` ^8.1.6 (`BlocBuilder`, `BlocListener`, `BlocSelector`, `BlocProvider`, `context.read`), `equatable` ^2.0.5, `vibration` ^3.1.8, `flutter_local_notifications` ^21.0.0, existing `TimerBloc`/`TimerState`/`TimerEvent` from issue #9, `mocktail` ^1.0.4 (dev, for widget tests).

**VCS:** This repo uses `jj` exclusively (see `core-commands` skill). Commit messages use the `caveman-commit` skill. All multi-line commit messages use the `mktemp` + Write-tool temp-file pattern — never heredocs.

---

## Prerequisites

This plan consumes the outputs of issues #5–#10. Before starting, verify these exist on the current branch:

- `lib/blocs/timer/timer_bloc.dart` — `TimerBloc(LogsBloc)`, handles `TimerStarted`/`TimerPaused`/`TimerResumed`/`TimerReset`/`TimerTicked`/`TimerModeChanged`/`TimerCompleted`.
- `lib/blocs/timer/timer_state.dart` — `TimerState` abstract class with `TimerMode get mode`, and subclasses `TimerInitial(mode, duration)`, `TimerRunInProgress(mode, remainingSeconds)`, `TimerPaused(mode, remainingSeconds)`, `TimerComplete(mode)`.
- `lib/blocs/timer/timer_event.dart` — `TimerStarted(mode)`, `TimerPaused()`, `TimerResumed()`, `TimerReset()`, `TimerTicked(remainingSeconds)`, `TimerModeChanged(mode)`, `TimerCompleted()`.
- `lib/di.dart` — `AppDeps` builds `TimerBloc(_logsBloc)`.
- `lib/main.dart` — `VipoApp` wraps `TimerScreen` in `MultiRepositoryProvider` → `MultiBlocProvider` (provides `TimerBloc`, `LogsBloc`, `NotesBloc`).
- `lib/widgets/donut_timer.dart` — `DonutTimer({remainingSeconds, totalSeconds, color, onTap, onLongPress, isRunning})`, computes its own `progress` and hint text internally.
- `lib/widgets/mode_switch.dart` — `ModeSwitch({currentMode, onModeChanged})`.
- `lib/notifications.dart` — `initialize()` and `show({title, body})`.
- `lib/domain/models/timer_mode.dart` — `TimerMode` enum with `duration`, `label`, `color` (`CupertinoDynamicColor`).
- `mocktail: ^1.0.4`, `bloc_test: ^9.1.7` present under `dev_dependencies`.
- `flutter analyze` baseline: only 5 pre-existing `avoid_print` **infos** in `lib/notifications.dart`, zero warnings/errors (confirmed).

If any are missing, stop and run the prerequisite plans first.

---

## Spec Notes & Design Decisions

Read these before implementing — they resolve ambiguities and conflicts between the issue text and the actual codebase.

### SN-1. `DonutTimer` is UNCHANGED — feed its existing constructor, not `progress`/`hintText`

The issue body lists "`DonutTimer` receives `progress`, `remainingSeconds`, `hintText`, `onTap`, `onLongPress` from `BlocBuilder` output." However, the issue also states (and the acceptance criteria require) that `DonutTimer` and `ModeSwitch` widget files stay **unchanged from their current implementations**.

The real `lib/widgets/donut_timer.dart` does **not** take `progress` or `hintText` parameters. It accepts exactly:

```dart
const DonutTimer({
  required this.remainingSeconds,
  required this.totalSeconds,
  required this.color,
  required this.onTap,
  required this.onLongPress,
  this.isRunning = false,
});
```

It computes `progress = totalSeconds > 0 ? remainingSeconds / totalSeconds : 0.0` internally (`donut_timer.dart:31`) and derives the hint text ("tap to start" / "tap to pause" / "tap to resume") from `isRunning` and `remainingSeconds < totalSeconds` internally (`donut_timer.dart:64-87`).

**Resolution:** `BlocBuilder<TimerBloc, TimerState>` maps `TimerState` → the **existing** `DonutTimer` constructor params, never to the issue's hypothetical `progress`/`hintText`:

| `DonutTimer` param | Source from `TimerState` |
|--------------------|--------------------------|
| `remainingSeconds` | `TimerInitial.duration` \| `TimerRunInProgress.remainingSeconds` \| `TimerPaused.remainingSeconds` \| `TimerComplete` → `0` |
| `totalSeconds` | `state.mode.duration.inSeconds` |
| `color` | `CupertinoDynamicColor.resolve(state.mode.color, context)` (resolved inside `builder`, where `context` is available) |
| `isRunning` | `state is TimerRunInProgress` |
| `onTap` | dispatch mapped by current state (SN-4) |
| `onLongPress` | dispatch `TimerReset` |

This keeps `DonutTimer` byte-for-byte unchanged while satisfying the intent (the `BlocBuilder` output drives the donut).

### SN-2. `TimerMode` resolution needs `context` → color resolution happens inside `builder`

`TimerMode.color` is a `CupertinoDynamicColor`, which must be resolved against an ambient `BuildContext`/`Brightness` via `CupertinoDynamicColor.resolve(color, context)`. This requires a `context` that participates in the widget tree (the ambient `CupertinoApp` dark theme). `BlocBuilder.builder(context, state)` provides exactly that `context`. Therefore `color` is resolved **inside** the `builder` callback, not as a top-level `BlocSelector`. The `isRunning` flag and `remainingSeconds` are also derived inside `builder`. Only the **mode** (a plain enum, no `context` needed) is extracted via `BlocSelector` for `ModeSwitch`.

### SN-3. `TimerState` vs `TimerEvent` name collision — import states with the `st` prefix

Both `timer_state.dart` and `timer_event.dart` export a class named `TimerPaused` (a state and an event). When `timer_screen.dart` imports both, Dart reports a name clash. This is the same situation already resolved in `timer_bloc.dart` (see the issue #9 plan's SN-1).

**Resolution:** Import `timer_state.dart` with the prefix `st`; import `timer_event.dart` un-prefixed. So:

- `BlocBuilder<TimerBloc, st.TimerState>`
- `BlocListener<TimerBloc, st.TimerState>`
- `BlocSelector<TimerBloc, st.TimerState, TimerMode>`
- Exhaustive `switch (state)` patterns use `st.TimerInitial()`, `st.TimerRunInProgress()`, `st.TimerPaused()`, `st.TimerComplete()`
- Events dispatched un-prefixed: `TimerStarted(mode)`, `TimerPaused()`, `TimerResumed()`, `TimerReset()`, `TimerModeChanged(mode)`

Widget tests use the same convention.

### SN-4. Tap mapping — one `onTap` handles all four states

The old `_toggleTimer()` branched on `_isComplete` and `_isRunning`. In the bloc world, the same branching moves into the `onTap` callback but **dispatches events** instead of mutating state. The mapping, based on the `TimerBloc`'s current state at tap time:

| Current `TimerState` | `onTap` dispatches |
|----------------------|--------------------|
| `TimerInitial` | `TimerStarted(state.mode)` |
| `TimerRunInProgress` | `TimerPaused()` |
| `TimerPaused` | `TimerResumed()` |
| `TimerComplete` | `TimerReset()` |

The callback reads the **current** state via `context.read<TimerBloc>().state` (a `context.read` call inside a callback — permitted; `context.read` is NOT called during `build`). `onLongPress` always dispatches `TimerReset()`.

### SN-5. `StatelessWidget`, not `StatefulWidget` — no `TickerProvider` needed

`DonutTimer` uses `flutter_animate`'s `.animate()` extension, which is an **implicit** animation wrapper (runs its own ticker internally); it does not require the parent to be a `TickerProvider`. The `CustomPaint` repaint is driven by `_DonutPainter.shouldRepaint`, not by an `AnimationController` in `TimerScreen`. No `SingleTickerProviderStateMixin` / `TickerProvider` is referenced anywhere in the current `TimerScreen`.

**Resolution:** `TimerScreen` becomes a `StatelessWidget` (matches the issue's primary preference). No `initState`/`dispose`/`Ticker` remains. This is the cleanest outcome and satisfies the acceptance criterion ("StatelessWidget, or StatefulWidget only if TickerProvider is required — justify in a comment if kept").

### SN-6. Side effects (vibration + notification) live in `BlocListener`, fired once per completion

The issue is explicit: vibration and local notification happen in `BlocListener` when `TimerComplete` is emitted, **not** inside `TimerBloc` (BLoCs must not import platform packages — issue #9 design rule). The old `_triggerCompletion()` logic moves verbatim into the `BlocListener` `listener` callback:

```dart
final mode = state.mode;
if (await Vibration.hasVibrator()) {
  Vibration.vibrate(duration: 500);
}
await notifications.show(
  title: '${mode.label} Complete',
  body: 'Time for ${mode == TimerMode.work ? 'a break' : 'work'}!',
);
```

To guarantee the side effect fires **exactly once** per completion (and not on every rebuild or re-emit of an equal `TimerComplete` state), gate it with `listenWhen`:

```dart
listenWhen: (previous, current) =>
    current is st.TimerComplete && previous is! st.TimerComplete,
```

`flutter_bloc` already dedupes equal equatable states, but this guard makes the intent unambiguous and safe against any future re-emission. `notifications` (id `0`) replaces the previous notification, matching the existing single-id behavior.

### SN-7. Move `timer_screen.dart` → `lib/screens/timer_screen.dart`

The issue's final acceptance criterion reads "No file in `lib/screens/` imports from `lib/data/` or `lib/repositories/`." The current screen lives at `lib/timer_screen.dart` (root of `lib/`); there is no `lib/screens/` directory yet. The criterion clearly assumes a `lib/screens/` home for screen files.

**Resolution:** Create the refactored screen at `lib/screens/timer_screen.dart` and delete the old `lib/timer_screen.dart`. Update the two importers found in the codebase (`grep timer_screen`):

- `lib/main.dart:10` — `import 'package:vipo/timer_screen.dart';` → `import 'package:vipo/screens/timer_screen.dart';`
- `test/widget_test.dart:4` — same change.

(`docs/plans/*.md` mention the old path in prose only — they are immutable historical docs and are not edited.)

This also aligns the project with the conventional `lib/screens/` + `lib/widgets/` split already used for widgets.

### SN-8. Widget tests use the real `TimerBloc` + a `MockLogsRepository` (no `FakeTimerBloc`)

`TimerScreen` looks up `TimerBloc` via `BlocProvider<TimerBloc>` and `context.read<TimerBloc>()`. A fake Bloc typed as a *different* class would not be found by `BlocProvider<TimerBloc>` / `BlocBuilder<TimerBloc, …>`. Constructing `TimerBloc` directly is trivial — it takes a `LogsBloc`, which takes a `LogsRepository`. We provide a `MockLogsRepository` (mocktail) whose `createLog` returns a `Result.success(...)` (same pattern as `test/blocs/timer/timer_bloc_test.dart:14-36`). Provide it via `BlocProvider<TimerBloc>.value(value: bloc)` and a bare `CupertinoApp` parent (no `AppDeps`, no real `Dio`, no network).

**Why the periodic ticker is safe in tests:** `TimerBloc._startTicker` uses `Stream.periodic(1s).take(n)`. These timers only fire when the test clock advances to 1000 ms via `pump(duration)` / `pumpAndSettle`. `flutter_animate` finishes in ~300 ms, so `await tester.pumpAndSettle()` returns after the animation settles — **before** the first 1000 ms tick — and the periodic stream timer is left pending (it does not schedule a frame, so `pumpAndSettle` does not advance to it). Asserting `bloc.state` immediately after a tap therefore sees `TimerRunInProgress` with the *full* duration remaining, with no tick. `bloc.close()` in `tearDown` cancels the subscription, so no stray timers leak between tests.

**Why `BlocListener` side effects don't fire in widget tests:** all widget tests operate in `TimerInitial` / `TimerRunInProgress` / mode-changed states. The `BlocListener.listenWhen` returns `false` unless the *new* state is `TimerComplete`, so `Vibration.hasVibrator()` / `notifications.show()` are never called in the test harness — avoiding `MissingPluginException` from the `vibration` plugin and real notification dispatch in the headless test environment. Seeding `TimerComplete` would require either dispatching a full countdown (impractical) or using bloc internals (private `emit`), so the `TimerComplete` → vibration/notification side-effect path is verified by **code inspection** plus the existing `TimerBloc` bloc test (`TimerTicked(0)` → `TimerComplete`, `timer_bloc_test.dart:80-97`), and is exercised on-device manually. This is documented in Task 2's final step.

### SN-9. Scope of BLoC consumption — only `TimerBloc` is read by `TimerScreen` today

The issue header mentions consuming `TimerBloc`, `LogsBloc`, and `NotesBloc`. However `TimerScreen` currently renders only the timer donut + mode switch — there is no logs or notes UI yet (such screens are future issues). `LogsBloc` and `NotesBloc` remain **provided** in the `MultiBlocProvider` tree from issue #10 (unchanged), but `TimerScreen` does not read them. Forcing a cosmetic `BlocBuilder<LogsBloc>/<NotesBloc>` with no UI to render would violate YAGNI.

**Resolution:** This plan wires `TimerBloc` consumption only (`BlocBuilder`/`BlocSelector`/`BlocListener`). The acceptance criteria likewise reference only `TimerBloc`. `LogsBloc`/`NotesBloc` stay provided (issue #10) for the future logs/notes screens.

### SN-10. Import hygiene — no `lib/data/` or `lib/repositories/` from the screen

`lib/screens/timer_screen.dart` imports only: `package:flutter/cupertino.dart`, `package:flutter_bloc/flutter_bloc.dart`, `package:vibration/vibration.dart`, the `TimerBloc`/event/state files, `domain/models/timer_mode.dart`, `widgets/donut_timer.dart`, `widgets/mode_switch.dart`, and `notifications.dart`. It does **not** import `lib/data/` or `lib/repositories/`, satisfying the boundary acceptance criterion. Vibration and notifications are platform-side-effect packages used only in `BlocListener` (UI layer), never in BLoCs — consistent with issue #9's rule.

---

## File Structure

**Create:**

| File | Responsibility |
|------|----------------|
| `lib/screens/timer_screen.dart` | New `TimerScreen` as a `StatelessWidget`: `BlocListener` (side effects on `TimerComplete`) wrapping a `CupertinoPageScaffold`; `BlocBuilder<TimerBloc, TimerState>` driving `DonutTimer`; `BlocSelector<TimerBloc, TimerState, TimerMode>` driving `ModeSwitch`; callbacks dispatch events via `context.read<TimerBloc>()`. |
| `test/screens/timer_screen_test.dart` | Widget tests: renders initial 20:00 + "tap to start"; tap dispatches `TimerStarted`; mode change dispatches `TimerModeChanged`. Uses real `TimerBloc` + `MockLogsRepository` via `BlocProvider.value`. |

**Delete:**

- `lib/timer_screen.dart` — replaced by `lib/screens/timer_screen.dart` (SN-7).

**Modify:**

- `lib/main.dart:10` — repoint import to `package:vipo/screens/timer_screen.dart`.
- `test/widget_test.dart:4` — repoint import to `package:vipo/screens/timer_screen.dart`.

**Out of scope (explicitly deferred):** logs/notes UI screens (future issues), replacing `print()` in `notifications.dart` (pre-existing `info`s, catalogued in `AGENTS.md`), dependency-injection of `vibration`/`flutter_local_notifications` to make side effects unit-testable, any change to `BellutTimer`/`ModeSwitch`/BLoC/repository/domain files.

---

## Task 1: Write failing widget tests for the refactored `TimerScreen`

**Files:**
- Create: `test/screens/timer_screen_test.dart`

- [ ] **Step 1: Create the failing widget test**

Create `test/screens/timer_screen_test.dart`:

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vipo/blocs/logs/logs_bloc.dart';
import 'package:vipo/blocs/timer/timer_bloc.dart';
import 'package:vipo/blocs/timer/timer_state.dart' as st;
import 'package:vipo/domain/models/log_entry.dart';
import 'package:vipo/domain/models/timer_mode.dart';
import 'package:vipo/domain/result.dart';
import 'package:vipo/repositories/logs_repository.dart';
import 'package:vipo/screens/timer_screen.dart';
import 'package:vipo/widgets/donut_timer.dart';

class MockLogsRepository extends Mock implements LogsRepository {}

void main() {
  late MockLogsRepository mockLogsRepository;
  late LogsBloc logsBloc;
  late TimerBloc timerBloc;

  final fallbackEntry = LogEntry(
    id: '1',
    pomodoroState: TimerMode.work,
    action: LogAction.start,
    createdAt: DateTime(2025, 1, 1),
  );

  setUpAll(() {
    registerFallbackValue(fallbackEntry);
  });

  setUp(() {
    mockLogsRepository = MockLogsRepository();
    when(() => mockLogsRepository.createLog(any()))
        .thenAnswer((_) async => Result.success(fallbackEntry));
    logsBloc = LogsBloc(mockLogsRepository);
    timerBloc = TimerBloc(logsBloc);
  });

  tearDown(() async {
    await timerBloc.close();
    await logsBloc.close();
  });

  Widget _pumpSubject() {
    return CupertinoApp(
      home: BlocProvider<TimerBloc>.value(
        value: timerBloc,
        child: const TimerScreen(),
      ),
    );
  }

  testWidgets('renders initial work countdown 20:00 and tap-to-start hint',
      (tester) async {
    await tester.pumpWidget(_pumpSubject());
    await tester.pumpAndSettle();

    expect(find.text('20:00'), findsOneWidget);
    expect(find.text('tap to start'), findsOneWidget);
    expect(find.byType(DonutTimer), findsOneWidget);
  });

  testWidgets(
      'tapping the donut in the initial state dispatches TimerStarted '
      'and the bloc emits TimerRunInProgress', (tester) async {
    await tester.pumpWidget(_pumpSubject());
    await tester.pumpAndSettle();

    expect(timerBloc.state, isA<st.TimerInitial>());

    await tester.tap(find.byType(DonutTimer));
    await tester.pumpAndSettle();

    expect(timerBloc.state, isA<st.TimerRunInProgress>());
    expect(
      (timerBloc.state as st.TimerRunInProgress).mode,
      TimerMode.work,
    );
  });

  testWidgets('selecting Short Break dispatches TimerModeChanged '
      'and the bloc emits TimerInitial(shortBreak)', (tester) async {
    await tester.pumpWidget(_pumpSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Short Break'));
    await tester.pumpAndSettle();

    expect(timerBloc.state, isA<st.TimerInitial>());
    expect(
      (timerBloc.state as st.TimerInitial).mode,
      TimerMode.shortBreak,
    );
    expect(find.text('05:00'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/screens/timer_screen_test.dart`
Expected: FAIL — compile error: `Target of URI doesn't exist: 'package:vipo/screens/timer_screen.dart'` (the new screen path does not exist yet) and `TimerScreen` not defined. This confirms the test is red before the implementation exists.

- [ ] **Step 3: Commit (red) with caveman-commit**

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

Suggested commit subject: `test(timer): add failing TimerScreen bloc tests`

---

## Task 2: Create the refactored `TimerScreen` at `lib/screens/timer_screen.dart`

**Files:**
- Create: `lib/screens/timer_screen.dart`
- Delete: `lib/timer_screen.dart` (after importers are repointed in Task 3)
- Modify: `lib/main.dart:10`
- Modify: `test/widget_test.dart:4`

> **Note:** This task creates the new file, and repoints the importers so the old root-level `lib/timer_screen.dart` can be deleted. The deletion of the old file is the last step of this task (it must stay until importers are repointed, otherwise the tree won't compile in between).

- [ ] **Step 1: Create `lib/screens/timer_screen.dart`**

Create the file with the full refactored implementation:

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vibration/vibration.dart';
import 'package:vipo/blocs/timer/timer_bloc.dart';
import 'package:vipo/blocs/timer/timer_event.dart';
import 'package:vipo/blocs/timer/timer_state.dart' as st;
import 'package:vipo/domain/models/timer_mode.dart';
import 'package:vipo/notifications.dart' as notifications;
import 'package:vipo/widgets/donut_timer.dart';
import 'package:vipo/widgets/mode_switch.dart';

/// Pure view for the pomodoro timer.
///
/// Owns no state. Reads timer state from the ambient [TimerBloc] (provided in
/// `main.dart` via [AppDeps]) and dispatches user interactions back to it.
/// - [BlocBuilder] drives [DonutTimer]'s presentational props.
/// - [BlocSelector] selects the current [TimerMode] for [ModeSwitch].
/// - [BlocListener] fires vibration + local notification once on
///   [st.TimerComplete] (platform side effects live in the UI layer; BLoCs
///   never import platform packages — issue #9).
///
/// [StatelessWidget] is sufficient: [DonutTimer]'s animation is an implicit
/// `flutter_animate` wrapper that owns its ticker, so no [TickerProvider] is
/// required here.
class TimerScreen extends StatelessWidget {
  const TimerScreen({super.key});

  int _remainingSeconds(st.TimerState state) {
    return switch (state) {
      st.TimerInitial(:final duration) => duration,
      st.TimerRunInProgress(:final remainingSeconds) => remainingSeconds,
      st.TimerPaused(:final remainingSeconds) => remainingSeconds,
      st.TimerComplete() => 0,
    };
  }

  void _onDonutTap(BuildContext context) {
    final bloc = context.read<TimerBloc>();
    switch (bloc.state) {
      case st.TimerInitial():
        bloc.add(TimerStarted(bloc.state.mode));
      case st.TimerRunInProgress():
        bloc.add(TimerPaused());
      case st.TimerPaused():
        bloc.add(TimerResumed());
      case st.TimerComplete():
        bloc.add(TimerReset());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TimerBloc, st.TimerState>(
      listenWhen: (previous, current) =>
          current is st.TimerComplete && previous is! st.TimerComplete,
      listener: (context, state) async {
        final mode = state.mode;
        if (await Vibration.hasVibrator()) {
          Vibration.vibrate(duration: 500);
        }
        await notifications.show(
          title: '${mode.label} Complete',
          body: 'Time for ${mode == TimerMode.work ? 'a break' : 'work'}!',
        );
      },
      child: CupertinoPageScaffold(
        backgroundColor: CupertinoColors.systemBackground,
        child: SafeArea(
          child: SizedBox.expand(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(),
                BlocBuilder<TimerBloc, st.TimerState>(
                  builder: (context, state) {
                    return DonutTimer(
                      remainingSeconds: _remainingSeconds(state),
                      totalSeconds: state.mode.duration.inSeconds,
                      color:
                          CupertinoDynamicColor.resolve(state.mode.color, context),
                      onTap: () => _onDonutTap(context),
                      onLongPress: () =>
                          context.read<TimerBloc>().add(TimerReset()),
                      isRunning: state is st.TimerRunInProgress,
                    );
                  },
                ),
                const SizedBox(height: 48),
                BlocSelector<TimerBloc, st.TimerState, TimerMode>(
                  selector: (state) => state.mode,
                  builder: (context, mode) {
                    return ModeSwitch(
                      currentMode: mode,
                      onModeChanged: (newMode) =>
                          context.read<TimerBloc>().add(TimerModeChanged(newMode)),
                    );
                  },
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

Notes on the implementation (no need to add as comments — these are design rationale):
- `_onDonutTap` reads the **current** `bloc.state` (a `context.read` inside a user callback — permitted; never called during `build`).
- `color` is resolved inside `builder` where the ambient `BuildContext` (dark `CupertinoApp` theme) is available (SN-2).
- `BlocSelector` selects only `state.mode` (`TimerMode`) → `ModeSwitch` rebuilds only when the mode changes, not on every tick.
- The `switch (bloc.state)` in `_onDonutTap` is exhaustive over the four sealed `TimerState` subclasses; the analyzer will flag any missing case.

- [ ] **Step 2: Repoint the import in `lib/main.dart`**

Using the `edit` tool with exact text match, replace in `lib/main.dart`:

```
import 'package:vipo/timer_screen.dart';
```

with:

```
import 'package:vipo/screens/timer_screen.dart';
```

This is the only change to `main.dart` — the `MultiBlocProvider` tree (providing `TimerBloc`, `LogsBloc`, `NotesBloc`) is already correct from issue #10 and is left untouched.

- [ ] **Step 3: Repoint the import in `test/widget_test.dart`**

Using the `edit` tool with exact text match, replace in `test/widget_test.dart`:

```
import 'package:vipo/timer_screen.dart';
```

with:

```
import 'package:vipo/screens/timer_screen.dart';
```

- [ ] **Step 4: Delete the old root-level screen file**

Run:

```bash
rm lib/timer_screen.dart
```

- [ ] **Step 5: Run the new widget test to verify it passes**

Run: `flutter test test/screens/timer_screen_test.dart`
Expected: PASS — 3 tests green (render initial state, tap → `TimerRunInProgress`, mode change → `TimerInitial(shortBreak)` + `05:00`).

- [ ] **Step 6: Run the existing `widget_test.dart` to confirm the full tree still builds**

Run: `flutter test test/widget_test.dart`
Expected: PASS — `TimerScreen` found exactly once within `VipoApp`'s provider tree.

- [ ] **Step 7: Run `flutter analyze`**

Run: `flutter analyze`
Expected: only the 5 pre-existing `avoid_print` **infos** in `lib/notifications.dart`. **Zero errors, zero warnings** introduced. (If a `switch` exhaustion or `context.read` lint appears, fix it before continuing.)

- [ ] **Step 8: Commit with caveman-commit**

Temp-file pattern:

```bash
mktemp
# Write commit message to the returned path
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

Suggested commit subject: `refactor(timer): move TimerScreen to BlocBuilder`

Suggested body (the "why" is non-obvious):

```
Screen is now a pure view: zero setState, zero business logic.
TimerState drives DonutTimer via BlocBuilder; mode via BlocSelector;
vibration + notification fire once in BlocListener on TimerComplete.
File moves to lib/screens/ to match the issue's import-boundary criterion.
```

---

## Task 3: Final verification — analyze + full test run + acceptance criteria

**Files:** none modified.

- [ ] **Step 1: Run `flutter analyze`**

Run: `flutter analyze`
Expected: only the 5 pre-existing `avoid_print` **infos** in `lib/notifications.dart`. **Zero errors, zero warnings.** If any issue introduced by this plan appears, fix it before proceeding (the 5 `info`s are pre-existing and explicitly out of scope — see `AGENTS.md` gotchas).

- [ ] **Step 2: Run the full test suite**

Run: `flutter test`
Expected: all tests pass — the pre-existing BLoC / service / repository / domain / DI tests, the existing `test/widget_test.dart`, and the new `test/screens/timer_screen_test.dart`.

- [ ] **Step 3: Verify the import boundary**

Run: `rg -n "lib/data/|lib/repositories/" lib/screens/`
Expected: **no matches** — `lib/screens/` imports neither `lib/data/` nor `lib/repositories/`.

- [ ] **Step 4: Verify zero `setState` and no surviving local state**

Run (from repo root):

```bash
rg -n "setState|_remainingSeconds|_isRunning|_isComplete|_currentMode|_timer\b" lib/screens/timer_screen.dart
```

Expected: **no matches** — the refactored screen contains no `setState` and none of the former local-state fields.

- [ ] **Step 5: Verify `DonutTimer` and `ModeSwitch` are unchanged**

Confirm the two widget files were not touched by this plan:

```bash
rg -n "class DonutTimer|const DonutTimer|required this\.|class ModeSwitch|class _DonutPainter" lib/widgets/donut_timer.dart lib/widgets/mode_switch.dart
```

Expected: the original class/constructor signatures are intact (the files are byte-for-byte unchanged — no edits were made to them in any task here).

- [ ] **Step 6: Walk the acceptance criteria checklist**

Confirm each box from the issue:

- [ ] `flutter analyze` passes with zero warnings (5 pre-existing `info`s remain, out of scope).
- [ ] `TimerScreen` contains zero `setState` calls (Step 4).
- [ ] `TimerScreen` is a `StatelessWidget` (`lib/screens/timer_screen.dart` — justified inline by the class doc comment: no `TickerProvider` needed).
- [ ] All former local state (`_remainingSeconds`, `_isRunning`, `_isComplete`, `_currentMode`) is removed (Step 4).
- [ ] Timer display reads from `BlocBuilder<TimerBloc, TimerState>` (Task 2, Step 1).
- [ ] Mode display reads from `BlocSelector<TimerBloc, TimerState, TimerMode>` (Task 2, Step 1).
- [ ] User interactions dispatch events to `TimerBloc` (not `setState`) (Task 2, Step 1 + Task 1 widget tests).
- [ ] `DonutTimer` and `ModeSwitch` widget files are unchanged (Step 5).
- [ ] `BlocListener` handles side effects (vibration, notifications) when `TimerComplete` is emitted (Task 2, Step 1; verified by code inspection + `timer_bloc_test.dart:80-97` + on-device manual test — see SN-8).
- [ ] No file in `lib/screens/` imports from `lib/data/` or `lib/repositories/` (Step 3).

No further commit is needed for a verification-only task.

- [ ] **Step 7: Manual on-device smoke test (optional but recommended)**

Run: `flutter run -d macos`
Manual checks:
1. Initial screen shows `20:00` and "tap to start"; the donut is full.
2. Tap the donut → countdown begins, hint shows "tap to pause", `DonutTimer`'s fade+scale animation plays once.
3. Tap again → pauses ("tap to resume"); tap → resumes.
4. Long-press → resets to the full current duration.
5. Tap a mode segment (Short Break) → immediately switches to `05:00`, donut resets.
6. Let a short countdown finish (set work/short to a tiny duration in a throwaway debug build, or just observe): on `TimerComplete`, the device vibrates (if it has a vibrator — macOS does not) and a local notification appears with title `"<Mode> Complete"`. The donut shows `00:00` / "tap to start" again, and tapping resets.
7. No debug startup notification appears (already removed in issue #10).

---

## Self-Review

**Spec coverage:**

- "Delete `_remainingSeconds`, `_isRunning`, `_isComplete`, `_currentMode`" → Task 2 Step 1 (StatelessWidget owns none); verified Task 3 Step 4. ✓
- "Convert `TimerScreen` from `StatefulWidget` to `StatelessWidget`" → SN-5 + Task 2 Step 1 (class doc justifies the choice). ✓
- "Timer display — wrap `DonutTimer` in `BlocBuilder<TimerBloc, TimerState>`" → Task 2 Step 1 `BlocBuilder` block. ✓
- "Drive `DonutTimer` progress, remaining time, hint text from `TimerInitial`/`RunInProgress`/`Paused`/`Complete`" → SN-1 mapping table; `_remainingSeconds(s)` covers all four states; progress + hint are derived inside unchanged `DonutTimer` from `remainingSeconds`/`totalSeconds`/`isRunning`. ✓
- "Mode display — `BlocSelector<TimerBloc, TimerState, TimerMode>`" → Task 2 Step 1 `BlocSelector` block. ✓
- "Side effects — `BlocListener<TimerBloc, TimerState>`; `TimerComplete` → vibration + local notification" → SN-6 + Task 2 Step 1 `BlocListener` block. ✓
- "Start/Pause/Resume/Reset taps dispatch `TimerStarted`/`TimerPaused`/`TimerResumed`/`TimerReset`" → SN-4 mapping table + `_onDonutTap`. ✓
- "Mode change dispatches `TimerModeChanged(mode)`" → `onModeChanged` callback. ✓
- "Long press dispatches `TimerReset`" → `onLongPress`. ✓
- "DonutTimer & ModeSwitch unchanged" → SN-1; Task 3 Step 5 verifies; no task edits them. ✓
- "Zero `setState`" → verified Task 3 Step 4. ✓
- "Zero business logic" → all decision-making is in `TimerBloc`; screen only maps state→props and dispatches events. ✓
- "No `context.read<>()` in `build()`" → `_onDonutTap` and the `onLongPress`/`onModeChanged` closures are user callbacks, executed outside `build`; `build()` only declares widgets. ✓
- "No direct repository access from UI" → SN-10; verified Task 3 Step 3. ✓
- "Side effects in UI (BlocListener), BLoCs don't import platform packages" → SN-6/SN-10; `vibration` & `notifications` imported only by the screen. ✓
- "No file in `lib/screens/` imports from `lib/data/` or `lib/repositories/`" → SN-7 + Task 3 Step 3. ✓
- Acceptance: `flutter analyze` zero warnings → Task 3 Step 1. ✓
- Acceptance: `TimerScreen` is `StatelessWidget` (justified) → Task 2 Step 1 doc comment. ✓
- Acceptance: `BlocListener` handles side effects on `TimerComplete` → Task 2 Step 1 + Task 3 Step 6 + SN-8 note on testability. ✓
- LogsBloc/NotesBloc mention → SN-9 (provided, not yet rendered; YAGNI). ✓

**Placeholder scan:** No TBD/TODO/"implement later"/"add error handling"/"similar to Task N". Every code step contains complete, compilable code. Commit steps give concrete commands and suggested subjects.

**Type consistency:** State classes referenced (`st.TimerInitial(mode, duration)`, `st.TimerRunInProgress(mode, remainingSeconds)`, `st.TimerPaused(mode, remainingSeconds)`, `st.TimerComplete(mode)`) match `lib/blocs/timer/timer_state.dart` exactly. Events (`TimerStarted(mode)`, `TimerPaused()`, `TimerResumed()`, `TimerReset()`, `TimerModeChanged(mode)`) match `lib/blocs/timer/timer_event.dart` exactly. `_remainingSeconds` switch patterns use Dart 3 object-destructuring (`:final duration`, `:final remainingSeconds`) valid under SDK ^3.10.4. `DonutTimer` constructor params match `lib/widgets/donut_timer.dart:5-14`. `ModeSwitch` constructor params match `lib/widgets/mode_switch.dart:4-9`. `MockLogsRepository`/`LogsBloc`/`TimerBloc`/`Result.success`/`registerFallbackValue` patterns match `test/blocs/timer/timer_bloc_test.dart:14-36` and `test/blocs/logs/logs_bloc_test.dart` conventions. Import paths use `package:vipo/...` (the pubspec `name: vipo`) consistently.

No issues found. Plan is complete.
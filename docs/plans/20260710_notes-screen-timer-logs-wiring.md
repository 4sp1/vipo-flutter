# Notes Screen & Navigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use supervised-plan-execution to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Cupertino-styled `NotesScreen` with create/list/delete/fetch functionality and navigation from `TimerScreen`, plus clean up `avoid_print` lint issues so `flutter analyze` passes with zero findings.

**Architecture:** The TimerBloc→LogsBloc wiring is already implemented (verified in existing code). This plan covers the remaining work: restructuring `main.dart` providers above `CupertinoApp` (so pushed routes inherit bloc providers), creating `NotesScreen` as a `StatefulWidget` that dispatches only to `NotesBloc` and reads `TimerMode` from `TimerBloc`, and adding a navigation bar trailing button to `TimerScreen` using `CupertinoPageRoute`. BLoC-to-BLoC is via event dispatch; side effects remain in UI layer.

**Tech Stack:** Flutter with Cupertino-only widgets, `flutter_bloc` for state management, `mocktail` for tests, manual DI via `AppDeps`.

---

## Context: Already Implemented (No Tasks Required)

The following acceptance criteria from the issue are **already satisfied** by the existing codebase (issues #5–#11):

- `TimerBloc` accepts `LogsBloc` (not `LogsRepository`) — see `lib/blocs/timer/timer_bloc.dart:13`
- Every timer action dispatches `LogCreated` — see `_onStarted`, `_onPaused`, `_onResumed`, `_onReset`, `_onModeChanged`, `_onCompleted`
- Fire-and-forget dispatch — `void _dispatchLog(...)` calls `_logsBloc.add(...)` without `await`
- `di.dart` constructs `LogsBloc` before `TimerBloc` — see `lib/di.dart:40-41`
- Vibration + notification in `BlocListener` inside `TimerScreen` — see `lib/screens/timer_screen.dart:53-65`
- `TimerBloc` does not import `notifications.dart`, `vibration`, or any platform package
- No file in `lib/screens/` imports from `lib/data/` or `lib/repositories/` (verified)
- No file in `lib/blocs/` imports from `lib/screens/` or `lib/widgets/` (verified)

**Current `flutter analyze` status:** 5 `avoid_print` info issues in `lib/notifications.dart` (exit code 1).
**Current `flutter test` status:** 110 tests, all passing.

## File Structure

### Create
- `lib/screens/notes_screen.dart` — `NotesScreen` widget (`StatefulWidget`). Cupertino-only. Reads `NotesBloc` and `TimerBloc` from the inherited `MultiBlocProvider`. Dispatches events only to `NotesBloc`. Handles create (dialog), list (success states), delete (swipe), error+retry.
- `test/screens/notes_screen_test.dart` — Widget tests for `NotesScreen` covering loading, success (populated + empty), failure, retry, add dialog (create + cancel), swipe delete.

### Modify
- `lib/notifications.dart:7-60` — Remove 5 `print()` calls so `flutter analyze` passes with zero findings.
- `lib/main.dart:26-45` — Restructure `VipoApp.build`: move `MultiRepositoryProvider` + `MultiBlocProvider` to wrap `CupertinoApp` instead of wrapping `home`. Pushed routes (like `NotesScreen`) must find bloc providers, and `BlocProvider` inside `home` only covers the initial route.
- `lib/screens/timer_screen.dart:52-107` — Add `CupertinoNavigationBar` with trailing button that pushes `NotesScreen` via `CupertinoPageRoute`.
- `test/screens/timer_screen_test.dart:1-100` — Update pump helper to (a) place `MultiBlocProvider` above `CupertinoApp`, (b) provide `NotesBloc` alongside `TimerBloc` so pushed `NotesScreen` resolves providers, and (c) add a new test that verifies tapping the nav button pushes `NotesScreen`.

### Unchanged (verified already satisfies acceptance criteria)
- `lib/blocs/timer/**`, `lib/blocs/logs/**`, `lib/blocs/notes/**` — no changes.
- `lib/di.dart` — no changes (already constructs `LogsBloc` before `TimerBloc`).
- `test/di_test.dart` — no changes (already verifies the full graph).

---

### Task 1: Remove `print()` calls from `lib/notifications.dart`

**Files:**
- Modify: `lib/notifications.dart`

The `avoid_print` lint (inherited from `package:flutter_lints/flutter.yaml`) flags 5 `print()` calls; `flutter analyze` exits with code 1. The acceptance criterion says "`flutter analyze` passes with zero warnings." Remove the debug prints — AGENTS.md already flags them for removal ("Remove before shipping").

- [ ] **Step 1: Remove all print() calls and finalize file**

Replace the entire contents of `lib/notifications.dart` with:

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final notifications = FlutterLocalNotificationsPlugin();

Future<void> initialize() async {
  final initialized = await notifications.initialize(
    settings: const InitializationSettings(
      macOS: DarwinInitializationSettings(),
    ),
  );

  final macosPlugin = notifications
      .resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin
      >();

  if (macosPlugin == null) {
    return;
  }

  await macosPlugin.requestPermissions(
    alert: true,
    badge: true,
    sound: true,
  );

  await notifications
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >()
      ?.requestPermissions(alert: true, badge: true, sound: true);
}

Future<void> show({required String title, required String body}) async {
  try {
    await notifications.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        macOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  } catch (_) {
    // Silently ignore notification errors: notification failures must not
    // affect the user's timer flow.
  }
}
```

- [ ] **Step 2: Run `flutter analyze` and confirm zero findings**

Run: `flutter analyze`
Expected: `No issues found! (ran in <N>s)` with exit code 0

- [ ] **Step 3: Run `flutter test` and confirm all existing tests still pass**

Run: `flutter test`
Expected: `All tests passed!` (110 passing)

- [ ] **Step 4: Commit with caveman-commit**

Use the `caveman-commit` skill to write a descriptive commit message. Then use the temp file pattern from the core-commands skill:

```bash
mktemp
# Returns: /tmp/tmp.XXXXXX
```

Use Write tool to save the commit message (e.g. `fix(notifications): remove debug prints for avoid_print lint`) to that path, then:

```bash
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

---

### Task 2: Move providers above `CupertinoApp` in `lib/main.dart`

**Files:**
- Modify: `lib/main.dart:26-45`

Currently `MultiRepositoryProvider` + `MultiBlocProvider` wrap the `home` parameter only. When `TimerScreen` later pushes `NotesScreen` via `Navigator`, the pushed route is NOT a descendant of these providers — it would throw `ProviderNotFoundException` for `NotesBloc` and `TimerBloc`. Move the providers outside `CupertinoApp` so every route built inside its `Navigator` inherits them.

- [ ] **Step 1: Restructure `VipoApp.build`**

In `lib/main.dart`, replace the `build` method of `VipoApp` (currently lines 26–46) with:

```dart
  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<LogsRepository>.value(value: deps.logsRepository),
        RepositoryProvider<NotesRepository>.value(value: deps.notesRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<LogsBloc>(create: (_) => deps.logsBloc),
          BlocProvider<TimerBloc>(create: (_) => deps.timerBloc),
          BlocProvider<NotesBloc>(create: (_) => deps.notesBloc),
        ],
        child: CupertinoApp(
          title: 'Vipo',
          debugShowCheckedModeBanner: false,
          theme: const CupertinoThemeData(brightness: Brightness.dark),
          home: const TimerScreen(),
        ),
      ),
    );
  }
```

Imports already in the file cover everything used here (no new imports needed).

- [ ] **Step 2: Run `flutter test` and confirm existing tests still pass**

Run: `flutter test test/widget_test.dart test/di_test.dart`
Expected: All tests pass. `VipoApp builds TimerScreen within the provider tree` still finds `TimerScreen`. `AppDeps` tests unaffected (di.dart unchanged).

- [ ] **Step 3: Commit with caveman-commit**

```bash
mktemp
# Returns: /tmp/tmp.XXXXXX
```

Write a message like `refactor(main): hoist bloc providers above CupertinoApp` to that path, then:

```bash
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

---

### Task 3: Create `lib/screens/notes_screen.dart`

**Files:**
- Create: `lib/screens/notes_screen.dart`
- Test: `test/screens/notes_screen_test.dart`

Build `NotesScreen` test-first. The widget reads `NotesBloc` for state, dispatches `NotesFetchRequested`/`NoteCreated`/`NoteDeleted` events, and reads `TimerBloc.state.mode` for the current `TimerMode` (used when creating a note). Cupertino-only. `StatefulWidget` so `initState` can dispatch the initial fetch.

- [ ] **Step 1: Write the failing tests**

Create `test/screens/notes_screen_test.dart`:

```dart
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vipo/blocs/logs/logs_bloc.dart';
import 'package:vipo/blocs/notes/notes_bloc.dart';
import 'package:vipo/domain/models/log_action.dart';
import 'package:vipo/domain/models/log_entry.dart';
import 'package:vipo/domain/models/note.dart';
import 'package:vipo/domain/models/timer_mode.dart';
import 'package:vipo/domain/result.dart';
import 'package:vipo/repositories/logs_repository.dart';
import 'package:vipo/repositories/notes_repository.dart';
import 'package:vipo/screens/notes_screen.dart';
import 'package:vipo/blocs/timer/timer_bloc.dart';

class MockLogsRepository extends Mock implements LogsRepository {}

class MockNotesRepository extends Mock implements NotesRepository {}

void main() {
  late MockLogsRepository mockLogsRepository;
  late MockNotesRepository mockNotesRepository;
  late LogsBloc logsBloc;
  late TimerBloc timerBloc;
  late NotesBloc notesBloc;

  final testNote = Note(
    id: '1',
    content: 'hello',
    createdAt: DateTime(2025, 1, 1, 12, 0),
  );

  final fallbackEntry = LogEntry(
    id: '1',
    pomodoroState: TimerMode.work,
    action: LogAction.start,
    createdAt: DateTime(2025, 1, 1),
  );

  setUpAll(() {
    registerFallbackValue(fallbackEntry);
    registerFallbackValue(testNote);
    registerFallbackValue(TimerMode.work);
    registerFallbackValue('');
  });

  setUp(() {
    mockLogsRepository = MockLogsRepository();
    when(() => mockLogsRepository.createLog(any()))
        .thenAnswer((_) async => Result.success(fallbackEntry));
    logsBloc = LogsBloc(mockLogsRepository);
    timerBloc = TimerBloc(logsBloc);

    mockNotesRepository = MockNotesRepository();
    when(() => mockNotesRepository.getNotes())
        .thenAnswer((_) async => Result.success(<Note>[]));
    notesBloc = NotesBloc(mockNotesRepository);
  });

  tearDown(() async {
    await notesBloc.close();
    await timerBloc.close();
    await logsBloc.close();
  });

  Widget pumpSubject() {
    return CupertinoApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<NotesBloc>.value(value: notesBloc),
          BlocProvider<TimerBloc>.value(value: timerBloc),
        ],
        child: const NotesScreen(),
      ),
    );
  }

  testWidgets(
      'shows CupertinoActivityIndicator while notes are loading',
      (tester) async {
    final completer = Completer<Result<List<Note>>>();
    when(() => mockNotesRepository.getNotes())
        .thenAnswer((_) async => await completer.future);

    await tester.pumpWidget(pumpSubject());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

    completer.complete(Result.success(<Note>[]));
    await tester.pumpAndSettle();
  });

  testWidgets('shows notes list on load success', (tester) async {
    when(() => mockNotesRepository.getNotes())
        .thenAnswer((_) async => Result.success([testNote]));

    await tester.pumpWidget(pumpSubject());
    await tester.pumpAndSettle();

    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('shows empty-state message when notes list is empty',
      (tester) async {
    when(() => mockNotesRepository.getNotes())
        .thenAnswer((_) async => Result.success(<Note>[]));

    await tester.pumpWidget(pumpSubject());
    await tester.pumpAndSettle();

    expect(find.text('No notes yet'), findsOneWidget);
  });

  testWidgets('shows error message and Retry button on load failure',
      (tester) async {
    when(() => mockNotesRepository.getNotes()).thenAnswer(
      (_) async => Result.failure(NoteRetrievalFailure('badGateway')),
    );

    await tester.pumpWidget(pumpSubject());
    await tester.pumpAndSettle();

    expect(find.textContaining('NoteRetrievalFailure'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets(
      'tapping Retry re-dispatches NotesFetchRequested and clears error',
      (tester) async {
    final callCount = <int>[];
    when(() => mockNotesRepository.getNotes()).thenAnswer((_) async {
      callCount.add(1);
      if (callCount.length == 1) {
        return Result.failure(NoteRetrievalFailure('badGateway'));
      }
      return Result.success(<Note>[]);
    });

    await tester.pumpWidget(pumpSubject());
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('No notes yet'), findsOneWidget);
    verify(() => mockNotesRepository.getNotes()).called(2);
  });

  testWidgets(
      'tapping + shows dialog, entering text, tapping Add dispatches NoteCreated',
      (tester) async {
    when(() => mockNotesRepository.getNotes())
        .thenAnswer((_) async => Result.success(<Note>[]));
    when(() => mockNotesRepository.createNote(any(), any()))
        .thenAnswer((_) async => Result.success(testNote));

    await tester.pumpWidget(pumpSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.add));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.byType(CupertinoTextField), findsOneWidget);

    await tester.enterText(find.byType(CupertinoTextField), 'hello');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    verify(() => mockNotesRepository.createNote(any(), any())).called(1);
  });

  testWidgets(
      'tapping Cancel in the add note dialog does not create a note',
      (tester) async {
    when(() => mockNotesRepository.getNotes())
        .thenAnswer((_) async => Result.success(<Note>[]));

    await tester.pumpWidget(pumpSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.add));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(CupertinoTextField), 'hello');
    await tester.pump();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    verifyNever(() => mockNotesRepository.createNote(any(), any()));
  });

  testWidgets('swiping a note dispatches NoteDeleted', (tester) async {
    when(() => mockNotesRepository.getNotes())
        .thenAnswer((_) async => Result.success([testNote]));
    when(() => mockNotesRepository.deleteNote(any()))
        .thenAnswer((_) async => Result<void>.success(null));

    await tester.pumpWidget(pumpSubject());
    await tester.pumpAndSettle();

    await tester.drag(find.text('hello'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    verify(() => mockNotesRepository.deleteNote('1')).called(1);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/screens/notes_screen_test.dart`
Expected: Compilation failure: `notes_screen.dart` not found / `NotesScreen` undefined (Target of URI doesn't exist).

- [ ] **Step 3: Implement `NotesScreen`**

Create `lib/screens/notes_screen.dart`:

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vipo/blocs/notes/notes_bloc.dart';
import 'package:vipo/blocs/notes/notes_event.dart';
import 'package:vipo/blocs/notes/notes_state.dart';
import 'package:vipo/blocs/timer/timer_bloc.dart';
import 'package:vipo/domain/models/note.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  @override
  void initState() {
    super.initState();
    context.read<NotesBloc>().add(NotesFetchRequested());
  }

  void _showAddNoteDialog(BuildContext context) {
    final timerMode = context.read<TimerBloc>().state.mode;
    final notesBloc = context.read<NotesBloc>();
    final controller = TextEditingController();

    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('New Note'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: CupertinoTextField(
            controller: controller,
            placeholder: 'Enter note content',
            autofocus: true,
            maxLines: 3,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              final content = controller.text.trim();
              if (content.isNotEmpty) {
                notesBloc.add(
                  NoteCreated(
                    content: content,
                    pomodoroState: timerMode,
                  ),
                );
              }
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Notes'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showAddNoteDialog(context),
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: SafeArea(
        top: false,
        child: BlocBuilder<NotesBloc, NotesState>(
          builder: (context, state) {
            return switch (state) {
              NotesInitial() || NotesLoadInProgress() =>
                const Center(child: CupertinoActivityIndicator()),
              NotesLoadSuccess(:final notes) => notes.isEmpty
                  ? const Center(child: Text('No notes yet'))
                  : ListView.builder(
                      itemCount: notes.length,
                      itemBuilder: (context, index) {
                        final note = notes[index];
                        return Dismissible(
                          key: ValueKey(note.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            color: CupertinoColors.systemRed,
                            padding: const EdgeInsets.only(right: 16),
                            child: const Icon(
                              CupertinoIcons.delete,
                              color: CupertinoColors.white,
                            ),
                          ),
                          confirmDismiss: (_) async {
                            context
                                .read<NotesBloc>()
                                .add(NoteDeleted(note.id));
                            return true;
                          },
                          child: CupertinoListTile(
                            title: Text(note.content),
                            subtitle:
                                Text(_formatDate(note.createdAt)),
                          ),
                        );
                      },
                    ),
              NotesLoadFailure(:final message) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(message),
                      const SizedBox(height: 16),
                      CupertinoButton(
                        onPressed: () => context
                            .read<NotesBloc>()
                            .add(NotesFetchRequested()),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
            };
          },
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/screens/notes_screen_test.dart`
Expected: `All tests passed!` (8 tests).

If the "swiping a note dispatches NoteDeleted" test fails to find `Dismissible` (sometimes `CupertinoListTile` needs explicit `CupertinoListTile.insetGrouped` or hit-test coordinates), change the `tester.drag` target to `find.byType(Dismissible)` or `find.byType(CupertinoListTile)` and replace the drag gesture with a slower `tester.fling`:

```dart
await tester.fling(
  find.byType(Dismissible),
  const Offset(-500, 0),
  1000,
);
```

Then pumpAndSettle and check `verify(() => mockNotesRepository.deleteNote('1')).called(1)`.

- [ ] **Step 5: Run `flutter analyze` on the new file**

Run: `flutter analyze lib/screens/notes_screen.dart test/screens/notes_screen_test.dart`
Expected: `No issues found!` with exit code 0.

- [ ] **Step 6: Commit with caveman-commit**

```bash
mktemp
# Returns: /tmp/tmp.XXXXXX
```

Write a message like `feat(notes): add NotesScreen with create/list/delete` to that path, then:

```bash
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

---

### Task 4: Add navigation from `TimerScreen` to `NotesScreen`

**Files:**
- Modify: `lib/screens/timer_screen.dart:52-107`
- Test: `test/screens/timer_screen_test.dart` (update `pumpSubject` and add new test)

Add a `CupertinoNavigationBar` with a trailing `CupertinoButton` that pushes `NotesScreen` via `CupertinoPageRoute<void>`. The `CupertinoPageScaffold` must propagate the `BlocListener` wrapper above it (existing behavior — keep `BlocListener` as the outermost widget).

- [ ] **Step 1: Update `TimerScreen` to import `NotesScreen`**

Add import at the top of `lib/screens/timer_screen.dart` (after existing imports, around line 10):

```dart
import 'package:vipo/screens/notes_screen.dart';
```

- [ ] **Step 2: Add `CupertinoNavigationBar` to the scaffold**

In `lib/screens/timer_screen.dart`, modify the `CupertinoPageScaffold` in `build` (starting at the line `child: CupertinoPageScaffold(`). Replace the existing `CupertinoPageScaffold(...)` block — preserving the existing ` BlocListener` wrapper above it — with:

```dart
      child: CupertinoPageScaffold(
        backgroundColor: CupertinoColors.systemBackground,
        navigationBar: CupertinoNavigationBar(
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => const NotesScreen(),
                ),
              );
            },
            child: const Icon(CupertinoIcons.list_bullet),
          ),
        ),
        child: SafeArea(
          top: false,
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
```

Key changes from the existing code:
- New `navigationBar` parameter on `CupertinoPageScaffold` with trailing button that calls `Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => const NotesScreen()))`.
- `SafeArea` now has `top: false` — because the navigation bar already consumes the top safe-area inset; without this, layout would double-apply top padding.

The `BlocListener<TimerBloc, st.TimerState>` wrapper above the scaffold stays unchanged (it doesn't touch the nav bar — same listener for vibration + notification).

- [ ] **Step 3: Update `test/screens/timer_screen_test.dart` to provide `NotesBloc` and use providers-above-app pattern**

In `test/screens/timer_screen_test.dart`, replace the existing imports and test setup. The new imports needed:

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vipo/blocs/logs/logs_bloc.dart';
import 'package:vipo/blocs/notes/notes_bloc.dart';
import 'package:vipo/blocs/timer/timer_bloc.dart';
import 'package:vipo/blocs/timer/timer_state.dart' as st;
import 'package:vipo/domain/models/log_action.dart';
import 'package:vipo/domain/models/log_entry.dart';
import 'package:vipo/domain/models/note.dart';
import 'package:vipo/domain/models/timer_mode.dart';
import 'package:vipo/domain/result.dart';
import 'package:vipo/repositories/logs_repository.dart';
import 'package:vipo/repositories/notes_repository.dart';
import 'package:vipo/screens/notes_screen.dart';
import 'package:vipo/screens/timer_screen.dart';
import 'package:vipo/widgets/donut_timer.dart';

class MockLogsRepository extends Mock implements LogsRepository {}

class MockNotesRepository extends Mock implements NotesRepository {}
```

Replace `setUp`, `tearDown`, and `pumpSubject`:

```dart
  late MockLogsRepository mockLogsRepository;
  late MockNotesRepository mockNotesRepository;
  late LogsBloc logsBloc;
  late NotesBloc notesBloc;

  final fallbackEntry = LogEntry(
    id: '1',
    pomodoroState: TimerMode.work,
    action: LogAction.start,
    createdAt: DateTime(2025, 1, 1),
  );

  final testNote = Note(
    id: '1',
    content: 'hello',
    createdAt: DateTime(2025, 1, 1, 12, 0),
  );

  setUpAll(() {
    registerFallbackValue(fallbackEntry);
    registerFallbackValue(testNote);
    registerFallbackValue(TimerMode.work);
    registerFallbackValue('');
  });

  setUp(() {
    mockLogsRepository = MockLogsRepository();
    when(() => mockLogsRepository.createLog(any()))
        .thenAnswer((_) async => Result.success(fallbackEntry));
    logsBloc = LogsBloc(mockLogsRepository);

    mockNotesRepository = MockNotesRepository();
    when(() => mockNotesRepository.getNotes())
        .thenAnswer((_) async => Result.success(<Note>[]));
    when(() => mockNotesRepository.createNote(any(), any()))
        .thenAnswer((_) async => Result.success(testNote));
    notesBloc = NotesBloc(mockNotesRepository);
  });

  tearDown(() async {
    await notesBloc.close();
    await logsBloc.close();
  });

  Widget pumpSubject() {
    return MultiBlocProvider(
      providers: [
        BlocProvider<TimerBloc>(create: (_) => TimerBloc(logsBloc)),
        BlocProvider<NotesBloc>(create: (_) => NotesBloc(mockNotesRepository)),
      ],
      child: CupertinoApp(
        home: const TimerScreen(),
      ),
    );
  }
```

The existing tests in the file (lines starting with `testWidgets('renders initial work countdown 20:00...`, `tapping the donut in the initial state ...`, `selecting Short Break dispatches ...`) should remain unchanged. Add a new test at the end of `void main()`:

```dart
  testWidgets(
      'tapping the notes button pushes NotesScreen onto the navigator',
      (tester) async {
    await tester.pumpWidget(pumpSubject());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(NotesScreen), findsNothing);

    await tester.tap(find.byIcon(CupertinoIcons.list_bullet));
    await tester.pumpAndSettle();

    expect(find.byType(NotesScreen), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
  });
```

- [ ] **Step 4: Run `flutter test` for the timer screen test file**

Run: `flutter test test/screens/timer_screen_test.dart`
Expected: `All tests passed!` (4 tests: 3 existing + 1 new).

If the existing tests fail with "TimeoutException" or "pumpAndSettle" issues during the new navigation test, the likely cause is `flutter_animate`'s `.animate()` chain on the `CustomPaint` inside `DonutTimer` either looping or not settling. Use `await tester.pump(const Duration(milliseconds: 500))` after tapping the nav button instead of `await tester.pumpAndSettle()`, then assert.

A safer alternative for the new test that avoids any pump-and-settle issues:

```dart
  testWidgets(
      'tapping the notes button pushes NotesScreen onto the navigator',
      (tester) async {
    await tester.pumpWidget(pumpSubject());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(NotesScreen), findsNothing);

    await tester.tap(find.byIcon(CupertinoIcons.list_bullet));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(NotesScreen), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
  });
```

- [ ] **Step 5: Run `flutter analyze` on modified files**

Run: `flutter analyze lib/screens/timer_screen.dart test/screens/timer_screen_test.dart`
Expected: `No issues found!` with exit code 0.

- [ ] **Step 6: Commit with caveman-commit**

```bash
mktemp
# Returns: /tmp/tmp.XXXXXX
```

Write a message like `feat(timer): add Notes nav button + route push` to that path, then:

```bash
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

---

### Task 5: Full verification

**Files:**
- No file changes — verification only.

- [ ] **Step 1: Run `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found! (ran in <N>s)` with exit code 0.

- [ ] **Step 2: Run `flutter test`**

Run: `flutter test`
Expected: `All tests passed!` — expected count 118 (110 original + 8 new for NotesScreen; pre-existing 3 for TimerScreen became 4 after adding the navigation test).

If any test fails:
- Re-read the failing assertion and the referenced file.
- Compare the expected vs actual state and make a targeted fix (do not re-run blindly).
- Common gotcha: `tester.pumpAndSettle()` after tapping the NotesScreen nav button might run into infinite animations from `flutter_animate` in `DonutTimer`. Replace with `tester.pump(const Duration(milliseconds: 500))` and read the state.

- [ ] **Step 3: Acceptance criteria check**

Verify against issue body:

- [x] `flutter analyze` passes with zero warnings.
- [x] `TimerBloc` no longer accepts `LogsRepository` — it accepts `LogsBloc` instead and dispatches `LogCreated` events (already true; unchanged by this plan).
- [x] Every timer action (start, pause, resume, reset, expire, mode change) fires the corresponding `LogAction` to `LogsBloc` (already true).
- [x] Log dispatch failures do not affect timer state or UI (already true: `NotesScreen`/`TimerBloc` use fire-and-forget).
- [x] `di.dart` constructs `LogsBloc` before `TimerBloc` and injects it into `TimerBloc` (already true).
- [x] Vibration and local notification are handled in `BlocListener` inside `TimerScreen`, not inside `TimerBloc` (already true).
- [x] `TimerBloc` does not import `notifications.dart`, `vibration`, or any platform package (already true).
- [x] `NotesScreen` exists in `lib/screens/notes_screen.dart` with list, create, and delete functionality (created by Task 3).
- [x] `NotesScreen` uses only Cupertino widgets — no Material widgets (Task 3 used `CupertinoPageScaffold`, `CupertinoNavigationBar`, `CupertinoButton`, `CupertinoAlertDialog`, `CupertinoTextField`, `CupertinoListTile`, `CupertinoActivityIndicator`, `ListView`, `Dismissible` (SDK-only), `Text`).
- [x] `NotesScreen` reads state via `BlocBuilder<NotesBloc, NotesState>` and dispatches events only to `NotesBloc`.
- [x] Navigation from `TimerScreen` to `NotesScreen` uses `CupertinoPageRoute` (added in Task 4).
- [x] No file in `lib/screens/` imports from `lib/data/` or `lib/repositories/` (check manually: `timer_screen.dart` imports `flutter/cupertino`, `flutter_bloc`, `vibration`, `vipo/blocs/*`, `vipo/domain/models/*`, `vipo/notifications.dart`, `vipo/widgets/*`, `vipo/screens/notes_screen.dart` — none from `lib/data/` or `lib/repositories/`; `notes_screen.dart` imports `flutter/cupertino`, `flutter_bloc`, `vipo/blocs/*` only — none from `lib/data/` or `lib/repositories/`).
- [x] No file in `lib/blocs/` imports from `lib/screens/` or `lib/widgets/` (already true; this plan did not modify any file in `lib/blocs/`).
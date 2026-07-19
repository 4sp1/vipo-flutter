# NotesScreen StatelessWidget + NotesBloc Self-Dispatch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use supervised-plan-execution to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert `NotesScreen` from `StatefulWidget` to `StatelessWidget` and move the initial-notes-fetch dispatch off the view entirely: `NotesBloc` self-dispatches `NotesFetchRequested` from its constructor, so no view primes it. Mirrors the `TimerScreen` refactor from issue #11.

**Architecture:** `NotesBloc`'s constructor registers all `on<Event>` handlers, then calls `add(NotesFetchRequested())` as its last statement — the BLoC owns its initial load just like `TimerBloc` owns `TimerInitial(work)`. `NotesScreen` becomes a pure view (`BlocBuilder` only; `context.read` survives solely inside user-triggered callbacks like `_showAddNoteDialog` and `Retry`/`NoteDeleted`). Because `NotesBloc` now fetches on construction, two smoke tests that build the real `AppDeps` graph (`test/widget_test.dart`, `test/di_test.dart`) would otherwise fire a real HTTP call to `http://localhost:8080`; this plan adds a tiny `NotesRepository?` test-seam to `AppDeps` and injects a `MockNotesRepository` in those tests so no real HTTP is made.

**Tech Stack:** Dart ^3.10.4, Flutter, `flutter_bloc` + `equatable`, `dio` ^5.7.0, `mocktail` + `bloc_test` for tests. VCS is `jj` (collocated with git) — commits use the temp-file + `jj describe --stdin` + `jj new` pattern from the `core-commands` skill. Commits use the `caveman-commit` skill for the message.

---

## File Structure

| File | Role | Action |
|---|---|---|
| `lib/blocs/notes/notes_bloc.dart` | BLoC; gains self-dispatch in constructor | Modify |
| `lib/screens/notes_screen.dart` | View; `StatefulWidget` → `StatelessWidget` | Modify |
| `lib/di.dart` | `AppDeps` adds optional `NotesRepository?` test-seam | Modify |
| `test/blocs/notes/notes_bloc_test.dart` | Account for self-dispatch emissions | Modify (rewrite) |
| `test/screens/notes_screen_test.dart` | Construct bloc per-test after stubs set | Modify (rewrite) |
| `test/widget_test.dart` | Inject mock notes repo to avoid real HTTP | Modify |
| `test/di_test.dart` | Inject mock notes repo to avoid real HTTP | Modify |
| `AGENTS.md` | Reflect `StatelessWidget` + self-dispatch | Modify |

No new files. No changes under `lib/data/api/` (generated).

---

## Current state audit (read before editing)

Read these before touching anything (Task 1 confirms the baseline is green):

- `lib/screens/notes_screen.dart` — `StatefulWidget`, `_NotesScreenState.initState` calls `context.read<NotesBloc>().add(NotesFetchRequested())` at `lib/screens/notes_screen.dart:17-20`. `_showAddNoteDialog` (`lib/screens/notes_screen.dart:22-64`) and the `Retry`/`NoteDeleted` callbacks already use `context.read` from user-triggered callbacks (allowed).
- `lib/blocs/notes/notes_bloc.dart` — `NotesBloc(this._notesRepository) : super(NotesInitial())` registers `on<NotesFetchRequested>`, `on<NoteCreated>`, `on<NoteDeleted>` (`lib/blocs/notes/notes_bloc.dart:9-13`). `_onFetchRequested` emits `NotesLoadInProgress` then `NotesLoadSuccess`/`NotesLoadFailure` (`lib/blocs/notes/notes_bloc.dart:17-28`) — used by the `Retry` button too, so it must stay unconditional.
- `lib/di.dart` — `AppDeps()` (`lib/di.dart:23-43`) builds `Dio` → `LogsApi`/`NotesApi` → services → repositories → BLoCs in one constructor. `NotesBloc(_notesRepository)` is the last BLoC.
- `test/blocs/notes/notes_bloc_test.dart` — 6 tests; uses `seed: () => NotesLoadSuccess(...)` for `NoteCreated`/`NoteDeleted` tests (no `getNotes` stub). With self-dispatch those seeds are wiped by the constructor-time fetch, so the file is rewritten (not patched).
- `test/screens/notes_screen_test.dart` — constructs `notesBloc` in `setUp` with default `getNotes → success([])` stub; many tests re-stub `getNotes` in the test body then expect the re-stubbed data. With self-dispatch the re-stub never re-fetches (fetch already fired in `setUp`), so the file is rewritten to construct the bloc per-test after the right stub is set.
- `test/widget_test.dart` and `test/di_test.dart` — both construct the real `AppDeps()`. With self-dispatch, `AppDeps()` fires a real `GET /notes` to `http://localhost:8080` during construction; `di_test.dart`'s `tearDown` calls `deps.dispose()` which closes `NotesBloc` while the fetch is still pending → when the rejected `Dio` future resumes it calls `emit` on a closed bloc → `StateError`. Hence the seam.
- `AGENTS.md` — three references to `NotesScreen` as `StatefulWidget` / `initState` dispatch (`AGENTS.md:35`, `AGENTS.md:64`, `AGENTS.md:111`).

---

### Task 1: Establish a clean working baseline

**Files:**
- Read: `lib/screens/notes_screen.dart`, `lib/blocs/notes/notes_bloc.dart`, `lib/di.dart`, the four test files listed above, `AGENTS.md`
- Run: `flutter analyze`, `flutter test`

- [ ] **Step 1: Read the files listed under "Current state audit" above**

Read each file end-to-end so the edits in later tasks match exact whitespace.

- [ ] **Step 2: Confirm the baseline is green**

Run:
```bash
flutter analyze
flutter test
```
Expected: `flutter analyze` reports zero issues; `flutter test` reports all tests passing. If anything is red before you start, stop and report — the baseline must be green so Task 7's verification is a true diff.

- [ ] **Step 3: Start a working change**

```bash
jj new
```

---

### Task 2: `NotesBloc` self-dispatches `NotesFetchRequested`; rewrite its bloc test

**Files:**
- Modify: `lib/blocs/notes/notes_bloc.dart`
- Test: `test/blocs/notes/notes_bloc_test.dart` (rewrite)

- [ ] **Step 1: Write the failing test (rewrite `test/blocs/notes/notes_bloc_test.dart`)**

Overwrite the entire file with:

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vipo/blocs/notes/notes_bloc.dart';
import 'package:vipo/blocs/notes/notes_event.dart';
import 'package:vipo/blocs/notes/notes_state.dart';
import 'package:vipo/domain/models/note.dart';
import 'package:vipo/domain/models/timer_mode.dart';
import 'package:vipo/domain/result.dart';
import 'package:vipo/repositories/notes_repository.dart';

class MockNotesRepository extends Mock implements NotesRepository {}

void main() {
  late MockNotesRepository mockNotesRepository;

  final testNote = Note(
    id: '1',
    content: 'hello',
    createdAt: DateTime(2025, 1, 1),
  );

  setUpAll(() {
    registerFallbackValue(testNote);
    registerFallbackValue(TimerMode.work);
    registerFallbackValue('');
  });

  setUp(() {
    mockNotesRepository = MockNotesRepository();
    // Default stub so the constructor-time self-dispatch never hits an
    // unstubbed mock. Tests that need different data override this.
    when(() => mockNotesRepository.getNotes())
        .thenAnswer((_) async => Result.success(<Note>[]));
  });

  group('NotesBloc', () {
    test('initial state is NotesInitial synchronously after construction', () {
      // The self-dispatched NotesFetchRequested is queued; it has not been
      // processed yet at the moment of this synchronous assertion.
      final bloc = NotesBloc(mockNotesRepository);
      addTearDown(bloc.close);
      expect(bloc.state, NotesInitial());
    });

    blocTest<NotesBloc, NotesState>(
      'self-dispatches NotesFetchRequested on construction (success)',
      build: () {
        when(() => mockNotesRepository.getNotes())
            .thenAnswer((_) async => Result.success([testNote]));
        return NotesBloc(mockNotesRepository);
      },
      // No `act`: the constructor's add(NotesFetchRequested()) is the act.
      act: null,
      wait: const Duration(milliseconds: 50),
      expect: () => [NotesLoadInProgress(), NotesLoadSuccess([testNote])],
    );

    blocTest<NotesBloc, NotesState>(
      'self-dispatches NotesFetchRequested on construction (failure)',
      build: () {
        when(() => mockNotesRepository.getNotes()).thenAnswer(
          (_) async => Result.failure(NoteRetrievalFailure('badGateway')),
        );
        return NotesBloc(mockNotesRepository);
      },
      act: null,
      wait: const Duration(milliseconds: 50),
      expect: () => [
        NotesLoadInProgress(),
        NotesLoadFailure('NoteRetrievalFailure: badGateway'),
      ],
    );

    blocTest<NotesBloc, NotesState>(
      'emits [NotesLoadInProgress, NotesLoadSuccess, NotesLoadSuccess(prepended)] on NoteCreated success',
      build: () {
        when(() => mockNotesRepository.createNote(any(), any()))
            .thenAnswer((_) async => Result.success(testNote));
        return NotesBloc(mockNotesRepository);
      },
      // No `seed`: the self-dispatch owns the initial load.Expect the
      // self-dispatch emissions first, then the NoteCreated emission.
      wait: const Duration(milliseconds: 50),
      act: (bloc) => bloc.add(
        NoteCreated(content: 'hello', pomodoroState: TimerMode.work),
      ),
      expect: () => [
        NotesLoadInProgress(),
        NotesLoadSuccess(<Note>[]),
        NotesLoadSuccess([testNote]),
      ],
    );

    blocTest<NotesBloc, NotesState>(
      'does not change state on NoteCreated failure (only self-dispatch emits)',
      build: () {
        when(() => mockNotesRepository.createNote(any(), any())).thenAnswer(
          (_) async => Result.failure(NoteCreateFailure('badGateway')),
        );
        return NotesBloc(mockNotesRepository);
      },
      wait: const Duration(milliseconds: 50),
      act: (bloc) => bloc.add(
        NoteCreated(content: 'hello', pomodoroState: TimerMode.work),
      ),
      // Self-dispatch emits NotesLoadInProgress + NotesLoadSuccess([]);
      // the failed NoteCreated emits nothing.
      expect: () => [NotesLoadInProgress(), NotesLoadSuccess(<Note>[])],
    );

    blocTest<NotesBloc, NotesState>(
      'emits NotesLoadSuccess without deleted note on NoteDeleted success',
      build: () {
        when(() => mockNotesRepository.getNotes())
            .thenAnswer((_) async => Result.success([testNote]));
        when(() => mockNotesRepository.deleteNote(any()))
            .thenAnswer((_) async => Result<void>.success(null));
        return NotesBloc(mockNotesRepository);
      },
      wait: const Duration(milliseconds: 50),
      act: (bloc) => bloc.add(NoteDeleted('1')),
      expect: () => [
        NotesLoadInProgress(),
        NotesLoadSuccess([testNote]),
        NotesLoadSuccess([]),
      ],
    );

    blocTest<NotesBloc, NotesState>(
      'does not change state on NoteDeleted failure (only self-dispatch emits)',
      build: () {
        when(() => mockNotesRepository.getNotes())
            .thenAnswer((_) async => Result.success([testNote]));
        when(() => mockNotesRepository.deleteNote(any())).thenAnswer(
          (_) async => Result<void>.failure(
            NoteRetrievalFailure('badGateway'),
          ),
        );
        return NotesBloc(mockNotesRepository);
      },
      wait: const Duration(milliseconds: 50),
      act: (bloc) => bloc.add(NoteDeleted('1')),
      expect: () => [
        NotesLoadInProgress(),
        NotesLoadSuccess([testNote]),
      ],
    );

    blocTest<NotesBloc, NotesState>(
      'Retry: re-dispatching NotesFetchRequested from NotesLoadFailure re-fetches',
      build: () {
        final callCount = <int>[];
        when(() => mockNotesRepository.getNotes()).thenAnswer((_) async {
          callCount.add(1);
          if (callCount.length == 1) {
            return Result.failure(NoteRetrievalFailure('badGateway'));
          }
          return Result.success(<Note>[]);
        });
        return NotesBloc(mockNotesRepository);
      },
      wait: const Duration(milliseconds: 50),
      act: (bloc) => bloc.add(NotesFetchRequested()),
      // First 2 emissions from constructor self-dispatch (in-progress →
      // failure). Next 2 from the explicit Retry dispatch in `act`
      // (in-progress → success). 4 emissions proves the double-fetch.
      expect: () => [
        NotesLoadInProgress(),
        NotesLoadFailure('NoteRetrievalFailure: badGateway'),
        NotesLoadInProgress(),
        NotesLoadSuccess(<Note>[]),
      ],
    );
  });
}
```

> **Note on the Retry test:** `NotesRepository` is a private field on the bloc, so the call count is asserted via the emission sequence (4 emissions ⇒ 2 fetches) rather than a `verify` block. The constructor self-dispatch is the first fetch; the `act`-dispatched `NotesFetchRequested` is the second (simulating the `Retry` button).

- [ ] **Step 2: Run the new tests to verify they fail**

Run:
```bash
flutter test test/blocs/notes/notes_bloc_test.dart
```
Expected: FAIL — the `NotesBloc` constructor does not yet self-dispatch, so the `act: null` tests expect emissions that never arrive, and the `NoteCreated`/`NoteDeleted` tests expect `NotesLoadInProgress`/`NotesLoadSuccess(...)` from the self-dispatch as their first emissions but get only the `act`-driven emission (or nothing on failure). The synchronous `initial state is NotesInitial` test passes both before and after the change — that's expected.

- [ ] **Step 3: Implement self-dispatch in `NotesBloc`**

Replace the constructor of `lib/blocs/notes/notes_bloc.dart`:

Old (exact, `lib/blocs/notes/notes_bloc.dart:8-13`):
```dart
class NotesBloc extends Bloc<NotesEvent, NotesState> {
  NotesBloc(this._notesRepository) : super(NotesInitial()) {
    on<NotesFetchRequested>(_onFetchRequested);
    on<NoteCreated>(_onNoteCreated);
    on<NoteDeleted>(_onNoteDeleted);
  }

```

New:
```dart
class NotesBloc extends Bloc<NotesEvent, NotesState> {
  NotesBloc(this._notesRepository) : super(NotesInitial()) {
    on<NotesFetchRequested>(_onFetchRequested);
    on<NoteCreated>(_onNoteCreated);
    on<NoteDeleted>(_onNoteDeleted);

    // Self-dispatch the initial load so no view has to prime the BLoC.
    // Must come AFTER every on<...> handler is registered so the event has
    // a handler. Mirrors TimerBloc's self-contained initial state.
    add(NotesFetchRequested());
  }

```

Do not change `_onFetchRequested` — it stays unconditional so the `Retry` button (which dispatches `NotesFetchRequested` from `NotesLoadFailure`) keeps working.

- [ ] **Step 4: Run the bloc tests to verify they pass**

Run:
```bash
flutter test test/blocs/notes/notes_bloc_test.dart
```
Expected: PASS — all 8 tests pass.

- [ ] **Step 5: Run analyze**

Run:
```bash
flutter analyze lib/blocs/notes test/blocs/notes
```
Expected: zero issues.

- [ ] **Step 6: Commit with caveman-commit**

Use the `caveman-commit` skill to draft a message, then the temp-file pattern from `core-commands`:
```bash
mktemp
# → /tmp/tmp.XXXXXX
```
Write the commit message to that path with the Write tool, then:
```bash
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```
Suggested message (caveman-compressed):
```
refactor(notes-bloc): self-dispatch fetch in ctor

BLoC owns initial load; no view primes it.
```

---

### Task 3: Convert `NotesScreen` to `StatelessWidget`

**Files:**
- Modify: `lib/screens/notes_screen.dart`

- [ ] **Step 1: Convert the class header and remove `initState`**

Replace the class header + `State` opening + `initState` (exact, `lib/screens/notes_screen.dart:1-20`):

Old:
```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vipo/blocs/notes/notes_bloc.dart';
import 'package:vipo/blocs/notes/notes_event.dart';
import 'package:vipo/blocs/notes/notes_state.dart';
import 'package:vipo/blocs/timer/timer_bloc.dart';

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

```

New:
```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vipo/blocs/notes/notes_bloc.dart';
import 'package:vipo/blocs/notes/notes_event.dart';
import 'package:vipo/blocs/notes/notes_state.dart';
import 'package:vipo/blocs/timer/timer_bloc.dart';

/// Pure view for the notes list.
///
/// Owns no state. Reads notes state from the ambient [NotesBloc] (provided in
/// `main.dart` via [AppDeps]) and dispatches user interactions back to it via
/// [BlocBuilder]. The initial fetch is self-dispatched by [NotesBloc]'s
/// constructor — no view priming is needed.
class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

```

- [ ] **Step 2: Verify brace balance — no trailing-brace edit needed**

The replacement in Step 1 removed the `StatefulWidget` class (open + close braces) **and** the `class _NotesScreenState extends State<NotesScreen> {` opening line **and** the `initState` method (open + close braces). It did **not** remove:
- the `}` at `lib/screens/notes_screen.dart:155` that previously closed `_NotesScreenState`.

After Step 1, that surviving `}` now closes the new `NotesScreen extends StatelessWidget` class. Net brace count is unchanged and balanced — **do not delete any trailing brace**. The methods `_showAddNoteDialog`, `_formatDate`, and `build` keep their original 2-space indentation (they were `State` methods indented one level; as `StatelessWidget` methods they are indented one level too — identical).

Verify with:
```bash
flutter analyze lib/screens/notes_screen.dart
```
Expected: zero issues. If analyze reports an unbalanced-brace / `expected` error, the most likely cause is accidentally deleting the final `}` — restore it.

- [ ] **Step 3: Verify analyze + tests**

Run:
```bash
flutter analyze lib/screens/notes_screen.dart
flutter test test/screens/notes_screen_test.dart
```
Expected: analyze clean. The widget tests will FAIL (the bloc they pump was constructed in `setUp` and already fetched the default empty list; tests that re-stub `getNotes` to `[testNote]` no longer see that data). This is expected — Task 4 rewrites those tests. Do NOT commit yet.

- [ ] **Step 4: Do not commit yet**

This task is committed together with Task 4's test rewrite so the repo is never in a state where the widget tests are red on `main`.

---

### Task 4: Rewrite `test/screens/notes_screen_test.dart` for per-test bloc construction

**Files:**
- Test: `test/screens/notes_screen_test.dart` (rewrite)

With `NotesBloc` self-dispatching on construction, the bloc must be constructed AFTER the test's `getNotes()` stub is set. The old `setUp` constructed the bloc once with a default stub; tests that re-stubbed `getNotes` in the body never saw the re-stub because the fetch had already fired in `setUp`.

- [ ] **Step 1: Rewrite `test/screens/notes_screen_test.dart`**

Overwrite the entire file with:

```dart
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vipo/blocs/logs/logs_bloc.dart';
import 'package:vipo/blocs/notes/notes_bloc.dart';
import 'package:vipo/blocs/notes/notes_event.dart';
import 'package:vipo/blocs/timer/timer_bloc.dart';
import 'package:vipo/domain/models/log_action.dart';
import 'package:vipo/domain/models/log_entry.dart';
import 'package:vipo/domain/models/note.dart';
import 'package:vipo/domain/models/timer_mode.dart';
import 'package:vipo/domain/result.dart';
import 'package:vipo/repositories/logs_repository.dart';
import 'package:vipo/repositories/notes_repository.dart';
import 'package:vipo/screens/notes_screen.dart';

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
    // Default stub used by any test that does not override getNotes().
    when(() => mockNotesRepository.getNotes())
        .thenAnswer((_) async => Result.success(<Note>[]));

    addTearDown(() async {
      await logsBloc.close();
      await timerBloc.close();
    });
  });

  /// Constructs a [NotesBloc] against [mockNotesRepository] and registers
  /// tear-down to close it. Callers MUST set any `getNotes()` / `createNote()`
  /// / `deleteNote()` stubs BEFORE calling this, because [NotesBloc]
  /// self-dispatches the initial fetch in its constructor (issue #41).
  void makeNotesBloc() {
    notesBloc = NotesBloc(mockNotesRepository);
    addTearDown(() async => await notesBloc.close());
  }

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

  testWidgets('shows CupertinoActivityIndicator while notes are loading',
      (tester) async {
    final completer = Completer<Result<List<Note>>>();
    when(() => mockNotesRepository.getNotes())
        .thenAnswer((_) async => await completer.future);
    makeNotesBloc();

    await tester.pumpWidget(pumpSubject());
    await tester.pump();

    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

    completer.complete(Result.success(<Note>[]));
    await tester.pump();
    await tester.pump();
  });

  testWidgets('shows notes list on load success', (tester) async {
    when(() => mockNotesRepository.getNotes())
        .thenAnswer((_) async => Result.success([testNote]));
    makeNotesBloc();

    await tester.pumpWidget(pumpSubject());
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pump();

    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('shows empty-state message when notes list is empty',
      (tester) async {
    makeNotesBloc();

    await tester.pumpWidget(pumpSubject());
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pump();

    expect(find.text('No notes yet'), findsOneWidget);
  });

  testWidgets('shows error message and Retry button on load failure',
      (tester) async {
    when(() => mockNotesRepository.getNotes()).thenAnswer(
      (_) async => Result.failure(NoteRetrievalFailure('badGateway')),
    );
    makeNotesBloc();

    await tester.pumpWidget(pumpSubject());
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pump();

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
    makeNotesBloc();

    await tester.pumpWidget(pumpSubject());
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pump();
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pump();

    expect(find.text('No notes yet'), findsOneWidget);
    verify(() => mockNotesRepository.getNotes()).called(2);
  });

  testWidgets(
      'tapping + shows dialog, entering text, tapping Add dispatches NoteCreated',
      (tester) async {
    when(() => mockNotesRepository.createNote(any(), any()))
        .thenAnswer((_) async => Result.success(testNote));
    makeNotesBloc();

    await tester.pumpWidget(pumpSubject());
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(CupertinoIcons.add));
    await tester.pump();
    await tester.pump();

    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.byType(CupertinoTextField), findsOneWidget);

    await tester.enterText(find.byType(CupertinoTextField), 'hello');
    await tester.pump();

    await tester.tap(find.text('Add'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    verify(() => mockNotesRepository.createNote(any(), any())).called(1);
  });

  testWidgets(
      'tapping Cancel in the add note dialog does not create a note',
      (tester) async {
    makeNotesBloc();

    await tester.pumpWidget(pumpSubject());
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(CupertinoIcons.add));
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(CupertinoTextField), 'hello');
    await tester.pump();

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump();

    verifyNever(() => mockNotesRepository.createNote(any(), any()));
  });

  testWidgets('dispatching NoteDeleted removes a note from the list',
      (tester) async {
    when(() => mockNotesRepository.getNotes())
        .thenAnswer((_) async => Result.success([testNote]));
    when(() => mockNotesRepository.deleteNote(any()))
        .thenAnswer((_) async => Result<void>.success(null));
    makeNotesBloc();

    await tester.pumpWidget(pumpSubject());
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pump();

    expect(find.text('hello'), findsOneWidget);

    notesBloc.add(NoteDeleted('1'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pump();

    verify(() => mockNotesRepository.deleteNote('1')).called(1);
    expect(find.text('hello'), findsNothing);
  });
}
```

- [ ] **Step 2: Run the widget tests**

Run:
```bash
flutter test test/screens/notes_screen_test.dart
```
Expected: PASS — all 8 tests pass.

- [ ] **Step 3: Run analyze**

Run:
```bash
flutter analyze lib/screens/notes_screen.dart test/screens/notes_screen_test.dart
```
Expected: zero issues.

- [ ] **Step 4: Commit Tasks 3 + 4 together**

```bash
mktemp
# → /tmp/tmp.XXXXXX
```
Write the message, then:
```bash
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```
Suggested message:
```
refactor(notes-screen): convert to StatelessWidget

NotesBloc self-dispatches fetch; view no longer primes it.
```

---

### Task 5: Add `NotesRepository?` seam to `AppDeps`; keep smoke tests HTTP-free

**Files:**
- Modify: `lib/di.dart`
- Test: `test/widget_test.dart`
- Test: `test/di_test.dart`

`NotesBloc` now fetches on construction, so building the real `AppDeps()` graph fires a real `GET /notes` to `http://localhost:8080`. `di_test.dart`'s `tearDown` calls `deps.dispose()` which closes `NotesBloc` while that fetch is still pending → `StateError` when the rejected future resumes. Fix: an optional `NotesRepository?` constructor parameter on `AppDeps`. Production passes nothing (unchanged). Tests pass a `MockNotesRepository` with `getNotes → success([])`.

- [ ] **Step 1: Modify `AppDeps` constructor**

Replace `lib/di.dart` constructor (exact, `lib/di.dart:23-43`):

Old:
```dart
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
```

New:
```dart
class AppDeps {
  /// [notesRepository] is a test-only seam: when non-null it replaces the
  /// real `NotesRepository` so the `NotesBloc` constructor-time fetch
  /// (issue #41) does not hit the network in smoke tests. Production callers
  /// pass nothing and get the full `Dio` → `NotesApi` → `NotesService` →
  /// `NotesRepository` chain.
  AppDeps({NotesRepository? notesRepository}) {
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
    _notesRepository = notesRepository ?? NotesRepository(_notesService);

    _logsBloc = LogsBloc(_logsRepository);
    _timerBloc = TimerBloc(_logsBloc);
    _notesBloc = NotesBloc(_notesRepository);
  }
```

Add the `NotesRepository` import if not already present (`lib/di.dart` already imports it on line 10 — verify).

- [ ] **Step 2: Update `test/widget_test.dart`**

Replace the entire file with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vipo/blocs/timer/timer_bloc.dart';
import 'package:vipo/di.dart';
import 'package:vipo/domain/models/note.dart';
import 'package:vipo/domain/result.dart';
import 'package:vipo/main.dart';
import 'package:vipo/repositories/notes_repository.dart';
import 'package:vipo/screens/timer_screen.dart';

class _MockNotesRepository extends Mock implements NotesRepository {}

void main() {
  testWidgets('VipoApp builds TimerScreen within the provider tree',
      (tester) async {
    // NotesBloc self-dispatches its fetch in the constructor (issue #41).
    // Inject a mock notes repository so no real HTTP is made from the smoke
    // test.
    final notesRepository = _MockNotesRepository();
    when(() => notesRepository.getNotes())
        .thenAnswer((_) async => Result.success(<Note>[]));

    final deps = AppDeps(notesRepository: notesRepository);
    addTearDown(() async => await deps.dispose());

    await tester.pumpWidget(VipoApp(deps: deps));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(TimerScreen), findsOneWidget);
  });
}
```

Wait — `_MockNotesRepository` is declared at top-level with a private `_` prefix; that is fine in a test file. But `TimerBloc` import is unused in the test body. Drop it. Final imports (drop `package:vipo/blocs/timer/timer_bloc.dart`):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vipo/di.dart';
import 'package:vipo/domain/models/note.dart';
import 'package:vipo/domain/result.dart';
import 'package:vipo/main.dart';
import 'package:vipo/repositories/notes_repository.dart';
import 'package:vipo/screens/timer_screen.dart';

class _MockNotesRepository extends Mock implements NotesRepository {}

void main() {
  testWidgets('VipoApp builds TimerScreen within the provider tree',
      (tester) async {
    final notesRepository = _MockNotesRepository();
    when(() => notesRepository.getNotes())
        .thenAnswer((_) async => Result.success(<Note>[]));

    final deps = AppDeps(notesRepository: notesRepository);
    addTearDown(() async => await deps.dispose());

    await tester.pumpWidget(VipoApp(deps: deps));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(TimerScreen), findsOneWidget);
  });
}
```

- [ ] **Step 3: Update `test/di_test.dart`**

Replace the entire file with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vipo/blocs/logs/logs_bloc.dart';
import 'package:vipo/blocs/notes/notes_bloc.dart';
import 'package:vipo/blocs/timer/timer_bloc.dart';
import 'package:vipo/di.dart';
import 'package:vipo/domain/models/note.dart';
import 'package:vipo/domain/result.dart';
import 'package:vipo/repositories/logs_repository.dart';
import 'package:vipo/repositories/notes_repository.dart';

class _MockNotesRepository extends Mock implements NotesRepository {}

void main() {
  group('AppDeps', () {
    late _MockNotesRepository notesRepository;
    late AppDeps deps;

    setUp(() {
      notesRepository = _MockNotesRepository();
      when(() => notesRepository.getNotes())
          .thenAnswer((_) async => Result.success(<Note>[]));
      deps = AppDeps(notesRepository: notesRepository);
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

- [ ] **Step 4: Run the smoke tests**

Run:
```bash
flutter test test/widget_test.dart test/di_test.dart
```
Expected: both files PASS, no real HTTP made.

- [ ] **Step 5: Run analyze**

Run:
```bash
flutter analyze lib/di.dart test/widget_test.dart test/di_test.dart
```
Expected: zero issues.

- [ ] **Step 6: Commit**

```bash
mktemp
# → /tmp/tmp.XXXXXX
```
Write the message, then:
```bash
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```
Suggested message:
```
test(di): inject mock notes repo in smoke tests

NotesBloc fetches on ctor; seam avoids real HTTP in tests.
```

---

### Task 6: Update `AGENTS.md` to reflect `StatelessWidget` + self-dispatch

**Files:**
- Modify: `AGENTS.md`

- [ ] **Step 1: Architecture tree — `NotesScreen` line**

Replace `AGENTS.md:35`:

Old:
```
                                │    └─ NotesScreen (StatefulWidget — BlocBuilder; initState issues NotesFetchRequested)
```
New:
```
                                │    └─ NotesScreen (StatelessWidget — BlocBuilder only; NotesBloc self-dispatches the initial fetch on construction)
```

- [ ] **Step 2: Screens section — `notes_screen.dart` entry**

Replace `AGENTS.md:64`:

Old:
```
notes_screen.dart        → StatefulWidget — BlocBuilder; initState dispatches NotesFetchRequested; push from TimerScreen
```
New:
```
notes_screen.dart        → StatelessWidget — BlocBuilder only; NotesBloc self-dispatches NotesFetchRequested from its constructor; push from TimerScreen
```

- [ ] **Step 3: Gotchas — replace the `NotesScreen is a StatefulWidget` bullet**

Replace `AGENTS.md:111`:

Old:
```
- **NotesScreen is a StatefulWidget** (not a `StatelessWidget`): the `_NotesScreenState.initState` dispatches `NotesFetchRequested` once. The push from `TimerScreen` is a plain `CupertinoPageRoute`, not a named route — there is no router in this app.
```
New:
```
- **NotesScreen is a `StatelessWidget`** (converted in #41): it no longer dispatches `NotesFetchRequested` from `initState` — `NotesBloc` self-dispatches the fetch from its constructor (after all `on<Event>` handlers are registered), so no view primes it. The push from `TimerScreen` is a plain `CupertinoPageRoute`, not a named route — there is no router in this app.
```

- [ ] **Step 4: Key Patterns — add a self-dispatch note**

Insert a new bullet at the end of the "Key Patterns & Conventions" section (after the `flutter_animate` bullet, before the "Notification initialization" bullet). The `flutter_animate` bullet is `AGENTS.md:86`. Insert immediately after it:

New bullet to insert:
```
- **NotesBloc self-dispatches the initial fetch**: `NotesBloc`'s constructor registers all `on<Event>` handlers, then calls `add(NotesFetchRequested())` as its last statement. BLoCs own their initial state transitions — no view primes them. This mirrors `TimerBloc`'s self-contained `TimerInitial(work)` initial state. `AppDeps` accepts an optional `NotesRepository?` test-seam so smoke tests can inject a mock repository (the constructor-time fetch would otherwise hit the network).
```

- [ ] **Step 5: Run analyze (doc-only, but confirm no accidental code)**

Run:
```bash
flutter analyze
```
Expected: zero issues.

- [ ] **Step 6: Commit**

```bash
mktemp
# → /tmp/tmp.XXXXXX
```
Write the message, then:
```bash
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```
Suggested message:
```
docs(agents): notes screen is stateless; bloc self-dispatches
```

---

### Task 7: Full verification

**Files:**
- Run: `flutter analyze`, `flutter test`

- [ ] **Step 1: Full analyze**

Run:
```bash
flutter analyze
```
Expected: zero issues.

- [ ] **Step 2: Full test suite**

Run:
```bash
flutter test
```
Expected: ALL tests pass (BLoC tests, repository tests, service tests, mapper tests, model tests, widget tests, smoke tests, DI test).

- [ ] **Step 3: Self-review against acceptance criteria**

Walk through the issue's acceptance criteria explicitly:

- [ ] `NotesScreen` is a `StatelessWidget` and contains zero `initState` / `context.read` calls outside user-triggered callbacks → grep `lib/screens/notes_screen.dart` for `initState` (zero hits) and `context.read` (only inside `_showAddNoteDialog`, `Retry` onPressed, `Dismissible.confirmDismiss`).
- [ ] `NotesBloc` dispatches `NotesFetchRequested` from its constructor; no view primes it → `grep -n "add(NotesFetchRequested" lib/` shows exactly one hit in `notes_bloc.dart`.
- [ ] `flutter analyze` passes with zero warnings.
- [ ] `flutter test` passes.
- [ ] `AGENTS.md` documents `NotesScreen` as `StatelessWidget` and notes the self-dispatch in `NotesBloc`.
- [ ] No regression: retry still works (Retry test passes), add still works (`NoteCreated` test passes), delete still works (`NoteDeleted` test passes), notes load on first navigation (`shows notes list on load success` passes).

Commands to spot-check:
```bash
grep -n "initState" lib/screens/notes_screen.dart           # expect: no matches
grep -n "add(NotesFetchRequested" lib/blocs/notes/notes_bloc.dart lib/screens/notes_screen.dart  # expect: only notes_bloc.dart
grep -n "StatelessWidget" lib/screens/notes_screen.dart     # expect: one match
```

- [ ] **Step 4: Final commit if anything was tweaked during verification**

If Step 3 surfaced fixes, amend the current change:
```bash
jj describe   # review current message
# make edits ...
jj describe --stdin < "/tmp/tmp.XXXXXX"   # if message needs updating
```
Otherwise nothing to do — the plan is complete.

---

## Notes / trade-offs

- **Why not the `BlocListener` fallback (option 2 in the issue)?** It adds widget-tree machinery (`listenWhen` on `NotesInitial`) for no gain over the constructor self-dispatch, and still leaves the view responsible for priming. Option 1 is cleaner and matches `TimerBloc`'s self-contained initial state.
- **Why an `AppDeps` seam instead of a `NotesBloc` test-only constructor?** The seam lives at the composition root (idiomatic constructor DI, which `AGENTS.md` already champions) and is usable by any smoke/integration test. A `NotesBloc(autoFetch: false)` parameter would leak test concerns into production code.
- **Why does `_notesService` still get constructed when `notesRepository` is injected?** It keeps the `NotesApi`/`NotesService` part of the graph building (the di_test asserts the graph builds). Wastes one allocation in tests only; production is unaffected. Acceptable.
- **No retry regression:** `_onFetchRequested` stays unconditional — the `Retry` button dispatches `NotesFetchRequested` from `NotesLoadFailure`, which re-enters `_onFetchRequested` and re-fetches. Covered by the Retry bloc_test and the Retry widget test.
- **No `seed` in bloc tests:** seeding is wiped by the constructor-time fetch anyway, so the rewritten tests stub `getNotes` per-test instead and expect the self-dispatch emissions first. This is more honest about the bloc's real behavior.

## Related issues

- #41 — this plan
- #4 — parent architecture issue (spirit of "views = layout + animation only")
- #11 — the `TimerScreen` `StatelessWidget` refactor this mirrors
- #9 — `NotesBloc` definition (this plan augments its constructor behavior)
- #13 — `AGENTS.md` (Task 6 updates the now-stale `StatefulWidget` references)
# TimerBloc, LogsBloc, and NotesBloc Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use supervised-plan-execution to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create three immutable `flutter_bloc` BLoCs — `TimerBloc`, `LogsBloc`, `NotesBloc` — that replace the current `StatefulWidget` state management with event-driven `on<Event>` handlers, equatable events/states, and constructor-injected dependencies. No BLoC imports UI code, platform-specific packages, or generated API client code.

**Architecture:** Each BLoC lives in `lib/blocs/<name>/` with three files: `*_event.dart` (immutable events extending `Equatable`), `*_state.dart` (immutable states extending `Equatable`), and `*_bloc.dart` (the `Bloc<Event, State>` class with `on<Event>` handlers). `LogsBloc` and `NotesBloc` are independent — they accept their respective repositories via constructor. `TimerBloc` accepts `LogsBloc` via constructor and dispatches `LogCreated` events to it (fire-and-forget). All BLoCs depend only on repositories, domain models, and `flutter_bloc`/`equatable` — never on `lib/data/api/`, `lib/screens/`, `lib/widgets/`, or platform packages.

**Tech Stack:** Dart ^3.10.4, Flutter, `flutter_bloc` ^8.1.6, `equatable` ^2.0.5, `bloc_test` ^9.1.7 (dev), `mocktail` ^1.0.4 (already present), existing repositories and domain models from issues #5–#8.

---

## Prerequisites

This plan consumes outputs of the domain-models, services, and repositories issues (#5–#8). Before starting, the following must exist:

- `lib/domain/models/timer_mode.dart` — `TimerMode` enum with `duration`, `label`, `color`.
- `lib/domain/models/log_action.dart` — `LogAction` enum (`start`, `pause`, `resume`, `reset`, `expire`, `select`).
- `lib/domain/models/log_entry.dart` — `LogEntry` class with `id` (String), `pomodoroState` (TimerMode), `action` (LogAction), `createdAt` (DateTime).
- `lib/domain/models/note.dart` — `Note` class with `id`, `content`, `createdAt`.
- `lib/domain/result.dart` — `Result<T>` sealed class (`Success<T>`, `Failure<T>`) plus domain failure exceptions.
- `lib/repositories/logs_repository.dart` — `LogsRepository` with `createLog(LogEntry)` and `getLogs()`, returning `Result<T>`.
- `lib/repositories/notes_repository.dart` — `NotesRepository` with `createNote(Note, TimerMode)`, `getNotes()`, `deleteNote(String)`, returning `Result<T>`.
- `mocktail: ^1.0.4` present under `dev_dependencies` in `pubspec.yaml`.
- `flutter analyze` clean up to and including the repositories commit.

If any are missing, stop and run the prerequisite plans first.

---

## Spec Notes & Design Decisions

Read these before implementing — they resolve mismatches between the issue text and the codebase.

### SN-1. `TimerPaused` name collision — event vs. state

The issue defines `TimerPaused` as both an event ("user taps pause") and a state ("paused mid-countdown"). Both files (`timer_event.dart`, `timer_state.dart`) export a class named `TimerPaused`. When `timer_bloc.dart` imports both, Dart reports a name clash.

**Resolution:** Import `timer_state.dart` with the prefix `st` in `timer_bloc.dart`. Events are imported without prefix (they're used as type arguments in `on<Event>`). States use `st.TimerPaused(...)`, `st.TimerRunInProgress(...)`, etc. This preserves the issue's naming while resolving the conflict. Test files use the same convention.

### SN-2. `NoteCreated` carries `pomodoroState` — deviation from issue signature

The issue specifies `NoteCreated(content)`. But `NotesRepository.createNote(Note, TimerMode)` requires a `TimerMode` (the generated `CreateNoteRequest` needs `pomodoroState`, and the domain `Note` deliberately omits it — see the repositories plan's SN-1). The BLoC cannot invent a `TimerMode`; the caller must supply it.

**Resolution:** `NoteCreated` carries both `content` and `pomodoroState`:

```dart
class NoteCreated extends NotesEvent {
  const NoteCreated({required this.content, required this.pomodoroState});
  final String content;
  final TimerMode pomodoroState;
}
```

The UI layer (issue #11) reads the current `TimerMode` from `TimerBloc` state when dispatching `NoteCreated`.

### SN-3. `TimerState` has an abstract `mode` getter

All four `TimerState` subclasses carry a `TimerMode mode` field. Rather than casting in every handler (`if (state is TimerRunInProgress) ... current.mode`), we declare `TimerMode get mode;` on the abstract `TimerState` class. Each subclass overrides it with a `final` field. Handlers then write `state.mode` unconditionally — clean and DRY.

### SN-4. `TimerResumed` starts `Stream.periodic(1s)` — confirmed by issue comment

A GitHub comment on issue #9 asks: "shouldn't `TimerResumed` also start `Stream.periodic(1s)`?" The issue body says "On `TimerResumed`: restart subscription, emit `TimerRunInProgress`." "Restart subscription" means starting a new periodic stream. **Confirmed:** `TimerResumed` starts a new `Stream.periodic(1s)` subscription (just like `TimerStarted`), counting down from the current remaining seconds.

### SN-5. `LogCreated` event carries a `LogEntry` with placeholder fields

The issue says `LogCreated(entry)`. The domain `LogEntry` requires `id` and `createdAt`, but these are server-assigned (the `LogsService.createLog` ignores them). `TimerBloc` dispatches `LogCreated` with `LogEntry(id: '', pomodoroState: mode, action: action, createdAt: DateTime.now())`. The repository and service only read `action` and `pomodoroState` — the placeholders are harmless.

### SN-6. No `emit` call on failure — flutter_bloc filters equal states

The issue says "re-emit current state unchanged" on log/note create/delete failures. Flutter's `BlocBase.emit` performs `if (state == newState) return;` — with equatable states, re-emitting the same state is a no-op (no state change emitted to listeners). Therefore, simply **not calling `emit` on failure** is equivalent and cleaner. Tests use `expect: () => <State>[]` (empty expectation — no states emitted).

### SN-7. Fire-and-forget logs — `TimerBloc` never awaits `LogsBloc`

`TimerBloc._dispatchLog()` calls `_logsBloc.add(LogCreated(...))` synchronously and returns immediately. `add` on a `Bloc` is synchronous (queues the event). `TimerBloc` never listens to `LogsBloc` state or awaits its processing. If `LogsRepository.createLog` fails, `LogsBloc` handles the failure internally — `TimerBloc` state is unaffected. This satisfies "logs are fire-and-forget — failures do not affect timer state."

### SN-8. Stale test file carried forward — `test/widget_test.dart`

Per `AGENTS.md`, `test/widget_test.dart` is the stale Flutter template (references `MyApp`, `Icons.add`) and fails as-is. We **do not** touch it. Test commands target `test/blocs/` paths only.

### SN-9. `TimerTicked` adds `TimerCompleted` when reaching zero — not emit directly

The issue defines both `TimerTicked(remainingSeconds)` and `TimerCompleted` as separate events. When the tick decrements to zero:
1. `TimerTicked` handler checks `remainingSeconds <= 0`, and if so, calls `add(TimerCompleted())` (does not emit `TimerComplete` directly).
2. `TimerCompleted` handler cancels the subscription, emits `TimerComplete(state.mode)`, and dispatches `LogCreated(expire)`.

This keeps the expire log dispatch in one handler (`TimerCompleted`) rather than duplicating it in `TimerTicked`.

### SN-10. Import boundary — `package:flutter/cupertino.dart` is allowed transitively

The issue says "BLoCs should not import platform-specific packages" (e.g., `vibration`, `flutter_local_notifications`). `TimerMode` imports `package:flutter/cupertino.dart` for `CupertinoDynamicColor`. This is the Flutter framework itself (not a platform plugin), and `TimerMode` is a domain model that every layer already imports. The BLoC files never directly import `package:flutter/cupertino.dart` or any widget library — the import is transitive through `timer_mode.dart`, which is acceptable.

---

## File Structure

**Create:**

| File | Responsibility |
|------|----------------|
| `lib/blocs/timer/timer_event.dart` | `TimerEvent` abstract class + 7 event classes (`TimerStarted`, `TimerPaused`, `TimerResumed`, `TimerReset`, `TimerTicked`, `TimerModeChanged`, `TimerCompleted`) |
| `lib/blocs/timer/timer_state.dart` | `TimerState` abstract class (with `mode` getter) + 4 state classes (`TimerInitial`, `TimerRunInProgress`, `TimerPaused`, `TimerComplete`) |
| `lib/blocs/timer/timer_bloc.dart` | `TimerBloc` — own `StreamSubscription<int>` for periodic ticks, `on<Event>` handlers, dispatches `LogCreated` to injected `LogsBloc` |
| `lib/blocs/logs/logs_event.dart` | `LogsEvent` abstract class + `LogsFetchRequested`, `LogCreated` |
| `lib/blocs/logs/logs_state.dart` | `LogsState` abstract class + `LogsInitial`, `LogsLoadInProgress`, `LogsLoadSuccess`, `LogsLoadFailure` |
| `lib/blocs/logs/logs_bloc.dart` | `LogsBloc` — accepts `LogsRepository`, handles fetch and create events |
| `lib/blocs/notes/notes_event.dart` | `NotesEvent` abstract class + `NotesFetchRequested`, `NoteCreated`, `NoteDeleted` |
| `lib/blocs/notes/notes_state.dart` | `NotesState` abstract class + `NotesInitial`, `NotesLoadInProgress`, `NotesLoadSuccess`, `NotesLoadFailure` |
| `lib/blocs/notes/notes_bloc.dart` | `NotesBloc` — accepts `NotesRepository`, handles fetch, create, delete events |
| `test/blocs/timer/timer_bloc_test.dart` | `bloc_test` tests for `TimerBloc` using a real `LogsBloc` + `MockLogsRepository` |
| `test/blocs/logs/logs_bloc_test.dart` | `bloc_test` tests for `LogsBloc` using `MockLogsRepository` |
| `test/blocs/notes/notes_bloc_test.dart` | `bloc_test` tests for `NotesBloc` using `MockNotesRepository` |

**Modify:** `pubspec.yaml` (add `flutter_bloc`, `equatable`, `bloc_test` dependencies).

**Out of scope (explicitly deferred):** DI wiring / `BlocProvider` tree (#10/#14), UI refactoring (#11), `LogsBloc` → `TimerBloc` dependency refinement (#14 — this issue injects `LogsBloc` directly; #14 may switch to an interface).

---

## Task 1: Add `flutter_bloc`, `equatable`, and `bloc_test` dependencies

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add dependencies to `pubspec.yaml`**

In the `dependencies:` section, after the last existing dependency (`vibration: ^3.1.8`), add:

```yaml
  flutter_bloc: ^8.1.6
  equatable: ^2.0.5
```

In the `dev_dependencies:` section, after `mocktail: ^1.0.4`, add:

```yaml
  bloc_test: ^9.1.7
```

- [ ] **Step 2: Run `flutter pub get`**

Run: `flutter pub get`
Expected: Resolves dependencies successfully. `flutter_bloc`, `equatable`, and `bloc_test` appear in `.dart_tool/package_config.json`.

- [ ] **Step 3: Verify `flutter analyze` is clean**

Run: `flutter analyze`
Expected: No new warnings from the dependency additions.

- [ ] **Step 4: Commit with caveman-commit**

Use the caveman-commit skill to write a descriptive commit message. Then:

```bash
mktemp
# Returns: /tmp/tmp.XXXXXX
# Use Write tool to save commit message to that path
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

Suggested message: `chore(deps): add flutter_bloc, equatable, bloc_test`

---

## Task 2: Create `LogsBloc` events and states

**Files:**
- Create: `lib/blocs/logs/logs_event.dart`
- Create: `lib/blocs/logs/logs_state.dart`

- [ ] **Step 1: Create `lib/blocs/logs/logs_event.dart`**

```dart
import 'package:equatable/equatable.dart';
import 'package:vipo/domain/models/log_entry.dart';

abstract class LogsEvent extends Equatable {
  const LogsEvent();
}

class LogsFetchRequested extends LogsEvent {
  const LogsFetchRequested();

  @override
  List<Object?> get props => [];
}

class LogCreated extends LogsEvent {
  const LogCreated(this.entry);
  final LogEntry entry;

  @override
  List<Object?> get props => [entry];
}
```

- [ ] **Step 2: Create `lib/blocs/logs/logs_state.dart`**

```dart
import 'package:equatable/equatable.dart';
import 'package:vipo/domain/models/log_entry.dart';

abstract class LogsState extends Equatable {
  const LogsState();
}

class LogsInitial extends LogsState {
  const LogsInitial();

  @override
  List<Object?> get props => [];
}

class LogsLoadInProgress extends LogsState {
  const LogsLoadInProgress();

  @override
  List<Object?> get props => [];
}

class LogsLoadSuccess extends LogsState {
  const LogsLoadSuccess(this.entries);
  final List<LogEntry> entries;

  @override
  List<Object?> get props => [entries];
}

class LogsLoadFailure extends LogsState {
  const LogsLoadFailure(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
```

- [ ] **Step 3: Verify `flutter analyze` passes**

Run: `flutter analyze lib/blocs/logs/`
Expected: No warnings.

- [ ] **Step 4: Commit with caveman-commit**

```bash
mktemp
# Write commit message to temp file
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

Suggested message: `feat(blocs): add LogsBloc events and states`

---

## Task 3: Write failing `LogsBloc` tests

**Files:**
- Create: `test/blocs/logs/logs_bloc_test.dart`

- [ ] **Step 1: Create `test/blocs/logs/logs_bloc_test.dart`**

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vipo/blocs/logs/logs_bloc.dart';
import 'package:vipo/blocs/logs/logs_event.dart';
import 'package:vipo/blocs/logs/logs_state.dart';
import 'package:vipo/domain/models/log_action.dart';
import 'package:vipo/domain/models/log_entry.dart';
import 'package:vipo/domain/models/timer_mode.dart';
import 'package:vipo/domain/result.dart';
import 'package:vipo/repositories/logs_repository.dart';

class MockLogsRepository extends Mock implements LogsRepository {}

void main() {
  late MockLogsRepository mockLogsRepository;

  final testLogEntry = LogEntry(
    id: '1',
    pomodoroState: TimerMode.work,
    action: LogAction.start,
    createdAt: DateTime(2025, 1, 1),
  );

  setUp(() {
    mockLogsRepository = MockLogsRepository();
    registerFallbackValue(testLogEntry);
  });

  group('LogsBloc', () {
    test('initial state is LogsInitial', () {
      expect(LogsBloc(mockLogsRepository).state, LogsInitial());
    });

    blocTest<LogsBloc, LogsState>(
      'emits [LogsLoadInProgress, LogsLoadSuccess] on LogsFetchRequested success',
      build: () {
        when(() => mockLogsRepository.getLogs())
            .thenAnswer((_) async => Result.success([testLogEntry]));
        return LogsBloc(mockLogsRepository);
      },
      act: (bloc) => bloc.add(LogsFetchRequested()),
      expect: () => [LogsLoadInProgress(), LogsLoadSuccess([testLogEntry])],
    );

    blocTest<LogsBloc, LogsState>(
      'emits [LogsLoadInProgress, LogsLoadFailure] on LogsFetchRequested failure',
      build: () {
        when(() => mockLogsRepository.getLogs()).thenAnswer(
          (_) async => Result.failure(LogRetrievalFailure('connectionTimeout')),
        );
        return LogsBloc(mockLogsRepository);
      },
      act: (bloc) => bloc.add(LogsFetchRequested()),
      expect: () => [
        LogsLoadInProgress(),
        LogsLoadFailure('LogRetrievalFailure: connectionTimeout'),
      ],
    );

    blocTest<LogsBloc, LogsState>(
      'emits [LogsLoadSuccess with appended entry] on LogCreated success',
      build: () {
        when(() => mockLogsRepository.createLog(any()))
            .thenAnswer((_) async => Result.success(testLogEntry));
        return LogsBloc(mockLogsRepository);
      },
      seed: () => LogsLoadSuccess([]),
      act: (bloc) => bloc.add(LogCreated(testLogEntry)),
      expect: () => [LogsLoadSuccess([testLogEntry])],
    );

    blocTest<LogsBloc, LogsState>(
      'does not change state on LogCreated failure',
      build: () {
        when(() => mockLogsRepository.createLog(any())).thenAnswer(
          (_) async => Result.failure(LogCreateFailure('connectionTimeout')),
        );
        return LogsBloc(mockLogsRepository);
      },
      seed: () => LogsLoadSuccess([]),
      act: (bloc) => bloc.add(LogCreated(testLogEntry)),
      expect: () => <LogsState>[],
    );
  });
}
```

- [ ] **Step 2: Run tests to verify they fail (compilation error — `LogsBloc` not implemented)**

Run: `flutter test test/blocs/logs/logs_bloc_test.dart`
Expected: FAIL — `lib/blocs/logs/logs_bloc.dart` does not exist (URI target not found).

- [ ] **Step 3: Commit with caveman-commit**

```bash
mktemp
# Write commit message to temp file
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

Suggested message: `test(blocs): add failing LogsBloc tests`

---

## Task 4: Implement `LogsBloc` to make tests pass

**Files:**
- Create: `lib/blocs/logs/logs_bloc.dart`

- [ ] **Step 1: Create `lib/blocs/logs/logs_bloc.dart`**

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vipo/domain/models/log_entry.dart';
import 'package:vipo/domain/result.dart';
import 'package:vipo/repositories/logs_repository.dart';
import 'logs_event.dart';
import 'logs_state.dart';

class LogsBloc extends Bloc<LogsEvent, LogsState> {
  LogsBloc(this._logsRepository) : super(LogsInitial()) {
    on<LogsFetchRequested>(_onFetchRequested);
    on<LogCreated>(_onLogCreated);
  }

  final LogsRepository _logsRepository;

  Future<void> _onFetchRequested(
    LogsFetchRequested event,
    Emitter<LogsState> emit,
  ) async {
    emit(LogsLoadInProgress());
    final result = await _logsRepository.getLogs();
    if (result is Success<List<LogEntry>>) {
      emit(LogsLoadSuccess(result.value));
    } else if (result is Failure<List<LogEntry>>) {
      emit(LogsLoadFailure(result.exception.toString()));
    }
  }

  Future<void> _onLogCreated(
    LogCreated event,
    Emitter<LogsState> emit,
  ) async {
    final result = await _logsRepository.createLog(event.entry);
    if (result is Success<LogEntry>) {
      final currentEntries = state is LogsLoadSuccess
          ? (state as LogsLoadSuccess).entries
          : const <LogEntry>[];
      emit(LogsLoadSuccess([...currentEntries, result.value]));
    }
    // On failure: do not emit — state stays unchanged (see plan SN-6).
  }
}
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `flutter test test/blocs/logs/logs_bloc_test.dart`
Expected: PASS — all 4 tests pass.

- [ ] **Step 3: Verify `flutter analyze` passes**

Run: `flutter analyze lib/blocs/logs/`
Expected: No warnings.

- [ ] **Step 4: Commit with caveman-commit**

```bash
mktemp
# Write commit message to temp file
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

Suggested message: `feat(blocs): implement LogsBloc with fetch and create handlers`

---

## Task 5: Create `NotesBloc` events and states

**Files:**
- Create: `lib/blocs/notes/notes_event.dart`
- Create: `lib/blocs/notes/notes_state.dart`

- [ ] **Step 1: Create `lib/blocs/notes/notes_event.dart`**

```dart
import 'package:equatable/equatable.dart';
import 'package:vipo/domain/models/timer_mode.dart';

abstract class NotesEvent extends Equatable {
  const NotesEvent();
}

class NotesFetchRequested extends NotesEvent {
  const NotesFetchRequested();

  @override
  List<Object?> get props => [];
}

class NoteCreated extends NotesEvent {
  const NoteCreated({required this.content, required this.pomodoroState});

  final String content;
  final TimerMode pomodoroState;

  @override
  List<Object?> get props => [content, pomodoroState];
}

class NoteDeleted extends NotesEvent {
  const NoteDeleted(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}
```

- [ ] **Step 2: Create `lib/blocs/notes/notes_state.dart`**

```dart
import 'package:equatable/equatable.dart';
import 'package:vipo/domain/models/note.dart';

abstract class NotesState extends Equatable {
  const NotesState();
}

class NotesInitial extends NotesState {
  const NotesInitial();

  @override
  List<Object?> get props => [];
}

class NotesLoadInProgress extends NotesState {
  const NotesLoadInProgress();

  @override
  List<Object?> get props => [];
}

class NotesLoadSuccess extends NotesState {
  const NotesLoadSuccess(this.notes);
  final List<Note> notes;

  @override
  List<Object?> get props => [notes];
}

class NotesLoadFailure extends NotesState {
  const NotesLoadFailure(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
```

- [ ] **Step 3: Verify `flutter analyze` passes**

Run: `flutter analyze lib/blocs/notes/`
Expected: No warnings.

- [ ] **Step 4: Commit with caveman-commit**

```bash
mktemp
# Write commit message to temp file
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

Suggested message: `feat(blocs): add NotesBloc events and states`

---

## Task 6: Write failing `NotesBloc` tests

**Files:**
- Create: `test/blocs/notes/notes_bloc_test.dart`

- [ ] **Step 1: Create `test/blocs/notes/notes_bloc_test.dart`**

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
  });

  group('NotesBloc', () {
    test('initial state is NotesInitial', () {
      expect(NotesBloc(mockNotesRepository).state, NotesInitial());
    });

    blocTest<NotesBloc, NotesState>(
      'emits [NotesLoadInProgress, NotesLoadSuccess] on NotesFetchRequested success',
      build: () {
        when(() => mockNotesRepository.getNotes())
            .thenAnswer((_) async => Result.success([testNote]));
        return NotesBloc(mockNotesRepository);
      },
      act: (bloc) => bloc.add(NotesFetchRequested()),
      expect: () => [NotesLoadInProgress(), NotesLoadSuccess([testNote])],
    );

    blocTest<NotesBloc, NotesState>(
      'emits [NotesLoadInProgress, NotesLoadFailure] on NotesFetchRequested failure',
      build: () {
        when(() => mockNotesRepository.getNotes()).thenAnswer(
          (_) async => Result.failure(NoteRetrievalFailure('badGateway')),
        );
        return NotesBloc(mockNotesRepository);
      },
      act: (bloc) => bloc.add(NotesFetchRequested()),
      expect: () => [
        NotesLoadInProgress(),
        NotesLoadFailure('NoteRetrievalFailure: badGateway'),
      ],
    );

    blocTest<NotesBloc, NotesState>(
      'emits [NotesLoadSuccess with prepended note] on NoteCreated success',
      build: () {
        when(() => mockNotesRepository.createNote(any(), any()))
            .thenAnswer((_) async => Result.success(testNote));
        return NotesBloc(mockNotesRepository);
      },
      seed: () => NotesLoadSuccess([]),
      act: (bloc) => bloc.add(
        NoteCreated(content: 'hello', pomodoroState: TimerMode.work),
      ),
      expect: () => [NotesLoadSuccess([testNote])],
    );

    blocTest<NotesBloc, NotesState>(
      'does not change state on NoteCreated failure',
      build: () {
        when(() => mockNotesRepository.createNote(any(), any())).thenAnswer(
          (_) async => Result.failure(NoteCreateFailure('badGateway')),
        );
        return NotesBloc(mockNotesRepository);
      },
      seed: () => NotesLoadSuccess([]),
      act: (bloc) => bloc.add(
        NoteCreated(content: 'hello', pomodoroState: TimerMode.work),
      ),
      expect: () => <NotesState>[],
    );

    blocTest<NotesBloc, NotesState>(
      'emits [NotesLoadSuccess without deleted note] on NoteDeleted success',
      build: () {
        when(() => mockNotesRepository.deleteNote(any()))
            .thenAnswer((_) async => Result<void>.success(null));
        return NotesBloc(mockNotesRepository);
      },
      seed: () => NotesLoadSuccess([testNote]),
      act: (bloc) => bloc.add(NoteDeleted('1')),
      expect: () => [NotesLoadSuccess([])],
    );

    blocTest<NotesBloc, NotesState>(
      'does not change state on NoteDeleted failure',
      build: () {
        when(() => mockNotesRepository.deleteNote(any())).thenAnswer(
          (_) async => Result<void>.failure(
            NoteRetrievalFailure('badGateway'),
          ),
        );
        return NotesBloc(mockNotesRepository);
      },
      seed: () => NotesLoadSuccess([testNote]),
      act: (bloc) => bloc.add(NoteDeleted('1')),
      expect: () => <NotesState>[],
    );
  });
}
```

- [ ] **Step 2: Run tests to verify they fail (compilation error — `NotesBloc` not implemented)**

Run: `flutter test test/blocs/notes/notes_bloc_test.dart`
Expected: FAIL — `lib/blocs/notes/notes_bloc.dart` does not exist.

- [ ] **Step 3: Commit with caveman-commit**

```bash
mktemp
# Write commit message to temp file
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

Suggested message: `test(blocs): add failing NotesBloc tests`

---

## Task 7: Implement `NotesBloc` to make tests pass

**Files:**
- Create: `lib/blocs/notes/notes_bloc.dart`

- [ ] **Step 1: Create `lib/blocs/notes/notes_bloc.dart`**

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vipo/domain/models/note.dart';
import 'package:vipo/domain/models/timer_mode.dart';
import 'package:vipo/domain/result.dart';
import 'package:vipo/repositories/notes_repository.dart';
import 'notes_event.dart';
import 'notes_state.dart';

class NotesBloc extends Bloc<NotesEvent, NotesState> {
  NotesBloc(this._notesRepository) : super(NotesInitial()) {
    on<NotesFetchRequested>(_onFetchRequested);
    on<NoteCreated>(_onNoteCreated);
    on<NoteDeleted>(_onNoteDeleted);
  }

  final NotesRepository _notesRepository;

  Future<void> _onFetchRequested(
    NotesFetchRequested event,
    Emitter<NotesState> emit,
  ) async {
    emit(NotesLoadInProgress());
    final result = await _notesRepository.getNotes();
    if (result is Success<List<Note>>) {
      emit(NotesLoadSuccess(result.value));
    } else if (result is Failure<List<Note>>) {
      emit(NotesLoadFailure(result.exception.toString()));
    }
  }

  Future<void> _onNoteCreated(
    NoteCreated event,
    Emitter<NotesState> emit,
  ) async {
    final note = Note(
      id: '',
      content: event.content,
      createdAt: DateTime.now(),
    );
    final result = await _notesRepository.createNote(note, event.pomodoroState);
    if (result is Success<Note>) {
      final currentNotes = state is NotesLoadSuccess
          ? (state as NotesLoadSuccess).notes
          : const <Note>[];
      emit(NotesLoadSuccess([result.value, ...currentNotes]));
    }
    // On failure: do not emit — state stays unchanged (see plan SN-6).
  }

  Future<void> _onNoteDeleted(
    NoteDeleted event,
    Emitter<NotesState> emit,
  ) async {
    final result = await _notesRepository.deleteNote(event.id);
    if (result is Success<void>) {
      final currentNotes = state is NotesLoadSuccess
          ? (state as NotesLoadSuccess).notes
          : const <Note>[];
      emit(NotesLoadSuccess(
        currentNotes.where((n) => n.id != event.id).toList(),
      ));
    }
    // On failure: do not emit — state stays unchanged (see plan SN-6).
  }
}
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `flutter test test/blocs/notes/notes_bloc_test.dart`
Expected: PASS — all 6 tests pass.

- [ ] **Step 3: Verify `flutter analyze` passes**

Run: `flutter analyze lib/blocs/notes/`
Expected: No warnings.

- [ ] **Step 4: Commit with caveman-commit**

```bash
mktemp
# Write commit message to temp file
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

Suggested message: `feat(blocs): implement NotesBloc with fetch, create, delete handlers`

---

## Task 8: Create `TimerBloc` events and states

**Files:**
- Create: `lib/blocs/timer/timer_event.dart`
- Create: `lib/blocs/timer/timer_state.dart`

- [ ] **Step 1: Create `lib/blocs/timer/timer_event.dart`**

```dart
import 'package:equatable/equatable.dart';
import 'package:vipo/domain/models/timer_mode.dart';

abstract class TimerEvent extends Equatable {
  const TimerEvent();
}

class TimerStarted extends TimerEvent {
  const TimerStarted(this.mode);
  final TimerMode mode;

  @override
  List<Object?> get props => [mode];
}

class TimerPaused extends TimerEvent {
  const TimerPaused();

  @override
  List<Object?> get props => [];
}

class TimerResumed extends TimerEvent {
  const TimerResumed();

  @override
  List<Object?> get props => [];
}

class TimerReset extends TimerEvent {
  const TimerReset();

  @override
  List<Object?> get props => [];
}

class TimerTicked extends TimerEvent {
  const TimerTicked(this.remainingSeconds);
  final int remainingSeconds;

  @override
  List<Object?> get props => [remainingSeconds];
}

class TimerModeChanged extends TimerEvent {
  const TimerModeChanged(this.mode);
  final TimerMode mode;

  @override
  List<Object?> get props => [mode];
}

class TimerCompleted extends TimerEvent {
  const TimerCompleted();

  @override
  List<Object?> get props => [];
}
```

- [ ] **Step 2: Create `lib/blocs/timer/timer_state.dart`**

Note: `TimerState` declares an abstract `mode` getter (see SN-3) so handlers can access `state.mode` without casting.

```dart
import 'package:equatable/equatable.dart';
import 'package:vipo/domain/models/timer_mode.dart';

abstract class TimerState extends Equatable {
  const TimerState();

  TimerMode get mode;
}

class TimerInitial extends TimerState {
  const TimerInitial(this.mode, this.duration);

  @override
  final TimerMode mode;
  final int duration;

  @override
  List<Object?> get props => [mode, duration];
}

class TimerRunInProgress extends TimerState {
  const TimerRunInProgress(this.mode, this.remainingSeconds);

  @override
  final TimerMode mode;
  final int remainingSeconds;

  @override
  List<Object?> get props => [mode, remainingSeconds];
}

class TimerPaused extends TimerState {
  const TimerPaused(this.mode, this.remainingSeconds);

  @override
  final TimerMode mode;
  final int remainingSeconds;

  @override
  List<Object?> get props => [mode, remainingSeconds];
}

class TimerComplete extends TimerState {
  const TimerComplete(this.mode);

  @override
  final TimerMode mode;

  @override
  List<Object?> get props => [mode];
}
```

- [ ] **Step 3: Verify `flutter analyze` passes**

Run: `flutter analyze lib/blocs/timer/timer_event.dart lib/blocs/timer/timer_state.dart`
Expected: No warnings.

- [ ] **Step 4: Commit with caveman-commit**

```bash
mktemp
# Write commit message to temp file
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

Suggested message: `feat(blocs): add TimerBloc events and states`

---

## Task 9: Write failing `TimerBloc` tests

**Files:**
- Create: `test/blocs/timer/timer_bloc_test.dart`

Note: `TimerBloc` requires a `LogsBloc` dependency (implemented in Task 4). Tests use a real `LogsBloc` backed by a `MockLogsRepository` so we can verify that `LogCreated` events reach the repository.

The state file is imported as `st` (see SN-1) because `TimerPaused` exists as both an event and a state class.

- [ ] **Step 1: Create `test/blocs/timer/timer_bloc_test.dart`**

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vipo/blocs/logs/logs_bloc.dart';
import 'package:vipo/blocs/timer/timer_bloc.dart';
import 'package:vipo/blocs/timer/timer_event.dart';
import 'package:vipo/blocs/timer/timer_state.dart' as st;
import 'package:vipo/domain/models/log_action.dart';
import 'package:vipo/domain/models/log_entry.dart';
import 'package:vipo/domain/models/timer_mode.dart';
import 'package:vipo/domain/result.dart';
import 'package:vipo/repositories/logs_repository.dart';

class MockLogsRepository extends Mock implements LogsRepository {}

void main() {
  late MockLogsRepository mockLogsRepository;
  late LogsBloc logsBloc;

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
  });

  tearDown(() {
    logsBloc.close();
  });

  group('TimerBloc', () {
    test('initial state is TimerInitial with work mode', () {
      final bloc = TimerBloc(logsBloc);
      expect(
        bloc.state,
        st.TimerInitial(TimerMode.work, TimerMode.work.duration.inSeconds),
      );
      bloc.close();
    });

    blocTest<TimerBloc, st.TimerState>(
      'emits [TimerRunInProgress] on TimerStarted and dispatches LogCreated(start)',
      build: () => TimerBloc(logsBloc),
      act: (bloc) => bloc.add(TimerStarted(TimerMode.work)),
      expect: () => [
        st.TimerRunInProgress(TimerMode.work, TimerMode.work.duration.inSeconds),
      ],
      verify: (_) {
        verify(() => mockLogsRepository.createLog(
              any(
                that: isA<LogEntry>().having(
                  (e) => e.action,
                  'action',
                  LogAction.start,
                ),
              ),
            )).called(1);
      },
    );

    blocTest<TimerBloc, st.TimerState>(
      'emits [TimerRunInProgress] with decremented seconds on TimerTicked',
      build: () => TimerBloc(logsBloc),
      seed: () => st.TimerRunInProgress(TimerMode.work, 1200),
      act: (bloc) => bloc.add(TimerTicked(1199)),
      expect: () => [st.TimerRunInProgress(TimerMode.work, 1199)],
    );

    blocTest<TimerBloc, st.TimerState>(
      'emits [TimerComplete] on TimerTicked reaching zero and dispatches LogCreated(expire)',
      build: () => TimerBloc(logsBloc),
      seed: () => st.TimerRunInProgress(TimerMode.work, 1),
      act: (bloc) => bloc.add(TimerTicked(0)),
      expect: () => [st.TimerComplete(TimerMode.work)],
      verify: (_) {
        verify(() => mockLogsRepository.createLog(
              any(
                that: isA<LogEntry>().having(
                  (e) => e.action,
                  'action',
                  LogAction.expire,
                ),
              ),
            )).called(1);
      },
    );

    blocTest<TimerBloc, st.TimerState>(
      'emits [TimerPaused] on TimerPaused and dispatches LogCreated(pause)',
      build: () => TimerBloc(logsBloc),
      seed: () => st.TimerRunInProgress(TimerMode.work, 1000),
      act: (bloc) => bloc.add(TimerPaused()),
      expect: () => [st.TimerPaused(TimerMode.work, 1000)],
      verify: (_) {
        verify(() => mockLogsRepository.createLog(
              any(
                that: isA<LogEntry>().having(
                  (e) => e.action,
                  'action',
                  LogAction.pause,
                ),
              ),
            )).called(1);
      },
    );

    blocTest<TimerBloc, st.TimerState>(
      'emits [TimerRunInProgress] on TimerResumed and dispatches LogCreated(resume)',
      build: () => TimerBloc(logsBloc),
      seed: () => st.TimerPaused(TimerMode.work, 1000),
      act: (bloc) => bloc.add(TimerResumed()),
      expect: () => [st.TimerRunInProgress(TimerMode.work, 1000)],
      verify: (_) {
        verify(() => mockLogsRepository.createLog(
              any(
                that: isA<LogEntry>().having(
                  (e) => e.action,
                  'action',
                  LogAction.resume,
                ),
              ),
            )).called(1);
      },
    );

    blocTest<TimerBloc, st.TimerState>(
      'emits [TimerInitial] on TimerReset and dispatches LogCreated(reset)',
      build: () => TimerBloc(logsBloc),
      seed: () => st.TimerRunInProgress(TimerMode.work, 1000),
      act: (bloc) => bloc.add(TimerReset()),
      expect: () => [
        st.TimerInitial(TimerMode.work, TimerMode.work.duration.inSeconds),
      ],
      verify: (_) {
        verify(() => mockLogsRepository.createLog(
              any(
                that: isA<LogEntry>().having(
                  (e) => e.action,
                  'action',
                  LogAction.reset,
                ),
              ),
            )).called(1);
      },
    );

    blocTest<TimerBloc, st.TimerState>(
      'emits [TimerInitial] on TimerModeChanged and dispatches LogCreated(select)',
      build: () => TimerBloc(logsBloc),
      seed: () => st.TimerInitial(TimerMode.work, TimerMode.work.duration.inSeconds),
      act: (bloc) => bloc.add(TimerModeChanged(TimerMode.shortBreak)),
      expect: () => [
        st.TimerInitial(
          TimerMode.shortBreak,
          TimerMode.shortBreak.duration.inSeconds,
        ),
      ],
      verify: (_) {
        verify(() => mockLogsRepository.createLog(
              any(
                that: isA<LogEntry>().having(
                  (e) => e.action,
                  'action',
                  LogAction.select,
                ),
              ),
            )).called(1);
      },
    );
  });
}
```

- [ ] **Step 2: Run tests to verify they fail (compilation error — `TimerBloc` not implemented)**

Run: `flutter test test/blocs/timer/timer_bloc_test.dart`
Expected: FAIL — `lib/blocs/timer/timer_bloc.dart` does not exist.

- [ ] **Step 3: Commit with caveman-commit**

```bash
mktemp
# Write commit message to temp file
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

Suggested message: `test(blocs): add failing TimerBloc tests`

---

## Task 10: Implement `TimerBloc` to make tests pass

**Files:**
- Create: `lib/blocs/timer/timer_bloc.dart`

Note: `timer_state.dart` is imported as `st` (see SN-1) to avoid the `TimerPaused` name collision. Each handler that represents a user action dispatches a `LogCreated` event to the injected `LogsBloc` (fire-and-forget, see SN-7).

- [ ] **Step 1: Create `lib/blocs/timer/timer_bloc.dart`**

```dart
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vipo/blocs/logs/logs_bloc.dart';
import 'package:vipo/blocs/logs/logs_event.dart';
import 'package:vipo/domain/models/log_action.dart';
import 'package:vipo/domain/models/log_entry.dart';
import 'package:vipo/domain/models/timer_mode.dart';
import 'timer_event.dart';
import 'timer_state.dart' as st;

class TimerBloc extends Bloc<TimerEvent, st.TimerState> {
  TimerBloc(this._logsBloc)
      : super(
          st.TimerInitial(
            TimerMode.work,
            TimerMode.work.duration.inSeconds,
          ),
        ) {
    on<TimerStarted>(_onStarted);
    on<TimerPaused>(_onPaused);
    on<TimerResumed>(_onResumed);
    on<TimerReset>(_onReset);
    on<TimerTicked>(_onTicked);
    on<TimerModeChanged>(_onModeChanged);
    on<TimerCompleted>(_onCompleted);
  }

  final LogsBloc _logsBloc;
  StreamSubscription<int>? _tickerSubscription;

  /// Starts (or restarts) a periodic 1-second stream that emits decreasing
  /// remaining-seconds values and feeds them back as [TimerTicked] events.
  /// Uses `.take(remainingSeconds)` so the stream auto-completes when the
  /// countdown reaches zero.
  void _startTicker({required int remainingSeconds}) {
    _tickerSubscription?.cancel();
    _tickerSubscription = Stream.periodic(
      const Duration(seconds: 1),
      (tickCount) => remainingSeconds - tickCount - 1,
    ).take(remainingSeconds).listen(
          (remaining) => add(TimerTicked(remaining)),
        );
  }

  /// Fire-and-forget: dispatches a [LogCreated] event to the injected
  /// [LogsBloc]. Failures in the log pipeline never affect timer state.
  void _dispatchLog(LogAction action, TimerMode mode) {
    _logsBloc.add(
      LogCreated(
        LogEntry(
          id: '',
          pomodoroState: mode,
          action: action,
          createdAt: DateTime.now(),
        ),
      ),
    );
  }

  void _onStarted(TimerStarted event, Emitter<st.TimerState> emit) {
    emit(st.TimerRunInProgress(event.mode, event.mode.duration.inSeconds));
    _startTicker(remainingSeconds: event.mode.duration.inSeconds);
    _dispatchLog(LogAction.start, event.mode);
  }

  void _onPaused(TimerPaused event, Emitter<st.TimerState> emit) {
    _tickerSubscription?.cancel();
    final current = state;
    if (current is st.TimerRunInProgress) {
      emit(st.TimerPaused(current.mode, current.remainingSeconds));
      _dispatchLog(LogAction.pause, current.mode);
    }
  }

  void _onResumed(TimerResumed event, Emitter<st.TimerState> emit) {
    final current = state;
    if (current is st.TimerPaused) {
      emit(st.TimerRunInProgress(current.mode, current.remainingSeconds));
      _startTicker(remainingSeconds: current.remainingSeconds);
      _dispatchLog(LogAction.resume, current.mode);
    }
  }

  void _onReset(TimerReset event, Emitter<st.TimerState> emit) {
    _tickerSubscription?.cancel();
    final mode = state.mode;
    emit(st.TimerInitial(mode, mode.duration.inSeconds));
    _dispatchLog(LogAction.reset, mode);
  }

  void _onModeChanged(TimerModeChanged event, Emitter<st.TimerState> emit) {
    _tickerSubscription?.cancel();
    emit(st.TimerInitial(event.mode, event.mode.duration.inSeconds));
    _dispatchLog(LogAction.select, event.mode);
  }

  void _onTicked(TimerTicked event, Emitter<st.TimerState> emit) {
    if (event.remainingSeconds <= 0) {
      add(TimerCompleted());
    } else {
      emit(st.TimerRunInProgress(state.mode, event.remainingSeconds));
    }
  }

  void _onCompleted(TimerCompleted event, Emitter<st.TimerState> emit) {
    _tickerSubscription?.cancel();
    emit(st.TimerComplete(state.mode));
    _dispatchLog(LogAction.expire, state.mode);
  }

  @override
  Future<void> close() {
    _tickerSubscription?.cancel();
    return super.close();
  }
}
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `flutter test test/blocs/timer/timer_bloc_test.dart`
Expected: PASS — all 8 tests pass.

- [ ] **Step 3: Verify `flutter analyze` passes**

Run: `flutter analyze lib/blocs/timer/`
Expected: No warnings.

- [ ] **Step 4: Commit with caveman-commit**

```bash
mktemp
# Write commit message to temp file
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

Suggested message: `feat(blocs): implement TimerBloc with tick stream and log dispatch`

---

## Task 11: Final verification — acceptance criteria check

**Files:**
- Verify all `lib/blocs/` files
- Verify all `test/blocs/` files

- [ ] **Step 1: Run the full BLoC test suite**

Run: `flutter test test/blocs/`
Expected: All tests pass (LogsBloc: 4, NotesBloc: 6, TimerBloc: 8 = 18 total).

- [ ] **Step 2: Run `flutter analyze` across the entire project**

Run: `flutter analyze`
Expected: Zero warnings. (The stale `test/widget_test.dart` may surface its own pre-existing errors — those are out of scope per AGENTS.md. If `flutter analyze` flags any file under `lib/blocs/`, fix it.)

- [ ] **Step 3: Verify no BLoC file imports forbidden paths**

Run: `grep -r "data/api\|screens/\|widgets/\|notifications\.dart\|vibration" lib/blocs/`
Expected: No matches — no BLoC file imports from `lib/data/api/`, `lib/screens/`, `lib/widgets/`, `notifications.dart`, or `vibration`.

- [ ] **Step 4: Verify all BLoC files use equatable**

Run: `grep -r "extends Equatable" lib/blocs/ | wc -l`
Expected: At least 7 (3 abstract bases: TimerEvent, TimerState (st), LogsEvent, LogsState, NotesEvent, NotesState + concrete classes). The exact count should be 3 event bases + 3 state bases + all concrete classes. Verify none of the event/state files is missing `Equatable`.

- [ ] **Step 5: Verify TimerBloc does not import platform packages**

Run: `grep "vibration\|flutter_local_notifications\|notifications" lib/blocs/timer/timer_bloc.dart`
Expected: No matches.

- [ ] **Step 6: Verify TimerBloc closes its StreamSubscription**

Run: `grep "_tickerSubscription?.cancel" lib/blocs/timer/timer_bloc.dart`
Expected: At least 2 matches (in `close()` and at least one handler).

- [ ] **Step 7: Commit with caveman-commit (if any fixes were made)**

If the steps above required any fixes, commit them. Otherwise skip.

```bash
mktemp
# Write commit message to temp file
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

Suggested message: `test(blocs): verify acceptance criteria for all BLoCs`
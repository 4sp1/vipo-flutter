# LogsService & NotesService Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use supervised-plan-execution to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create thin, stateless service wrappers (`LogsService`, `NotesService`) that delegate to the generated `dart-dio` API client (`LogsApi`, `NotesApi` via constructor injection) and return only domain models (`LogEntry`, `Note`), so repositories can consume the data layer without coupling to generated types.

**Architecture:** A new `lib/data/services/` package beside the existing `lib/data/api/`. Each service holds one immutable reference to its injected `LogsApi` / `NotesApi` instance and exposes pure async methods that (1) build the generated request DTO, (2) call exactly one generated API method, (3) read `Response<T>.data` and map every response into domain models via the existing `lib/domain/mappers/` functions. No mutable state, no caching, no error normalization — `DioException` propagates upward. DI wiring (`lib/di.dart`) is explicitly deferred to issue #4 and not touched here.

**Tech Stack:** Dart ^3.10.4, Flutter, `flutter_test`, `mocktail` (new dev dependency for service unit tests), existing generated OpenAPI client under `lib/data/api/`, existing domain mappers under `lib/domain/mappers/`.

---

## Spec Notes & Design Decisions

Read these before implementing — they resolve mismatches between the issue text and the actual generated code.

### SN-1. Generated API method names differ from the issue's shorthand

The issue text uses conceptual method names (`createLog`, `getLogs`, `getNotes`, `getNoteById`). The generated `dart-dio` classes have slightly different names. The service methods keep the issue's public names; internally they call the generated ones.

| Service method (public) | Generated API method called | Generated return type |
|--------------------------|------------------------------|-----------------------|
| `LogsService.createLog(LogEntry)` | `LogsApi.createLogEntry(createLogEntryRequest:)` | `Future<Response<api.LogEntry>>` |
| `LogsService.getLogs()` | `LogsApi.listLogEntries()` | `Future<Response<api.LogEntryList>>` |
| `NotesService.createNote(Note, TimerMode)` | `NotesApi.createNote(createNoteRequest:)` | `Future<Response<api.Note>>` |
| `NotesService.getNotes()` | `NotesApi.listNotes()` | `Future<Response<api.NoteList>>` |
| `NotesService.getNoteById(String)` | `NotesApi.getNote(id: int)` | `Future<Response<api.Note>>` |
| `NotesService.deleteNote(String)` | `NotesApi.deleteNote(id: int)` | `Future<Response<void>>` |

There is **no** single-log GET-by-ID on `LogsApi`, so `LogsService` exposes only `createLog` and `getLogs` (matches the issue scope). `NotesApi.getNote` takes `int id` (named param), so the service `String -> int.parse`-converts before calling.

### SN-2. `createNote` needs a `TimerMode` parameter — deviation from issue signature

The issue specifies `Future<Note> createNote(Note note)`. But the generated `NotesApi.createNote` requires a `CreateNoteRequest` with a **required** `pomodoroState` field, and the domain `Note` (per issue #6 / SN-2 of the prior plan) deliberately does not model `pomodoroState`. A thin service cannot invent this value, so we deviate and add it as an explicit parameter:

```dart
Future<Note> createNote(Note note, TimerMode pomodoroState)
```

Rationale: this mirrors the existing `toApiNote(Note, {required api.PomodoroState pomodoroState})` mapper decision (issue #6 SN-2). Repositories (issue #4) will pass the contextual timer-mode at creation time. The issue's other signatures are honored verbatim.

### SN-3. Added request builders to the mapper files (not inline in services)

The existing mappers (`toApiLogEntry`, `toApiNote`) build **full** entity DTOs and would require `int.parse(id)` — invalid for `create` requests because the server assigns the `id`. So we add two small new mapper functions, one per mapper file, that build the create-request DTOs from domain inputs:

```dart
api.CreateLogEntryRequest toCreateLogEntryRequest(LogEntry entry)   // log_entry_mapper.dart
api.CreateNoteRequest    toCreateNoteRequest(Note note, TimerMode pomodoroState)  // note_mapper.dart
```

Why in the mapper files (not inline in services): keeps each service method as exactly **one** mapping step + **one** API call (the issue's "thin" rule), reuses the existing private `_toApiLogAction` helper that already lives in `log_entry_mapper.dart`, and is DRY/testable in isolation. Services may import generated API classes per the design rules; the new mappers are still thin glue with no business logic.

### SN-4. List DTOs use nullable `entries` / `notes` — guard with `?? const []`

The generated `LogEntryList.entries` and `NoteList.notes` are both `List<...>?`. Services must not dereference them blindly. Both services default a null list to `const <api.LogEntry>[]` / `const <api.Note>[]` before mapping. No business rule about totals — `total` is ignored.

### SN-5. `Response<T>.data` is `T?` — services use `!` after the awaited call

Generated methods return `Future<Response<T>>`; `Response<T>.data` is `T?` (the body may be missing on error responses that Dio still resolves). For success-path happy paths the services assert `!` and map; if the server returns `null` body for a 2xx, the `!` throws — acceptable because such responses indicate a broken server contract, and the wrapping repository (#4) will normalize errors. Tests cover the populated-data path.

### SN-6. `mocktail` for service tests (new dev dependency)

There is currently no mocking lib in `pubspec.yaml`. The generated `LogsApi` / `NotesApi` are concrete classes with a private `final Dio _dio` — they cannot be cleanly subclassed by hand. We add [mocktail](https://pub.dev/packages/mocktail) (`^1.0.4`) as a dev dependency. Test doubles are `class MockLogsApi extends Mock implements api.LogsApi {}` (using `implements`, so the private `_dio` is never constructed; mocktail's `noSuchMethod` handles all calls). Custom types passed to `any(named:)` require `registerFallbackValue` in a `setUpAll` block — `int id` and `String id` are primitives and do not need fallback values in mocktail.

### SN-7. `flutter test` is partially pre-broken (out of scope)

Per `AGENTS.md`, `test/widget_test.dart` is the stale Flutter template (references `MyApp`, `Icons.add`) and fails as-is. We **do not** touch it. Our tests are scoped to `test/domain/` and `test/data/services/`. Full-suite runs in this plan target the new test files only (or `flutter test test/domain test/data`).

### SN-8. Import alias `as api`

To avoid name collisions (`LogEntry`, `Note`, `LogAction` exist in both layers), every service and every new mapper uses `import '...' as api` for generated files and un-aliased imports for domain types. The existing mappers and tests already follow this convention.

### SN-9. `flutter analyze` acceptance gate

The acceptance criteria require `flutter analyze` to pass with zero warnings. All generated API files under `lib/data/api/` are excluded from lint via `// ignore_for_file: type=lint` headers (per `AGENTS.md`) — our new hand-authored files do **not** add that header and must be warning-free, matching the existing domain files.

---

## File Structure

**Create:**

| File | Responsibility |
|------|----------------|
| `lib/data/services/logs_service.dart` | `LogsService` — thin wrapper over `LogsApi`; `createLog`, `getLogs` |
| `lib/data/services/notes_service.dart` | `NotesService` — thin wrapper over `NotesApi`; `createNote`, `getNotes`, `getNoteById`, `deleteNote` |
| `test/data/services/logs_service_test.dart` | Unit tests for `LogsService` using `mocktail`'s `MockLogsApi` |
| `test/data/services/notes_service_test.dart` | Unit tests for `NotesService` using `mocktail`'s `MockNotesApi` |

**Modify:**

| File | Change |
|------|--------|
| `lib/domain/mappers/log_entry_mapper.dart` | Add `toCreateLogEntryRequest(LogEntry)` builder |
| `lib/domain/mappers/note_mapper.dart` | Add `toCreateNoteRequest(Note, TimerMode)` builder |
| `test/domain/log_entry_mapper_test.dart` | Add `group('toCreateLogEntryRequest', ...)` tests |
| `test/domain/note_mapper_test.dart` | Add `group('toCreateNoteRequest', ...)` tests |
| `pubspec.yaml` | Add `mocktail: ^1.0.4` under `dev_dependencies:` |

**Delete:** none.

**Out of scope (explicitly deferred):** `lib/di.dart` wiring, repository layer (#4), error normalization — services let `DioException` propagate.

---

## Task 1: Add `toCreateLogEntryRequest` request mapper

**Files:**
- Modify: `lib/domain/mappers/log_entry_mapper.dart` (append a new function)
- Test: `test/domain/log_entry_mapper_test.dart` (append a `group`)

- [ ] **Step 1: Write the failing test**

Open `test/domain/log_entry_mapper_test.dart`. Add a new import line at the top (after the existing `import '...' as api;` lines, before the domain imports):

```dart
import 'package:vipo/data/api/src/model/create_log_entry_request.dart' as api;
```

Append this group right before the closing `}` of `main()` (indentation matches the surrounding `group('toApiLogEntry', (...)` block at column 2):

```dart
  group('toCreateLogEntryRequest', () {
    test('builds request from action and pomodoroState; omits id/createdAt/payload', () {
      final domain = LogEntry(
        id: '0',
        pomodoroState: TimerMode.shortBreak,
        action: LogAction.pause,
        createdAt: DateTime.utc(2026, 1, 2, 10, 0, 0),
      );
      final req = toCreateLogEntryRequest(domain);
      expect(req.action, api.LogAction.pause);
      expect(req.session, api.PomodoroState.shortBreak);
      expect(req.payload, isNull);
    });

    test('round-trips all six LogActions', () {
      for (final action in LogAction.values) {
        final domain = LogEntry(
          id: '7',
          pomodoroState: TimerMode.work,
          action: action,
          createdAt: ts,
        );
        expect(toCreateLogEntryRequest(domain).action.name, action.name);
      }
    });

    test('round-trips all three TimerModes', () {
      for (final mode in TimerMode.values) {
        final domain = LogEntry(
          id: '7',
          pomodoroState: mode,
          action: LogAction.start,
          createdAt: ts,
        );
        expect(toCreateLogEntryRequest(domain).session, isA<api.PomodoroState>());
      }
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/log_entry_mapper_test.dart -p vm`
Expected: FAIL — `toCreateLogEntryRequest` is undefined; analyzer/test errors with `Method not found: 'toCreateLogEntryRequest'`.

- [ ] **Step 3: Write minimal implementation**

Open `lib/domain/mappers/log_entry_mapper.dart`. Add this import line just below the existing `import 'package:vipo/data/api/src/model/log_action.dart' as api;` line (line 2):

```dart
import 'package:vipo/data/api/src/model/create_log_entry_request.dart' as api;
```

Append this function at the very end of the file (after `toApiLogEntry`, matching its indentation at column 0):

```dart

/// Builds the generated `CreateLogEntryRequest` from a domain `LogEntry`.
///
/// Only `action` and `session` are carried over — the server assigns `id`
/// and `timestamp`, and `payload` is intentionally left `null`. Reuses the
/// private `_toApiLogAction` helper defined above.
api.CreateLogEntryRequest toCreateLogEntryRequest(LogEntry domainEntry) {
  return api.CreateLogEntryRequest(
    action: _toApiLogAction(domainEntry.action),
    session: toApiPomodoroState(domainEntry.pomodoroState),
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/domain/log_entry_mapper_test.dart -p vm`
Expected: PASS — all groups green, including the new `toCreateLogEntryRequest` group.

- [ ] **Step 5: Confirm `flutter analyze` is clean on the modified files**

Run: `flutter analyze lib/domain/mappers/log_entry_mapper.dart test/domain/log_entry_mapper_test.dart`
Expected: "No issues found!"

- [ ] **Step 6: Commit with caveman-commit**

Use the `caveman-commit` skill to write a descriptive commit message. Then use the temp file pattern from the core-commands skill for the commit message:

```bash
mktemp
# Tool returns: /tmp/tmp.XXXXXX
```

Use the Write tool to save the commit message to that path, for example:

```
feat(mappers): add LogEntry create-request builder

Wraps generated CreateLogEntryRequest construction so services can
delegate without duplicating action/session mapping. Server-assigned
id/timestamp/payload omitted, mirroring toApiLogEntry's contract.

Refs #7
```

Then:

```bash
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

---

## Task 2: Add `toCreateNoteRequest` request mapper

**Files:**
- Modify: `lib/domain/mappers/note_mapper.dart` (append a new function; reuse `TimerMode`)
- Test: `test/domain/note_mapper_test.dart` (append a `group`)

- [ ] **Step 1: Write the failing test**

Open `test/domain/note_mapper_test.dart`. Add two new import lines at the top, after the existing `import '...' as api;` lines and before the domain imports:

```dart
import 'package:vipo/data/api/src/model/create_note_request.dart' as api;
import 'package:vipo/domain/models/timer_mode.dart';
```

Append this group right before the closing `}` of `main()` (indentation at column 2):

```dart
  group('toCreateNoteRequest', () {
    test('maps content and supplied pomodoroState; omits id/createdAt', () {
      final domain = Note(id: '0', content: 'hello', createdAt: ts);
      final req = toCreateNoteRequest(domain, TimerMode.shortBreak);
      expect(req.note, 'hello');
      expect(req.pomodoroState, api.PomodoroState.shortBreak);
    });

    test('round-trips all three TimerModes', () {
      final domain = Note(id: '0', content: 'x', createdAt: ts);
      const expected = <TimerMode, api.PomodoroState>{
        TimerMode.work: api.PomodoroState.work,
        TimerMode.shortBreak: api.PomodoroState.shortBreak,
        TimerMode.longBreak: api.PomodoroState.longBreak,
      };
      for (final entry in expected.entries) {
        expect(toCreateNoteRequest(domain, entry.key).pomodoroState, entry.value);
      }
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/note_mapper_test.dart -p vm`
Expected: FAIL — `toCreateNoteRequest` is undefined; `Method not found: 'toCreateNoteRequest'`.

- [ ] **Step 3: Write minimal implementation**

Open `lib/domain/mappers/note_mapper.dart`. Add these two import lines just after the existing `import 'package:vipo/data/api/src/model/pomodoro_state.dart' as api;` line (line 2):

```dart
import 'package:vipo/data/api/src/model/create_note_request.dart' as api;
import 'package:vipo/domain/mappers/pomodoro_state_mapper.dart';
import 'package:vipo/domain/models/timer_mode.dart';
```

Append this function at the very end of the file (after `toApiNote`, indentation at column 0):

```dart

/// Builds the generated `CreateNoteRequest` from a domain `Note` plus the
/// contextual timer-mode. Only `note` (domain content) and `pomodoroState`
/// are carried over — the server assigns `id` and `createdAt`.
api.CreateNoteRequest toCreateNoteRequest(Note domainNote, TimerMode pomodoroState) {
  return api.CreateNoteRequest(
    note: domainNote.content,
    pomodoroState: toApiPomodoroState(pomodoroState),
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/domain/note_mapper_test.dart -p vm`
Expected: PASS — all groups green, including the new `toCreateNoteRequest` group.

- [ ] **Step 5: Confirm `flutter analyze` is clean on the modified files**

Run: `flutter analyze lib/domain/mappers/note_mapper.dart test/domain/note_mapper_test.dart`
Expected: "No issues found!"

- [ ] **Step 6: Commit with caveman-commit**

Use the `caveman-commit` skill to write a descriptive commit message. Then use the temp file pattern from the core-commands skill:

```bash
mktemp
# Tool returns: /tmp/tmp.XXXXXX
```

Use the Write tool to save the commit message to that path, for example:

```
feat(mappers): add Note create-request builder

Wraps generated CreateNoteRequest construction, taking the contextual
TimerMode that the domain Note deliberately omits (per #6 SN-2).
Server-assigned id/createdAt omitted.

Refs #7
```

Then:

```bash
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

---

## Task 3: Add `mocktail` dev dependency

**Files:**
- Modify: `pubspec.yaml` (add one line under `dev_dependencies:`)

- [ ] **Step 1: Add the dependency**

Open `pubspec.yaml`. Under the existing `dev_dependencies:` block, add a `mocktail` line after `json_serializable: ^6.8.0` so the block becomes:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.13
  flutter_launcher_icons: "^0.14.4"
  flutter_lints: ^6.0.0
  json_serializable: ^6.8.0
  mocktail: ^1.0.4
```

- [ ] **Step 2: Resolve dependencies**

Run: `flutter pub get`
Expected: terminates with `Got dependencies!` (or similar) and a new line for `mocktail-1.0.x` in the output.

- [ ] **Step 3: Confirm `flutter analyze` still clean project-wide**

Run: `flutter analyze`
Expected: "No issues found!" (no analyzer regression from adding the package).

- [ ] **Step 4: Commit with caveman-commit**

Use the `caveman-commit` skill to write a descriptive commit message. Then use the temp file pattern from the core-commands skill:

```bash
mktemp
```

Use the Write tool to save the commit message to that path, for example:

```
chore(deps): add mocktail for service tests

Mocktail lets service unit tests stub generated LogsApi/NotesApi
without subclassing their final Dio field; no build_runner needed.

Refs #7
```

Then:

```bash
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

---

## Task 4: Create `LogsService` (TDD)

**Files:**
- Create: `lib/data/services/logs_service.dart`
- Test: `test/data/services/logs_service_test.dart`

- [ ] **Step 1: Write the failing test**

Create the test directory and file `test/data/services/logs_service_test.dart` with this content exactly:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vipo/data/api/vipo_api.dart' as api;
import 'package:vipo/data/services/logs_service.dart';
import 'package:vipo/domain/models/log_action.dart';
import 'package:vipo/domain/models/log_entry.dart';
import 'package:vipo/domain/models/timer_mode.dart';

class MockLogsApi extends Mock implements api.LogsApi {}

void main() {
  late MockLogsApi mockApi;
  late LogsService service;
  final ts = DateTime.utc(2026, 1, 1, 9, 0, 0);

  setUpAll(() {
    registerFallbackValue(
      api.CreateLogEntryRequest(
        action: api.LogAction.start,
        session: api.PomodoroState.work,
      ),
    );
  });

  setUp(() {
    mockApi = MockLogsApi();
    service = LogsService(mockApi);
  });

  Response<T> okResponse<T>(T data) => Response<T>(
        requestOptions: RequestOptions(path: '/any'),
        data: data,
        statusCode: 200,
      );

  group('LogsService.createLog', () {
    test('builds request, calls LogsApi.createLogEntry, returns mapped LogEntry',
        () async {
      final apiEntry = api.LogEntry(
        id: 42,
        action: api.LogAction.start,
        session: api.PomodoroState.work,
        timestamp: ts,
      );
      when(() => mockApi.createLogEntry(
              createLogEntryRequest: any(named: 'createLogEntryRequest')))
          .thenAnswer((_) async => okResponse<api.LogEntry>(apiEntry));

      final input = LogEntry(
        id: '0',
        pomodoroState: TimerMode.work,
        action: LogAction.start,
        createdAt: ts,
      );
      final result = await service.createLog(input);

      expect(result, isA<LogEntry>());
      expect(result.id, '42');
      expect(result.action, LogAction.start);
      expect(result.pomodoroState, TimerMode.work);
      expect(result.createdAt, ts);
      final captured = verify(
        () => mockApi.createLogEntry(
            createLogEntryRequest: captureNamed('createLogEntryRequest')),
      ).captured.single as api.CreateLogEntryRequest;
      expect(captured.action, api.LogAction.start);
      expect(captured.session, api.PomodoroState.work);
      expect(captured.payload, isNull);
    });
  });

  group('LogsService.getLogs', () {
    test('calls LogsApi.listLogEntries with defaults and maps each entry',
        () async {
      final list = api.LogEntryList(entries: [
        api.LogEntry(
            id: 1,
            action: api.LogAction.start,
            session: api.PomodoroState.work,
            timestamp: ts),
        api.LogEntry(
            id: 2,
            action: api.LogAction.reset,
            session: api.PomodoroState.longBreak,
            timestamp: ts),
      ], total: 2);
      when(() => mockApi.listLogEntries()).thenAnswer(
          (_) async => okResponse<api.LogEntryList>(list));

      final result = await service.getLogs();

      expect(result, isA<List<LogEntry>>());
      expect(result.length, 2);
      expect(result[0].id, '1');
      expect(result[0].action, LogAction.start);
      expect(result[1].id, '2');
      expect(result[1].action, LogAction.reset);
      expect(result[1].pomodoroState, TimerMode.longBreak);
      verify(() => mockApi.listLogEntries()).called(1);
    });

    test('returns empty list when API returns null entries', () async {
      when(() => mockApi.listLogEntries()).thenAnswer(
          (_) async => okResponse<api.LogEntryList>(api.LogEntryList()));

      final result = await service.getLogs();

      expect(result, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/services/logs_service_test.dart -p vm`
Expected: FAIL — compiles with errors about `LogsService` and `logs_service.dart` not existing. (mocktail import also fails compilation until `pub get` has been run — Task 3 must be complete first.)

- [ ] **Step 3: Write minimal implementation**

Create `lib/data/services/logs_service.dart` with this content exactly:

```dart
import 'package:vipo/data/api/vipo_api.dart' as api;
import 'package:vipo/domain/mappers/log_entry_mapper.dart';
import 'package:vipo/domain/models/log_entry.dart';

/// Thin, stateless wrapper around the generated [api.LogsApi].
///
/// Every method delegates to exactly one generated API call and maps the
/// response into a domain [LogEntry]. `DioException` propagates untouched —
/// error normalization is the repository's responsibility (see #4).
class LogsService {
  const LogsService(this._logsApi);

  final api.LogsApi _logsApi;

  /// Creates a log entry on the server and returns the persisted domain copy.
  ///
  /// `entry.id` and `entry.createdAt` are ignored — the server assigns them.
  Future<LogEntry> createLog(LogEntry entry) async {
    final request = toCreateLogEntryRequest(entry);
    final response =
        await _logsApi.createLogEntry(createLogEntryRequest: request);
    return toDomainLogEntry(response.data!);
  }

  /// Lists log entries from the server using generated defaults
  /// (`limit = 50`, `offset = 0`).
  Future<List<LogEntry>> getLogs() async {
    final response = await _logsApi.listLogEntries();
    final entries = response.data?.entries ?? const <api.LogEntry>[];
    return entries.map(toDomainLogEntry).toList(growable: false);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/services/logs_service_test.dart -p vm`
Expected: PASS — all tests in both groups (`createLog`, `getLogs` empty/non-empty) green.

- [ ] **Step 5: Confirm `flutter analyze` is clean on the new files**

Run: `flutter analyze lib/data/services/logs_service.dart test/data/services/logs_service_test.dart`
Expected: "No issues found!"

- [ ] **Step 6: Commit with caveman-commit**

Use the `caveman-commit` skill to write a descriptive commit message. Then use the temp file pattern from the core-commands skill:

```bash
mktemp
```

Use the Write tool to save the commit message to that path, for example:

```
feat(services): add LogsService wrapping LogsApi

createLog/getLogs delegate to generated createLogEntry/listLogEntries
and map responses to domain LogEntry; no generated types leak out.
DioException propagates untouched; DI wiring deferred to #4.

Refs #7
```

Then:

```bash
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

---

## Task 5: Create `NotesService` (TDD)

**Files:**
- Create: `lib/data/services/notes_service.dart`
- Test: `test/data/services/notes_service_test.dart`

- [ ] **Step 1: Write the failing test**

Create the test directory and file `test/data/services/notes_service_test.dart` with this content exactly:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vipo/data/api/vipo_api.dart' as api;
import 'package:vipo/data/services/notes_service.dart';
import 'package:vipo/domain/models/note.dart';
import 'package:vipo/domain/models/timer_mode.dart';

class MockNotesApi extends Mock implements api.NotesApi {}

void main() {
  late MockNotesApi mockApi;
  late NotesService service;
  final ts = DateTime.utc(2026, 1, 1, 9, 0, 0);

  setUpAll(() {
    registerFallbackValue(
      api.CreateNoteRequest(
        note: '',
        pomodoroState: api.PomodoroState.work,
      ),
    );
  });

  setUp(() {
    mockApi = MockNotesApi();
    service = NotesService(mockApi);
  });

  Response<T> okResponse<T>(T data) => Response<T>(
        requestOptions: RequestOptions(path: '/any'),
        data: data,
        statusCode: 200,
      );

  group('NotesService.createNote', () {
    test('builds request with content+TimerMode, calls NotesApi.createNote, '
        'returns mapped Note', () async {
      final apiNote = api.Note(
        id: 11,
        note: 'hello',
        pomodoroState: api.PomodoroState.work,
        createdAt: ts,
      );
      when(() =>
              mockApi.createNote(createNoteRequest: any(named: 'createNoteRequest')))
          .thenAnswer((_) async => okResponse<api.Note>(apiNote));

      final input = Note(id: '0', content: 'hello', createdAt: ts);
      final result = await service.createNote(input, TimerMode.work);

      expect(result, isA<Note>());
      expect(result.id, '11');
      expect(result.content, 'hello');
      expect(result.createdAt, ts);
      final captured = verify(
        () => mockApi.createNote(
            createNoteRequest: captureNamed('createNoteRequest')),
      ).captured.single as api.CreateNoteRequest;
      expect(captured.note, 'hello');
      expect(captured.pomodoroState, api.PomodoroState.work);
    });
  });

  group('NotesService.getNotes', () {
    test('calls NotesApi.listNotes and maps each Note', () async {
      final list = api.NoteList(notes: [
        api.Note(
            id: 1,
            note: 'a',
            pomodoroState: api.PomodoroState.work,
            createdAt: ts),
        api.Note(
            id: 2,
            note: 'b',
            pomodoroState: api.PomodoroState.shortBreak,
            createdAt: ts),
      ], total: 2);
      when(() => mockApi.listNotes())
          .thenAnswer((_) async => okResponse<api.NoteList>(list));

      final result = await service.getNotes();

      expect(result, isA<List<Note>>());
      expect(result.length, 2);
      expect(result[0].id, '1');
      expect(result[0].content, 'a');
      expect(result[1].id, '2');
      expect(result[1].content, 'b');
      verify(() => mockApi.listNotes()).called(1);
    });

    test('returns empty list when API returns null notes', () async {
      when(() => mockApi.listNotes())
          .thenAnswer((_) async => okResponse<api.NoteList>(api.NoteList()));

      final result = await service.getNotes();

      expect(result, isEmpty);
    });
  });

  group('NotesService.getNoteById', () {
    test('parses String id to int and maps returned Note', () async {
      final apiNote = api.Note(
        id: 7,
        note: 'single',
        pomodoroState: api.PomodoroState.longBreak,
        createdAt: ts,
      );
      when(() => mockApi.getNote(id: any(named: 'id')))
          .thenAnswer((_) async => okResponse<api.Note>(apiNote));

      final result = await service.getNoteById('7');

      expect(result.id, '7');
      expect(result.content, 'single');
      verify(() => mockApi.getNote(id: 7)).called(1);
    });

    test('propagates FormatException when id is not an integer', () async {
      expect(() => service.getNoteById('not-a-number'),
          throwsA(isA<FormatException>()));
    });
  });

  group('NotesService.deleteNote', () {
    test('parses String id and calls NotesApi.deleteNote', () async {
      when(() => mockApi.deleteNote(id: any(named: 'id')))
          .thenAnswer((_) async => okResponse<void>(null));

      await service.deleteNote('5');

      verify(() => mockApi.deleteNote(id: 5)).called(1);
    });

    test('propagates FormatException when id is not an integer', () async {
      expect(() => service.deleteNote('abc'),
          throwsA(isA<FormatException>()));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/services/notes_service_test.dart -p vm`
Expected: FAIL — `NotesService` and `notes_service.dart` do not exist (`Target of URI doesn't exist`).

- [ ] **Step 3: Write minimal implementation**

Create `lib/data/services/notes_service.dart` with this content exactly:

```dart
import 'package:vipo/data/api/vipo_api.dart' as api;
import 'package:vipo/domain/mappers/note_mapper.dart';
import 'package:vipo/domain/models/note.dart';
import 'package:vipo/domain/models/timer_mode.dart';

/// Thin, stateless wrapper around the generated [api.NotesApi].
///
/// Every method delegates to exactly one generated API call and maps the
/// response into a domain [Note]. `DioException` propagates untouched —
/// error normalization is the repository's responsibility (see #4).
class NotesService {
  const NotesService(this._notesApi);

  final api.NotesApi _notesApi;

  /// Creates a note on the server and returns the persisted domain copy.
  ///
  /// [pomodoroState] is supplied by the caller because the domain `Note`
  /// deliberately omits it (per #6 SN-2) while `CreateNoteRequest` requires
  /// it. `note.id` and `note.createdAt` are ignored — server-assigned.
  Future<Note> createNote(Note note, TimerMode pomodoroState) async {
    final request = toCreateNoteRequest(note, pomodoroState);
    final response = await _notesApi.createNote(createNoteRequest: request);
    return toDomainNote(response.data!);
  }

  /// Lists notes from the server using generated defaults (`limit = 50`).
  Future<List<Note>> getNotes() async {
    final response = await _notesApi.listNotes();
    final notes = response.data?.notes ?? const <api.Note>[];
    return notes.map(toDomainNote).toList(growable: false);
  }

  /// Fetches a single note by its string id (parsed server-side as int).
  Future<Note> getNoteById(String id) async {
    final response = await _notesApi.getNote(id: int.parse(id));
    return toDomainNote(response.data!);
  }

  /// Deletes a note by its string id (parsed server-side as int).
  Future<void> deleteNote(String id) async {
    await _notesApi.deleteNote(id: int.parse(id));
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/services/notes_service_test.dart -p vm`
Expected: PASS — all five groups green (createNote, getNotes non-empty, getNotes empty, getNoteById happy & FormatException, deleteNote happy & FormatException).

- [ ] **Step 5: Confirm `flutter analyze` is clean on the new files**

Run: `flutter analyze lib/data/services/notes_service.dart test/data/services/notes_service_test.dart`
Expected: "No issues found!"

- [ ] **Step 6: Commit with caveman-commit**

Use the `caveman-commit` skill to write a descriptive commit message. Then use the temp file pattern from the core-commands skill:

```bash
mktemp
```

Use the Write tool to save the commit message to that path, for example:

```
feat(services): add NotesService wrapping NotesApi

createNote/getNotes/getNoteById/deleteNote delegate to generated
NotesApi and map to domain Note; createNote takes the contextual
TimerMode that the domain Note omits (#6 SN-2). DioException and
FormatException propagate untouched; DI wiring deferred to #4.

Refs #7
```

Then:

```bash
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

---

## Task 6: Verify acceptance criteria

**Files:** none modified — verification only.

- [ ] **Step 1: Run `flutter analyze` over the whole project**

Run: `flutter analyze`
Expected: "No issues found!" — confirms the zero-warnings criterion and that no new types (`logs_service.dart`, `notes_service.dart`) leak lint.

- [ ] **Step 2: Run the new test scope**

Run: `flutter test test/domain test/data -p vm`
Expected: PASS — all `test/domain/*` mapper tests (including the two new request-mapper groups) and all `test/data/services/*` service tests pass.

- [ ] **Step 3: Verify the services-only dependencies condition (no BLoC/UI imports)**

Run a search of the new files for forbidden imports (none should match):

Run: `rg -n "package:vipo/(blocs|screens|widgets)/" lib/data/services/`
Expected: no output (zero matches). If anything matches, fix the import — services must depend only on `lib/data/api/`, `lib/domain/mappers/`, and `lib/domain/models/`.

- [ ] **Step 4: Verify no generated types leak through service method signatures**

Open `lib/data/services/logs_service.dart` and `lib/data/services/notes_service.dart`. Confirm that every **public** method's declared return type is one of: `Future<LogEntry>`, `Future<List<LogEntry>>`, `Future<Note>`, `Future<List<Note>>`, `Future<void>`. No method declares a return type referencing `api.*` (the only `api.*` references are inside private bodies). Constructor parameter types reference `api.LogsApi` / `api.NotesApi` only (allowed — the issue explicitly mandates constructor DI with generated clients).

- [ ] **Step 5: Verify no service holds mutable state**

Open `lib/data/services/logs_service.dart` and `lib/data/services/notes_service.dart`. Confirm each class declares exactly one `final` field (`_logsApi` / `_notesApi`), the constructor is `const`, and no method assigns any field. (Both files match this in the implementations above.)

- [ ] **Step 6: (Optional) Review the full diff and clean up**

Run: `jj diff` (or `jj status`) and scan for stray debug `print` statements, leftover imports, or temp-file artefacts in `/tmp`.
Clean up any untracked temp files: `rm /tmp/tmp.*` (only your own leftovers — none expected if every commit step paired `rm` with the `mktemp`).

---

## Self-Review Checklist (run after writing, not in plan execution)

- [x] **Spec coverage:** Every issue acceptance criterion maps to a task step:
  - `flutter analyze` zero warnings → Task 1.5, 2.5, 3.3, 4.5, 5.5, 6.1.
  - `LogsService` and `NotesService` exist under `lib/data/services/` → Task 4, Task 5.
  - Both accept generated API client via constructor injection → Step 3 of Tasks 4 and 5 (`final api.LogsApi _logsApi; const LogsService(this._logsApi)` / `final api.NotesApi _notesApi; const NotesService(this._notesApi)`).
  - Every service method returns a domain model / `void`, no generated types leak → Step 6.4 plus the `// thin` implementation of each method (only bodies reference `api.*`).
  - No mutable state, no internal API client construction → Step 6.5; constructors are `const`, single `final` field.
  - `DioException` propagates unswallowed → no `try/catch` in either service body (`createLog`, `getLogs`, `createNote`, `getNotes`, `getNoteById`, `deleteNote`).
  - No `lib/blocs/`, `lib/screens/`, `lib/widgets/` imports → Step 6.3.
- [x] **Placeholder scan:** No "TBD", "add validation", "handle edge cases", "similar to Task N". Every code step contains complete copy-pasteable Dart.
- [x] **Type consistency:** `toCreateLogEntryRequest(LogEntry)` (Task 1) is the exact name used in `LogsService.createLog` (Task 4). `toCreateNoteRequest(Note, TimerMode)` (Task 2) matches `NotesService.createNote` (Task 5). The service method `getNoteById(String)` calls `getNote(id: int.parse(id))` (per SN-1) consistent in tests and implementation.
- [x] **Issue signature deviations:** Only `createNote(Note, TimerMode)` deviates from the issue's `createNote(Note)`, documented in SN-2 with rationale linking to the existing #6 SN-2 decision. All other signatures match the issue verbatim.
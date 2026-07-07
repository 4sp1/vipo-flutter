# LogsRepository & NotesRepository Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use supervised-plan-execution to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create `LogsRepository` and `NotesRepository` in `lib/repositories/` that wrap the corresponding services, return only domain types wrapped in a `Result<T>` sealed class, and normalize every transport-layer exception (`DioException`) plus `FormatException` into domain-meaningful failures so BLoCs can pattern-match without try-catch and never see generated-API or transport types.

**Architecture:** Two thin repository classes sit between the service layer (`lib/data/services/` from issue #7) and the (future) BLoC layer. Each repository holds one `final` service reference injected via a `const` constructor. Every public method is `Future<Result<T>>`, wraps a single service call in a `try / on DioException catch / on FormatException catch` block, and returns `Result.success(...)` on the happy path or `Result.failure(<DomainFailure>(...))` on error. A new `lib/domain/result.dart` file owns the `Result<T>` sealed type and the four domain-failure exception classes from the issue. No BLoC/UI imports and no `lib/data/api/` imports are permitted anywhere in `lib/repositories/` or `lib/domain/result.dart`.

**Tech Stack:** Dart ^3.10.4 (sealed classes), Flutter, `flutter_test`, `mocktail` (already added as a dev dependency by the prerequisite services plan — see Prerequisites), existing services (`LogsService`, `NotesService`) and domain models (`LogEntry`, `Note`) from issues #5/#6/#7.

---

## Prerequisites

This plan **consumes** outputs of the services plan (`docs/plans/20260707_logs-notes-services.md`, issue #7). Execute that plan first. Concretely, before starting Task 2 below, the following must already exist in the working tree:

- `lib/data/services/logs_service.dart` exposing `LogsService` with `Future<LogEntry> createLog(LogEntry entry)` and `Future<List<LogEntry>> getLogs()`.
- `lib/data/services/notes_service.dart` exposing `NotesService` with `Future<Note> createNote(Note note, TimerMode pomodoroState)`, `Future<List<Note>> getNotes()`, `Future<Note> getNoteById(String id)`, `Future<void> deleteNote(String id)`.
- `mocktail: ^1.0.4` present under `dev_dependencies:` in `pubspec.yaml`.
- `flutter analyze` clean up to and including the services commit.

If any of the above are missing, stop and run the services plan first — the repository tests below `import 'package:vipo/data/services/...'` and will not compile otherwise.

---

## Spec Notes & Design Decisions

Read these before implementing — they resolve mismatches between the issue text and the actual service interfaces.

### SN-1. `createNote` must take a `TimerMode` parameter — deviation from issue signature

The issue specifies `Future<Result<Note>> createNote(Note note)` for `NotesRepository`. But the prerequisite `NotesService.createNote` signature is `Future<Note> createNote(Note note, TimerMode pomodoroState)` (see the services plan's SN-2 — the generated `CreateNoteRequest` requires a `pomodoroState` field that the domain `Note` deliberately omits per issue #6). A repository that "does no business logic" cannot invent a `TimerMode`, so we deviate and add it as an explicit parameter, mirroring the service contract:

```dart
Future<Result<Note>> createNote(Note note, TimerMode pomodoroState)
```

The services plan explicitly anticipated this: "Repositories (issue #4) will pass the contextual timer-mode at creation time." BLoCs (issue #9) will supply the active timer mode when calling the repository. All other repository signatures match the issue verbatim.

### SN-2. `FormatException` is also normalized — not only `DioException`

The issue text says repositories "normalize `DioException`". Strictly. But the prerequisite services also throw `FormatException` from `int.parse(id)` inside `NotesService.getNoteById` and `NotesService.deleteNote` when a caller passes a non-numeric `String id` (services plan, Tasks 5 `getNoteById` and `deleteNote` happy-path + FormatException tests).

The issue's `Result`-type section states the explicit goal: *"Repositories return `Result<T>` instead of throwing, so BLoCs can pattern-match on success/failure without try-catch."* If a `FormatException` from a bad id escaped the repository, BLoCs would be forced back into try-catch, defeating that goal. Therefore the repositories catch **both** `DioException` and `FormatException` and normalize both. `FormatException` is treated as a caller-input error and mapped to `NoteRetrievalFailure('Invalid note id: "..."')`. Other unchecked exceptions are intentionally not caught — those indicate programmer bugs and should surface loudly during development.

### SN-3. Only four domain-failure exception classes exist — `deleteNote` maps to `NoteRetrievalFailure`

The issue names exactly four failures: `LogCreateFailure`, `LogRetrievalFailure`, `NoteCreateFailure`, `NoteRetrievalFailure`. There is no `NoteDeleteFailure`. To avoid inventing a 5th class (YAGNI — the issue's acceptance criteria enumerate exactly these four), `NotesRepository.deleteNote` normalizes errors to `NoteRetrievalFailure` (the only Note-side non-create failure available). The class's docstring explicitly notes it covers both retrieval and deletion. This is the literal reading of the issue's acceptance criteria.

### SN-4. The `DioException` object is never stored on a failure

The issue is emphatic that callers "never see `DioException`". Failures therefore hold only a `String message` — never a typed `cause` field of type `Object?` (a caller could cast it back to `DioException`, leaking the type). The repository's catch block stringifies the salient, stable fields (`type.name` and `response?.statusCode`) into a short human-readable message — e.g. `'badResponse (HTTP 500)'` or `'connectionTimeout'`. The original `DioException` object is garbage-collected once the catch block returns. Tests assert on the failure *type* and on substrings of the message (e.g. `contains('500')`, `contains('timeout')`), never on identity with the thrown object.

### SN-5. `Result<void>` for `deleteNote` — building the success value

`NotesRepository.deleteNote` is declared `Future<Result<void>>`. The service `deleteNote` returns `Future<void>` — there is no real value to carry. On the happy path the repository builds the success value with `Result.success<void>(null)`. Dart permits `null` as the argument to a `void`-typed parameter, and `flutter analyze` accepts it (dio's own `Response<void>` uses the same trick). Tests assert on the `Success<void>` type, not on any carried `.value`.

### SN-6. A tiny private `_dioSummary` helper is duplicated across both repository files

Each repository file defines its own `String _dioSummary(DioException e)` top-level helper used only inside that file. This is intentional: keeping the helper file-private (Dart `_` prefix) preserves the "no public transport-aware surface" rule, and the alternative — a shared file like `lib/repositories/repo_error.dart` exporting a `DioException`-typed function — would create a public, library-level symbol referencing `DioException`, contradicting SN-4's spirit. Two identical 3-line functions beat one shared abstraction at this scale (YAGNI / surgical-changes).

### SN-7. Import aliasing is not needed in repository files

Unlike the services/mappers, repository method signatures reference **only** domain types (`LogEntry`, `Note`, `Result`, and the four failure classes) and the service classes (`LogsService`, `NotesService`). No generated `api.*` type appears in any repository's public surface, so there is no name collision to alias away. Repository files still `import 'package:dio/dio.dart'` (for catching `DioException` and reading `DioExceptionType`) — this is allowed: `dio` is a direct dependency in `pubspec.yaml` (`dio: ^5.7.0`), and the issue only forbids `lib/data/api/` imports (not the `dio` package itself).

### SN-8. `flutter test` is partially pre-broken (out of scope, carried forward from the services plan)

Per `AGENTS.md`, `test/widget_test.dart` is the stale Flutter template (references `MyApp`, `Icons.add`) and fails as-is. We **do not** touch it. Test commands in this plan target `test/repositories/` (and, for the final acceptance gate, `test/domain test/data test/repositories`). The full-suite `flutter test` run is left to a separate fix issue (#20).

### SN-9. `flutter analyze` acceptance gate

All new hand-authored files must be warning-free (matching the existing domain files). The generated API files under `lib/data/api/` carry `// ignore_for_file: type=lint` headers and are out of scope — they are not imported by anything in this plan, so they cannot introduce warnings here.

---

## File Structure

**Create:**

| File | Responsibility |
|------|----------------|
| `lib/domain/result.dart` | `Result<T>` sealed class (`Success<T>`, `Failure<T>`), plus the four domain-failure `Exception` classes (`LogCreateFailure`, `LogRetrievalFailure`, `NoteCreateFailure`, `NoteRetrievalFailure`) |
| `lib/repositories/logs_repository.dart` | `LogsRepository` — wraps `LogsService`; `createLog`, `getLogs`; normalizes `DioException` to `LogCreateFailure` / `LogRetrievalFailure` |
| `lib/repositories/notes_repository.dart` | `NotesRepository` — wraps `NotesService`; `createNote`, `getNotes`, `getNoteById`, `deleteNote`; normalizes `DioException` + `FormatException` to `NoteCreateFailure` / `NoteRetrievalFailure` |
| `test/domain/result_test.dart` | Unit tests for `Result<T>` (success/failure construction, type/value preservation, `void` success) and the four failure classes' `toString` |
| `test/repositories/logs_repository_test.dart` | Unit tests for `LogsRepository` using `mocktail` `MockLogsService`; happy paths + `DioException` normalization (timeout, 4xx, 5xx) |
| `test/repositories/notes_repository_test.dart` | Unit tests for `NotesRepository` using `mocktail` `MockNotesService`; happy paths + `DioException` + `FormatException` normalization |

**Modify:** none. (No existing file is touched — the repository layer is brand new.)

**Delete:** none.

**Out of scope (explicitly deferred):** DI wiring in `lib/di.dart` (issue #10's BlocProvider tree wiring wires repositories up to BLoCs); BLoC consumption of these repositories (issue #9); refactoring `main.dart` to inject the repositories (issue #10).

---

## Task 1: Create `Result<T>` sealed class and the four domain failures (TDD)

**Files:**
- Create: `lib/domain/result.dart`
- Test: `test/domain/result_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/domain/result_test.dart` with this content exactly:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vipo/domain/result.dart';

void main() {
  group('Result.success', () {
    test('holds the supplied value and is a Success', () {
      const result = Result<int>.success(42);
      expect(result, isA<Success<int>>());
      expect((result as Success<int>).value, 42);
    });

    test('preserves generic type parameter for List<String>', () {
      final result = Result<List<String>>.success(const ['a', 'b']);
      expect(result, isA<Success<List<String>>>());
      expect((result as Success<List<String>>).value, ['a', 'b']);
    });

    test('void success accepts null and is a Success<void>', () {
      final result = Result<void>.success(null);
      expect(result, isA<Success<void>>());
    });
  });

  group('Result.failure', () {
    test('holds the supplied exception and is a Failure', () {
      const exception = FormatException('bad');
      const result = Result<String>.failure(exception);
      expect(result, isA<Failure<String>>());
      expect((result as Failure<String>).exception, same(exception));
    });

    test('exception class identity is preserved (LogCreateFailure)', () {
      const failure = LogCreateFailure('boom');
      final result = Result<String>.failure(failure);
      expect((result as Failure<String>).exception, isA<LogCreateFailure>());
    });
  });

  group('Sealed exhaustiveness', () {
    test('a Result is either Success or Failure and nothing else', () {
      Result<int> success = const Result<int>.success(1);
      Result<int> failing = const Result<int>.failure(LogRetrievalFailure('x'));

      String describe(Result<int> r) => switch (r) {
            Success(:final value) => 'ok=$value',
            Failure(:final exception) => 'err=$exception',
          };

      expect(describe(success), 'ok=1');
      expect(describe(failing), startsWith('err='));
    });
  });

  group('Domain failure toString', () {
    test('LogCreateFailure', () {
      expect(const LogCreateFailure('cannot create').toString(),
          'LogCreateFailure: cannot create');
    });
    test('LogRetrievalFailure', () {
      expect(const LogRetrievalFailure('cannot list').toString(),
          'LogRetrievalFailure: cannot list');
    });
    test('NoteCreateFailure', () {
      expect(const NoteCreateFailure('cannot create').toString(),
          'NoteCreateFailure: cannot create');
    });
    test('NoteRetrievalFailure', () {
      expect(const NoteRetrievalFailure('cannot get').toString(),
          'NoteRetrievalFailure: cannot get');
    });
  });

  group('Domain failures are Exceptions', () {
    test('every failure class implements Exception', () {
      expect(const LogCreateFailure(''), isA<Exception>());
      expect(const LogRetrievalFailure(''), isA<Exception>());
      expect(const NoteCreateFailure(''), isA<Exception>());
      expect(const NoteRetrievalFailure(''), isA<Exception>());
    });

    test('every failure exposes a non-final-but-immutable message field', () {
      expect(const LogCreateFailure('m1').message, 'm1');
      expect(const LogRetrievalFailure('m2').message, 'm2');
      expect(const NoteCreateFailure('m3').message, 'm3');
      expect(const NoteRetrievalFailure('m4').message, 'm4');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/result_test.dart -p vm`
Expected: FAIL — `Target of URI doesn't exist: 'package:vipo/domain/result.dart'` and undefined names (`Result`, `Success`, `Failure`, `LogCreateFailure`, ...).

- [ ] **Step 3: Write minimal implementation**

Create `lib/domain/result.dart` with this content exactly:

```dart
/// Result of an operation that can either succeed with a value or fail with
/// an [Exception]. Follows Flutter's `Result` design pattern:
/// <https://docs.flutter.dev/app-architecture/design-patterns/result>.
///
/// Repository methods return `Result<T>` instead of throwing, so callers
/// (BLoCs) can `switch` on success/failure without try-catch and without
/// ever touching transport-layer exceptions like `DioException`.
sealed class Result<T> {
  const Result();

  /// Creates a successful result holding [value].
  const factory Result.success(T value) = Success<T>;

  /// Creates a failure result holding [exception].
  const factory Result.failure(Exception exception) = Failure<T>;
}

/// The success variant of [Result]. Carries the returned [value].
final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;

  @override
  String toString() => 'Success($value)';
}

/// The failure variant of [Result]. Carries the domain [exception]; never a
/// raw `DioException` — repositories normalize transport errors into the
/// domain failures defined below before wrapping them here.
final class Failure<T> extends Result<T> {
  const Failure(this.exception);

  final Exception exception;

  @override
  String toString() => 'Failure($exception)';
}

/// Creating a log entry on the server failed.
///
/// `LogsRepository.createLog` produces this when the underlying
/// `LogsService.createLog` throws a `DioException`.
class LogCreateFailure implements Exception {
  const LogCreateFailure(this.message);

  final String message;

  @override
  String toString() => 'LogCreateFailure: $message';
}

/// Reading log entries from the server failed.
///
/// `LogsRepository.getLogs` produces this when the underlying
/// `LogsService.getLogs` throws a `DioException`.
class LogRetrievalFailure implements Exception {
  const LogRetrievalFailure(this.message);

  final String message;

  @override
  String toString() => 'LogRetrievalFailure: $message';
}

/// Creating a note on the server failed.
///
/// `NotesRepository.createNote` produces this when the underlying
/// `NotesService.createNote` throws a `DioException`.
class NoteCreateFailure implements Exception {
  const NoteCreateFailure(this.message);

  final String message;

  @override
  String toString() => 'NoteCreateFailure: $message';
}

/// Reading or deleting a note on the server failed.
///
/// `NotesRepository.getNotes`, `NotesRepository.getNoteById`, and
/// `NotesRepository.deleteNote` produce this when the underlying
/// `NotesService` method throws a `DioException` — or, for the id-taking
/// methods, a `FormatException` from `int.parse` on a non-numeric id.
class NoteRetrievalFailure implements Exception {
  const NoteRetrievalFailure(this.message);

  final String message;

  @override
  String toString() => 'NoteRetrievalFailure: $message';
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/domain/result_test.dart -p vm`
Expected: PASS — all groups green (success/failure construction, sealed exhaustiveness, all four `toString` cases, `Exception` relation).

- [ ] **Step 5: Confirm `flutter analyze` is clean on the new files**

Run: `flutter analyze lib/domain/result.dart test/domain/result_test.dart`
Expected: `No issues found!`

- [ ] **Step 6: Commit with caveman-commit**

Use the `caveman-commit` skill to write a descriptive commit message. Then use the temp file pattern from the core-commands skill:

```bash
mktemp
```

Use the Write tool to save the commit message to that path, for example:

```
feat(domain): add Result<T> sealed type + 4 failures

Result.success/failure per Flutter Result pattern; LogCreateFailure,
LogRetrievalFailure, NoteCreateFailure, NoteRetrievalFailure as the
only domain failures repositories may return. Failures hold a String
message only — no DioException object leaks through.

Refs #8
```

Then:

```bash
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

---

## Task 2: Create `LogsRepository` (TDD)

**Files:**
- Create: `lib/repositories/logs_repository.dart`
- Test: `test/repositories/logs_repository_test.dart`

- [ ] **Step 1: Write the failing test**

Create the directory and file `test/repositories/logs_repository_test.dart` with this content exactly:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vipo/data/services/logs_service.dart';
import 'package:vipo/domain/models/log_action.dart';
import 'package:vipo/domain/models/log_entry.dart';
import 'package:vipo/domain/models/timer_mode.dart';
import 'package:vipo/domain/result.dart';
import 'package:vipo/repositories/logs_repository.dart';

class MockLogsService extends Mock implements LogsService {}

void main() {
  late MockLogsService mockService;
  late LogsRepository repo;
  final ts = DateTime.utc(2026, 1, 2, 10, 0, 0);

  setUp(() {
    mockService = MockLogsService();
    repo = LogsRepository(mockService);
  });

  // Builds a DioException mirroring what the service would throw.
  DioException dioError(DioExceptionType type, {int? statusCode}) {
    final response = statusCode == null
        ? null
        : Response<void>(
            requestOptions: RequestOptions(path: '/logs'),
            statusCode: statusCode,
          );
    return DioException(
      requestOptions: RequestOptions(path: '/logs'),
      response: response,
      type: type,
      message: 'boom',
    );
  }

  LogEntry sampleEntry() => LogEntry(
        id: '1',
        pomodoroState: TimerMode.work,
        action: LogAction.start,
        createdAt: ts,
      );

  group('LogsRepository.createLog', () {
    test('returns Result.success wrapping the service-returned LogEntry',
        () async {
      final entry = sampleEntry();
      when(() => mockService.createLog(entry))
          .thenAnswer((_) async => entry);

      final result = await repo.createLog(entry);

      expect(result, isA<Success<LogEntry>>());
      expect((result as Success<LogEntry>).value, entry);
      verify(() => mockService.createLog(entry)).called(1);
    });

    test('returns Result.failure(LogCreateFailure) on connectionTimeout',
        () async {
      final entry = sampleEntry();
      when(() => mockService.createLog(entry)).thenThrow(
        dioError(DioExceptionType.connectionTimeout),
      );

      final result = await repo.createLog(entry);

      expect(result, isA<Failure<LogEntry>>());
      final failure = (result as Failure<LogEntry>).exception;
      expect(failure, isA<LogCreateFailure>());
      expect((failure as LogCreateFailure).message, contains('connectionTimeout'));
    });

    test('returns Result.failure(LogCreateFailure) on a 5xx badResponse',
        () async {
      final entry = sampleEntry();
      when(() => mockService.createLog(entry)).thenThrow(
        dioError(DioExceptionType.badResponse, statusCode: 500),
      );

      final result = await repo.createLog(entry);

      expect(result, isA<Failure<LogEntry>>());
      final failure = (result as Failure<LogEntry>).exception;
      expect(failure, isA<LogCreateFailure>());
      expect(failure.message, contains('500'));
    });

    test('returns Result.failure(LogCreateFailure) on a 400 badResponse',
        () async {
      final entry = sampleEntry();
      when(() => mockService.createLog(entry)).thenThrow(
        dioError(DioExceptionType.badResponse, statusCode: 400),
      );

      final result = await repo.createLog(entry);

      expect(result, isA<Failure<LogEntry>>());
      expect((result as Failure<LogEntry>).exception, isA<LogCreateFailure>());
    });
  });

  group('LogsRepository.getLogs', () {
    test('returns Result.success wrapping the service-returned list',
        () async {
      final list = [sampleEntry()];
      when(() => mockService.getLogs()).thenAnswer((_) async => list);

      final result = await repo.getLogs();

      expect(result, isA<Success<List<LogEntry>>>());
      expect((result as Success<List<LogEntry>>).value, same(list));
      verify(() => mockService.getLogs()).called(1);
    });

    test('returns Result.success with an empty list when service returns []',
        () async {
      when(() => mockService.getLogs()).thenAnswer((_) async => const []);

      final result = await repo.getLogs();

      expect(result, isA<Success<List<LogEntry>>>());
      expect((result as Success<List<LogEntry>>).value, isEmpty);
    });

    test('returns Result.failure(LogRetrievalFailure) on receiveTimeout',
        () async {
      when(() => mockService.getLogs()).thenThrow(
        dioError(DioExceptionType.receiveTimeout),
      );

      final result = await repo.getLogs();

      expect(result, isA<Failure<List<LogEntry>>>());
      final failure = (result as Failure<List<LogEntry>>).exception;
      expect(failure, isA<LogRetrievalFailure>());
      expect((failure as LogRetrievalFailure).message,
          contains('receiveTimeout'));
    });

    test('returns Result.failure(LogRetrievalFailure) on 503 badResponse',
        () async {
      when(() => mockService.getLogs()).thenThrow(
        dioError(DioExceptionType.badResponse, statusCode: 503),
      );

      final result = await repo.getLogs();

      expect(result, isA<Failure<List<LogEntry>>>());
      final failure = (result as Failure<List<LogEntry>>).exception;
      expect(failure, isA<LogRetrievalFailure>());
      expect(failure.message, contains('503'));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/repositories/logs_repository_test.dart -p vm`
Expected: FAIL — `Target of URI doesn't exist: 'package:vipo/repositories/logs_repository.dart'` (`LogsRepository`, `repo` unresolved). This also confirms Task 1 of this plan is complete and the prerequisite services plan is in place; otherwise the `LogsService` import itself fails.

- [ ] **Step 3: Write minimal implementation**

Create `lib/repositories/logs_repository.dart` with this content exactly:

```dart
import 'package:dio/dio.dart';
import 'package:vipo/data/services/logs_service.dart';
import 'package:vipo/domain/models/log_entry.dart';
import 'package:vipo/domain/result.dart';

/// Single source of truth for log data — the only class the BLoC layer may
/// call to read or write logs. Wraps a single injected [LogsService] and
/// returns [Result]s so callers never see [DioException].
///
/// No business logic: every method delegates to exactly one service method
/// and maps any thrown [DioException] to a domain failure. The service is
/// the **only** data-layer dependency — this file does not import
/// `lib/data/api/` (generated code) and does not import any BLoC/UI file.
class LogsRepository {
  const LogsRepository(this._service);

  final LogsService _service;

  /// Creates a log entry on the server. Delegates to
  /// [LogsService.createLog]. Any [DioException] is normalized to a
  /// [LogCreateFailure] (the original `DioException` is not stored on the
  /// failure — only a short message is, per SN-4 of the plan).
  Future<Result<LogEntry>> createLog(LogEntry entry) async {
    try {
      return Result.success(await _service.createLog(entry));
    } on DioException catch (e) {
      return Result.failure(LogCreateFailure(_dioSummary(e)));
    }
  }

  /// Lists log entries from the server. Delegates to
  /// [LogsService.getLogs]. Any [DioException] is normalized to a
  /// [LogRetrievalFailure].
  Future<Result<List<LogEntry>>> getLogs() async {
    try {
      return Result.success(await _service.getLogs());
    } on DioException catch (e) {
      return Result.failure(LogRetrievalFailure(_dioSummary(e)));
    }
  }
}

/// Builds a short, transport-free summary string of a [DioException] so the
/// domain failure carries no `DioException` object reference. Duplicated in
/// `notes_repository.dart` deliberately (see SN-6 of the plan).
String _dioSummary(DioException e) {
  final code = e.response?.statusCode;
  return code == null ? e.type.name : '${e.type.name} (HTTP $code)';
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/repositories/logs_repository_test.dart -p vm`
Expected: PASS — all eight tests green: `createLog` happy + timeout + 500 + 400; `getLogs` happy + empty + receiveTimeout + 503.

- [ ] **Step 5: Confirm `flutter analyze` is clean on the new files**

Run: `flutter analyze lib/repositories/logs_repository.dart test/repositories/logs_repository_test.dart`
Expected: `No issues found!`

- [ ] **Step 6: Commit with caveman-commit**

Use the `caveman-commit` skill to write a descriptive commit message. Then use the temp file pattern from the core-commands skill:

```bash
mktemp
```

Use the Write tool to save the commit message to that path, for example:

```
feat(repos): add LogsRepository wrapping LogsService

createLog/getLogs delegate to LogsService and wrap results in
Result<T>. DioException is normalized to LogCreateFailure /
LogRetrievalFailure with a short message; the DioException object
is never stored, so BLoCs never see transport types.

Refs #8
```

Then:

```bash
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

---

## Task 3: Create `NotesRepository` (TDD)

**Files:**
- Create: `lib/repositories/notes_repository.dart`
- Test: `test/repositories/notes_repository_test.dart`

- [ ] **Step 1: Write the failing test**

Create the directory and file `test/repositories/notes_repository_test.dart` with this content exactly:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vipo/data/services/notes_service.dart';
import 'package:vipo/domain/models/note.dart';
import 'package:vipo/domain/models/timer_mode.dart';
import 'package:vipo/domain/result.dart';
import 'package:vipo/repositories/notes_repository.dart';

class MockNotesService extends Mock implements NotesService {}

void main() {
  late MockNotesService mockService;
  late NotesRepository repo;
  final ts = DateTime.utc(2026, 1, 1, 9, 0, 0);

  setUp(() {
    mockService = MockNotesService();
    repo = NotesRepository(mockService);
  });

  DioException dioError(DioExceptionType type, {int? statusCode}) {
    final response = statusCode == null
        ? null
        : Response<void>(
            requestOptions: RequestOptions(path: '/notes'),
            statusCode: statusCode,
          );
    return DioException(
      requestOptions: RequestOptions(path: '/notes'),
      response: response,
      type: type,
      message: 'boom',
    );
  }

  Note sampleNote() =>
      Note(id: '11', content: 'hello', createdAt: ts);

  group('NotesRepository.createNote', () {
    test('returns Result.success wrapping the service-returned Note',
        () async {
      final note = sampleNote();
      when(() => mockService.createNote(note, TimerMode.work))
          .thenAnswer((_) async => note);

      final result = await repo.createNote(note, TimerMode.work);

      expect(result, isA<Success<Note>>());
      expect((result as Success<Note>).value, note);
      verify(() => mockService.createNote(note, TimerMode.work)).called(1);
    });

    test('returns Result.failure(NoteCreateFailure) on 500 badResponse',
        () async {
      final note = sampleNote();
      when(() => mockService.createNote(note, TimerMode.shortBreak))
          .thenThrow(dioError(DioExceptionType.badResponse, statusCode: 500));

      final result = await repo.createNote(note, TimerMode.shortBreak);

      expect(result, isA<Failure<Note>>());
      final failure = (result as Failure<Note>).exception;
      expect(failure, isA<NoteCreateFailure>());
      expect(failure.message, contains('500'));
    });

    test('returns Result.failure(NoteCreateFailure) on sendTimeout',
        () async {
      final note = sampleNote();
      when(() => mockService.createNote(note, TimerMode.longBreak))
          .thenThrow(dioError(DioExceptionType.sendTimeout));

      final result = await repo.createNote(note, TimerMode.longBreak);

      expect(result, isA<Failure<Note>>());
      final failure = (result as Failure<Note>).exception;
      expect(failure, isA<NoteCreateFailure>());
      expect((failure as NoteCreateFailure).message, contains('sendTimeout'));
    });
  });

  group('NotesRepository.getNotes', () {
    test('returns Result.success wrapping the service-returned list',
        () async {
      final list = [sampleNote()];
      when(() => mockService.getNotes()).thenAnswer((_) async => list);

      final result = await repo.getNotes();

      expect(result, isA<Success<List<Note>>>());
      expect((result as Success<List<Note>>).value, same(list));
      verify(() => mockService.getNotes()).called(1);
    });

    test('returns Result.failure(NoteRetrievalFailure) on 502 badResponse',
        () async {
      when(() => mockService.getNotes()).thenThrow(
        dioError(DioExceptionType.badResponse, statusCode: 502),
      );

      final result = await repo.getNotes();

      expect(result, isA<Failure<List<Note>>>());
      final failure = (result as Failure<List<Note>>).exception;
      expect(failure, isA<NoteRetrievalFailure>());
      expect(failure.message, contains('502'));
    });
  });

  group('NotesRepository.getNoteById', () {
    test('returns Result.success wrapping the service-returned Note',
        () async {
      final note = sampleNote();
      when(() => mockService.getNoteById('11'))
          .thenAnswer((_) async => note);

      final result = await repo.getNoteById('11');

      expect(result, isA<Success<Note>>());
      expect((result as Success<Note>).value, note);
      verify(() => mockService.getNoteById('11')).called(1);
    });

    test('returns Result.failure(NoteRetrievalFailure) on 404 badResponse',
        () async {
      when(() => mockService.getNoteById('11')).thenThrow(
        dioError(DioExceptionType.badResponse, statusCode: 404),
      );

      final result = await repo.getNoteById('11');

      expect(result, isA<Failure<Note>>());
      final failure = (result as Failure<Note>).exception;
      expect(failure, isA<NoteRetrievalFailure>());
      expect(failure.message, contains('404'));
    });

    test('normalizes FormatException from a non-numeric id', () async {
      when(() => mockService.getNoteById('abc'))
          .thenThrow(const FormatException('Could not parse'));

      final result = await repo.getNoteById('abc');

      expect(result, isA<Failure<Note>>());
      final failure = (result as Failure<Note>).exception;
      expect(failure, isA<NoteRetrievalFailure>());
      expect(failure.message, contains('Invalid note id'));
    });
  });

  group('NotesRepository.deleteNote', () {
    test('returns Result<void> success when service returns normally',
        () async {
      when(() => mockService.deleteNote('5')).thenAnswer((_) async {});

      final result = await repo.deleteNote('5');

      expect(result, isA<Success<void>>());
      verify(() => mockService.deleteNote('5')).called(1);
    });

    test('returns Result.failure(NoteRetrievalFailure) on 500 badResponse',
        () async {
      when(() => mockService.deleteNote('5')).thenThrow(
        dioError(DioExceptionType.badResponse, statusCode: 500),
      );

      final result = await repo.deleteNote('5');

      expect(result, isA<Failure<void>>());
      final failure = (result as Failure<void>).exception;
      expect(failure, isA<NoteRetrievalFailure>());
      expect(failure.message, contains('500'));
    });

    test('normalizes FormatException from a non-numeric id', () async {
      when(() => mockService.deleteNote('abc'))
          .thenThrow(const FormatException('Could not parse'));

      final result = await repo.deleteNote('abc');

      expect(result, isA<Failure<void>>());
      final failure = (result as Failure<void>).exception;
      expect(failure, isA<NoteRetrievalFailure>());
      expect(failure.message, contains('Invalid note id'));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/repositories/notes_repository_test.dart -p vm`
Expected: FAIL — `Target of URI doesn't exist: 'package:vipo/repositories/notes_repository.dart'` (`NotesRepository`, `repo` unresolved).

- [ ] **Step 3: Write minimal implementation**

Create `lib/repositories/notes_repository.dart` with this content exactly:

```dart
import 'package:dio/dio.dart';
import 'package:vipo/data/services/notes_service.dart';
import 'package:vipo/domain/models/note.dart';
import 'package:vipo/domain/models/timer_mode.dart';
import 'package:vipo/domain/result.dart';

/// Single source of truth for note data — the only class the BLoC layer may
/// call to read or write notes. Wraps a single injected [NotesService] and
/// returns [Result]s so callers never see [DioException] or
/// [FormatException].
///
/// No business logic: every method delegates to exactly one service method
/// and maps any thrown [DioException] or [FormatException] to a domain
/// failure. The service is the **only** data-layer dependency — this file
/// does not import `lib/data/api/` (generated code) and does not import any
/// BLoC/UI file.
class NotesRepository {
  const NotesRepository(this._service);

  final NotesService _service;

  /// Creates a note on the server. Delegates to
  /// [NotesService.createNote]. [pomodoroState] is supplied by the caller
  /// because the domain [Note] deliberately omits it (see SN-1 of the
  /// plan), matching the service contract from issue #7. Any
  /// [DioException] is normalized to a [NoteCreateFailure].
  Future<Result<Note>> createNote(Note note, TimerMode pomodoroState) async {
    try {
      return Result.success(
        await _service.createNote(note, pomodoroState),
      );
    } on DioException catch (e) {
      return Result.failure(NoteCreateFailure(_dioSummary(e)));
    }
  }

  /// Lists notes from the server. Delegates to [NotesService.getNotes].
  /// Any [DioException] is normalized to a [NoteRetrievalFailure].
  Future<Result<List<Note>>> getNotes() async {
    try {
      return Result.success(await _service.getNotes());
    } on DioException catch (e) {
      return Result.failure(NoteRetrievalFailure(_dioSummary(e)));
    }
  }

  /// Fetches a single note by its string id. Delegates to
  /// [NotesService.getNoteById]. Any [DioException] is normalized to a
  /// [NoteRetrievalFailure]. A [FormatException] thrown by the service when
  /// `id` is non-numeric is likewise normalized to a [NoteRetrievalFailure]
  /// so callers never need try-catch (see SN-2 of the plan).
  Future<Result<Note>> getNoteById(String id) async {
    try {
      return Result.success(await _service.getNoteById(id));
    } on DioException catch (e) {
      return Result.failure(NoteRetrievalFailure(_dioSummary(e)));
    } on FormatException {
      return Result.failure(
        NoteRetrievalFailure('Invalid note id: "$id"'),
      );
    }
  }

  /// Deletes a note by its string id. Delegates to
  /// [NotesService.deleteNote]. Any [DioException] is normalized to a
  /// [NoteRetrievalFailure] — there is no `NoteDeleteFailure` (issue scope,
  /// see SN-3 of the plan); `NoteRetrievalFailure` covers deletion too.
  /// A [FormatException] from a non-numeric `id` is normalized to a
  /// [NoteRetrievalFailure] (see SN-2).
  Future<Result<void>> deleteNote(String id) async {
    try {
      await _service.deleteNote(id);
      return Result.success<void>(null);
    } on DioException catch (e) {
      return Result.failure(NoteRetrievalFailure(_dioSummary(e)));
    } on FormatException {
      return Result.failure(
        NoteRetrievalFailure('Invalid note id: "$id"'),
      );
    }
  }
}

/// Builds a short, transport-free summary string of a [DioException] so the
/// domain failure carries no `DioException` object reference. Duplicated in
/// `logs_repository.dart` deliberately (see SN-6 of the plan).
String _dioSummary(DioException e) {
  final code = e.response?.statusCode;
  return code == null ? e.type.name : '${e.type.name} (HTTP $code)';
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/repositories/notes_repository_test.dart -p vm`
Expected: PASS — all eleven tests green: `createNote` happy + 500 + sendTimeout; `getNotes` happy + 502; `getNoteById` happy + 404 + FormatException; `deleteNote` happy + 500 + FormatException.

- [ ] **Step 5: Confirm `flutter analyze` is clean on the new files**

Run: `flutter analyze lib/repositories/notes_repository.dart test/repositories/notes_repository_test.dart`
Expected: `No issues found!`

- [ ] **Step 6: Commit with caveman-commit**

Use the `caveman-commit` skill to write a descriptive commit message. Then use the temp file pattern from the core-commands skill:

```bash
mktemp
```

Use the Write tool to save the commit message to that path, for example:

```
feat(repos): add NotesRepository wrapping NotesService

createNote (extra TimerMode param, matches service SN-2),
getNotes, getNoteById, deleteNote delegate to NotesService and
return Result<T>. DioException and FormatException are both
normalized to NoteCreateFailure / NoteRetrievalFailure; the
original exceptions are never stored, so BLoCs never see
transport types or try-catch.

Refs #8
```

Then:

```bash
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

---

## Task 4: Verify acceptance criteria

**Files:** none modified — verification only.

- [ ] **Step 1: Run `flutter analyze` over the whole project**

Run: `flutter analyze`
Expected: `No issues found!` — confirms the zero-warnings criterion, and that none of the new files (`lib/domain/result.dart`, `lib/repositories/*`, `test/repositories/*`) leak any analyzer warning.

- [ ] **Step 2: Run the relevant test scope**

Run: `flutter test test/domain test/data test/repositories -p vm`
Expected: PASS — all `test/domain/*` (including the new `result_test.dart`), all `test/data/services/*` (from the prerequisite services plan), and all `test/repositories/*` (this plan) pass. `test/widget_test.dart` is intentionally excluded (known-broken stale template, out of scope per SN-8).

- [ ] **Step 3: Verify the no-BLoC / no-UI / no-generated-code import rule**

Run each of the following searches (each must produce **zero matches**):

```bash
rg -n "package:vipo/(blocs|screens|widgets)/" lib/repositories/
rg -n "package:vipo/data/api/" lib/repositories/
rg -n "package:vipo/(blocs|screens|widgets)/" lib/domain/result.dart
rg -n "package:vipo/data/api/" lib/domain/result.dart
```

Expected: all four commands print nothing (no matches). The repositories may import only `package:dio/dio.dart`, `package:vipo/data/services/*`, `package:vipo/domain/models/*`, and `package:vipo/domain/result.dart` (see the import blocks written in Tasks 2 & 3).

- [ ] **Step 4: Verify no generated-API type appears in any repository's public surface**

Open `lib/repositories/logs_repository.dart` and `lib/repositories/notes_repository.dart`. For each public method, confirm:
- The declared **return type** is one of `Future<Result<LogEntry>>`, `Future<Result<List<LogEntry>>>`, `Future<Result<Note>>`, `Future<Result<List<Note>>>`, `Future<Result<void>>`. No `api.*` reference.
- The **parameter types** are domain types only (`LogEntry`, `Note`, `String`, `TimerMode`). No `api.*` reference.
- The **constructor parameter type** is the service class (`LogsService` / `NotesService`) — never `api.LogsApi` / `api.NotesApi` (the issue forbids the repository touching generated code; service is the only data-layer dependency).

The only `dio`-typed reference inside these files is the private `_dioSummary(DioException e)` helper, which is a file-private top-level function (not a public method or field) — acceptable, since `DioException` is from the `dio` package (a direct dependency) and not generated code under `lib/data/api/`.

- [ ] **Step 5: Verify every repository method returns `Result<T>` and none throws `DioException`**

Open `lib/repositories/logs_repository.dart` and `lib/repositories/notes_repository.dart`. For every public method, confirm a `try { ... return Result.success(...); } on DioException catch (...) { return Result.failure(...); }` pattern (and, for `getNoteById` / `deleteNote`, an additional `on FormatException` catch returning `Result.failure(NoteRetrievalFailure(...))`). No method rethrows `DioException` or `FormatException`. No method has an unguarded code path that could throw a transport-layer exception out to the caller.

- [ ] **Step 6: Verify constructor DI — no service instantiated internally**

Run:

```bash
rg -n "LogsService\(|NotesService\(" lib/repositories/
```

Expected: **zero matches** (the repositories never `new`-up their services; they receive them via the `const` constructor's `this._service` parameter). The only `LogsService(` / `NotesService(` references in the codebase are in tests (`MockLogsService()` / `MockNotesService()` — different identifiers) and in the prerequisite services plan's DI wiring (out of scope here).

- [ ] **Step 7: (Optional) Review the full diff and clean up**

Run: `jj diff` (or `jj status`) and scan for stray debug `print` statements, leftover imports, or temp-file artefacts in `/tmp`.
Clean up any untracked temp files: `rm /tmp/tmp.*` (only your own leftovers — none expected if every commit step paired `rm` with the `mktemp`).
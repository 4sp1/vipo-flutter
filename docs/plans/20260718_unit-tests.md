# Unit Tests for BLoCs, Repositories, and Services Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use supervised-plan-execution to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the test suite fully satisfy issue #12's acceptance criteria — every BLoC, repository, service, mapper, and `Result<T>` covered with `mocktail`/`bloc_test`, all dependencies mocked, `flutter test` green and `flutter analyze` zero warnings.

**Architecture:** The repo already contains a near-complete test suite (see the **Current state audit** below). This plan audits those tests against issue #12's acceptance criteria, then fills the concrete gaps: `DioException`-propagation tests for both services, a direct `TimerCompleted` event test, and a `TimerBloc.close()` subscription-cancellation test. No production code changes are required for the gaps — they are pure test additions. Commits use the `jj` temp-file pattern (see `core-commands` skill).

**Tech Stack:** Dart + Flutter, `flutter_test`, `mocktail` (mocks), `bloc_test` (BLoC suites), `dio` (`DioException`), `equatable`, `flutter_bloc`. Generated API client under `lib/data/api/` (excluded from analysis by `analysis_options.yaml`).

---

## Current state audit (completed during planning)

All 21 source files and all 20 existing test files were read. Mapping each acceptance criterion from issue #12 to current coverage:

| Acceptance criterion | Status | Evidence |
|---|---|---|
| `flutter test` green | **needs verification** | Run in Task 1 |
| `flutter analyze` zero warnings | **needs verification** | Run in Task 1 |
| Every BLoC has `bloc_test` suite covering all events/transitions | partial | `timer_bloc_test.dart` covers TimerStarted/Ticked(incl. zero)/Paused/Resumed/Reset/ModeChanged but **no direct `TimerCompleted` event test**; **no `StreamSubscription` cancel-on-close test** |
| Every repository has success+failure `Result` paths | ✅ | `logs_repository_test.dart` (8), `notes_repository_test.dart` (12) cover all methods incl. `FormatException` path |
| Every service verifies delegation+mapping | partial | Delegation+mapping covered for both services; **no `DioException`-propagation tests in either service** |
| Every mapper has round-trip over all enum cases | ✅ | `pomodoro_state_mapper`, `log_entry_mapper` (all 6 LogAction × all TimerMode), `note_mapper` (all PomodoroState) |
| `Result<T>` pattern-matching tests | ✅ | `result_test.dart` exercises sealed switch on `Success`/`Failure` |
| Four domain failure exception types tested | ✅ | `result_test.dart`: `isA<Exception>()`, `toString()`, `.message` for all four |
| No real HTTP / all deps mocked | ✅ | Only `di_test.dart`, `widget_test.dart`, `api_smoke_test.dart` instantiate real `AppDeps`/`VipoApi`; none make network calls. All unit tests mock the API/service/repository layer |
| Mocks use `mocktail`; BLoC tests use `bloc_test` | ✅ | Confirmed across all unit test files |

**Decision: do NOT refactor `timer_bloc_test.dart` to mock `LogsBloc`.** Issue #12 says "Mock `LogsBloc`… verify `LogCreated` was added." The existing test instead injects a real `LogsBloc` backed by a `MockLogsRepository` and verifies `mockLogsRepository.createLog(any(that: isA<LogEntry>().having(e=>e.action, …, LogAction.start)))` was called. Because `createLog` is only reachable via the `LogsBloc`'s `LogCreated` handler, this assertion is strictly stronger than spying on `LogsBloc.add` — it proves the `LogCreated` event was both added **and** processed end-to-end. Mocking `LogsBloc` directly would reduce coverage and is a regression. The intent of the requirement (prove `LogCreated` flows out of `TimerBloc`) is already met. This plan does not touch that pattern.

File-location note: issue #12's tree shows `test/services/…` and `test/domain/mappers/…`, but the repo uses `test/data/services/…` and `test/domain/…`. The acceptance criteria do not mandate paths; this plan keeps the existing layout and only **adds** to files already at their real paths.

---

## File map

- Modify (add tests only, no prod changes):
  - `test/data/services/logs_service_test.dart` — add `DioException` propagation tests for `createLog` and `getLogs`
  - `test/data/services/notes_service_test.dart` — add `DioException` propagation tests for `createNote`, `getNotes`, `getNoteById`, `deleteNote`
  - `test/blocs/timer/timer_bloc_test.dart` — add direct `TimerCompleted` event test; add `close()` cancels subscription test

No new files. No production (`lib/`) changes.

---

## Task 1: Establish baseline — confirm existing suite is green and analyze is clean

**Files:**
- Read: `pubspec.yaml`, `analysis_options.yaml`

- [ ] **Step 1: Run the full test suite**

Run: `flutter test`
Expected: all tests pass. Capture the green summary (e.g. `All tests passed!`). If any fail, record the failure list — those become additional gap tasks before proceeding.

- [ ] **Step 2: Run static analysis**

Run: `flutter analyze`
Expected: `No issues found! (ran in …)`. If warnings exist, record them; only address warnings introduced by or related to the test files this plan touches. Do **not** fix unrelated pre-existing warnings (out of scope for this issue).

- [ ] **Step 3: Commit the baseline record**

No code changes here, so no commit. Proceed to Task 2.

---

## Task 2: Add `DioException` propagation tests to `logs_service_test.dart`

**Files:**
- Modify: `test/data/services/logs_service_test.dart`

The service contract (see `lib/data/services/logs_service.dart` doc comment: *"`DioException` propagates untouched — error normalization is the repository's responsibility"*) requires that a `DioException` thrown by the generated `LogsApi` surfaces from `LogsService` unchanged (not caught, not wrapped). Issue #12 explicitly requires: *"Verify `DioException` propagates unswallowed."*

The existing file already imports `package:dio/dio.dart` (uses `Response`, `RequestOptions`) and `api.LogEntry`/`api.LogEntryList`. No new imports needed.

- [ ] **Step 1: Write the failing tests**

Append a new top-level `group('LogsService error propagation', …)` to `main()` in `test/data/services/logs_service_test.dart`, **after** the existing `group('LogsService.getLogs', …)` block and before the closing `}` of `main`:

```dart
  group('LogsService error propagation (DioException surfaces unswallowed)', () {
    DioException dioErr({int? statusCode}) {
      final response = statusCode == null
          ? null
          : Response<void>(
              requestOptions: RequestOptions(path: '/log'),
              statusCode: statusCode,
            );
      return DioException(
        requestOptions: RequestOptions(path: '/log'),
        response: response,
        type: DioExceptionType.badResponse,
        message: 'boom',
      );
    }

    test('createLog propagates DioException from LogsApi.createLogEntry',
        () async {
      when(() => mockApi.createLogEntry(
              createLogEntryRequest: any(named: 'createLogEntryRequest')))
          .thenThrow(dioErr(statusCode: 500));

      final input = LogEntry(
        id: '0',
        pomodoroState: TimerMode.work,
        action: LogAction.start,
        createdAt: ts,
      );

      await expectLater(
        service.createLog(input),
        throwsA(isA<DioException>()),
      );
      verify(() => mockApi.createLogEntry(
              createLogEntryRequest: any(named: 'createLogEntryRequest')))
          .called(1);
    });

    test('getLogs propagates DioException from LogsApi.listLogEntries',
        () async {
      when(() => mockApi.listLogEntries()).thenThrow(dioErr(statusCode: 503));

      await expectLater(
        service.getLogs(),
        throwsA(isA<DioException>()
            .having((e) => e.response?.statusCode, 'statusCode', 503)),
      );
      verify(() => mockApi.listLogEntries()).called(1);
    });
  });
```

- [ ] **Step 2: Run the new tests to verify they pass**

Run: `flutter test test/data/services/logs_service_test.dart`
Expected: PASS. The service has no try/catch around the API calls, so the `DioException` surfaces directly. If a test fails with "MissingStubError", the `when` matcher is wrong — re-check the named param spelling (`createLogEntryRequest:`).

- [ ] **Step 3: Run the whole file once more for regressions**

Run: `flutter test test/data/services/logs_service_test.dart`
Expected: all tests (existing + new) pass.

- [ ] **Step 4: Commit with caveman-commit**

Use temp-file pattern:
```bash
mktemp
# Write the message below to the returned path with the Write tool:
test(logs): assert DioException propagates unswallowed

Services must surface transport errors untouched so repositories
can normalize them into domain failures (#12).

# then:
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

---

## Task 3: Add `DioException` propagation tests to `notes_service_test.dart`

**Files:**
- Modify: `test/data/services/notes_service_test.dart`

Same contract as logs service: `NotesService` must let `DioException` from `api.NotesApi` propagate. Issue #12 requires it for all four methods. The existing file imports `package:dio/dio.dart` and `api.Note`/`api.NoteList`; no new imports needed.

- [ ] **Step 1: Write the failing tests**

Append a new top-level `group('NotesService error propagation', …)` to `main()` in `test/data/services/notes_service_test.dart`, **after** the existing `group('NotesService.deleteNote', …)` block and before the closing `}` of `main`:

```dart
  group('NotesService error propagation (DioException surfaces unswallowed)',
      () {
    DioException dioErr({int? statusCode}) {
      final response = statusCode == null
          ? null
          : Response<void>(
              requestOptions: RequestOptions(path: '/notes'),
              statusCode: statusCode,
            );
      return DioException(
        requestOptions: RequestOptions(path: '/notes'),
        response: response,
        type: DioExceptionType.badResponse,
        message: 'boom',
      );
    }

    test('createNote propagates DioException from NotesApi.createNote',
        () async {
      when(() =>
              mockApi.createNote(createNoteRequest: any(named: 'createNoteRequest')))
          .thenThrow(dioErr(statusCode: 500));

      final input = Note(id: '0', content: 'hello', createdAt: ts);

      await expectLater(
        service.createNote(input, TimerMode.work),
        throwsA(isA<DioException>()),
      );
    });

    test('getNotes propagates DioException from NotesApi.listNotes', () async {
      when(() => mockApi.listNotes()).thenThrow(dioErr(statusCode: 502));

      await expectLater(
        service.getNotes(),
        throwsA(isA<DioException>()
            .having((e) => e.response?.statusCode, 'statusCode', 502)),
      );
    });

    test('getNoteById propagates DioException from NotesApi.getNote', () async {
      when(() => mockApi.getNote(id: any(named: 'id')))
          .thenThrow(dioErr(statusCode: 404));

      await expectLater(
        service.getNoteById('7'),
        throwsA(isA<DioException>()
            .having((e) => e.response?.statusCode, 'statusCode', 404)),
      );
      verify(() => mockApi.getNote(id: 7)).called(1);
    });

    test('deleteNote propagates DioException from NotesApi.deleteNote',
        () async {
      when(() => mockApi.deleteNote(id: any(named: 'id')))
          .thenThrow(dioErr(statusCode: 500));

      await expectLater(
        service.deleteNote('5'),
        throwsA(isA<DioException>()),
      );
      verify(() => mockApi.deleteNote(id: 5)).called(1);
    });
  });
```

Note: `getNoteById('7')` and `deleteNote('5')` use numeric ids so `int.parse` succeeds and the call reaches the mocked API (where the `DioException` is thrown). The non-numeric-id `FormatException` path is already covered by existing tests; do not duplicate.

- [ ] **Step 2: Run the new tests to verify they pass**

Run: `flutter test test/data/services/notes_service_test.dart`
Expected: PASS. If a `MissingStubError` appears for `deleteNote`'s `Response<void>`, confirm the mock already returns `okResponse<void>(null)` in earlier tests — `thenThrow` overrides that stub anyway, so this should not occur.

- [ ] **Step 3: Run the whole file for regressions**

Run: `flutter test test/data/services/notes_service_test.dart`
Expected: all tests pass.

- [ ] **Step 4: Commit with caveman-commit**

```bash
mktemp
# Write to the returned path:
test(notes): assert DioException propagates unswallowed

All four NotesService methods must surface transport errors
untouched so the repository can normalize them (#12).

jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

---

## Task 4: Add direct `TimerCompleted` event test to `timer_bloc_test.dart`

**Files:**
- Modify: `test/blocs/timer/timer_bloc_test.dart`

Issue #12 lists `TimerCompleted` as a discrete event: *"emits `TimerComplete`; verify `LogCreated` was added to mocked `LogsBloc`."* The existing suite covers `TimerCompleted` only indirectly (via `TimerTicked(0)` which internally `add`s `TimerCompleted`). Add a direct test that seeds `TimerRunInProgress` and fires `TimerCompleted`.

The existing file already imports everything needed (`bloc_test`, `mocktail`, the timer event/state classes, `LogAction`, `LogEntry`, `TimerMode`, `Result`, `LogsRepository`). No new imports.

- [ ] **Step 1: Write the failing test**

Insert the following `blocTest` inside the existing `group('TimerBloc', …)` block in `test/blocs/timer/timer_bloc_test.dart`, e.g. immediately after the existing `TimerModeChanged` `blocTest`:

```dart
    blocTest<TimerBloc, st.TimerState>(
      'emits [TimerComplete] on TimerCompleted and dispatches LogCreated(expire)',
      build: () => TimerBloc(logsBloc),
      seed: () => st.TimerRunInProgress(TimerMode.work, 500),
      act: (bloc) => bloc.add(const TimerCompleted()),
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
```

- [ ] **Step 2: Run the test to verify it passes**

Run: `flutter test test/blocs/timer/timer_bloc_test.dart`
Expected: PASS. `TimerCompleted` → `_onCompleted` emits `TimerComplete(state.mode)` and calls `_dispatchLog(LogAction.expire, state.mode)`, which adds a `LogCreated` to the real `LogsBloc`; the real `LogsBloc` then calls `mockLogsRepository.createLog`, which is stubbed in `setUp` to return `Result.success(fallbackEntry)`. The verify asserts the repository saw an entry whose `.action` is `LogAction.expire` — proving the `LogCreated(expire)` event flowed out.

- [ ] **Step 3: Run the whole file for regressions**

Run: `flutter test test/blocs/timer/timer_bloc_test.dart`
Expected: all timer tests pass.

- [ ] **Step 4: Commit with caveman-commit**

```bash
mktemp
# Write to the returned path:
test(timer): cover TimerCompleted event directly

Existing suite only reached TimerCompleted via TimerTicked(0).
Add a direct-event test asserting TimerComplete + LogCreated(expire).

jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

---

## Task 5: Add `TimerBloc.close()` subscription-cancellation test

**Files:**
- Modify: `test/blocs/timer/timer_bloc_test.dart`

Issue #12 requires: *"Verify `StreamSubscription` is cancelled on `TimerBloc.close()`."* `TimerBloc.close()` calls `_tickerSubscription?.cancel()` (see `lib/blocs/timer/timer_bloc.dart`). The ticker is a real `Stream.periodic` created inside `_startTicker`, so it is **not** injectable. The strongest in-scope, non-flaky assertion is: after `TimerStarted` opens a subscription and the bloc is then closed, no further `TimerTicked` events are processed (i.e. the cancellation took effect) and the bloc's stream completes.

Because `Stream.periodic` uses the zone's timer scheduler, `FakeAsync` (from `package:fake_async`, available transitively via `flutter_test`) controls it deterministically — letting us start the ticker, advance time to prove it is ticking, then close and advance far more time to prove it stopped.

- [ ] **Step 1: Add the `fake_async` import**

At the top of `test/blocs/timer/timer_bloc_test.dart`, add (with the other dart/library imports, before the `package:vipo/…` imports to keep convention):

```dart
import 'package:fake_async/fake_async.dart';
```

- [ ] **Step 2: Write the test**

Insert this `test` inside the existing `group('TimerBloc', …)` block in `test/blocs/timer/timer_bloc_test.dart`, after the cancellation target `TimerCompleted` test from Task 4:

```dart
    test('cancels the ticker StreamSubscription on close', () {
      fakeAsync((async) {
        final bloc = TimerBloc(logsBloc);

        // Seed a running timer without going through TimerStarted so we
        // control exactly when the ticker starts.
        bloc.add(TimerStarted(TimerMode.work));
        async.flushMicrotasks();

        // Advance 2 real seconds: the Stream.periodic ticker (1 tick/sec)
        // would emit 2 TimerTicked events while subscribed. Capture states.
        final states = <st.TimerState>[];
        final sub = bloc.stream.listen(states.add);
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        // While running, the bloc should have progressed (ticked at least
        // once after the initial TimerRunInProgress emission).
        expect(states.whereType<st.TimerRunInProgress>(), isNotEmpty);

        // Now close — this must cancel the ticker subscription.
        bloc.close();
        async.flushMicrotasks();

        // Advance far beyond the original remaining duration. If the
        // subscription were NOT cancelled, the bloc would attempt to
        // add() TimerTicked events to a closed bloc, throwing. No throw
        // + no further emissions means cancel() took effect.
        final countBefore = states.length;
        async.elapse(const Duration(seconds: 40));
        async.flushMicrotasks();

        expect(states.length, countBefore);

        // The remaining duration is 1200s; assert the ticker never reached
        // it (closing prevented TimerComplete/TimerCompleted from firing).
        expect(states.whereType<st.TimerComplete>(), isEmpty);

        sub.cancel();
      });
    });
```

Why this is deterministic: `FakeAsync` replaces the zone's timer queue, and `Stream.periodic` schedules each emission as a zone timer, so `async.elapse` advances the countdown deterministically (one `TimerTicked` per virtual second, each carrying `remaining - tickCount - 1`). While subscribed, those ticks translate into `TimerRunInProgress` emissions on `bloc.stream` → `states` grows. After `close()` cancels the subscription, advancing 40 more virtual seconds must not grow `states` (no ticks delivered) and must not throw.

- [ ] **Step 3: Run the test to verify it passes**

Run: `flutter test test/blocs/timer/timer_bloc_test.dart --plain-name "cancels the ticker StreamSubscription on close"`
Expected: PASS.

If it fails because `states` grew after close: the `_tickerSubscription?.cancel()` path isn't being hit — confirm `TimerStarted` actually started the ticker (the `add` must be flushed via `async.flushMicrotasks()` **before** `.listen`, but we attach the listener after flush; that's fine, we only care about post-close growth). If pre-close emissions aren't captured, move the `.listen` call to **before** `bloc.add(TimerStarted(…))` and then `async.flushMicrotasks()`.

- [ ] **Step 4: Run the whole file for regressions**

Run: `flutter test test/blocs/timer/timer_bloc_test.dart`
Expected: all timer tests pass.

- [ ] **Step 5: Commit with caveman-commit**

```bash
mktemp
# Write to the returned path:
test(timer): verify ticker subscription cancelled on close

Use FakeAsync to elapse time, prove ticking then assert no
emissions after close — guards against leaked Stream.periodic.

jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

---

## Task 6: Final verification — full suite green + analyze clean

**Files:** none (verification only)

- [ ] **Step 1: Run the complete test suite**

Run: `flutter test`
Expected: `All tests passed!` with a count that includes the new tests from Tasks 2–5 on top of the pre-existing suite.

- [ ] **Step 2: Run static analysis across the repo**

Run: `flutter analyze`
Expected: `No issues found!`. The new tests use the same import style and `mocktail`/`bloc_test` APIs already present, so no new warnings should appear. If a lint fires (e.g. `prefer_single_quotes`), fix it in the offending test file only — do not change other files.

- [ ] **Step 3: Cross-check acceptance criteria**

Walk this checklist against the now-green suite:

- [ ] Every BLoC has `bloc_test`-based suite covering all events and state transitions — `timer` (incl. direct `TimerCompleted` + close), `logs` (fetch success/fail, created success/fail), `notes` (fetch success/fail, created success/fail, deleted success/fail).
- [ ] Every repository has success+failure `Result` paths — `logs_repository_test.dart`, `notes_repository_test.dart` (incl. `FormatException` path).
- [ ] Every service verifies delegation, mapping, **and `DioException` propagation** — both service test files now have the propagation group.
- [ ] Every mapper has a round-trip over all enum cases — three mapper test files.
- [ ] `Result<T>` sealed class pattern-matching tests — `result_test.dart`.
- [ ] Four domain failure types tested — `result_test.dart`.
- [ ] No test uses a real HTTP client / makes network calls — confirmed (only `di_test`/`widget_test`/`api_smoke_test` construct `AppDeps`/`VipoApi`; none perform I/O).
- [ ] All mocks use `mocktail`; BLoC tests use `bloc_test` — confirmed.

- [ ] **Step 4: Final commit if any lint fixes were applied in Step 2**

If Step 2 required edits, commit them:
```bash
mktemp
# Write to the returned path:
test: satisfy analyze on new propagation/cancel tests

# (only if Step 2 produced diffs)
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```
If Step 2 was already clean, skip the commit — Task 5's commit is the final one.

---

## Self-review notes

**Spec coverage:** Every checkbox in issue #12's acceptance criteria maps to a task or is marked satisfied in the audit table. The four genuine gaps (service `DioException` propagation ×2, direct `TimerCompleted`, close-cancellation) are Tasks 2–5. No spec requirement is left unaddressed.

**Placeholder scan:** No TBD/TODO/"similar to Task N"/"add appropriate handling" appears. Every code step contains the literal Dart to insert.

**Type consistency:** Verified against source:
- `mockApi.createLogEntry(createLogEntryRequest: …)` — matches `LogsApi.createLogEntry` signature (`required CreateLogEntryRequest createLogEntryRequest`).
- `mockApi.listLogEntries()` — matches `LogsApi.listLogEntries` (all params optional/default).
- `mockApi.createNote(createNoteRequest: …)`, `mockApi.listNotes()`, `mockApi.getNote(id: …)`, `mockApi.deleteNote(id: …)` — match `NotesApi` signatures.
- `mockLogsRepository.createLog(any())` stub in `setUp` matches `LogsRepository.createLog(LogEntry)` — the existing timer tests rely on this; our `TimerCompleted` test reuses it, no change needed.
- `TimerComplete(TimerMode)` constructor + `st.TimerComplete` alias match `timer_state.dart`.
- `LogAction.expire` exists in both domain and generated enums (verified in `log_action.dart`).
- `fake_async` is a transitive dep of `flutter_test`; `fakeAsync`/`FakeAsync` are public API.

**Dart conventions:** New tests use single quotes and trailing commas matching the existing file style (which passes `flutter_lints`).

Plan saved to `docs/plans/20260718_unit-tests.md`. Ready to execute with `supervised-plan-execution` — sequential implementation with two-stage self-review after each task. Proceed?
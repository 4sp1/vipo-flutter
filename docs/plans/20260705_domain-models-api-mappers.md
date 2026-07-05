# Domain Models & API Mappers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use supervised-plan-execution to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create pure-data domain models (`LogEntry`, `Note`, `LogAction`) and mappers that bridge generated API types (`PomodoroState`, `LogEntry`, `Note`, `LogAction`) with domain types (`TimerMode`, `LogEntry`, `Note`, `LogAction`), so higher layers never import generated code directly.

**Architecture:** A new `lib/domain/` layer with two sub-folders: `models/` (immutable value classes + enums, no generated-code imports) and `mappers/` (pure functions that import `lib/data/api/` with an `as api` alias and translate to/from domain types). The existing `TimerMode` enum relocates from `lib/models/` to `lib/domain/models/` verbatim; its two importers are repointed.

**Tech Stack:** Dart ^3.10.4, Flutter, `flutter_test`, existing generated OpenAPI client under `lib/data/api/`.

---

## Spec Notes & Design Decisions

Read these before implementing — they resolve mismatches between the issue text and the actual generated code.

### SN-1. Domain-vs-API field name/type differences for `LogEntry`
The issue describes domain `LogEntry` fields as `id` (String), `pomodoroState` (TimerMode), `action` (LogAction), `createdAt` (DateTime). The generated `ApiLogEntry` (in `lib/data/api/src/model/log_entry.dart`) actually has: `id` (int), `action` (LogAction), `session` (PomodoroState), `timestamp` (DateTime), `payload` (Object?). Mapping decisions:

| Domain field     | API field     | Conversion                  |
|------------------|---------------|-----------------------------|
| `id: String`     | `id: int`     | `int.toString()` ↔ `int.parse` |
| `pomodoroState`  | `session`     | via `pomodoro_state_mapper` |
| `action`         | `action`      | via `_toDomainLogAction` / `_toApiLogAction` |
| `createdAt`      | `timestamp`   | identity (DateTime)         |
| _(none)_         | `payload`     | dropped on domain side; set to `null` on reverse |

### SN-2. Domain `Note` omits `pomodoroState`; reverse mapper needs it injected
Generated `ApiNote` (in `lib/data/api/src/model/note.dart`) has required `pomodoroState: PomodoroState` plus `id` (int), `note` (String), `createdAt` (DateTime). The issue specifies domain `Note` with only `id` (String), `content` (String), `createdAt` (DateTime) — `pomodoroState` is intentionally not modelled in the domain layer.

**Deviation from spec signature:** `toApiNote` cannot construct a valid `ApiNote` without `pomodoroState`. We therefore deviate from the issue's literal `ApiNote toApiNote(Note domainNote)` signature and implement:

```dart
api.Note toApiNote(Note domainNote, {required api.PomodoroState pomodoroState})
```

Rationale: keeps the domain `Note` lossless per spec while forcing the caller to supply the contextual timer-mode metadata (mirroring `CreateNoteRequest`, which also requires `pomodoroState`). The domain→API direction is inherently lossy/needs context; making it an explicit required parameter beats silently defaulting.

### SN-3. No separate `log_action_mapper` file
The issue lists only three mapper files. `LogAction` conversion is therefore implemented as **private** helpers `_toDomainLogAction` / `_toApiLogAction` inside `log_entry_mapper.dart`. They are covered by tests via the public `LogEntry` mappers.

### SN-4. Exhaustive switches, no fallthrough
Every mapper uses a `switch (e) { case ...: return ...; }` over an enum with **no default** and **no `throw UnimplementedError`**. The Dart analyzer enforces exhaustiveness, so adding a new enum case later produces a compile error at every mapper — exactly what we want.

### SN-5. `flutter test` is partially pre-broken (out of scope)
`test/widget_test.dart` is the stale Flutter template (references `MyApp` + Material `Icons.add`); per `AGENTS.md` it fails as-is. We do **not** touch it. We run only our new tests via `flutter test test/domain/`. The acceptance gate is `flutter analyze` (zero warnings) plus our domain tests passing.

### SN-6. Import alias `as api`
To avoid name collisions (`LogEntry`, `Note`, `LogAction` exist in both layers), every mapper imports generated files with `as api` and references them as `api.LogEntry`, etc. The domain layer code uses un-aliased imports for its own types.

---

## File Structure

**Create:**

| File | Responsibility |
|------|----------------|
| `lib/domain/models/timer_mode.dart` | Relocated `TimerMode` enum (verbatim body) |
| `lib/domain/models/log_action.dart` | Domain `LogAction` enum — pure Dart, no API import |
| `lib/domain/models/log_entry.dart` | Immutable `LogEntry` value class (id, pomodoroState, action, createdAt) |
| `lib/domain/models/note.dart` | Immutable `Note` value class (id, content, createdAt) |
| `lib/domain/mappers/pomodoro_state_mapper.dart` | `PomodoroState` ↔ `TimerMode` |
| `lib/domain/mappers/log_entry_mapper.dart` | `ApiLogEntry` ↔ `LogEntry` (+ private `LogAction` helpers) |
| `lib/domain/mappers/note_mapper.dart` | `ApiNote` ↔ `Note` |
| `test/domain/timer_mode_test.dart` | Sanity test for relocated enum |
| `test/domain/log_action_test.dart` | `LogAction` enum arity/names |
| `test/domain/log_entry_model_test.dart` | `LogEntry` equality |
| `test/domain/note_model_test.dart` | `Note` equality |
| `test/domain/pomodoro_state_mapper_test.dart` | `PomodoroState` ↔ `TimerMode` |
| `test/domain/log_entry_mapper_test.dart` | `ApiLogEntry` ↔ `LogEntry` round-trips |
| `test/domain/note_mapper_test.dart` | `ApiNote` ↔ `Note` |

**Modify (import path repoint only — no logic changes):**

| File | Line | Old | New |
|------|------|-----|-----|
| `lib/timer_screen.dart` | 4 | `import 'models/timer_mode.dart';` | `import 'domain/models/timer_mode.dart';` |
| `lib/widgets/mode_switch.dart` | 2 | `import '../models/timer_mode.dart';` | `import '../domain/models/timer_mode.dart';` |

**Delete:**

| File | Reason |
|------|--------|
| `lib/models/timer_mode.dart` | Relocated to `lib/domain/models/` |

---

## Task 1: Relocate `TimerMode` enum to `lib/domain/models/`

**Files:**
- Create: `lib/domain/models/timer_mode.dart`
- Modify: `lib/timer_screen.dart:4`, `lib/widgets/mode_switch.dart:2`
- Delete: `lib/models/timer_mode.dart`
- Test: `test/domain/timer_mode_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/domain/timer_mode_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vipo/domain/models/timer_mode.dart';

void main() {
  test('TimerMode has exactly three values work, shortBreak, longBreak', () {
    expect(TimerMode.values.map((m) => m.name).toList(), [
      'work',
      'shortBreak',
      'longBreak',
    ]);
  });

  test('each mode exposes duration, label, color', () {
    for (final mode in TimerMode.values) {
      expect(mode.duration, isA<Duration>());
      expect(mode.label, isA<String>());
      expect(mode.color, isNotNull);
    }
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/domain/timer_mode_test.dart`
Expected: FAIL with `Error when reading `lib/domain/models/timer_mode.dart`: ... does not exist` (target_not_yet_defined / import not found).

- [ ] **Step 3: Create the relocated file**

Create `lib/domain/models/timer_mode.dart` with the **exact same body** as the original `lib/models/timer_mode.dart`:

```dart
import 'package:flutter/cupertino.dart';

enum TimerMode {
  work(
    duration: Duration(minutes: 20),
    label: 'Work',
    color: CupertinoColors.systemRed,
  ),
  shortBreak(
    duration: Duration(minutes: 5),
    label: 'Short Break',
    color: CupertinoColors.systemGreen,
  ),
  longBreak(
    duration: Duration(minutes: 15),
    label: 'Long Break',
    color: CupertinoColors.systemBlue,
  );

  const TimerMode({
    required this.duration,
    required this.label,
    required this.color,
  });

  final Duration duration;
  final String label;
  final CupertinoDynamicColor color;
}
```

- [ ] **Step 4: Delete the old file**

Run: `rm lib/models/timer_mode.dart`

- [ ] **Step 5: Repoint imports**

In `lib/timer_screen.dart` line 4, change:

```dart
import 'models/timer_mode.dart';
```
to:
```dart
import 'domain/models/timer_mode.dart';
```

In `lib/widgets/mode_switch.dart` line 2, change:

```dart
import '../models/timer_mode.dart';
```
to:
```dart
import '../domain/models/timer_mode.dart';
```

- [ ] **Step 6: Verify analyze passes**

Run: `flutter analyze`
Expected: `No issues found!` (or zero issues). If any issues appear, read them and fix the exact import line that still points at the old path.

- [ ] **Step 7: Run the test to verify it passes**

Run: `flutter test test/domain/timer_mode_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 8: Commit with caveman-commit**

Use the `caveman-commit` skill to write a descriptive commit message. Then use temp file pattern from core-commands skill for commit message:

```bash
mktemp
# Returns: /tmp/tmp.XXXXXX
```

Use Write tool to save the commit message to that path, e.g.:

```
refactor(domain): relocate TimerMode to lib/domain/models

Moves the enum verbatim and repoints imports in timer_screen
and mode_switch. No behaviour change; prepares lib/domain for
new domain models and mappers.

Refs #6
```

Then:

```bash
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

---

## Task 2: Domain `LogAction` enum

**Files:**
- Create: `lib/domain/models/log_action.dart`
- Test: `test/domain/log_action_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/domain/log_action_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vipo/domain/models/log_action.dart';

void main() {
  test('LogAction has exactly six values in spec order', () {
    expect(LogAction.values.map((e) => e.name).toList(), [
      'start',
      'pause',
      'resume',
      'reset',
      'expire',
      'select',
    ]);
  });

  test('every value is distinct', () {
    final names = LogAction.values.map((e) => e.name).toSet();
    expect(names.length, LogAction.values.length);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/domain/log_action_test.dart`
Expected: FAIL (file/import does not exist).

- [ ] **Step 3: Write the minimal implementation**

Create `lib/domain/models/log_action.dart`:

```dart
/// Domain mirror of the API's `LogAction` enum.
///
/// Kept free of any `lib/data/api/` import so the domain layer
/// never depends on generated code.
enum LogAction {
  start,
  pause,
  resume,
  reset,
  expire,
  select;
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/domain/log_action_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Verify analyze passes**

Run: `flutter analyze`
Expected: zero issues.

- [ ] **Step 6: Commit with caveman-commit**

Use the `caveman-commit` skill, then temp file pattern:

```bash
mktemp
```

Write message:

```
feat(domain): add LogAction enum

Mirrors the API LogAction values in the domain layer with no
dependency on generated code.

Refs #6
```

Then:

```bash
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

---

## Task 3: Domain `LogEntry` value class

**Files:**
- Create: `lib/domain/models/log_entry.dart`
- Test: `test/domain/log_entry_model_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/domain/log_entry_model_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vipo/domain/models/log_entry.dart';
import 'package:vipo/domain/models/log_action.dart';
import 'package:vipo/domain/models/timer_mode.dart';

void main() {
  final ts = DateTime.utc(2026, 1, 1, 9, 0, 0);

  LogEntry make({String id = '1'}) => LogEntry(
        id: id,
        pomodoroState: TimerMode.work,
        action: LogAction.start,
        createdAt: ts,
      );

  test('equality is value-based', () {
    expect(make(), equals(make()));
    expect(make().hashCode, make().hashCode);
  });

  test('different id is not equal', () {
    expect(make(id: '1'), isNot(equals(make(id: '2'))));
  });

  test('different pomodoroState is not equal', () {
    final a = make();
    final b = LogEntry(
      id: '1',
      pomodoroState: TimerMode.shortBreak,
      action: LogAction.start,
      createdAt: ts,
    );
    expect(a, isNot(equals(b)));
  });

  test('different action is not equal', () {
    final a = make();
    final b = LogEntry(
      id: '1',
      pomodoroState: TimerMode.work,
      action: LogAction.pause,
      createdAt: ts,
    );
    expect(a, isNot(equals(b)));
  });

  test('toString includes id and action', () {
    final e = make();
    expect(e.toString(), contains('id'));
    expect(e.toString(), contains('start'));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/domain/log_entry_model_test.dart`
Expected: FAIL (import / class does not exist).

- [ ] **Step 3: Write the minimal implementation**

Create `lib/domain/models/log_entry.dart`:

```dart
import 'log_action.dart';
import 'timer_mode.dart';

/// Domain representation of a pomodoro log entry.
///
/// Field mapping vs the generated `lib/data/api/.../log_entry.dart`:
///   id            (String)  <-  id          (int)
///   pomodoroState (TimerMode) <- session    (PomodoroState)
///   action        (LogAction) <- action     (LogAction)
///   createdAt     (DateTime) <- timestamp   (DateTime)
///   _             <-           payload      (Object?)  // dropped
class LogEntry {
  const LogEntry({
    required this.id,
    required this.pomodoroState,
    required this.action,
    required this.createdAt,
  });

  final String id;
  final TimerMode pomodoroState;
  final LogAction action;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LogEntry &&
          other.id == id &&
          other.pomodoroState == pomodoroState &&
          other.action == action &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, pomodoroState, action, createdAt);

  @override
  String toString() =>
      'LogEntry(id: $id, pomodoroState: $pomodoroState, action: $action, '
      'createdAt: $createdAt)';
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/domain/log_entry_model_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Verify analyze passes**

Run: `flutter analyze`
Expected: zero issues.

- [ ] **Step 6: Commit with caveman-commit**

```bash
mktemp
```

Write message:

```
feat(domain): add LogEntry value class

Immutable domain LogEntry (id/pomodoroState/action/createdAt)
with no dependency on generated code.

Refs #6
```

```bash
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

---

## Task 4: Domain `Note` value class

**Files:**
- Create: `lib/domain/models/note.dart`
- Test: `test/domain/note_model_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/domain/note_model_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vipo/domain/models/note.dart';

void main() {
  final ts = DateTime.utc(2026, 1, 1, 9, 0, 0);

  Note make({String id = '1', String content = 'x'}) => Note(
        id: id,
        content: content,
        createdAt: ts,
      );

  test('equality is value-based', () {
    expect(make(), equals(make()));
    expect(make().hashCode, make().hashCode);
  });

  test('different id is not equal', () {
    expect(make(id: '1'), isNot(equals(make(id: '2'))));
  });

  test('different content is not equal', () {
    expect(make(content: 'x'), isNot(equals(make(content: 'y'))));
  });

  test('different createdAt is not equal', () {
    final a = make();
    final b = Note(
      id: '1',
      content: 'x',
      createdAt: ts.add(const Duration(seconds: 1)),
    );
    expect(a, isNot(equals(b)));
  });

  test('toString includes id and content', () {
    final n = make(content: 'hello');
    expect(n.toString(), contains('hello'));
    expect(n.toString(), contains('id'));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/domain/note_model_test.dart`
Expected: FAIL (class does not exist).

- [ ] **Step 3: Write the minimal implementation**

Create `lib/domain/models/note.dart`:

```dart
/// Domain representation of a user note.
///
/// Field mapping vs the generated `lib/data/api/.../note.dart`:
///   id        (String)   <-  id             (int)
///   content   (String)   <-  note           (String)
///   createdAt (DateTime) <-  createdAt      (DateTime)
///   _         <-             pomodoroState  (PomodoroState)  // dropped
class Note {
  const Note({
    required this.id,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String content;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Note &&
          other.id == id &&
          other.content == content &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, content, createdAt);

  @override
  String toString() => 'Note(id: $id, content: $content, createdAt: $createdAt)';
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/domain/note_model_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Verify analyze passes**

Run: `flutter analyze`
Expected: zero issues.

- [ ] **Step 6: Commit with caveman-commit**

```bash
mktemp
```

Write message:

```
feat(domain): add Note value class

Immutable domain Note (id/content/createdAt) with no dependency
on generated code.

Refs #6
```

```bash
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

---

## Task 5: `pomodoro_state_mapper.dart`

**Files:**
- Create: `lib/domain/mappers/pomodoro_state_mapper.dart`
- Test: `test/domain/pomodoro_state_mapper_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/domain/pomodoro_state_mapper_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vipo/data/api/src/model/pomodoro_state.dart' as api;
import 'package:vipo/domain/models/timer_mode.dart';
import 'package:vipo/domain/mappers/pomodoro_state_mapper.dart';

void main() {
  group('toTimerMode', () {
    test('work -> work', () {
      expect(toTimerMode(api.PomodoroState.work), TimerMode.work);
    });
    test('short_break -> shortBreak', () {
      expect(toTimerMode(api.PomodoroState.shortBreak), TimerMode.shortBreak);
    });
    test('long_break -> longBreak', () {
      expect(toTimerMode(api.PomodoroState.longBreak), TimerMode.longBreak);
    });
  });

  group('toApiPomodoroState', () {
    test('work -> work', () {
      expect(toApiPomodoroState(TimerMode.work), api.PomodoroState.work);
    });
    test('shortBreak -> short_break', () {
      expect(toApiPomodoroState(TimerMode.shortBreak),
          api.PomodoroState.shortBreak);
    });
    test('longBreak -> long_break', () {
      expect(toApiPomodoroState(TimerMode.longBreak),
          api.PomodoroState.longBreak);
    });
  });

  test('round-trip preserves value for every mode', () {
    for (final mode in TimerMode.values) {
      expect(toTimerMode(toApiPomodoroState(mode)), mode);
    }
    for (final state in api.PomodoroState.values) {
      expect(toApiPomodoroState(toTimerMode(state)), state);
    }
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/domain/pomodoro_state_mapper_test.dart`
Expected: FAIL (functions not defined / file does not exist).

- [ ] **Step 3: Write the minimal implementation**

Create `lib/domain/mappers/pomodoro_state_mapper.dart`:

```dart
import 'package:vipo/data/api/src/model/pomodoro_state.dart' as api;
import 'package:vipo/domain/models/timer_mode.dart';

/// Converts the generated API enum `PomodoroState` to the domain `TimerMode`.
TimerMode toTimerMode(api.PomodoroState apiState) {
  switch (apiState) {
    case api.PomodoroState.work:
      return TimerMode.work;
    case api.PomodoroState.shortBreak:
      return TimerMode.shortBreak;
    case api.PomodoroState.longBreak:
      return TimerMode.longBreak;
  }
}

/// Converts the domain `TimerMode` to the generated API enum `PomodoroState`.
api.PomodoroState toApiPomodoroState(TimerMode mode) {
  switch (mode) {
    case TimerMode.work:
      return api.PomodoroState.work;
    case TimerMode.shortBreak:
      return api.PomodoroState.shortBreak;
    case TimerMode.longBreak:
      return api.PomodoroState.longBreak;
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/domain/pomodoro_state_mapper_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Verify analyze passes**

Run: `flutter analyze`
Expected: zero issues. Note: the exhaustive switches must not produce a `default_missing` warning. If you see one, you forgot a case — re-read the enum values in `lib/data/api/src/model/pomodoro_state.dart`.

- [ ] **Step 6: Commit with caveman-commit**

```bash
mktemp
```

Write message:

```
feat(domain): add PomodoroState <-> TimerMode mapper

Pure exhaustive switch mapping both directions between the
generated API enum and the domain TimerMode enum.

Refs #6
```

```bash
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

---

## Task 6: `log_entry_mapper.dart` (includes private `LogAction` helpers)

**Files:**
- Create: `lib/domain/mappers/log_entry_mapper.dart`
- Test: `test/domain/log_entry_mapper_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/domain/log_entry_mapper_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vipo/data/api/src/model/log_entry.dart' as api;
import 'package:vipo/data/api/src/model/log_action.dart' as api;
import 'package:vipo/data/api/src/model/pomodoro_state.dart' as api;
import 'package:vipo/domain/models/log_entry.dart';
import 'package:vipo/domain/models/log_action.dart';
import 'package:vipo/domain/models/timer_mode.dart';
import 'package:vipo/domain/mappers/log_entry_mapper.dart';

void main() {
  final ts = DateTime.utc(2026, 1, 1, 9, 0, 0);

  group('toDomainLogEntry', () {
    test('maps every field (id, session, action, timestamp)', () {
      final apiEntry = api.LogEntry(
        id: 42,
        action: api.LogAction.start,
        session: api.PomodoroState.work,
        timestamp: ts,
      );
      final d = toDomainLogEntry(apiEntry);
      expect(d.id, '42');
      expect(d.pomodoroState, TimerMode.work);
      expect(d.action, LogAction.start);
      expect(d.createdAt, ts);
    });

    test('drops payload (domain LogEntry has no payload field)', () {
      final apiEntry = api.LogEntry(
        id: 1,
        action: api.LogAction.reset,
        session: api.PomodoroState.longBreak,
        timestamp: ts,
        payload: {'some': 'data'},
      );
      final d = toDomainLogEntry(apiEntry);
      expect(d.id, '1');
      expect(d.pomodoroState, TimerMode.longBreak);
      expect(d.action, LogAction.reset);
    });

    test('maps every API LogAction case to a domain LogAction', () {
      for (final a in api.LogAction.values) {
        final entry = api.LogEntry(
          id: 1,
          action: a,
          session: api.PomodoroState.work,
          timestamp: ts,
        );
        expect(toDomainLogEntry(entry).action.name, a.name);
      }
    });

    test('maps every API PomodoroState case', () {
      for (final s in api.PomodoroState.values) {
        final entry = api.LogEntry(
          id: 1,
          action: api.LogAction.start,
          session: s,
          timestamp: ts,
        );
        expect(toDomainLogEntry(entry).pomodoroState, isA<TimerMode>());
      }
    });
  });

  group('toApiLogEntry', () {
    test('maps every field and sets payload to null', () {
      final domain = LogEntry(
        id: '42',
        pomodoroState: TimerMode.shortBreak,
        action: LogAction.pause,
        createdAt: ts,
      );
      final a = toApiLogEntry(domain);
      expect(a.id, 42);
      expect(a.session, api.PomodoroState.shortBreak);
      expect(a.action, api.LogAction.pause);
      expect(a.timestamp, ts);
      expect(a.payload, isNull);
    });

    test('round-trips all pomodoro states and all actions', () {
      for (final mode in TimerMode.values) {
        for (final action in LogAction.values) {
          final domain = LogEntry(
            id: '7',
            pomodoroState: mode,
            action: action,
            createdAt: ts,
          );
          final back = toDomainLogEntry(toApiLogEntry(domain));
          expect(back.id, '7');
          expect(back.pomodoroState, mode);
          expect(back.action, action);
          expect(back.createdAt, ts);
        }
      }
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/domain/log_entry_mapper_test.dart`
Expected: FAIL (file/functions not present).

- [ ] **Step 3: Write the minimal implementation**

Create `lib/domain/mappers/log_entry_mapper.dart`:

```dart
import 'package:vipo/data/api/src/model/log_entry.dart' as api;
import 'package:vipo/data/api/src/model/log_action.dart' as api;
import 'package:vipo/domain/models/log_entry.dart';
import 'package:vipo/domain/models/log_action.dart';
import 'package:vipo/domain/mappers/pomodoro_state_mapper.dart';

LogAction _toDomainLogAction(api.LogAction a) {
  switch (a) {
    case api.LogAction.start:
      return LogAction.start;
    case api.LogAction.pause:
      return LogAction.pause;
    case api.LogAction.resume:
      return LogAction.resume;
    case api.LogAction.reset:
      return LogAction.reset;
    case api.LogAction.expire:
      return LogAction.expire;
    case api.LogAction.select:
      return LogAction.select;
  }
}

api.LogAction _toApiLogAction(LogAction a) {
  switch (a) {
    case LogAction.start:
      return api.LogAction.start;
    case LogAction.pause:
      return api.LogAction.pause;
    case LogAction.resume:
      return api.LogAction.resume;
    case LogAction.reset:
      return api.LogAction.reset;
    case LogAction.expire:
      return api.LogAction.expire;
    case LogAction.select:
      return api.LogAction.select;
  }
}

/// Converts the generated API `LogEntry` into the domain `LogEntry`.
///
/// Field mapping: id (int->String), session -> pomodoroState,
/// action -> action, timestamp -> createdAt. `payload` is dropped.
LogEntry toDomainLogEntry(api.LogEntry apiEntry) {
  return LogEntry(
    id: apiEntry.id.toString(),
    pomodoroState: toTimerMode(apiEntry.session),
    action: _toDomainLogAction(apiEntry.action),
    createdAt: apiEntry.timestamp,
  );
}

/// Converts the domain `LogEntry` into the generated API `LogEntry`.
///
/// `payload` is set to `null` (the API field is optional).
/// Throws `FormatException` if [domainEntry.id] is not a valid integer.
api.LogEntry toApiLogEntry(LogEntry domainEntry) {
  return api.LogEntry(
    id: int.parse(domainEntry.id),
    action: _toApiLogAction(domainEntry.action),
    session: toApiPomodoroState(domainEntry.pomodoroState),
    timestamp: domainEntry.createdAt,
    payload: null,
  );
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/domain/log_entry_mapper_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Verify analyze passes**

Run: `flutter analyze`
Expected: zero issues.

- [ ] **Step 6: Commit with caveman-commit**

```bash
mktemp
```

Write message:

```
feat(domain): add LogEntry mapper with LogAction helpers

Pure bidirectional mapper between API and domain LogEntry,
including private LogAction helpers. Payload is dropped on
import and set to null on export.

Refs #6
```

```bash
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

---

## Task 7: `note_mapper.dart`

**Files:**
- Create: `lib/domain/mappers/note_mapper.dart`
- Test: `test/domain/note_mapper_test.dart`

> Reminder (see SN-2): `toApiNote` takes an extra **required** `pomodoroState` parameter because the generated `ApiNote.pomodoroState` is required and the domain `Note` deliberately omits it.

- [ ] **Step 1: Write the failing test**

Create `test/domain/note_mapper_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vipo/data/api/src/model/note.dart' as api;
import 'package:vipo/data/api/src/model/pomodoro_state.dart' as api;
import 'package:vipo/domain/models/note.dart';
import 'package:vipo/domain/mappers/note_mapper.dart';

void main() {
  final ts = DateTime.utc(2026, 1, 1, 9, 0, 0);

  group('toDomainNote', () {
    test('maps id (int->String), note -> content, createdAt', () {
      final apiNote = api.Note(
        id: 9,
        note: 'hello',
        pomodoroState: api.PomodoroState.work,
        createdAt: ts,
      );
      final d = toDomainNote(apiNote);
      expect(d.id, '9');
      expect(d.content, 'hello');
      expect(d.createdAt, ts);
    });

    test('drops pomodoroState (domain Note has no such field)', () {
      final apiNote = api.Note(
        id: 9,
        note: 'hello',
        pomodoroState: api.PomodoroState.longBreak,
        createdAt: ts,
      );
      final d = toDomainNote(apiNote);
      expect(d.id, '9');
      expect(d.content, 'hello');
      // no pomodoroState field to assert on — compilation is the assertion.
    });
  });

  group('toApiNote', () {
    test('injects required pomodoroState and maps other fields', () {
      final domain = Note(id: '9', content: 'hello', createdAt: ts);
      final a = toApiNote(domain, pomodoroState: api.PomodoroState.longBreak);
      expect(a.id, 9);
      expect(a.note, 'hello');
      expect(a.pomodoroState, api.PomodoroState.longBreak);
      expect(a.createdAt, ts);
    });

    test('accepts every PomodoroState value', () {
      final domain = Note(id: '9', content: 'hello', createdAt: ts);
      for (final s in api.PomodoroState.values) {
        final a = toApiNote(domain, pomodoroState: s);
        expect(a.pomodoroState, s);
      }
    });
  });

  test('round-trip preserves content/id/createdAt for every pomodoroState',
      () {
    final apiNote = api.Note(
      id: 5,
      note: 'world',
      pomodoroState: api.PomodoroState.shortBreak,
      createdAt: ts,
    );
    final d = toDomainNote(apiNote);
    final back = toApiNote(d, pomodoroState: api.PomodoroState.shortBreak);
    expect(back.id, 5);
    expect(back.note, 'world');
    expect(back.pomodoroState, api.PomodoroState.shortBreak);
    expect(back.createdAt, ts);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/domain/note_mapper_test.dart`
Expected: FAIL (file/functions do not exist).

- [ ] **Step 3: Write the minimal implementation**

Create `lib/domain/mappers/note_mapper.dart`:

```dart
import 'package:vipo/data/api/src/model/note.dart' as api;
import 'package:vipo/data/api/src/model/pomodoro_state.dart' as api;
import 'package:vipo/domain/models/note.dart';

/// Converts the generated API `Note` into the domain `Note`.
///
/// Field mapping: id (int->String), note -> content, createdAt -> createdAt.
/// The API's `pomodoroState` is intentionally dropped — see SN-2.
Note toDomainNote(api.Note apiNote) {
  return Note(
    id: apiNote.id.toString(),
    content: apiNote.note,
    createdAt: apiNote.createdAt,
  );
}

/// Converts the domain `Note` into the generated API `Note`.
///
/// [pomodoroState] is required because the generated `ApiNote` marks it
/// required, but the domain `Note` deliberately does not model it. The
/// caller supplies the contextual timer-mode at creation time.
/// Throws `FormatException` if [domainNote.id] is not a valid integer.
api.Note toApiNote(
  Note domainNote, {
  required api.PomodoroState pomodoroState,
}) {
  return api.Note(
    id: int.parse(domainNote.id),
    note: domainNote.content,
    pomodoroState: pomodoroState,
    createdAt: domainNote.createdAt,
  );
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/domain/note_mapper_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Verify analyze passes**

Run: `flutter analyze`
Expected: zero issues.

- [ ] **Step 6: Commit with caveman-commit**

```bash
mktemp
```

Write message:

```
feat(domain): add Note mapper

Pure bidirectional mapper between API and domain Note. Domain
Note omits pomodoroState, so toApiNote takes a required
pomodoroState parameter to satisfy the generated API model.

Refs #6
```

```bash
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

---

## Task 8: Final verification against acceptance criteria

**Files:** none modified — verification only.

- [ ] **Step 1: Run the full domain test suite**

Run: `flutter test test/domain/`
Expected: all tests PASS (≈32 tests across 7 files).

- [ ] **Step 2: Run `flutter analyze` and confirm zero issues**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Confirm `TimerMode` relocation is complete**

Run: `ls lib/models/` and confirm the directory is empty (or only contains non-`timer_mode.dart` files). Confirm `lib/domain/models/timer_mode.dart` exists:

Run: `ls lib/domain/models/timer_mode.dart`
Expected: path exists.

- [ ] **Step 4: Confirm no domain file imports UI/BLoC layers**

Run (from repo root):

```bash
grep -rnE "import .*'(blocs|screens|widgets)/" lib/domain/ && echo "FORBIDDEN IMPORT FOUND" || echo "OK: no forbidden imports"
```

Expected: `OK: no forbidden imports`.

- [ ] **Step 5: Confirm domain models have no generated-code dependency**

Run:

```bash
grep -rn "package:vipo/data/" lib/domain/models/ && echo "MODELS IMPORT API" || echo "OK: models are API-free"
```

Expected: `OK: models are API-free`. (Mappers under `lib/domain/mappers/` are *expected* to import `package:vipo/data/api/` — only `lib/domain/models/` must be clean.)

- [ ] **Step 6: Confirm mappers cover all enum cases (no `throw UnimplementedError`)**

Run:

```bash
grep -rn "UnimplementedError" lib/domain/ && echo "FALLTHROW FOUND" || echo "OK: no UnimplementedError"
```

Expected: `OK: no UnimplementedError`.

- [ ] **Step 7: Commit (only if steps 1-6 produced any cleanup edits)**

If the verification surfaced fixes, commit them with caveman-commit. Otherwise skip this step — there is nothing to commit.

```bash
mktemp
```

Write message:

```
test(domain): verify acceptance criteria for #6

Runs flutter analyze, domain tests, and import-grep checks to
confirm domain layer is API-free for models and free of UI/BLoC
imports.

Closes #6
```

```bash
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

---

## Acceptance-criteria traceability

| Acceptance criterion | Covered by |
|---|---|
| `flutter analyze` passes with zero warnings | Task 8 Step 2 (and each task's analyze step) |
| `TimerMode` moved to `lib/domain/models/timer_mode.dart`; all imports updated | Task 1 (Steps 3-5) |
| `LogEntry`, `Note`, `LogAction` exist in `lib/domain/models/` with no generated-code dependency | Tasks 2, 3, 4; verified Task 8 Step 5 |
| `pomodoro_state_mapper.dart`, `log_entry_mapper.dart`, `note_mapper.dart` exist in `lib/domain/mappers/` | Tasks 5, 6, 7 |
| Every mapper covers all enum cases — no fallthrough / `throw UnimplementedError` | Tasks 5, 6, 7 use exhaustive `switch`; verified Task 8 Step 6 |
| No file in `lib/domain/` imports `lib/blocs/`, `lib/screens/`, or `lib/widgets/` | Task 8 Step 4 |
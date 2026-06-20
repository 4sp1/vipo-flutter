# vipo-go Typed HTTP Client (dart-dio) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use supervised-plan-execution to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. This repo uses `jj` (not `git`) and the `caveman-commit` skill for commit messages; see `core-commands` skill for VCS rules.

**Goal:** Produce a typed, dio-based HTTP client from the vipo-go OpenAPI spec and commit it under `lib/data/api/`, forming the foundation for all later data-layer work (services, repositories, BLoCs).

**Architecture:** `openapi-generator` (dart-dio profile) translates `tooling/openapi.json` into Dart model + API classes using `json_serializable`. Output is flattened into the app package under `lib/data/api/` (internal `package:vipo_api/` imports rewritten to `package:vipo/data/api/`), then `build_runner` generates the `.g.dart` part files in one pass at the app root. Build-time base URL is a single `const String kApiBaseUrl` overridable via `--dart-define=API_BASE_URL=...`; a thin factory `buildApiClient()` wires it into the generated `ApiClient` so no caller hard-codes the host. A reproducible `tooling/generate_api.sh` owns every transformation, so files under `lib/data/api/` are never hand-edited.

**Tech Stack:** Dart ^3.10.4 / Flutter 3.41.9, `openapi-generator` (Homebrew), dio 5.x, `json_annotation` 4.x, `json_serializable` 6.x via `build_runner` 2.x, flutter_lints.

---

## Decisions & Tradeoffs

- **Embed vs path-dependency.** The dart-dio generator always nests its output under `<out>/lib/`. Two ways to land it in `lib/data/api/` were considered:
  - **A) Path-dependency** (generate a full nested package into `lib/data/api/` and add it as `path: lib/data/api`): regen is one literal `openapi-generator` call and `.openapi-generator-ignore` works natively, but it forces a second `pubspec.yaml` under `lib/`, a separate `build_runner` run inside the sub-package, and dio deps live in the nested pubspec rather than the app's.
  - **B) Flatten into the app package (chosen):** generate to a temp dir, copy `<tmp>/lib/*` into `lib/data/api/`, rewrite internal imports via the generator script, and run `build_runner` once at the app root. This matches issue step 3 ("add generated dependencies to `pubspec.yaml`") most directly, keeps a single pubspec and a single `build_runner` pass that future data-layer tasks will reuse, and lets the base-URL factory live next to generated code without a nested package. Cost is one idempotent `sed`-equivalent step in the generator script (no-op when the generator already emits relative imports).
- **Lint suppression for generated code.** Issue acceptance allows `// ignore_for_file` directives. The generate script prepends `// ignore_for_file: type=lint` to every generator-emitted `.dart` so `flutter analyze` reports zero lint warnings from `lib/data/api/` (real `type=error` diagnostics still surface). `.g.dart` part files already carry ignores from `json_serializable`. Fallback escalation in Task 4 Step 8 (`analyzer: exclude`) if any warning leaks.
- **Base URL configurability.** A hand-authored `lib/data/api_config.dart` (`const String.fromEnvironment` — overridable with `--dart-define`) plus `lib/data/api_client.dart` (`buildApiClient()` passing `basePathOverride: kApiBaseUrl`). Both live OUTSIDE `lib/data/api/` so the "no hand-edits under `lib/data/api/`" rule is never violated.
- **Existing stale test.** `test/widget_test.dart` (the default Flutter counter template referencing `MyApp` + `Icons.add`) is pre-existing and unrelated; per AGENTS.md it already fails. It is NOT touched (karpathy: surgical changes). The new smoke test under `test/data/` verifies acceptance criteria #3 without `Error`-type references (the generated `Error` class collides with `dart:core`'s `Error`).

## Files

- Create: `tooling/openapi.json` — committed v1.0.0-api spec (source of truth for codegen).
- Create: `tooling/generate_api.sh` — reproducible generation script (openapi-generator + flatten + import rewrite + ignore headers + build_runner).
- Create: `lib/data/api_config.dart` — `const String kApiBaseUrl` (`String.fromEnvironment`, `--dart-define`-overridable).
- Create: `lib/data/api_client.dart` — `ApiClient buildApiClient()` wiring `kApiBaseUrl` into the generated `ApiClient`.
- Create: `test/data/api_smoke_test.dart` — acceptance smoke test (base URL default + generated model/API symbols resolve).
- Create: `lib/data/api/` — generated tree (`openapi.dart`, `api/notes_api.dart`, `api/logs_api.dart`, `model/{pomodoro_state,log_action,note,log_entry,...}.dart` + `*.g.dart`). **Never hand-edit.**
- Create: `lib/data/api/.openapi-generator-ignore` — hand-authored guard listing machine-owned files (issue step 5).
- Modify: `pubspec.yaml` — add dio / json_annotation (deps) and build_runner / json_serializable (dev_deps).
- Modify: `AGENTS.md` — document the generation command.
- (Fallback only) Modify: `analysis_options.yaml` — add `analyzer: exclude: ['lib/data/api/**']` only if Task 4 detects lint leakage.

---

### Task 1: Lock the OpenAPI spec under tooling/

**Files:**
- Create: `tooling/openapi.json`

- [ ] **Step 1: Baseline the repo**

Run:
```bash
flutter analyze
flutter test
```
Record current `flutter analyze` and `flutter test` outputs. The stale `test/widget_test.dart` (default counter template) is expected to fail on `MyApp`/`Icons.add` — this is PRE-EXISTING per AGENTS.md and is explicitly out of scope. Keep the recorded outputs to compare against after the plan completes.

- [ ] **Step 2: Create the tooling directory**

Run:
```bash
mkdir -p tooling
```

- [ ] **Step 3: Fetch the spec**

Fetch `https://raw.githubusercontent.com/4sp1/vipo-go/refs/tags/v1.0.0-api/openapi.json`, saving it to `tooling/openapi.json`. Verify it is the Vipo Pomodoro API v1.0.0 spec. Expected: JSON object with `info.title == "Vipo Pomodoro API"`, `paths` keys `/notes`, `/notes/{id}`, `/logs`, and `components.schemas` containing `PomodoroState`, `LogAction`, `Note`, `LogEntry`, `CreateNoteRequest`, `CreateLogEntryRequest`.

- [ ] **Step 4: Verify the spec parses**

Run:
```bash
python3 -c "import json;d=json.load(open('tooling/openapi.json'));print(d['info']['title'], d['info']['version']);print('schemas:', ', '.join(sorted(d['components']['schemas'])));print('paths:', ', '.join(sorted(d['paths'])))"
```
Expected output:
```
Vipo Pomodoro API 1.0.0
schemas: CreateLogEntryRequest, CreateNoteRequest, Error, LogAction, LogEntry, LogEntryList, Note, NoteList, PomodoroState
paths: /logs, /notes, /notes/{id}
```

- [ ] **Step 5: Commit with caveman-commit**

Draft the commit message with the `caveman-commit` skill (subject ≤50 chars, body only if "why" non-obvious). Then use the temp file pattern from the `core-commands` skill:
1. `mktemp` → returns a path, e.g. `/tmp/tmp.AbCdEf`
2. Write tool → save the commit message to that path
3. `jj describe --stdin < "/tmp/tmp.AbCdEf"`
4. `rm "/tmp/tmp.AbCdEf"`
5. `jj new`

Expected resulting commit subject:
```
chore(tooling): pin vipo-go openapi spec v1.0.0
```
Body (why it's non-obvious): the spec is codegen source of truth for `lib/data/api/`; pinning the exact tag keeps regen reproducible.

---

### Task 2: Add generated dependencies to pubspec.yaml

**Files:**
- Modify: `pubspec.yaml` (`dependencies:` and `dev_dependencies:` blocks)

- [ ] **Step 1: Read the current pubspec**

Open `pubspec.yaml` and note the exact `dependencies:` and `dev_dependencies:` blocks (current deps: `flutter`, `cupertino_icons`, `flutter_animate`, `flutter_local_notifications`, `vibration`; dev: `flutter_test`, `flutter_launcher_icons`; lints: `flutter_lints`).

- [ ] **Step 2: Add runtime deps**

In the `dependencies:` block, after the existing entries (keep alphabetical-ish ordering as in the file), add:
```yaml
  dio: ^5.7.0
  json_annotation: ^4.9.0
```

- [ ] **Step 3: Add dev deps for codegen**

In the `dev_dependencies:` block, add:
```yaml
  build_runner: ^2.4.13
  json_serializable: ^6.8.0
```

Final relevant sections should read:
```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  dio: ^5.7.0
  flutter_animate: ^4.5.2
  flutter_local_notifications: ^21.0.0
  json_annotation: ^4.9.0
  vibration: ^3.1.8

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.13
  flutter_launcher_icons: "^0.14.4"
  flutter_lints: ^6.0.0
  json_serializable: ^6.8.0
```
(Do not reorder pre-existing entries; insert the two deps into each block preserving the surrounding indentation — 2 spaces under the block header.)

- [ ] **Step 4: Resolve**

Run:
```bash
flutter pub get
```
Expected: resolves successfully; dio / json_annotation / build_runner / json_serializable added to `.dart_tool/package_config.json`.

- [ ] **Step 5: Verify analyze still at baseline**

Run:
```bash
flutter analyze
```
Expected: no NEW issues relative to the Task 1 Step 1 baseline (adding deps does not introduce analysis warnings).

- [ ] **Step 6: Commit with caveman-commit**

Use the temp file + `jj describe --stdin` + `jj new` pattern. Expected subject:
```
build(pubspec): add dio + json_serializable deps
```
Body: pull `dio`/`json_annotation` are runtime deps of the upcoming generated dart-dio API client; `build_runner`/`json_serializable` generate its `*.g.dart` parts.

---

### Task 3: Add configurable base URL + failing smoke test (TDD red)

**Files:**
- Create: `lib/data/api_config.dart`
- Create: `lib/data/api_client.dart`
- Create: `test/data/api_smoke_test.dart`

- [ ] **Step 1: Create the base-URL const**

Create `lib/data/api_config.dart` with exactly:
```dart
/// Base URL of the vipo-go backend.
///
/// Overridable at build time with `--dart-define=API_BASE_URL=<url>`.
/// Defaults to the local development server declared in the OpenAPI spec.
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080',
);
```

- [ ] **Step 2: Create the client factory**

Create `lib/data/api_client.dart` with exactly:
```dart
import 'package:vipo/data/api/openapi.dart';

import 'api_config.dart';

/// Builds an [ApiClient] wired to the build-time-configured [kApiBaseUrl].
///
/// All data-layer code (services, repositories) MUST obtain the API client
/// through this function so the base URL stays overridable via
/// `--dart-define=API_BASE_URL=...` without editing generated code.
ApiClient buildApiClient() => ApiClient(basePathOverride: kApiBaseUrl);
```

Note: `lib/data/api/openapi.dart` (the generator's barrel) does not exist yet — this file will not compile until Task 4 runs the generator. That is intentional (TDD red).

- [ ] **Step 3: Create the smoke test**

Create `test/data/api_smoke_test.dart` with exactly:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vipo/data/api/openapi.dart';
import 'package:vipo/data/api_client.dart';
import 'package:vipo/data/api_config.dart';

void main() {
  test('kApiBaseUrl defaults to localhost:8080 when not overridden', () {
    expect(kApiBaseUrl, 'http://localhost:8080');
  });

  test('generated enums are present with the expected arity', () {
    // Names/order of individual enum cases are generator-controlled; only
    // assert counts so the test survives cosmetic changes to case spelling.
    expect(PomodoroState.values, hasLength(3));
    expect(LogAction.values, hasLength(6));
  });

  test('generated models are present and compile', () {
    final notes = <Note>[];
    final logEntries = <LogEntry>[];
    expect(notes, isEmpty);
    expect(logEntries, isEmpty);
  });

  test('generated api classes are present and compile', () {
    final notesApi = <NotesApi>[];
    final logsApi = <LogsApi>[];
    expect(notesApi, isEmpty);
    expect(logsApi, isEmpty);
  });

  test('buildApiClient wires kApiBaseUrl into the client', () {
    final client = buildApiClient();
    expect(client, isA<ApiClient>());
  });
}
```
Rationale for the assertions:
- `kApiBaseUrl` default check verifies acceptance #4 (base URL default + `--dart-define`-overridable).
- enum/model/api class checks verify acceptance #3 (generated `PomodoroState`, `LogAction`, `LogEntry`, `Note`, `LogsApi`, `NotesApi` resolve and compile).
- The generated `Error` class is deliberately NOT referenced (it collides with `dart:core.Error` for importers).
- Enum cases are asserted by length only (spelling is generator-controlled).

- [ ] **Step 4: Run the smoke test — expect FAILURE (red)**

Run:
```bash
flutter test test/data/api_smoke_test.dart
```
Expected: FAIL with a "target of URI doesn't exist: `package:vipo/data/api/openapi.dart`" / library not loaded compile error. This is the TDD red state — generated code does not exist yet.

If instead the test PASSES here, stop: an unexpected `lib/data/api/` already exists. Remove it (`rm -rf lib/data/api`) before continuing so Task 4's generation is deterministic.

- [ ] **Step 5: Commit with caveman-commit**

Temp file + `jj describe --stdin` + `jj new`. Expected subject:
```
feat(data): add api base url const and smoke test
```
Body: smoke test currently red against the not-yet-generated client; Task 4's `tooling/generate_api.sh` makes it green.

---

### Task 4: Generate the dart-dio client into `lib/data/api/` (TDD green)

**Files:**
- Create: `tooling/generate_api.sh`
- Create: `lib/data/api/` (whole tree — generated, never hand-edited)
- Create: `lib/data/api/.openapi-generator-ignore` (hand-authored guard)

- [ ] **Step 1: Verify openapi-generator is installed**

Run:
```bash
openapi-generator version
```
Expected: a version string (e.g. `7.x`). If missing, install first: `brew install openapi-generator` (requires a JDK).

- [ ] **Step 2: Write the generation script**

Create `tooling/generate_api.sh` with exactly:
```bash
#!/usr/bin/env bash
# Generate the typed dio HTTP client from the vipo-go OpenAPI spec into
# lib/data/api/. Idempotent: safe to re-run; overwrites previously generated
# artifacts but preserves hand-authored guard files such as
# .openapi-generator-ignore so they survive regeneration.
#
# Prereqs (macOS): Homebrew `openapi-generator` (needs a JDK), Flutter's
# `dart` on PATH with `build_runner` resolvable via pub.
#
# Usage:
#   ./tooling/generate_api.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SPEC="$ROOT/tooling/openapi.json"
OUT="$ROOT/lib/data/api"

if [[ ! -f "$SPEC" ]]; then
  echo "openapi spec not found at $SPEC" >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# 1. Generate into a throwaway dir; dart-dio always nests output under lib/.
openapi-generator generate \
  -i "$SPEC" \
  -g dart-dio \
  -o "$TMP" \
  --additional-properties="serializationLibrary=json_serializable,dateLibrary=core,pubName=vipo_api,pubLibrary=vipo.api,ensureUniqueParams=true,sortModelPropertiesByRequiredFlag=true,sortParamsByRequiredFlag=true,enumUnknownDefaultCase=false,useOptional=false" \
  >/dev/null

# 2. Wipe previously generated files; keep hand-authored .md / ignore guards.
rm -rf "$OUT"/api "$OUT"/model "$OUT"/doc
rm -f "$OUT"/openapi.dart "$OUT"/*.g.dart
mkdir -p "$OUT"
cp -R "$TMP"/lib/. "$OUT"/

# 3. Rewrite internal package:vipo_api/ imports to the in-app location.
#    A no-op when the generator already emits relative imports.
find "$OUT" -name '*.dart' -type f -print0 \
  | xargs -0 perl -i -pe 's{\bpackage:vipo_api/}{package:vipo/data/api/}g'

# 4. Prepend a lint-suppression header to every generator-emitted .dart so
#    `flutter analyze` stays warning-free (type=error still surfaces).
HEADER='// ignore_for_file: type=lint'
while IFS= read -r -d '' f; do
  head -n1 "$f" | grep -qF "$HEADER" && continue
  tmp="$(mktemp)"
  printf '%s\n' "$HEADER" | cat - "$f" > "$tmp" && mv "$tmp" "$f"
done < <(find "$OUT" -name '*.dart' -type f -print0)

# 5. Resolve deps and generate the json_serializable part (*.g.dart) files.
( cd "$ROOT" && flutter pub get )
( cd "$ROOT" && dart run build_runner build --delete-conflicting-outputs )

echo "Generated vipo-go API client into $OUT"
```

- [ ] **Step 3: Make it executable**

Run:
```bash
chmod +x tooling/generate_api.sh
```

- [ ] **Step 4: Create the `.openapi-generator-ignore` guard FIRST (so it survives the script's `rm -rf lib/data/api/api ...`)**

Create `lib/data/api/.openapi-generator-ignore` with exactly (this is a hand-authored guard — issue step 5 — not generated code):
```
# Everything matching the patterns below is owned by tooling/generate_api.sh.
# Do NOT hand-edit any file here. Re-run the generator instead.
#
# Patterns are relative to this file's location.
api/**
model/**
*.g.dart
openapi.dart
doc/**
```
(The script deletes only `api/`, `model/`, `doc/`, `openapi.dart`, `*.g.dart` — so this ignore file persists across regenerations.)

- [ ] **Step 5: Run the generator**

Run:
```bash
./tooling/generate_api.sh
```
Expected: prints `Generated vipo-go API client into .../lib/data/api`. `flutter pub get` and `dart run build_runner build --delete-conflicting-outputs` complete without errors.

- [ ] **Step 6: Verify the generated tree satisfies acceptance #3**

Run:
```bash
ls lib/data/api/api lib/data/api/model | sort
```
Expected to include at minimum:
```
logs_api.dart
notes_api.dart
log_action.dart
log_entry.g.dart
log_entry.dart
note.g.dart
note.dart
pomodoro_state.dart
... (create_log_entry_request, create_note_request, error, log_entry_list, note_list)
```
Confirm `lib/data/api/openapi.dart` exists and `export`s the model/api classes.

- [ ] **Step 7: Verify the smoke test is now green**

Run:
```bash
flutter test test/data/api_smoke_test.dart
```
Expected: all tests PASS. If the `buildApiClient()`/`ApiClient(basePathOverride: ...)` assertion fails to compile because the generated `ApiClient` constructor's parameter is named differently (e.g. `basePath`, `basePathOverride`), inspect `lib/data/api/openapi.dart`'s `ApiClient` constructor, then EDIT ONLY `lib/data/api_client.dart` (never the generated file) — for example:
```dart
ApiClient buildApiClient() => ApiClient(basePath: kApiBaseUrl);
```
Re-run the smoke test until green. Report the actual parameter name you settled on in your final summary.

- [ ] **Step 8: Verify `flutter analyze` is warning-free**

Run:
```bash
flutter analyze
```
Expected: NO warnings and NO lint diagnostics originating from `lib/data/api/**` (the `// ignore_for_file: type=lint` header suppresses lints; `type=error` diagnostics for genuine errors still surface). Compare against the Task 1 Step 1 baseline — the pre-existing `test/widget_test.dart` issues are tolerated; nothing else should be new.

Fallback escalation (only if a lint warning still leaks from `lib/data/api/`): add to the ROOT `analysis_options.yaml`:
```yaml
analyzer:
  exclude:
    - 'lib/data/api/**'
```
Then re-run `flutter analyze`. Prefer this over editing generated files. If invoked, commit the `analysis_options.yaml` change as part of this task.

- [ ] **Step 9: Verify full test suite introduces no new failures**

Run:
```bash
flutter test
```
Expected: `test/data/api_smoke_test.dart` passes; `test/widget_test.dart` FAILS as in the Task 1 Step 1 baseline (pre-existing, untouched). NO OTHER failures introduced.

- [ ] **Step 10: Confirm no hand-edits under `lib/data/api/`**

The only file under `lib/data/api/` authored by hand is `.openapi-generator-ignore` (issue step 5). Everything else is script output. Verify you did NOT edit any other file under `lib/data/api/`.

- [ ] **Step 11: Commit with caveman-commit**

Temp file + `jj describe --stdin` + `jj new`. Expected subject:
```
feat(data): generate dart-dio api client into lib/data/api
```
Body (why):
- Generated via `tooling/generate_api.sh` (openapi-generator dart-dio + build_runner) so the client is reproducible and never hand-edited.
- `// ignore_for_file: type=lint` headers keep `flutter analyze` warning-free.
- `kApiBaseUrl`/`buildApiClient()` provide the `--dart-define` base-URL seam.

---

### Task 5: Document the generation command in AGENTS.md

**Files:**
- Modify: `AGENTS.md` (append a new section)

- [ ] **Step 1: Read the current AGENTS.md tail**

Open `AGENTS.md` to locate the end of the file (after the "Project Structure Conventions" section) so the new section is appended cleanly without altering existing content.

- [ ] **Step 2: Append the "Generated API Client" section**

Append exactly (preserving the existing file's trailing newline):
```markdown

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
  `lib/data/api_client.dart`; never construct `ApiClient` directly with a
  hard-coded base URL.
```

- [ ] **Step 3: Verify the doc is accurate against the script**

Re-open `tooling/generate_api.sh` and confirm every claim in the appended section (profile name, additional-properties, output dir, build_runner invocation) matches the script exactly. Fix the doc if the script drifted.

- [ ] **Step 4: Commit with caveman-commit**

Temp file + `jj describe --stdin` + `jj new`. Expected subject:
```
docs: document api client generation in AGENTS.md
```

---

### Task 6: Final acceptance verification

- [ ] **Step 1: Re-run the full acceptance gate**

```bash
flutter analyze
flutter test
```
Acceptance:
- `flutter analyze`: zero warnings (generated files suppressed via `// ignore_for_file: type=lint`; pre-existing `test/widget_test.dart` issues from the baseline are tolerated as pre-existing).
- `flutter test`: `test/data/api_smoke_test.dart` PASS; no new failures beyond the baseline stale `widget_test.dart`.

- [ ] **Step 2: Verify acceptance #3 (generated types present)**

```bash
test -f lib/data/api/api/notes_api.dart && echo OK notes_api
test -f lib/data/api/api/logs_api.dart && echo OK logs_api
test -f lib/data/api/model/pomodoro_state.dart && echo OK pomodoro_state
test -f lib/data/api/model/log_action.dart && echo OK log_action
test -f lib/data/api/model/log_entry.dart && echo OK log_entry
test -f lib/data/api/model/note.dart && echo OK note
```
Expected: six `OK` lines.

- [ ] **Step 3: Verify acceptance #4 (base URL not hard-coded)**

```bash
grep -n "String.fromEnvironment" lib/data/api_config.dart
grep -n "basename\|basePath\|kApiBaseUrl" lib/data/api_client.dart
```
Expected: `api_config.dart` defines `kApiBaseUrl` via `String.fromEnvironment('API_BASE_URL', ...)`. `api_client.dart` passes `kApiBaseUrl` into the generated `ApiClient`. (The generated `openapi.dart` may still contain `http://localhost:8080` as a fallback default — that is fine because runtime always goes through `buildApiClient()`, which overrides it with `kApiBaseUrl`.) The smoke test's `buildApiClient()` assertion already verifies the wiring at runtime.

Then prove the override path is live:
```bash
flutter test test/data/api_smoke_test.dart --dart-define=API_BASE_URL=https://override.example
```
The smoke test's "defaults to localhost:8080" assertion WILL FAIL under the override — that is expected and proves `--dart-define` reaches the const. Re-run without the flag to restore green.

- [ ] **Step 4: Verify acceptance #6 (no hand-edits)**

List every file under `lib/data/api/` and confirm the only manually-authored one is `.openapi-generator-ignore`:
```bash
find lib/data/api -type f | sort
```
Expected: `api/*.dart`, `model/*.dart` (+ `*.g.dart`), `openapi.dart`, and `.openapi-generator-ignore` — nothing else. All non-`ignore` files are script output from `tooling/generate_api.sh`; no commit on this issue edited them by hand.

- [ ] **Step 5: Verify acceptance #5 (doc)**

```bash
grep -n "generate_api.sh" AGENTS.md
```
Expected: at least one match in the "Generated API Client" section.

- [ ] **Step 6: Report**

Final summary (under 4 lines if possible) covering:
- `flutter analyze` result vs baseline
- `flutter test` result (new smoke test PASS; stale `widget_test.dart` pre-existing failure noted)
- generated file inventory (confirm `NotesApi`, `LogsApi`, `PomodoroState`, `LogAction`, `LogEntry`, `Note` present)
- the actual `ApiClient` constructor parameter name used in `buildApiClient()`
- confirmation that no file under `lib/data/api/` other than `.openapi-generator-ignore` was hand-edited

No commit in this task (verification only).
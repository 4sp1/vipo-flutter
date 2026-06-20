# Generate Typed HTTP Client from vipo-go OpenAPI Spec — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use supervised-plan-execution to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate a typed, dio-based HTTP client from the vipo-go OpenAPI spec and integrate it into the Flutter project under `lib/data/api/`.

**Architecture:** Run `openapi-generator-cli` with the `dart-dio` profile against the v1.0.0 OpenAPI spec. The generated code lives as a standalone Dart package inside `lib/data/api/`. The app imports models (`PomodoroState`, `LogAction`, `LogEntry`, `Note`) and API client classes (`LogsApi`, `NotesApi`) from this package. A configurable `kApiBaseUrl` constant (overridable via `--dart-define`) replaces the hardcoded `basePath` in the generated `Openapi` class. `analysis_options.yaml` excludes generated code from project-level lint rules.

**Tech Stack:** openapi-generator-cli 7.23.0 (dart-dio generator), dio, json_annotation, built_value

---

### Task 1: Fetch and save the OpenAPI spec locally

**Files:**
- Create: `tooling/openapi.json`

- [ ] **Step 1: Create the `tooling/` directory and download the spec**

```bash
mkdir -p tooling
```

Then download the spec file:

```bash
curl -fsSL -o tooling/openapi.json https://raw.githubusercontent.com/4sp1/vipo-go/refs/tags/v1.0.0-api/openapi.json
```

- [ ] **Step 2: Verify the spec file is valid JSON**

```bash
python3 -m json.tool tooling/openapi.json > /dev/null && echo "Valid JSON" || echo "Invalid JSON"
```

Expected: `Valid JSON`

- [ ] **Step 3: Verify the spec contains expected models and paths**

```bash
grep -c '"PomodoroState\|"LogAction\|"LogEntry\|"Note"' tooling/openapi.json
```

Expected: multiple matches (at least 4)

- [ ] **Step 4: Commit with caveman-commit**

Use the caveman-commit skill. Temp file pattern from core-commands for the commit message:

```bash
mktemp
# Returns: /tmp/tmp.XXXXXX
```

Write commit message to that path via Write tool, then:

```bash
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

Commit message: `chore(tooling): add vipo-go OpenAPI spec v1.0.0`

---

### Task 2: Generate the dart-dio client into `lib/data/api/`

**Files:**
- Create: `lib/data/api/` (entire generated tree)

- [ ] **Step 1: Run openapi-generator-cli with dart-dio profile**

```bash
npx @openapitools/openapi-generator-cli generate \
  -g dart-dio \
  -i tooling/openapi.json \
  -o lib/data/api \
  --additional-properties=pubName=vipo_api,pubLibrary=vipo_api,useEnumExtension=true,sortModelPropertiesByRequiredFlag=true,sortParamsByRequiredFlag=true
```

This generates:
- `lib/data/api/lib/` — model and API classes
- `lib/data/api/lib/src/model/` — `PomodoroState`, `LogAction`, `LogEntry`, `Note`, `CreateNoteRequest`, `CreateLogEntryRequest`, `NoteList`, `LogEntryList`, `Error`
- `lib/data/api/lib/src/api/` — `LogsApi`, `NotesApi`
- `lib/data/api/lib/src/api_client.dart` — `Openapi` class with `basePathOverride` constructor param
- `lib/data/api/pubspec.yaml` — standalone Dart package `vipo_api`

- [ ] **Step 2: Verify expected files were generated**

```bash
ls lib/data/api/lib/src/model/ && ls lib/data/api/lib/src/api/
```

Expected output should include files for `PomodoroState`, `LogAction`, `LogEntry`, `Note`, `LogsApi`, `NotesApi`.

- [ ] **Step 3: Commit with caveman-commit**

```bash
mktemp
# Write commit message to temp file, then:
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

Commit message: `feat(api): generate dart-dio client from vipo-go OpenAPI spec`

---

### Task 3: Add generated dependencies to the app's `pubspec.yaml`

**Files:**
- Modify: `pubspec.yaml`

The generated package requires `dio`, `json_annotation`, and `built_value`. The app must depend on these plus path-reference the generated package.

- [ ] **Step 1: Add dependencies to `pubspec.yaml`**

Add these lines under `dependencies:` (after `vibration: ^3.1.8`):

```yaml
  dio: ^5.7.0
  json_annotation: ^4.9.0
  built_value: ^8.9.0
  collection: ^1.19.0
  vipo_api:
    path: lib/data/api
```

And add these under `dev_dependencies:` (after `flutter_launcher_icons`):

```yaml
  build_runner: ^2.4.0
  built_value_generator: ^8.9.0
  json_serializable: ^6.8.0
```

- [ ] **Step 2: Run `flutter pub get` at project root**

```bash
flutter pub get
```

Expected: resolves successfully with no errors.

- [ ] **Step 3: Run `flutter pub get` inside the generated package**

```bash
cd lib/data/api && flutter pub get && cd -
```

Expected: resolves successfully.

- [ ] **Step 4: Commit with caveman-commit**

```bash
mktemp
# Write commit message to temp file, then:
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

Commit message: `build(deps): add dio, json_annotation, built_value and vipo_api path dep`

---

### Task 4: Make the API base URL configurable via `--dart-define`

**Files:**
- Create: `lib/data/api/lib/src/api_constants.dart`

The generated `Openapi` class already accepts `basePathOverride` in its constructor. We create a thin constants file that reads from `--dart-define` and provide a factory that wires it in.

- [ ] **Step 1: Create `api_constants.dart` with configurable base URL**

```dart
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080',
);
```

- [ ] **Step 2: Verify `kApiBaseUrl` compiles**

```bash
flutter analyze lib/data/api/lib/src/api_constants.dart
```

Expected: no errors related to `api_constants.dart`.

- [ ] **Step 3: Commit with caveman-commit**

```bash
mktemp
# Write commit message to temp file, then:
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

Commit message: `feat(api): add configurable API base URL via --dart-define`

---

### Task 5: Exclude generated code from project lint analysis

**Files:**
- Modify: `analysis_options.yaml`
- Create: `lib/data/api/.openapi-generator-ignore`

The generated code may trigger project-level lint warnings. We exclude `lib/data/api/` from the project analyzer and add a `.openapi-generator-ignore` to prevent accidental edits.

- [ ] **Step 1: Add analyzer exclude for generated code in `analysis_options.yaml`**

Add `analyzer:` → `exclude:` section. The full file becomes:

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  exclude:
    - lib/data/api/**

linter:
  rules:
```

Edit the existing `analysis_options.yaml` to insert the `analyzer` block between the `include:` line and the `linter:` section.

- [ ] **Step 2: Create `.openapi-generator-ignore` in `lib/data/api/`**

This file tells openapi-generator to preserve our custom files on re-generation:

```
# Protect hand-written additions from being overwritten on re-generation
lib/src/api_constants.dart
```

- [ ] **Step 3: Run `flutter analyze` to confirm generated code is excluded**

```bash
flutter analyze
```

Expected: no warnings or errors from files under `lib/data/api/`. May show pre-existing issues from other files, but zero new issues.

- [ ] **Step 4: Commit with caveman-commit**

```bash
mktemp
# Write commit message to temp file, then:
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

Commit message: `chore(lint): exclude generated API code from project analysis`

---

### Task 6: Verify acceptance criteria end-to-end

**Files:** None (verification only)

- [ ] **Step 1: Verify `flutter analyze` passes with zero warnings**

```bash
flutter analyze
```

Expected: No new warnings. (Pre-existing stale test file warnings from `test/widget_test.dart` are known and out of scope.)

- [ ] **Step 2: Verify `flutter test` passes (no new test failures)**

```bash
flutter test
```

Expected: Same test results as before (known stale test may fail — that's pre-existing and out of scope).

- [ ] **Step 3: Verify `lib/data/api/` contains required models**

```bash
ls lib/data/api/lib/src/model/pomodoro_state.dart lib/data/api/lib/src/model/log_action.dart lib/data/api/lib/src/model/log_entry.dart lib/data/api/lib/src/model/note.dart
```

Expected: all four files exist.

- [ ] **Step 4: Verify `lib/data/api/` contains required API client classes**

```bash
grep -rl "class LogsApi" lib/data/api/lib/src/api/ && grep -rl "class NotesApi" lib/data/api/lib/src/api/
```

Expected: both files found.

- [ ] **Step 5: Verify API base URL is configurable**

```bash
grep -n "kApiBaseUrl" lib/data/api/lib/src/api_constants.dart && grep -rn "basePathOverride" lib/data/api/lib/src/api_client.dart | head -3
```

Expected: `kApiBaseUrl` uses `String.fromEnvironment` with `defaultValue: 'http://localhost:8080'`, and `basePathOverride` parameter exists in the `Openapi` constructor.

- [ ] **Step 6: Verify no files under `lib/data/api/` have been hand-edited after generation**

```bash
jj diff lib/data/api/
```

Expected: only `api_constants.dart` and `.openapi-generator-ignore` show as additions — no modifications to any generated files.

---

### Task 7: Document the generation command in `AGENTS.md`

**Files:**
- Modify: `AGENTS.md`

- [ ] **Step 1: Add API client generation section to `AGENTS.md`**

Append the following section after the `## Gotchas` section (before `## Project Structure Conventions`):

```markdown
## API Client Generation

The typed HTTP client under `lib/data/api/` is generated from the vipo-go OpenAPI spec. **Do not hand-edit** files in that directory — re-generate instead.

### Regenerate

```bash
# 1. Fetch the spec (update the tag URL when bumping versions)
curl -fsSL -o tooling/openapi.json https://raw.githubusercontent.com/4sp1/vipo-go/refs/tags/v1.0.0-api/openapi.json

# 2. Remove old generated code (preserves .openapi-generator-ignore)
find lib/data/api -not -name '.openapi-generator-ignore' -not -name 'lib' -not -name 'src' | xargs rm -rf

# 3. Regenerate
npx @openapitools/openapi-generator-cli generate \
  -g dart-dio \
  -i tooling/openapi.json \
  -o lib/data/api \
  --additional-properties=pubName=vipo_api,pubLibrary=vipo_api,useEnumExtension=true,sortModelPropertiesByRequiredFlag=true,sortParamsByRequiredFlag=true

# 4. Re-apply the analyzer exclude and re-run flutter pub get
flutter pub get
flutter analyze
```

### Configurable base URL

Override at build time:

```bash
flutter run --dart-define=API_BASE_URL=https://api.example.com
```

The `Openapi` class accepts `basePathOverride` at runtime:

```dart
import 'package:vipo_api/vipo_api.dart';
import 'package:vipo/data/api/lib/src/api_constants.dart';

final client = Openapi(basePathOverride: kApiBaseUrl);
```
```

- [ ] **Step 2: Verify the document reads correctly**

```bash
grep -A 30 "## API Client Generation" AGENTS.md
```

Expected: full section rendered with code blocks.

- [ ] **Step 3: Commit with caveman-commit**

```bash
mktemp
# Write commit message to temp file, then:
jj describe --stdin < "/tmp/tmp.XXXXXX"
rm "/tmp/tmp.XXXXXX"
jj new
```

Commit message: `docs(agents): add API client generation and base URL config`

---

## Self-Review Checklist

1. **Spec coverage:** Each step in the GitHub issue maps to a task:
   - Issue step 1 (Fetch spec) → Task 1
   - Issue step 2 (Run openapi-generator) → Task 2
   - Issue step 3 (Add generated dependencies) → Task 3
   - Issue step 4 (Configurable base URL) → Task 4
   - Issue step 5 (`.openapi-generator-ignore`) → Task 5
   - Issue step 6 (Document in AGENTS.md) → Task 7
   - Issue step 7 (Commit generated code as-is) → Tasks 2–5 (no hand-edits to generated files; only additions: `api_constants.dart` and `.openapi-generator-ignore`)

2. **Placeholder scan:** No TBDs, TODOs, or "add appropriate X" patterns. Every step has exact commands, file contents, or verification commands.

3. **Type consistency:** `kApiBaseUrl` is `const String` read via `String.fromEnvironment`. The `Openapi` class constructor accepts `basePathOverride` of type `String?`. `PomodoroState`, `LogAction`, `LogEntry`, `Note` are all model classes generated by the spec. `LogsApi` and `NotesApi` are the API client classes.

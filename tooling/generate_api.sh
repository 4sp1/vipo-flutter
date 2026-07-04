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
rm -rf "$OUT"/src "$OUT"/api "$OUT"/model "$OUT"/doc
rm -f "$OUT"/openapi.dart "$OUT"/vipo_api.dart "$OUT"/*.g.dart
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
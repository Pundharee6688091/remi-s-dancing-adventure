#!/bin/bash
# Every suite, into one file.
#
# Runs against a copy of the project with config/name changed, which is what
# sends user:// somewhere harmless. Tests write and delete save files; against
# the real name they would write into the player's own folder. That mistake
# has been made here before, so the copy is not optional.
set -uo pipefail

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${TMPDIR:-/tmp}/remi-tests"
OUT="${1:-$HERE/tests/results.txt}"
NAME="RemiTests"

[ -x "$GODOT" ] || { echo "No Godot at $GODOT. Set GODOT=/path/to/Godot" >&2; exit 2; }

echo "Copying the project to $WORK as $NAME"
rsync -a --delete --exclude '.godot' --exclude '.git' --exclude 'export' \
  "$HERE/" "$WORK/"
sed -i '' "s|^config/name=.*|config/name=\"$NAME\"|" "$WORK/project.godot"
got=$(grep '^config/name' "$WORK/project.godot")
[ "$got" = "config/name=\"$NAME\"" ] || { echo "RENAME FAILED: $got" >&2; exit 2; }

echo "Importing (first run can take a few minutes)"
"$GODOT" --headless --path "$WORK" --editor --quit >/dev/null 2>&1
"$GODOT" --headless --path "$WORK" --editor --quit >/dev/null 2>&1

{
  echo "Remi's Dancing Adventure - test run"
  echo "when:    $(date '+%Y-%m-%d %H:%M')"
  echo "commit:  $(cd "$HERE" && git rev-parse --short HEAD 2>/dev/null)"
  echo "machine: $(uname -m), $(sw_vers -productName 2>/dev/null) $(sw_vers -productVersion 2>/dev/null)"
  echo
} > "$OUT"

SUITES="input judge damage calc combo progress save"
for s in $SUITES; do
  [ -f "$WORK/tests/test_$s.tscn" ] || continue
  echo "=== $s" >> "$OUT"
  "$GODOT" --headless --path "$WORK" "res://tests/test_$s.tscn" 2>&1 \
    | grep -E "^  ok|^  FAIL|^FAILS" >> "$OUT"
  echo >> "$OUT"
done

PASS=$(grep -c "^  ok" "$OUT")
FAIL=$(grep -c "^  FAIL" "$OUT")
{
  echo "=== summary"
  echo "  passed: $PASS"
  echo "  failed: $FAIL"
} >> "$OUT"

cat "$OUT"
[ "$FAIL" -eq 0 ]

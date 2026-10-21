#!/bin/bash
# Build a debug export and point it at the editor's profiler.
#
# The editor's profiler cannot reach a release build, which is why the game
# logs its own numbers into sessions/ instead. This is the other half: when you
# want to know WHICH function is costing the time, not just how much, a debug
# build will talk to the editor over a socket and fill in the Profiler tab.
#
# Read the two numbers differently. The profiler tells you where the time goes,
# on a debug build that is slower than anything a player runs. The session log
# tells you how much time it actually takes, on the build you handed out. Use
# the first to find the hot spot and the second to report it.
#
#   ./tools/profile.sh            builds and launches, Mac preset
#   ./tools/profile.sh --build    builds only
#   PRESET="Rhythm Game Window" ./tools/profile.sh --build
set -uo pipefail

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
PRESET="${PRESET:-Rhythm Game Mac}"
PORT="${PORT:-6007}"
OUT="$HERE/export/Remi-debug.app"

[ -x "$GODOT" ] || { echo "No Godot at $GODOT. Set GODOT=/path/to/Godot" >&2; exit 2; }

echo "Exporting '$PRESET' with debug enabled"
"$GODOT" --headless --path "$HERE" --export-debug "$PRESET" "$OUT" \
  2>&1 | grep -vE "^\[ *[0-9]+%" | tail -5
[ -e "$OUT" ] || { echo "Export produced nothing at $OUT" >&2; exit 1; }

echo
echo "Built: $OUT"
if [ "${1:-}" = "--build" ]; then
  exit 0
fi

# The editor has to be the one listening, and only an editor does: run without
# -e and the flag is read as a game argument and quietly ignored, which looks
# exactly like the game failing to connect.
if ! lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  cat <<MSG

Nothing is listening on port $PORT, so there is no profiler to connect to.
Start the editor with its debug server first, in another terminal:

  "$GODOT" -e --path "$HERE" --debug-server tcp://127.0.0.1:$PORT

Then open Debugger at the bottom, pick the Profiler tab, and press Start.
Run this script again once that is up.
MSG
  exit 1
fi

echo "Launching against the profiler on 127.0.0.1:$PORT"
exec "$OUT/Contents/MacOS/Rhythm Game" --remote-debug "tcp://127.0.0.1:$PORT"

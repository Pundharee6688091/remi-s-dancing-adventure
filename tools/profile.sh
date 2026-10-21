#!/bin/bash
# Build a debug export and point it at the editor's profiler.
#
# The editor's profiler cannot reach a release build, which is why the game
# logs its own numbers into sessions/ instead. This is the other half: when you
# want to know WHICH function is costing the time, not just how much, a debug
# build will talk to the editor over a socket and fill in the Profiler tab.
#
# Read the two differently. The profiler tells you where the time goes, on a
# debug build slower than anything a player runs. The session log tells you how
# much time it takes, on the build you handed out. Use the first to find the
# hot spot and the second to report it.
#
#   ./tools/profile.sh                                 build and launch (Mac)
#   ./tools/profile.sh --build                          build only
#   PRESET="Rhythm Game Window" ./tools/profile.sh --build   the lab build
set -uo pipefail

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
PRESET="${PRESET:-Rhythm Game Mac}"
PORT="${PORT:-6007}"

[ -x "$GODOT" ] || { echo "No Godot at $GODOT. Set GODOT=/path/to/Godot" >&2; exit 2; }

# The extension has to match the platform: a Windows export written to a path
# ending .app leaves a staging file behind and no build. Taken from the
# preset's own export_path rather than guessed from its name, so adding a
# preset needs no change here.
EXT="$(awk -v want="name=\"$PRESET\"" '
	$0 == want { found = 1; next }
	/^\[preset\./ { found = 0 }
	found && /^export_path=/ { sub(/^export_path="/, ""); sub(/"$/, "");
		n = split($0, bits, "."); print bits[n]; exit }
' "$HERE/export_presets.cfg")"
[ -n "$EXT" ] || { echo "No preset named '$PRESET' in export_presets.cfg" >&2; exit 2; }

# A dmg is for handing the game out: a disk image has to be mounted before
# anything inside it runs. Profiling wants the bundle itself, which the macOS
# exporter produces from the same preset when the path ends .app.
[ "$EXT" = "dmg" ] && EXT="app"

OUT="$HERE/export/Remi-debug.$EXT"
rm -rf "$OUT"

echo "Exporting '$PRESET' with debug enabled, to $(basename "$OUT")"
"$GODOT" --headless --path "$HERE" --export-debug "$PRESET" "$OUT" \
	2>&1 | grep -vE "^\[ *[0-9]+%" | tail -4
# Checked after deleting it above, so a stale build from a previous run cannot
# be mistaken for this one succeeding. That mistake was made here once already.
[ -e "$OUT" ] || { echo "Export produced nothing at $OUT" >&2; exit 1; }
echo
echo "Built: $OUT"

if [ "${1:-}" = "--build" ]; then
	exit 0
fi

if [ "$EXT" != "app" ]; then
	cat <<MSG

That is not a build this Mac can run. Copy it to the target machine and see
"Profiling on a lab machine" in the project's session-logging notes.
MSG
	exit 0
fi

# The editor has to be the one listening, and only an editor does: run without
# -e and the flag is read as a game argument and silently ignored, which looks
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

BIN="$(find "$OUT/Contents/MacOS" -maxdepth 1 -type f -perm -111 | head -1)"
[ -n "$BIN" ] || { echo "No executable inside $OUT" >&2; exit 1; }
echo "Launching against the profiler on 127.0.0.1:$PORT"
exec "$BIN" --remote-debug "tcp://127.0.0.1:$PORT"

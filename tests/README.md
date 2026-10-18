# Automated tests

The 66 machine-checkable cases from the test plan, as seven headless Godot
scenes. Each prints one line per check and exits non-zero if any failed.

## Running them

    ./tests/run.sh                 # writes tests/results.txt
    ./tests/run.sh /tmp/run.txt    # or somewhere else

Needs Godot 4.7.2 on the path below, or set `GODOT` to point at it:

    GODOT=/Applications/Godot.app/Contents/MacOS/Godot ./tests/run.sh

The first run takes a few minutes, because it imports a fresh copy of the
project from scratch. Later runs are quick.

## Why it copies the project first

The tests write and delete save files. `run.sh` rsyncs the project to a
temporary folder and changes `config/name` in `project.godot`, which is what
moves `user://` out of the real save folder. A probe writing to the live
`user://` destroyed a real save file earlier in this project, so the copy is
not optional, and the script aborts if the rename does not take.

## The suites

| Suite | Cases | What it covers |
|---|---|---|
| `test_input` | input 01-08 | Volume and offset clamping, rebinding, the reserved keys, no two lanes on one key, reset to defaults, name length |
| `test_judge` | judge 01-20 | Every timing-window boundary at exactly 45 / 90 / 135 ms, on both sides of zero; misses, presses at nothing, double presses, lanes judged apart, pausing |
| `test_damage` | damage 01-11 | The meter, the star count and the win line across eleven whole 50-note runs, from all-perfect to all-miss |
| `test_calc` | calc 01-03 | Rounding at the display, the win line read off a real run, and a one-note chart (the divide-by-note-count edge) |
| `test_combo` | combo 01-10 | Combo kept and broken, max combo, and the achievements that hang off them, including that a replay does not award twice |
| `test_progress` | progress 01-07 | Which node is open on a new profile, unlocks, party joining, records kept at the best, and that a lost fight changes nothing |
| `test_save` | save 01-07 | Three slots round-tripping, renaming, deleting, settings and bindings persisting, and five kinds of broken save file |

The case numbers match the test plan document, so a failure line names the
row in the table it came from.

## Reading a failure

    FAIL judge 05  -46 ms is great (wanted great, got perfect)

Suite, case number, what was being checked, then wanted and got.

## Proving the suite works

A suite that passes against broken code proves nothing. Two rules were
deliberately changed in the copied project to check that it notices:

| Change | Caught by |
|---|---|
| Perfect window 45 → 50 ms | `judge 05` and `judge 09`, the two cases that sit at exactly ±46 ms |
| Win line 30 → 40 percent | `damage 09`, the run that lands at 32 percent |

Both went green again when the rules were put back. Worth repeating after any
change to `data/gameRule.json`.

## Not covered here

Anything a person has to judge: whether the charts are fun, whether 135 ms
feels fair, whether the Thai and English read naturally, whether a new player
works out the Skeptical Meter unprompted. That is what the playtest sheet is
for.

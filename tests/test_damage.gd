extends "res://tests/lib/harness.gd"
## Test plan: Damage, HP and stars, cases 01 to 11.
##
## Fifty notes, played by hand at offsets that land in the window we want, so
## each row of the table in the plan is reproduced exactly.

const NOTES := 50
const GAP := 1000.0
const PERFECT := 0.0
const GREAT := 60.0          # between 45 and 90
const GOOD := 110.0          # between 90 and 135


## Plays a run of the given mix and gives back [hp, stars, won].
func run(perfect: int, great: int, good: int, miss: int) -> Array:
	var notes: Array = []
	for i in NOTES:
		notes.append([0, 1000.0 + i * GAP])
	var field := make_field(notes)
	var judge := Judge.new()
	judge.setup(field)

	var i := 0
	for pair in [[perfect, PERFECT], [great, GREAT], [good, GOOD]]:
		for n in int(pair[0]):
			judge.press(0, field.notes[i].t_ms + float(pair[1]))
			i += 1
	# whatever is left is never pressed, and the end of song sweep takes it
	judge.sweep_all()

	var out := [Rules.hp_display(judge.hp), Rules.stars_for_hp(judge.hp),
		Rules.is_win(judge.hp), judge.counts.duplicate()]
	field.queue_free()
	return out


func _ready() -> void:
	await get_tree().process_frame

	var table := [
		["damage 01", 50, 0, 0, 0, 0.0, 3, true],
		["damage 02", 49, 0, 1, 0, 1.0, 2, true],
		["damage 03", 26, 24, 0, 0, 14.4, 2, true],
		["damage 04", 25, 25, 0, 0, 15.0, 2, true],
		["damage 05", 24, 26, 0, 0, 15.6, 1, true],
		["damage 06", 36, 0, 0, 14, 28.0, 1, true],
		["damage 07", 35, 0, 0, 15, 30.0, 1, true],
		["damage 08", 0, 50, 0, 0, 30.0, 1, true],
		["damage 09", 34, 0, 0, 16, 32.0, 0, false],
		["damage 10", 0, 0, 50, 0, 50.0, 0, false],
		["damage 11", 0, 0, 0, 50, 100.0, 0, false],
	]

	for row in table:
		var id: String = row[0]
		var got := run(int(row[1]), int(row[2]), int(row[3]), int(row[4]))
		var mix := "%dP %dGr %dGd %dM" % [row[1], row[2], row[3], row[4]]
		about(id, got[0], float(row[5]), "%s leaves the meter at %s%%"
			% [mix, row[5]], 0.051)
		equals(id, got[1], int(row[6]), "%s is %d stars" % [mix, row[6]])
		equals(id, got[2], bool(row[7]), "%s is a %s"
			% [mix, "win" if row[7] else "fail"])
		# and the judgements themselves landed where we meant them to
		var counts: Dictionary = got[3]
		equals(id, counts.perfect, int(row[1]), "%s counted its perfects" % mix)

	finish()

extends "res://tests/lib/harness.gd"
## Test plan: Calculation robustness, cases 01 to 03.
##
## 100 divided by these note counts does not come out even, so this is where
## the arithmetic shows its seams.

const AWKWARD := [97, 143, 211]


func play(count: int, offset: float, press_them: bool) -> Judge:
	var notes: Array = []
	for i in count:
		notes.append([0, 1000.0 + i * 500.0])
	var field := make_field(notes)
	var judge := Judge.new()
	judge.setup(field)
	if press_them:
		for n in field.notes:
			judge.press(0, n.t_ms + offset)
	judge.sweep_all()
	return judge


func _ready() -> void:
	await get_tree().process_frame

	# 01 every note perfect lands on nothing left, not on a speck of it
	for count in AWKWARD:
		var judge := play(count, 0.0, true)
		about("calc 01", Rules.hp_display(judge.hp), 0.0,
			"%d notes all perfect leaves exactly 0%%" % count, 0.0001)
		equals("calc 01", Rules.stars_for_hp(judge.hp), 3,
			"%d notes all perfect is 3 stars" % count)

	# 02 every note great leaves exactly the win line
	for count in AWKWARD:
		var judge := play(count, 60.0, true)
		about("calc 02", Rules.hp_display(judge.hp), 30.0,
			"%d notes all great leaves 30%%" % count, 0.051)

	# 03 a chart of one note
	var hit := play(1, 0.0, true)
	about("calc 03", Rules.hp_display(hit.hp), 0.0, "one note hit leaves 0%")
	var missed := play(1, 0.0, false)
	about("calc 03", Rules.hp_display(missed.hp), 100.0, "one note missed leaves 100%")
	equals("calc 03", missed.counts.miss, 1, "and counts as one miss")

	finish()

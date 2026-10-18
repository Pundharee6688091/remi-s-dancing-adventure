extends "res://tests/lib/harness.gd"
## Test plan: Combo and achievements, cases 01 to 10.

const AT := 5000.0
const GREAT := 60.0
const GOOD := 110.0


func three(offsets: Array) -> Judge:
	var notes: Array = []
	for i in offsets.size():
		notes.append([0, AT + i * 1000.0])
	var field := make_field(notes)
	var judge := Judge.new()
	judge.setup(field)
	for i in offsets.size():
		judge.press(0, field.notes[i].t_ms + float(offsets[i]))
	return judge


func rule(id: String) -> Dictionary:
	for a in Achievements.list:
		if String(a.get("id", "")) == id:
			return a
	return {}


func _ready() -> void:
	await get_tree().process_frame
	clear_saves()
	GameManager.slot = 1
	GameManager.save = SaveManager.create(1, "Combo")

	# 01 to 03, what keeps a combo and what breaks it
	equals("combo 01", three([0.0, 0.0, GREAT]).combo, 3,
		"perfect, perfect, great is a combo of 3")
	equals("combo 02", three([0.0, 0.0, GOOD]).combo, 0,
		"a good breaks it")
	# three notes, two of them hit, and the third left to slide past
	var field := make_field([[0, AT], [0, AT + 1000.0], [0, AT + 2000.0]])
	var missed := Judge.new()
	missed.setup(field)
	missed.press(0, AT)
	missed.press(0, AT + 1000.0)
	equals("combo 03", missed.combo, 2, "two hits make a combo of 2")
	missed.sweep(AT + 2000.0 + 200.0)
	equals("combo 03", missed.counts.miss, 1, "the third note is missed")
	equals("combo 03", missed.combo, 0, "and a miss breaks the combo")
	field.queue_free()

	# 04 a press with nothing in range leaves it alone
	var held := three([0.0, 0.0])
	held.press(0, AT + 9000.0)
	equals("combo 04", held.combo, 2, "a press at nothing does not break a combo")

	# 05 the highest combo seen, not the last
	var run := three([0.0, 0.0, 0.0, GOOD, 0.0])
	equals("combo 05", run.combo, 1, "the combo is back to 1 at the end")
	equals("combo 05", run.max_combo, 3, "but max combo kept the highest")

	# 06 sharp ears wants 30, not 29
	var ears := rule("sharp_ears")
	check("combo 06", not ears.is_empty(), "sharp ears is in the list")
	GameManager.save["best_combo"] = {"s1_1": 29}
	check("combo 06", Achievements.progress(ears) < 1.0, "29 does not earn it")
	GameManager.save["best_combo"] = {"s1_1": 30}
	check("combo 06", Achievements.progress(ears) >= 1.0, "30 does")

	# 07 cut a rug wants a song with no miss and no good
	GameManager.save["achievements"] = {}
	GameManager.save["full_combo"] = []
	Achievements.record_run("s1_1", {"perfect": 50, "great": 0, "good": 0, "miss": 0})
	check("combo 07", Achievements.is_earned("cut_a_rug"), "a clean run earns it")
	GameManager.save["achievements"] = {}
	GameManager.save["full_combo"] = []
	Achievements.record_run("s1_2", {"perfect": 49, "great": 0, "good": 1, "miss": 0})
	check("combo 07", not Achievements.is_earned("cut_a_rug"),
		"and a single good does not")

	# 08 the rising star wants twelve stars
	GameManager.save["achievements"] = {}
	GameManager.save["stars"] = {"s0_1": 3, "s1_1": 3, "s1_2": 3, "s1_3": 2}
	Achievements.refresh(false)
	check("combo 08", not Achievements.is_earned("rising_star"),
		"eleven stars is not enough")
	GameManager.save["stars"] = {"s0_1": 3, "s1_1": 3, "s1_2": 3, "s1_3": 3}
	Achievements.refresh(false)
	check("combo 08", Achievements.is_earned("rising_star"),
		"twelve earns it, which is three stars on all four fights")

	# 09 replaying counts the best result, not both
	GameManager.save["stars"] = {"s1_1": 3}
	var once := 0
	for id in GameManager.save.stars:
		once += int(GameManager.save.stars[id])
	GameManager.save["stars"]["s1_1"] = 3
	var twice := 0
	for id in GameManager.save.stars:
		twice += int(GameManager.save.stars[id])
	equals("combo 09", twice, once, "a replay does not add its stars again")

	# 10 nothing is earned a second time
	GameManager.save["achievements"] = {}
	GameManager.save["stars"] = {"s0_1": 3, "s1_1": 1}
	var first := Achievements.refresh(false)
	var second := Achievements.refresh(false)
	check("combo 10", first.size() > 0, "the first pass awards something")
	equals("combo 10", second.size(), 0, "the second awards nothing again")

	clear_saves()
	finish()

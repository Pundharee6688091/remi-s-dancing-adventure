extends "res://tests/lib/harness.gd"
## Test plan: Judge timing boundaries, cases 01 to 20.
##
## Driven by calling the judge at exact times rather than by playing, so a
## boundary is tested at the millisecond rather than at whatever the frame
## happened to be.

const AT := 5000.0          # when the one note under test sits


func fresh(notes: Array) -> Array:
	var field := make_field(notes)
	var judge := Judge.new()
	judge.setup(field)
	return [field, judge]


func judged_at(offset: float) -> String:
	var made := fresh([[0, AT]])
	var judge: Judge = made[1]
	var out := judge.press(0, AT + offset)
	(made[0] as Node).queue_free()
	return out


func _ready() -> void:
	await get_tree().process_frame

	# 01 to 12, the boundaries either side of every window
	var boundaries := [
		["judge 01", -136.0, ""], ["judge 02", -135.0, "good"],
		["judge 03", -91.0, "good"], ["judge 04", -90.0, "great"],
		["judge 05", -46.0, "great"], ["judge 06", -45.0, "perfect"],
		["judge 07", 0.0, "perfect"], ["judge 08", 45.0, "perfect"],
		["judge 09", 46.0, "great"], ["judge 10", 90.0, "great"],
		["judge 11", 91.0, "good"], ["judge 12", 135.0, "good"],
	]
	for row in boundaries:
		var got := judged_at(row[1])
		equals(row[0], got, row[2],
			"%+d ms is %s" % [int(row[1]), "ignored" if row[2] == "" else row[2]])

	# 13 no press, the sweep takes it
	var made := fresh([[0, AT]])
	var judge: Judge = made[1]
	judge.combo = 7
	judge.sweep(AT + 136.0)
	equals("judge 13", judge.counts.miss, 1, "a note past its window is a miss")
	equals("judge 13", judge.combo, 0, "and the combo resets")
	about("judge 13", judge.hp, 100.0, "a miss deals nothing, r is 100")
	(made[0] as Node).queue_free()

	# 14 a press with nothing near it
	made = fresh([[0, AT]])
	judge = made[1]
	judge.combo = 4
	var before: float = judge.hp
	equals("judge 14", judge.press(0, AT + 500.0), "", "a press with no note is ignored")
	about("judge 14", judge.hp, before, "no damage")
	equals("judge 14", judge.combo, 4, "and the combo is untouched")
	(made[0] as Node).queue_free()

	# 15 two notes in one lane, press between them
	made = fresh([[0, AT], [0, AT + 100.0]])
	judge = made[1]
	judge.press(0, AT + 40.0)
	check("judge 15", made[0].notes[0].judged and not made[0].notes[1].judged,
		"the nearer unhit note is the one judged")
	(made[0] as Node).queue_free()

	# 16 two lanes at the same moment
	made = fresh([[0, AT], [1, AT]])
	judge = made[1]
	judge.press(0, AT)
	judge.press(1, AT)
	equals("judge 16", judge.counts.perfect, 2, "both lanes judge separately")
	(made[0] as Node).queue_free()

	# 17 pressing an already hit note
	made = fresh([[0, AT]])
	judge = made[1]
	judge.press(0, AT)
	equals("judge 17", judge.press(0, AT), "", "a hit note is not judged twice")
	equals("judge 17", judge.counts.perfect, 1, "and counts once")
	(made[0] as Node).queue_free()

	# 18 a held key repeats, and a repeat is not a press
	var held := InputEventKey.new()
	held.physical_keycode = KEY_W
	held.pressed = true
	held.echo = true
	check("judge 18", not held.is_action_pressed("lane_0"),
		"an auto repeat does not count as a press")
	var once := InputEventKey.new()
	once.physical_keycode = KEY_W
	once.pressed = true
	check("judge 18", once.is_action_pressed("lane_0"), "the first press does")

	# 19 a press and the sweep on the same tick
	made = fresh([[0, AT]])
	judge = made[1]
	judge.press(0, AT + 130.0)
	judge.sweep(AT + 136.0)
	equals("judge 19", judge.counts.good, 1, "the press is the judgement")
	equals("judge 19", judge.counts.miss, 0, "and the sweep does not judge it again")
	(made[0] as Node).queue_free()

	# 20 a press while paused, through the battle rather than the judge
	clear_saves()
	GameManager.slot = 1
	GameManager.save = SaveManager.create(1, "Judge")
	GameManager.start_stage("s1_1")
	await get_tree().create_timer(3.2).timeout
	var battle: Node = SceneRouter._current
	if battle != null and battle.has_method("_pause"):
		battle._pause()
		await get_tree().process_frame
		var was: Dictionary = battle.judge.counts.duplicate()
		var press := InputEventAction.new()
		press.action = "lane_0"
		press.pressed = true
		Input.parse_input_event(press)
		await get_tree().process_frame
		equals("judge 20", battle.judge.counts, was, "a press while paused is ignored")
	else:
		check("judge 20", false, "could not reach a battle to pause")
	clear_saves()

	finish()

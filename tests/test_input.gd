extends "res://tests/lib/harness.gd"
## Test plan: Input validation and bounds, cases 01 to 08.

func key(code: int) -> InputEventKey:
	var k := InputEventKey.new()
	k.physical_keycode = code
	k.pressed = true
	return k


func pad(button: int) -> InputEventJoypadButton:
	var b := InputEventJoypadButton.new()
	b.button_index = button
	b.pressed = true
	return b


func _ready() -> void:
	await get_tree().process_frame
	var was := {"music": Settings.music, "sfx": Settings.sfx,
		"offset": Settings.offset, "speed": Settings.note_speed}

	# 01 volume to the minimum
	Settings.set_value("music", -50)
	equals("input 01", Settings.music, 0, "music stops at 0, never negative")
	Settings.set_value("sfx", -1)
	equals("input 01", Settings.sfx, 0, "and so does sfx")

	# 02 volume to the maximum
	Settings.set_value("music", 500)
	equals("input 02", Settings.music, 100, "music stops at 100, no overflow")
	Settings.set_value("sfx", 101)
	equals("input 02", Settings.sfx, 100, "and so does sfx")

	# 03 a key another lane already uses
	InputManager.reset()
	equals("input 03", InputManager.taken_by("up", key(KEY_A)), "UI_CTRL_LEFT",
		"rebinding up to A is refused, left has it")
	check("input 03", not InputManager.rebind("up", key(KEY_A)),
		"so the rebind itself is refused, not only the screen")
	check("input 03", InputManager.key_name("up") != InputManager.key_name("left"),
		"and never leaves two lanes on one key")
	check("input 03", InputManager.rebind("up", key(KEY_K)),
		"while a free key is still accepted")
	InputManager.reset()
	InputManager.reset()
	equals("input 03", InputManager.taken_by("up", pad(JOY_BUTTON_DPAD_LEFT)),
		"UI_CTRL_LEFT", "pad buttons are checked the same way")

	# 04 Esc and Enter
	equals("input 04", InputManager.taken_by("up", key(KEY_ESCAPE)), "UI_CTRL_BACK",
		"Esc belongs to back, so a lane cannot take it")
	equals("input 04", InputManager.taken_by("up", key(KEY_ENTER)), "UI_CTRL_CONFIRM",
		"and Enter belongs to confirm")

	# 05 the player's offset, which is the one a tester can reach
	Settings.set_value("offset", 0)
	equals("input 05", Settings.offset, 0, "zero offset is accepted")
	Settings.set_value("offset", 100)
	equals("input 05", Settings.offset, 100, "and +100")
	Settings.set_value("offset", -100)
	equals("input 05", Settings.offset, -100, "and -100")
	Settings.set_value("offset", 99999)
	equals("input 05", Settings.offset, Settings.OFFSET_RANGE,
		"an extreme value is clamped, not stored")
	Settings.set_value("offset", -99999)
	equals("input 05", Settings.offset, -Settings.OFFSET_RANGE,
		"in both directions")
	Settings.set_value("offset", 40)
	about("input 05", Rules.note_speed(), Rules.note_speed(),
		"and the song clock takes the offset", 0.0)

	# 06 profile names
	clear_saves()
	for name in ["", "x", "ยาวมากจริงๆนะ", "!@#$%^&*()", "Pun"]:
		var made := SaveManager.create(1, name)
		var read := SaveManager.load_slot(1)
		equals("input 06", read.get("name"), name,
			"a profile named '%s' saves and reads back" % name)
	clear_saves()

	# 07 reset to default
	InputManager.rebind("up", key(KEY_K))
	InputManager.reset()
	equals("input 07", InputManager.key_name("up"), "W", "reset puts up back to W")
	equals("input 07", InputManager.key_name("left"), "A", "and left to A")
	var arrow := InputEventKey.new()
	arrow.physical_keycode = KEY_UP
	check("input 07", InputMap.event_is_action(arrow, "lane_0"),
		"and the arrows are bound alongside")

	# 08 keyboard and gamepad together
	InputManager.reset()
	var w := InputEventKey.new()
	w.physical_keycode = KEY_W
	var dpad := InputEventJoypadButton.new()
	dpad.button_index = JOY_BUTTON_DPAD_UP
	check("input 08", InputMap.event_is_action(w, "lane_0")
		and InputMap.event_is_action(dpad, "lane_0"),
		"key and pad both reach the same lane")
	check("input 08", InputMap.event_is_action(w, "ui_up")
		and InputMap.event_is_action(dpad, "ui_up"),
		"and the same menu direction")

	Settings.set_value("music", was.music)
	Settings.set_value("sfx", was.sfx)
	Settings.set_value("offset", was.offset)
	Settings.set_value("note_speed", was.speed)
	finish()

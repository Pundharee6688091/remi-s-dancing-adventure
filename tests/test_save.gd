extends "res://tests/lib/harness.gd"
## Test plan: Save and Load, cases 01 to 07.

func put(slot: int, text: String) -> void:
	var f := FileAccess.open("user://slot_%d.json" % slot, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _ready() -> void:
	await get_tree().process_frame
	clear_saves()

	# 01 a profile in each of the three slots
	for slot in [1, 2, 3]:
		SaveManager.create(slot, "Tester%d" % slot)
	var all_there := true
	for slot in [1, 2, 3]:
		var s := SaveManager.load_slot(slot)
		if s.get("name") != "Tester%d" % slot or not s.has("created"):
			all_there = false
	check("save 01", all_there, "three separate profiles with name and date")
	equals("save 01", SaveManager.SLOTS, 3, "three slots exist")

	# 02 save, quit, relaunch, continue
	GameManager.slot = 1
	GameManager.save = SaveManager.load_slot(1)
	GameManager.save["stars"] = {"s1_1": 3}
	GameManager.save["seen"] = ["v1_1"]
	SaveManager.write(1, GameManager.save)
	var again := SaveManager.load_slot(1)
	# Compared as a number rather than as a dictionary: JSON has one number
	# type, so an int written out comes back as a float. Every reader casts,
	# so it does no harm, but == on the whole dictionary would fail on it.
	equals("save 02", int(again.get("stars", {}).get("s1_1", -1)), 3,
		"stars survive a reload")
	equals("save 02", again.get("seen"), ["v1_1"], "seen scenes survive")

	# 03 what the slot card shows
	var card := SaveManager.summary(1)
	equals("save 03", card.get("name"), "Tester1", "the card shows the name")
	check("save 03", String(card.get("line", "")).length() > 0,
		"and a line with progress and date")

	# 04 rename keeps the stars
	GameManager.save["name"] = "Renamed"
	SaveManager.write(1, GameManager.save)
	var renamed := SaveManager.load_slot(1)
	equals("save 04", renamed.get("name"), "Renamed", "the new name is saved")
	equals("save 04", int(renamed.get("stars", {}).get("s1_1", -1)), 3,
		"and the stars are untouched")

	# 05 delete removes only that slot
	SaveManager.delete(2)
	check("save 05", not SaveManager.exists(2), "the deleted slot is gone")
	check("save 05", SaveManager.exists(1) and SaveManager.exists(3),
		"and the others are left alone")

	# 06 missing, empty, invalid
	clear_saves()
	check("save 06", SaveManager.load_slot(1).is_empty(), "a missing file is empty")
	put(1, "")
	check("save 06", SaveManager.load_slot(1).is_empty(), "an empty file is empty")
	put(2, '{"name": "Pun", "stars": {')
	check("save 06", SaveManager.load_slot(2).is_empty(), "invalid json does not load")
	check("save 06", not SaveManager.exists(2), "and the broken file is set aside")
	put(3, '["not", "a", "profile"]')
	check("save 06", SaveManager.load_slot(3).is_empty(), "nor does a json array")
	clear_saves()
	GameManager.slot = 1
	GameManager.save = SaveManager.create(1, "Pun")
	Events.stage_cleared.emit("s1_1", 20.0)
	await get_tree().process_frame
	check("save 06", GameManager.save.get("stars", {}).has("s1_1"),
		"and a sound profile still records a clear, where it used to crash")

	# 07 settings persist
	var was_music: int = Settings.music
	var was_offset: int = Settings.offset
	Settings.set_value("music", 35)
	Settings.set_value("offset", 25)
	Settings.load_settings()
	equals("save 07", Settings.music, 35, "volume persists")
	equals("save 07", Settings.offset, 25, "offset persists")
	InputManager.rebind("up", _key(KEY_K))
	var fresh: Node = InputManager.get_script().new()
	add_child(fresh)
	await get_tree().process_frame
	equals("save 07", fresh.key_name("up"), "K", "and so do key bindings")
	fresh.queue_free()
	InputManager.reset()
	Settings.set_value("music", was_music)
	Settings.set_value("offset", was_offset)

	clear_saves()
	finish()


func _key(code: int) -> InputEventKey:
	var k := InputEventKey.new()
	k.physical_keycode = code
	k.pressed = true
	return k

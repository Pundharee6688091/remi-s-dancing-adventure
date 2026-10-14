extends Node
## Builds the game's actions at boot and keeps whatever the player has rebound.
##
## One row of the controls page is one action to the player, even where it
## drives two of Godot's: pressing Up is a lane in a fight and a menu
## direction everywhere else, and nobody wants to bind that twice.

const PATH := "user://settings.cfg"
const SECTION := "controls"

## The rows the controls page shows, in order. "also" is a key that stays
## bound whatever the player picks: the arrows are printed on the fight's own
## hint bar, and space confirming a focused button is older than this game.
const ROWS := [
	{"id": "up", "label": "UI_CTRL_UP", "actions": ["lane_0", "ui_up"],
		"key": KEY_W, "pad": JOY_BUTTON_DPAD_UP, "also": KEY_UP},
	{"id": "left", "label": "UI_CTRL_LEFT", "actions": ["lane_1", "ui_left"],
		"key": KEY_A, "pad": JOY_BUTTON_DPAD_LEFT, "also": KEY_LEFT},
	{"id": "right", "label": "UI_CTRL_RIGHT", "actions": ["lane_2", "ui_right"],
		"key": KEY_D, "pad": JOY_BUTTON_DPAD_RIGHT, "also": KEY_RIGHT},
	{"id": "down", "label": "UI_CTRL_DOWN", "actions": ["lane_3", "ui_down"],
		"key": KEY_S, "pad": JOY_BUTTON_DPAD_DOWN, "also": KEY_DOWN},
	{"id": "confirm", "label": "UI_CTRL_CONFIRM", "actions": ["ui_accept"],
		"key": KEY_ENTER, "pad": JOY_BUTTON_A, "also": KEY_SPACE},
	{"id": "back", "label": "UI_CTRL_BACK", "actions": ["ui_cancel"],
		"key": KEY_ESCAPE, "pad": JOY_BUTTON_B, "also": KEY_NONE},
]

## The ones the page does not show, because nothing about them is worth
## rebinding and two of them would collide with a row if they were.
const FIXED := [
	{"actions": ["delete"], "key": KEY_DELETE, "pad": JOY_BUTTON_X, "also": KEY_BACKSPACE},
	{"actions": ["toggle_language"], "key": KEY_F2, "pad": JOY_BUTTON_Y, "also": KEY_NONE},
	{"actions": ["skip_chapter"], "key": KEY_TAB, "pad": JOY_BUTTON_BACK, "also": KEY_NONE},
]

## What a pad button is called on the page. Godot only gives us a number.
const PAD_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Select", JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_SHOULDER: "L", JOY_BUTTON_RIGHT_SHOULDER: "R",
	JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down",
	JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right",
}

signal rebound()

## row id -> {"key": Key, "pad": JoyButton}
var binds := {}


func _ready() -> void:
	_defaults()
	_load()
	apply()


static func lane_action(lane: int) -> String:
	return "lane_%d" % lane


func row(id: String) -> Dictionary:
	for r in ROWS:
		if r.id == id:
			return r
	return {}


## What the page prints in each column.
func key_name(id: String) -> String:
	var k: int = binds[id]["key"]
	return OS.get_keycode_string(k) if k != KEY_NONE else "—"


func pad_name(id: String) -> String:
	var p: int = binds[id]["pad"]
	return PAD_NAMES.get(p, "Button %d" % p) if p >= 0 else "—"


## Who already answers to this press. Returns a row's label, "UI_CTRL_FIXED"
## for one of the keys the game keeps for itself, or "" when it is free.
##
## Two rows on the same key would both fire at once: in a fight that is two
## lanes off one press, and in a menu it is worse, because the row that moves
## the cursor is also the row being rebound.
func taken_by(id: String, event: InputEvent) -> String:
	var key := -1
	var pad := -1
	if event is InputEventKey:
		key = (event as InputEventKey).physical_keycode
	elif event is InputEventJoypadButton:
		pad = (event as InputEventJoypadButton).button_index
	else:
		return ""

	for r in ROWS:
		if r.id == id:
			continue
		if key != KEY_NONE and (binds[r.id]["key"] == key or r.also == key):
			return String(r.label)
		if pad >= 0 and binds[r.id]["pad"] == pad:
			return String(r.label)

	# The keys the game keeps: delete a save, swap language, skip a chapter.
	for r in FIXED:
		if key != KEY_NONE and (r.key == key or r.also == key):
			return "UI_CTRL_FIXED"
		if pad >= 0 and r.pad == pad:
			return "UI_CTRL_FIXED"

	# This row's own spare key is already its own, so it is not a clash, but
	# binding onto it would leave the row with one key where it had two.
	var mine := row(id)
	if key != KEY_NONE and not mine.is_empty() and mine.also == key:
		return "UI_CTRL_FIXED"
	return ""


## Give a row a key or a pad button, whichever the player pressed. Returns
## false when the press was neither, so the page can keep waiting.
func rebind(id: String, event: InputEvent) -> bool:
	if event is InputEventKey:
		binds[id]["key"] = (event as InputEventKey).physical_keycode
	elif event is InputEventJoypadButton:
		binds[id]["pad"] = (event as InputEventJoypadButton).button_index
	else:
		return false
	apply()
	_save()
	rebound.emit()
	return true


func reset() -> void:
	_defaults()
	apply()
	_save()
	rebound.emit()


## Rebuild every action from what is bound now. Clearing first is what makes
## this safe to call again after a change.
func apply() -> void:
	for r in ROWS:
		_bind(r.actions, binds[r.id]["key"], binds[r.id]["pad"], r.also)
	for r in FIXED:
		_bind(r.actions, r.key, r.pad, r.also)


func _defaults() -> void:
	for r in ROWS:
		binds[r.id] = {"key": r.key, "pad": r.pad}


func _bind(actions: Array, key: int, pad: int, also: int) -> void:
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		_add_key(action, key)
		if also != KEY_NONE and also != key:
			_add_key(action, also)
		if pad >= 0:
			var j := InputEventJoypadButton.new()
			j.button_index = pad
			InputMap.action_add_event(action, j)


func _add_key(action: String, key: int) -> void:
	if key == KEY_NONE:
		return
	var k := InputEventKey.new()
	k.physical_keycode = key
	InputMap.action_add_event(action, k)


## The settings file is shared, so it is read before it is written and only
## this section is touched.
func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	for r in ROWS:
		cfg.set_value(SECTION, r.id + "_key", binds[r.id]["key"])
		cfg.set_value(SECTION, r.id + "_pad", binds[r.id]["pad"])
	cfg.save(PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for r in ROWS:
		binds[r.id]["key"] = int(cfg.get_value(SECTION, r.id + "_key", r.key))
		binds[r.id]["pad"] = int(cfg.get_value(SECTION, r.id + "_pad", r.pad))

extends Node

func _ready() -> void:
	_add("lane_0", KEY_W, JOY_BUTTON_DPAD_UP, KEY_UP)
	_add("lane_1", KEY_A, JOY_BUTTON_DPAD_LEFT, KEY_LEFT)
	_add("lane_2", KEY_D, JOY_BUTTON_DPAD_RIGHT, KEY_RIGHT)
	_add("lane_3", KEY_S, JOY_BUTTON_DPAD_DOWN, KEY_DOWN)
	_add("delete", KEY_DELETE, JOY_BUTTON_X, KEY_BACKSPACE)


static func lane_action(lane: int) -> String:
	return "lane_%d" % lane


func _add(action: String, key: Key, pad: JoyButton, alt_key := KEY_NONE) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)

	_add_key(action, key)
	if alt_key != KEY_NONE:
		_add_key(action, alt_key)

	var j := InputEventJoypadButton.new()
	j.button_index = pad
	InputMap.action_add_event(action, j)


func _add_key(action: String, key: Key) -> void:
	var k := InputEventKey.new()
	k.physical_keycode = key
	InputMap.action_add_event(action, k)

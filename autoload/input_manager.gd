extends Node

func _ready() -> void:
	_add("lane_0", KEY_W,  JOY_BUTTON_DPAD_UP)
	_add("lane_1", KEY_A,  JOY_BUTTON_DPAD_LEFT)
	_add("lane_2", KEY_D,    JOY_BUTTON_DPAD_RIGHT)
	_add("lane_3", KEY_S, JOY_BUTTON_DPAD_DOWN)
	_add("delete", KEY_DELETE, JOY_BUTTON_X)


static func lane_action(lane: int) -> String:
	return "lane_%d" % lane


func _add(action: String, key: Key, pad: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)

	var k := InputEventKey.new()
	k.physical_keycode = key
	InputMap.action_add_event(action, k)

	var j := InputEventJoypadButton.new()
	j.button_index = pad
	InputMap.action_add_event(action, j)

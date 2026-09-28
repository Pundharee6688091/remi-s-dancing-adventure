extends Control

const SAVE_SLOTS := "res://scenes/ui/save_slots.tscn"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label("REMI'S DANCING ADVENTURE", Vector2(230, 280))
	_label("PRESS ANY BUTTON", Vector2(620, 360))


func _unhandled_input(event: InputEvent) -> void:
	var is_button := event is InputEventKey or event is InputEventJoypadButton
	if is_button and event.is_pressed() and not event.is_echo():
		get_viewport().set_input_as_handled()
		SceneRouter.goto(SAVE_SLOTS)


func _label(text: String, pos: Vector2) -> void:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 50)
	l.text = text
	l.position = pos
	add_child(l)

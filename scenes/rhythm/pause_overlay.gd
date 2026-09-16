class_name PauseOverlay
extends Control

signal resume_pressed
signal restart_pressed
signal quit_pressed

var _first: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var box := VBoxContainer.new()
	box.position = Vector2(520, 250)
	box.custom_minimum_size = Vector2(240, 0)
	box.add_theme_constant_override("separation", 12)
	add_child(box)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_first = _button(box, "Resume", func() -> void: resume_pressed.emit())
	_button(box, "Restart stage", func() -> void: restart_pressed.emit())
	_button(box, "Quit stage", func() -> void: quit_pressed.emit())

	hide()


func open() -> void:
	show()
	_first.grab_focus()


func _button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

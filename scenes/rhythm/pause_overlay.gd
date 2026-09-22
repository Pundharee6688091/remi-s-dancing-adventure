class_name PauseOverlay
extends Control

signal resume_pressed
signal restart_pressed
signal quit_pressed

var _first: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	UIKit.dim(self)
	var box := UIKit.card(self, Vector2(430, 190), 420)

	var title := Label.new()
	title.add_theme_font_size_override("font_size", 32)
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_first = _button(box, "Resume", func() -> void: resume_pressed.emit())
	var restart := _button(box, "Restart stage", func() -> void: restart_pressed.emit())
	var quit := _button(box, "Quit stage", func() -> void: quit_pressed.emit())

	UIKit.trap_focus([_first, restart, quit])
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

class_name ResultOverlay
extends Control

var _title: Label
var _lines: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var box := VBoxContainer.new()
	box.position = Vector2(440, 200)
	box.custom_minimum_size = Vector2(400, 0)
	box.add_theme_constant_override("separation", 14)
	add_child(box)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)

	_lines = Label.new()
	_lines.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_lines)

	hide()


func show_result(r: Dictionary) -> void:
	_title.text = "STAGE CLEAR" if r.won else "STAGE FAILED"

	var c: Dictionary = r.counts
	var stars: String = "★".repeat(r.stars) + "☆".repeat(3 - r.stars)

	_lines.text = "\n".join([
		"Monster HP left   %d%%" % r.hp,
		stars,
		"",
		"Perfect  %d" % c.perfect,
		"Great    %d" % c.great,
		"Good     %d" % c.good,
		"Miss     %d" % c.miss,
		"",
		"Enter to play again",
	])
	show()

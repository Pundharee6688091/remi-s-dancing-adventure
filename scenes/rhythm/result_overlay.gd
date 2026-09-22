class_name ResultOverlay
extends Control

var _title: Label
var _lines: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	UIKit.dim(self)
	var box := UIKit.card(self, Vector2(440, 140), 400)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 32)
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
		"Max combo  %d" % r.max_combo,
		"",
		"Perfect  %d" % c.perfect,
		"Great    %d" % c.great,
		"Good     %d" % c.good,
		"Miss     %d" % c.miss,
		"",
		"Enter to play again",
	])
	show()

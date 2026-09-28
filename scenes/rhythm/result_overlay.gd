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
	_title.text = tr("UI_STAGE_CLEAR_TITLE") if r.won else tr("UI_STAGE_FAILED_TITLE")

	var c: Dictionary = r.counts
	var stars: String = "★".repeat(r.stars) + "☆".repeat(3 - r.stars)

	var best := tr("UI_BEST_PCT") % r.previous_best
	if r.won and r.hp < r.previous_best:
		best = tr("UI_NEW_BEST") % r.previous_best

	_lines.text = "\n".join([
		tr("UI_MONSTER_HP_LEFT") % r.hp,
		stars,
		best,
		tr("UI_MAX_COMBO") % r.max_combo,
		"",
		tr("UI_PERFECT") % c.perfect,
		tr("UI_GREAT") % c.great,
		tr("UI_GOOD") % c.good,
		tr("UI_MISS") % c.miss,
		"",
		tr("UI_PLAY_AGAIN"),
	])
	show()

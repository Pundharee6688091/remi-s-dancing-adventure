class_name ResultOverlay
extends Control
## Layout lives in result_overlay.tscn.

@onready var _title: Label = %Title
@onready var _lines: Label = %Lines


func _ready() -> void:
	_set_hints()
	Events.language_changed.connect(_set_hints)
	hide()


## Enter replays the stage, Esc goes back to the map. See battle.gd's
## State.RESULT branch.
func _set_hints() -> void:
	%Hints.set_hints([["Enter", tr("UI_PLAY_AGAIN")], ["Esc", tr("UI_QUIT_STAGE")]])


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
	])
	show()

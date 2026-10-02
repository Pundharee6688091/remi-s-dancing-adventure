class_name StageDetail
extends Control
## Layout lives in stage_detail.tscn. Follows StagePreview.dc.html: opponent
## portrait on the left, four facts in a 2x2 grid on the right. No BPM or note
## count, the win line is the same everywhere so it is not repeated here.

signal fight_pressed(stage_id: String)

var _stage_id := ""

@onready var _fight: Button = %Fight
@onready var _back: Button = %Back


func _ready() -> void:
	_set_hints()
	Events.language_changed.connect(_set_hints)
	hide()


func open(stage_id: String) -> void:
	_stage_id = stage_id
	var n := Rules.stage(stage_id)
	var song_id: String = n.get("song", "")
	var opp: String = n.get("opponent", "")
	var available := ResourceLoader.exists(Rules.song_path(song_id)) \
		and FileAccess.file_exists(Rules.chart_path(song_id))

	%Title.text = opp if opp != "" else String(n.get("label", ""))
	%Sub.text = tr("UI_STAGE") % n.get("label", "")
	%Art.texture = UIKit.cropped_texture(Rules.enemy_path(song_id))

	if available:
		var chart := ChartParser.parse(Rules.chart_path(song_id))
		var secs := 0
		var stream: AudioStream = load(Rules.song_path(song_id))
		if stream != null:
			secs = int(stream.get_length())
		%Value.text = tr("UI_SONG_TIME") % [chart.title, secs / 60, secs % 60]
		%ValueDiff.text = "●".repeat(int(chart.level))
	else:
		%Value.text = tr("UI_SONG_MISSING")
		%ValueDiff.text = "—"

	var best := GameManager.stars_for(stage_id)
	%ValueBest.text = "★".repeat(best) + "☆".repeat(3 - best) if best > 0 \
		else tr("UI_NOT_CLEARED_DASH")
	%ValueReward.text = tr("UI_REWARD_JOINS") % opp if opp != "" else "—"

	_fight.disabled = not available
	_fight.focus_mode = Control.FOCUS_ALL if available else Control.FOCUS_NONE
	UIKit.trap_focus([_fight, _back] if available else [_back])
	show()
	(_fight if available else _back).grab_focus()


func _set_hints() -> void:
	%Hints.set_hints([["◀ ▶", tr("UI_MOVE")], ["Enter", tr("UI_CONFIRM")],
		["Esc", tr("UI_CLOSE")]])


func _on_fight_pressed() -> void:
	hide()
	fight_pressed.emit(_stage_id)


func _on_back_pressed() -> void:
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		hide()

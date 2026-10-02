class_name StageDetail
extends Control
## Layout lives in stage_detail.tscn.

signal fight_pressed(stage_id: String)

var _stage_id := ""

@onready var _title: Label = %Title
@onready var _info: Label = %Info
@onready var _fight: Button = %Fight
@onready var _back: Button = %Back


func _ready() -> void:
	hide()


func open(stage_id: String) -> void:
	_stage_id = stage_id
	var n := Rules.stage(stage_id)
	var song_id: String = n.get("song", "")
	var available := ResourceLoader.exists(Rules.song_path(song_id)) \
		and FileAccess.file_exists(Rules.chart_path(song_id))

	_title.text = tr("UI_STAGE") % n.get("label", "")

	var lines: Array[String] = []
	if available:
		var chart := ChartParser.parse(Rules.chart_path(song_id))
		lines.append(tr("UI_SONG") % chart.title)
		lines.append(tr("UI_BPM") % int(chart.bpm))
		lines.append(tr("UI_LEVEL") % "●".repeat(int(chart.level)))
	else:
		lines.append(tr("UI_SONG_MISSING"))

	var opp: String = n.get("opponent", "")
	lines.append(tr("UI_OPPONENT") % (opp if opp != "" else "—"))

	var best := GameManager.stars_for(stage_id)
	lines.append(tr("UI_BEST") % ("★".repeat(best) if best > 0 else tr("UI_NOT_CLEARED")))
	if opp != "":
		lines.append(tr("UI_REWARD") % opp)

	_info.text = "\n".join(PackedStringArray(lines))

	_fight.disabled = not available
	_fight.focus_mode = Control.FOCUS_ALL if available else Control.FOCUS_NONE
	UIKit.trap_focus([_fight, _back] if available else [_back])
	show()
	(_fight if available else _back).grab_focus()


func _on_fight_pressed() -> void:
	hide()
	fight_pressed.emit(_stage_id)


func _on_back_pressed() -> void:
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		hide()

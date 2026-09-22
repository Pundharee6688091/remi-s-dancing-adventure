class_name StageDetail
extends Control

signal fight_pressed(stage_id: String)

var _stage_id := ""
var _title: Label
var _info: Label
var _fight: Button
var _back: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	UIKit.dim(self)
	var box := UIKit.card(self, Vector2(420, 160), 440)

	_title = Label.new()
	box.add_child(_title)

	_info = Label.new()
	box.add_child(_info)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)

	_fight = Button.new()
	_fight.text = "Fight!"
	_fight.pressed.connect(_on_fight)
	row.add_child(_fight)

	_back = Button.new()
	_back.text = "Back"
	_back.pressed.connect(hide)
	row.add_child(_back)

	hide()


func open(stage_id: String) -> void:
	_stage_id = stage_id
	var n := Rules.stage(stage_id)
	var song_id: String = n.get("song", "")
	var available := ResourceLoader.exists(Rules.song_path(song_id)) \
		and FileAccess.file_exists(Rules.chart_path(song_id))

	_title.text = "Stage %s" % n.get("label", "")

	var lines: Array[String] = []
	if available:
		var chart := ChartParser.parse(Rules.chart_path(song_id))
		lines.append("Song      %s" % chart.title)
		lines.append("BPM       %d" % int(chart.bpm))
		lines.append("Level     %s" % "●".repeat(int(chart.level)))
	else:
		lines.append("This song is not in the game yet.")

	var opp: String = n.get("opponent", "")
	lines.append("Opponent  %s" % (opp if opp != "" else "—"))

	var best := GameManager.stars_for(stage_id)
	lines.append("Best      %s" % ("★".repeat(best) if best > 0 else "not cleared"))
	if opp != "":
		lines.append("Reward    %s joins your party" % opp)

	_info.text = "\n".join(PackedStringArray(lines))

	_fight.disabled = not available
	show()
	(_fight if available else _back).grab_focus()


func _on_fight() -> void:
	hide()
	fight_pressed.emit(_stage_id)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		hide()

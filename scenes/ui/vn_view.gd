class_name VnView
extends Control

const BGM := "res://music/vn_bgm1.wav"

var timeline := ""

## Only offered on a re-read, so a first time through cannot be jumped.
var _can_skip_chapter := false


func setup(params: Dictionary) -> void:
	timeline = String(params.get("timeline", ""))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if timeline == "":
		push_warning("Story node has no timeline")
		Events.story_finished.emit()
		return
	_can_skip_chapter = GameManager.save.get("seen", []).has(GameManager.current_stage_id)
	%Settings.routed = false
	%Settings.closed.connect(_close_settings)
	_set_hints()
	Events.language_changed.connect(_set_hints)

	_start_bgm()
	Dialogic.timeline_ended.connect(_on_timeline_ended)
	Dialogic.start(timeline)


func _set_hints() -> void:
	var hints: Array = [["Enter", tr("UI_NEXT")]]
	if _can_skip_chapter:
		hints.append(["Tab", tr("UI_SKIP_CHAPTER")])
	hints.append(["Esc", tr("UI_SETTINGS")])
	%Hints.set_hints(hints)



func _unhandled_input(event: InputEvent) -> void:
	if %Settings.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_open_settings()
	elif _can_skip_chapter and event.is_action_pressed("skip_chapter"):
		# Ending the timeline runs the normal finish path, so the node is
		# still marked seen and the map still gets the player back.
		# skip_ending, because otherwise end_timeline() starts Dialogic's
		# built-in "[clear]" ending timeline and waits to be advanced through
		# it, so timeline_ended never fires and the chapter never leaves.
		get_viewport().set_input_as_handled()
		Dialogic.end_timeline(true)


## Pausing Dialogic is what stops the chapter advancing underneath, since
## handle_input() bails while paused.
func _open_settings() -> void:
	Dialogic.paused = true
	%Hints.hide()
	%Settings.show()


func _close_settings() -> void:
	Dialogic.paused = false
	%Hints.show()


## The track is shorter than a chapter, so it restarts when it ends rather
## than relying on a loop point baked into the import.
func _start_bgm() -> void:
	if not ResourceLoader.exists(BGM):
		return
	%Bgm.stream = load(BGM)
	%Bgm.finished.connect(%Bgm.play)
	%Bgm.play()


func _on_timeline_ended() -> void:
	%Bgm.stop()
	Dialogic.timeline_ended.disconnect(_on_timeline_ended)
	Events.story_finished.emit()


func _exit_tree() -> void:
	Dialogic.paused = false
	if Dialogic.timeline_ended.is_connected(_on_timeline_ended):
		Dialogic.timeline_ended.disconnect(_on_timeline_ended)
	if Dialogic.current_timeline != null:
		Dialogic.end_timeline(true)

## Rebuilding this mid-song would restart the stage, so a language change
## leaves it alone. Its labels hold translation keys, so Godot re-translates
## them in place.
func blocks_reload() -> bool:
	return true

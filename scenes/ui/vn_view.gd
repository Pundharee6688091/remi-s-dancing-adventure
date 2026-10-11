class_name VnView
extends Control

const BGM := "res://music/vn_bgm1.wav"

var timeline := ""

## Whose backdrop to wear. Empty for a stage's intro, which is not the stage.
var bg_stage := ""

## What marks this chapter as watched. A stage's intro is remembered under its
## own key rather than the stage's, so the two never get confused.
var seen_key := ""

## Only offered on a re-read, so a first time through cannot be jumped.
var _can_skip_chapter := false


func setup(params: Dictionary) -> void:
	timeline = String(params.get("timeline", ""))
	bg_stage = String(params.get("stage", ""))
	seen_key = String(params.get("seen_key", ""))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if timeline == "":
		push_warning("Story node has no timeline")
		Events.story_finished.emit()
		return
	%Bg.texture = Rules.background("story", bg_stage)
	_can_skip_chapter = GameManager.save.get("seen", []).has(seen_key)
	%Settings.routed = false
	%Settings.closed.connect(_close_settings)
	_set_hints()
	Events.language_changed.connect(_on_language_changed)

	_start_bgm()
	Dialogic.timeline_ended.connect(_on_timeline_ended)
	Dialogic.start(timeline)


## Dialogic draws a line once and leaves it there, so switching language has to
## redraw whatever is already on screen. Lines after this one come through
## translated on their own.
func _on_language_changed() -> void:
	_set_hints()
	var timeline := Dialogic.current_timeline
	if timeline == null:
		return
	var idx: int = Dialogic.current_event_idx
	if idx < 0 or idx >= timeline.events.size():
		return
	var event = timeline.events[idx]
	if not (event is DialogicTextEvent):
		return
	if event.character != null:
		Dialogic.Text.update_name_label(event.character, true)
	Dialogic.Text.update_dialog_text(event.get_property_translated("text"), true)


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

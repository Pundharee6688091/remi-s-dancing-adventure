class_name VnView
extends Control

const BGM := "res://music/vn_bgm1.wav"

var timeline := ""


func setup(params: Dictionary) -> void:
	timeline = String(params.get("timeline", ""))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if timeline == "":
		push_warning("Story node has no timeline")
		Events.story_finished.emit()
		return
	%Settings.routed = false
	%Settings.closed.connect(_close_settings)
	_set_hints()
	Events.language_changed.connect(_set_hints)

	_start_bgm()
	Dialogic.timeline_ended.connect(_on_timeline_ended)
	Dialogic.start(timeline)


func _set_hints() -> void:
	%Hints.set_hints([["Enter", tr("UI_NEXT")], ["Ctrl", tr("UI_SKIP")],
		["Esc", tr("UI_SETTINGS")]])


## Hold Ctrl to fast-forward. Dialogic's auto-skip runs each event at its own
## pace rather than jumping, so nothing is missed, it just goes quickly.
func _process(_delta: float) -> void:
	if %Settings.visible:
		return
	var want := Input.is_physical_key_pressed(KEY_CTRL)
	if want != Dialogic.Inputs.auto_skip.enabled:
		Dialogic.Inputs.auto_skip.enabled = want


func _unhandled_input(event: InputEvent) -> void:
	if %Settings.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_open_settings()


## Pausing Dialogic is what stops the chapter advancing underneath, since
## handle_input() bails while paused.
func _open_settings() -> void:
	Dialogic.Inputs.auto_skip.enabled = false
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
	Dialogic.Inputs.auto_skip.enabled = false
	%Bgm.stop()
	Dialogic.timeline_ended.disconnect(_on_timeline_ended)
	Events.story_finished.emit()


func _exit_tree() -> void:
	Dialogic.Inputs.auto_skip.enabled = false
	Dialogic.paused = false
	if Dialogic.timeline_ended.is_connected(_on_timeline_ended):
		Dialogic.timeline_ended.disconnect(_on_timeline_ended)
	if Dialogic.current_timeline != null:
		Dialogic.end_timeline()

## Rebuilding this mid-song would restart the stage, so a language change
## leaves it alone. Its labels hold translation keys, so Godot re-translates
## them in place.
func blocks_reload() -> bool:
	return true

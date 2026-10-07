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
	_start_bgm()
	Dialogic.timeline_ended.connect(_on_timeline_ended)
	Dialogic.start(timeline)


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
	if Dialogic.timeline_ended.is_connected(_on_timeline_ended):
		Dialogic.timeline_ended.disconnect(_on_timeline_ended)
	if Dialogic.current_timeline != null:
		Dialogic.end_timeline()

## Rebuilding this mid-song would restart the stage, so a language change
## leaves it alone. Its labels hold translation keys, so Godot re-translates
## them in place.
func blocks_reload() -> bool:
	return true

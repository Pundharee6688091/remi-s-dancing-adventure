class_name VnView
extends Control

const BGM := "res://music/vn_bgm1.wav"

var timeline := ""

## The chapter's gist, shown before it is jumped. Empty for a chapter that has
## none, which then skips straight through.
var summary := ""

## What marks this chapter as watched. A stage's intro is remembered under its
## own key rather than the stage's, so the two never get confused.
var seen_key := ""

## Only offered on a re-read, so a first time through cannot be jumped.
var _can_skip_chapter := false


func setup(params: Dictionary) -> void:
	timeline = String(params.get("timeline", ""))
	summary = String(params.get("summary", ""))
	seen_key = String(params.get("seen_key", ""))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if timeline == "":
		push_warning("Story node has no timeline")
		Events.story_finished.emit()
		return
	_can_skip_chapter = GameManager.save.get("seen", []).has(seen_key)
	%Settings.routed = false
	%Settings.closed.connect(_close_settings)
	%SkipSummary.answered.connect(_on_skip_answered)
	_set_hints()
	Events.language_changed.connect(_on_language_changed)

	_start_bgm()
	# A name revealed in an earlier chapter is still sitting in the variable
	# in whatever language it was revealed in.
	_sync_names()
	Dialogic.VAR.variable_was_set.connect(_on_variable_set)
	Dialogic.timeline_ended.connect(_on_timeline_ended)
	# The box is built, and Dialogic's own style applied to it, after the
	# chapter starts, so the padding waits for the first line.
	Dialogic.Text.about_to_show_text.connect(_pad_dialogue)
	Dialogic.start(timeline)


## Thai stacks a vowel and a tone mark above the letter, reaching about a
## third of the font size higher than Latin ever does, and hangs a vowel below
## it as well. Both labels are sized from the font's Latin ascent, so they clip
## whatever leaves that line: the dialogue box cut the tops off its first line,
## and the name tab cut the tone mark off a name like เรมี่. Padding the text
## inside each gives it the room, and neither box's own art is touched.
##
## Done from here rather than in the addon's own scene, so updating Dialogic
## does not quietly undo it.
const HEADROOM := 0.3
const UNDERROOM := 0.12

var _padded := false

func _pad_dialogue(_info := {}) -> void:
	if _padded:
		return
	for n in get_tree().get_nodes_in_group("dialogic_dialog_text"):
		var text := n as RichTextLabel
		if text == null:
			continue
		var pad := roundi(text.get_theme_font_size("normal_font_size") * HEADROOM)
		var box := StyleBoxEmpty.new()
		box.content_margin_top = pad
		text.add_theme_stylebox_override("normal", box)
		_padded = true
	_pad_name()


## The name tab hangs off the top of the dialogue box, so the room it needs has
## to come out of the sky above it rather than out of the first line of speech.
## Growing towards the beginning is what keeps its bottom edge where it is,
## whatever Dialogic does with the tab's own offsets afterwards.
func _pad_name() -> void:
	for n in get_tree().get_nodes_in_group("dialogic_name_label"):
		var label := n as Label
		if label == null:
			continue
		var size := label.get_theme_font_size("font_size")
		var box := StyleBoxEmpty.new()
		box.content_margin_top = roundi(size * HEADROOM)
		box.content_margin_bottom = roundi(size * UNDERROOM)
		label.add_theme_stylebox_override("normal", box)
		var tab := label.get_parent() as Control
		if tab != null:
			tab.grow_vertical = Control.GROW_DIRECTION_BEGIN


## Dialogic keeps a character's name in a variable so it can read "???" until
## they give it, and the timelines set that variable to the English name. The
## name is translated before the variable is put into it, never after, so the
## variable itself has to hold the right language. Each one is named after its
## character, so the row to read comes from the variable's own name rather
## than from a second list that could drift away from it.
func _sync_names() -> void:
	var defaults: Dictionary = ProjectSettings.get_setting("dialogic/variables", {})
	for v in defaults:
		var var_name := String(v)
		if not var_name.ends_with("_name"):
			continue
		var key := "UI_NAME_" + var_name.trim_suffix("_name").to_upper()
		var want := tr(key)
		if want == key:
			continue                      # nobody wrote a name under that row
		# The value the variable starts at is the hidden one, so anything
		# else means the character has given their name and it can be swapped.
		# A character still hiding behind "???" is left alone.
		var now := String(Dialogic.VAR.get_variable(var_name, ""))
		if now == "" or now == String(defaults[v]) or now == want:
			continue
		Dialogic.VAR.set_variable(var_name, want)


## A name given mid-chapter arrives in English from the timeline, so it is
## swapped as it lands and the box is redrawn with it.
func _on_variable_set(info: Dictionary) -> void:
	if not String(info.get("variable", "")).ends_with("_name"):
		return
	_sync_names()
	var speaker := Dialogic.Text.get_current_speaker()
	if speaker != null:
		Dialogic.Text.update_name_label(speaker, true)


## Dialogic draws a line once and leaves it there, so switching language has to
## redraw whatever is already on screen. Lines after this one come through
## translated on their own.
func _on_language_changed() -> void:
	_set_hints()
	_sync_names()
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
		hints.append(["Tab", tr("UI_SKIP_CHAPTER"), _ask_skip])
	hints.append(["Esc", tr("UI_SETTINGS"), _open_settings])
	%Hints.set_hints(hints)



func _unhandled_input(event: InputEvent) -> void:
	if %Settings.visible or %SkipSummary.is_open():
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_open_settings()
	elif _can_skip_chapter and event.is_action_pressed("skip_chapter"):
		get_viewport().set_input_as_handled()
		_ask_skip()


## The gist goes up first, so jumping a chapter does not mean losing the
## thread. A chapter with nothing written for it skips the way it always did.
func _ask_skip() -> void:
	if summary == "":
		_skip_chapter()
		return
	Dialogic.paused = true
	%Hints.hide()
	%SkipSummary.ask(summary)


func _on_skip_answered(skip: bool) -> void:
	Dialogic.paused = false
	%Hints.show()
	if skip:
		_skip_chapter()


## Ending the timeline runs the normal finish path, so the node is still
## marked seen and the map still gets the player back. skip_ending, because
## otherwise end_timeline() starts Dialogic's built-in "[clear]" ending
## timeline and waits to be advanced through it, so timeline_ended never fires
## and the chapter never leaves.
func _skip_chapter() -> void:
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

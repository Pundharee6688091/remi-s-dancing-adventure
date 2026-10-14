class_name SkipSummary
extends Control
## The card that goes up when a chapter is about to be jumped: the gist of it
## first, then the choice. Layout lives in skip_summary.tscn.
##
## Shown before the skip rather than after it, so the answer is an informed
## one and nobody loses the thread by pressing Tab.

signal answered(skip: bool)


## Thai stacks a vowel and a tone mark above the letter, and a rich text box
## clips whatever leaves its first line, so that line's tops were being cut
## off. The same headroom the dialogue box gets, for the same reason.
const HEADROOM := 0.3


func _ready() -> void:
	UIKit.trap_focus([%Stay, %Skip])
	_pad_body()
	_set_hints()
	Events.language_changed.connect(_set_hints)
	hide()


func _pad_body() -> void:
	var box := StyleBoxEmpty.new()
	box.content_margin_top = roundi(
		%Body.get_theme_font_size("normal_font_size") * HEADROOM)
	%Body.add_theme_stylebox_override("normal", box)


## key is a translation key out of stages.json rather than prose, so the gist
## follows the language the rest of the screen is in, including a change made
## from the settings screen while the card is up.
##
## The box reads BBCode, so a summary can put a name in bold the way the two
## in stages.json already try to. Set as text rather than as parsed BBCode,
## because text is what Godot translates for us on a language change.
func ask(key: String) -> void:
	%Body.text = key
	show()
	# The skip is what was asked for by pressing Tab, so it takes the focus
	# and Enter goes straight through. Esc is the way back.
	%Skip.grab_focus()


func is_open() -> bool:
	return visible


func _set_hints() -> void:
	%Hints.set_hints([[["←", "→"], tr("UI_CHOOSE")],
		["Enter", tr("UI_CONFIRM")], ["Esc", tr("UI_SKIP_STAY")]])


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_answer(false)


func _on_stay_pressed() -> void:
	_answer(false)


func _on_skip_pressed() -> void:
	_answer(true)


func _answer(skip: bool) -> void:
	hide()
	answered.emit(skip)

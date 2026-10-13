class_name SkipSummary
extends Control
## The card that goes up when a chapter is about to be jumped: the gist of it
## first, then the choice. Layout lives in skip_summary.tscn.
##
## Shown before the skip rather than after it, so the answer is an informed
## one and nobody loses the thread by pressing Tab.

signal answered(skip: bool)


func _ready() -> void:
	UIKit.trap_focus([%Stay, %Skip])
	_set_hints()
	Events.language_changed.connect(_set_hints)
	hide()


## key is a translation key out of stages.json rather than prose, so the gist
## follows the language the rest of the screen is in, including a change made
## from the settings screen while the card is up.
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

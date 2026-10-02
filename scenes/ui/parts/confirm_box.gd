class_name ConfirmBox
extends Control
## Layout lives in confirm_box.tscn. One dialog reused everywhere, so the
## destructive answer is always on the right and Cancel always has focus.

signal answered(yes: bool)

@onready var _title: Label = %Title
@onready var _body: Label = %Body
@onready var _yes: Button = %Yes
@onready var _no: Button = %No


func _ready() -> void:
	UIKit.trap_focus([%No, %Yes])
	_set_hints()
	Events.language_changed.connect(_set_hints)
	hide()


func ask(title: String, body := "", yes_text := "", no_text := "") -> void:
	_title.text = title
	_body.text = body
	_body.visible = body != ""
	_yes.text = yes_text if yes_text != "" else tr("UI_YES")
	_no.text = no_text if no_text != "" else tr("UI_CANCEL")
	show()
	_no.grab_focus()


func is_open() -> bool:
	return visible


func _set_hints() -> void:
	%Hints.set_hints([[["←", "→"], tr("UI_CHOOSE")], ["Enter", tr("UI_CONFIRM")],
		["Esc", tr("UI_CANCEL")]])


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_answer(false)


func _on_yes_pressed() -> void:
	_answer(true)


func _on_no_pressed() -> void:
	_answer(false)


func _answer(yes: bool) -> void:
	hide()
	answered.emit(yes)

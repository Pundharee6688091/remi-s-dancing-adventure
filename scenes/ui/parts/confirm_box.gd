class_name ConfirmBox
extends Control

signal answered(yes: bool)

var _label: Label
var _yes: Button
var _no: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var box := VBoxContainer.new()
	box.position = Vector2(440, 280)
	box.custom_minimum_size = Vector2(400, 0)
	box.add_theme_constant_override("separation", 14)
	add_child(box)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)

	_no = Button.new()
	_no.pressed.connect(func() -> void: _answer(false))
	row.add_child(_no)

	_yes = Button.new()
	_yes.pressed.connect(func() -> void: _answer(true))
	row.add_child(_yes)

	hide()


func ask(question: String, yes_text := "Yes", no_text := "Cancel") -> void:
	_label.text = question
	_yes.text = yes_text
	_no.text = no_text
	show()
	_no.grab_focus()


func is_open() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_answer(false)


func _answer(yes: bool) -> void:
	hide()
	answered.emit(yes)

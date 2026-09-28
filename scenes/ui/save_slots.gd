extends Control

const SLOTS := 3

var _cards: Array[Button] = []
var _confirm: ConfirmBox
var _name_panel: Control
var _name_edit: LineEdit
var _pending_slot := 1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var title := Label.new()
	title.text = tr("UI_SELECT_PROFILE")
	title.position = Vector2(60, 50)
	add_child(title)

	var row := HBoxContainer.new()
	row.position = Vector2(60, 200)
	row.add_theme_constant_override("separation", 24)
	add_child(row)

	for i in SLOTS:
		var slot := i + 1
		var b := Button.new()
		b.custom_minimum_size = Vector2(300, 220)
		b.pressed.connect(func() -> void: _on_card_pressed(slot))
		row.add_child(b)
		_cards.append(b)

	var hint := Label.new()
	hint.text = tr("UI_SLOTS_HINT")
	hint.position = Vector2(60, 660)
	add_child(hint)

	_build_name_panel()

	_confirm = ConfirmBox.new()
	_confirm.answered.connect(_on_delete_answered)
	add_child(_confirm)

	_refresh()
	_cards[0].grab_focus()


func _refresh() -> void:
	for i in SLOTS:
		var s := SaveManager.summary(i + 1)
		if s.is_empty():
			_cards[i].text = tr("UI_EMPTY_SLOT")
		else:
			_cards[i].text = "%s\n%s" % [s.name, s.line]


func _on_card_pressed(slot: int) -> void:
	if SaveManager.exists(slot):
		GameManager.load_slot(slot)
	else:
		_pending_slot = slot
		_name_edit.text = ""
		_name_panel.show()
		_name_edit.grab_focus()


## Runs before any control sees the event — see the note below.
func _input(event: InputEvent) -> void:
	if _name_panel.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_name_panel.hide()
		_cards[_pending_slot - 1].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _confirm.is_open() or _name_panel.visible:
		return

	if event.is_action_pressed("ui_cancel"):
		SceneRouter.back()
	elif event.is_action_pressed("delete"):
		var slot := _focused_slot()
		if slot > 0 and SaveManager.exists(slot):
			_pending_slot = slot
			_confirm.ask(tr("UI_DELETE_CONFIRM")
				% SaveManager.summary(slot).name, tr("UI_DELETE"), tr("UI_CANCEL"))


func _focused_slot() -> int:
	var idx := _cards.find(get_viewport().gui_get_focus_owner())
	return idx + 1 if idx >= 0 else 0


func _on_delete_answered(yes: bool) -> void:
	if yes:
		SaveManager.delete(_pending_slot)
		_refresh()
	_cards[_pending_slot - 1].grab_focus()


func _build_name_panel() -> void:
	_name_panel = Control.new()
	_name_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_name_panel)

	UIKit.dim(_name_panel)
	var box := UIKit.card(_name_panel, Vector2(440, 240), 400)

	var l := Label.new()
	l.text = tr("UI_NAME_PROMPT")
	box.add_child(l)

	_name_edit = LineEdit.new()
	_name_edit.max_length = 16
	_name_edit.placeholder_text = tr("UI_YOUR_NAME")
	_name_edit.text_submitted.connect(func(_t: String) -> void: _start_new())
	box.add_child(_name_edit)

	var hint := Label.new()
	hint.text = tr("UI_NAME_HINT")
	box.add_child(hint)

	UIKit.trap_focus([_name_edit])
	_name_panel.hide()


func _start_new() -> void:
	var n := _name_edit.text.strip_edges()
	if n.is_empty():
		return
	_name_panel.hide()
	GameManager.start_new_game(_pending_slot, n)

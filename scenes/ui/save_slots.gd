extends Control
## Layout lives in save_slots.tscn.

const SLOTS := 3
const PORTRAIT := "res://characters/remi/Remi_default.png"

var _cards: Array[Button] = []
var _pending_slot := 1

@onready var _confirm: ConfirmBox = %Confirm
@onready var _name_panel: Control = %NamePanel
@onready var _name_edit: LineEdit = %NameEdit


func _ready() -> void:
	_cards = [%Slot1, %Slot2, %Slot3]
	var art := UIKit.cropped_texture(PORTRAIT)
	for c in _cards:
		(c.get_node("Pad/Box/Art/Filled/Portrait") as TextureRect).texture = art
	for i in SLOTS:
		var slot := i + 1
		_cards[i].pressed.connect(func() -> void: _on_card_pressed(slot))

	_confirm.answered.connect(_on_delete_answered)
	_confirm.visibility_changed.connect(_sync_hints)
	_name_panel.visibility_changed.connect(_sync_hints)
	_name_edit.text_submitted.connect(func(_t: String) -> void: _start_new())
	UIKit.trap_focus([_name_edit])
	_name_panel.hide()

	%Hints.set_hints([["◀ ▶", tr("UI_CHOOSE_SLOT")], ["Enter", tr("UI_SELECT")],
		["Del", tr("UI_DELETE")], ["Esc", tr("UI_BACK")]])

	_refresh()
	_cards[0].grab_focus()


func _sync_hints() -> void:
	%Hints.visible = not (_confirm.visible or _name_panel.visible)


## Each card is the same tree, so the pieces are reached by path rather
## than by a unique name per slot.
func _refresh() -> void:
	for i in SLOTS:
		var card: Button = _cards[i]
		var info := SaveManager.summary(i + 1)
		var used := not info.is_empty()

		card.get_node("Pad/Box/Art/Filled").visible = used
		card.get_node("Pad/Box/Art/Empty").visible = not used
		(card.get_node("Pad/Box/Name") as Label).text = \
			info.name if used else tr("UI_NEW_GAME")
		(card.get_node("Pad/Box/Line") as Label).text = \
			info.line if used else tr("UI_EMPTY_SLOT_LINE")


func _on_card_pressed(slot: int) -> void:
	if SaveManager.exists(slot):
		GameManager.load_slot(slot)
	else:
		_pending_slot = slot
		_name_edit.text = ""
		_name_panel.show()
		_name_edit.grab_focus()


## Runs before any control sees the event, so Esc closes the panel
## rather than leaving the screen.
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
			_confirm.ask(tr("UI_DELETE_CONFIRM") % SaveManager.summary(slot).name,
				tr("UI_DELETE_BODY"), tr("UI_DELETE"), tr("UI_CANCEL"))


func _focused_slot() -> int:
	var idx := _cards.find(get_viewport().gui_get_focus_owner())
	return idx + 1 if idx >= 0 else 0


func _on_delete_answered(yes: bool) -> void:
	if yes:
		SaveManager.delete(_pending_slot)
		_refresh()
	_cards[_pending_slot - 1].grab_focus()


func _start_new() -> void:
	var n := _name_edit.text.strip_edges()
	if n.is_empty():
		return
	_name_panel.hide()
	GameManager.start_new_game(_pending_slot, n)

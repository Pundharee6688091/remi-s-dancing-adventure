extends Control
## Layout lives in save_slots.tscn. Three cards on the left, a detail panel on
## the right for whichever card is highlighted. Left and right choose a slot,
## Enter steps into the panel, Esc steps back out.

const SLOTS := 3
const PORTRAIT := "res://characters/remi/Remi_default.png"

var _cards: Array[Button] = []
var _pending_slot := 1
## Which question the shared confirm box is currently asking.
var _pending := ""
var _renaming := false

@onready var _confirm: ConfirmBox = %Confirm

const PARTY_FACE := preload("res://scenes/ui/parts/party_face.tscn")
@onready var _name_panel: Control = %NamePanel
@onready var _name_edit: LineEdit = %NameEdit


func _ready() -> void:
	_cards = [%Slot1, %Slot2, %Slot3]
	var art := UIKit.cropped_texture(PORTRAIT)
	for i in SLOTS:
		var slot := i + 1
		var card := _cards[i]
		(card.get_node("Pad/Box/Art/Filled/Portrait") as TextureRect).texture = art
		# Enter picks the slot and steps into the panel rather than loading.
		card.pressed.connect(func() -> void: _enter_panel(slot))
		# Highlighting a card is what drives the panel, by keyboard or mouse.
		card.focus_entered.connect(func() -> void: _select(slot))
		card.mouse_entered.connect(card.grab_focus)

	UIKit.trap_focus(_cards)
	_confirm.answered.connect(_on_confirmed)
	# Focus stays trapped on the slot cards, so this one is for the mouse; the
	# keyboard way out is Esc back to the main menu, which has its own Quit.
	%ExitGame.pressed.connect(_ask_quit)
	_confirm.visibility_changed.connect(_sync_hints)
	_name_panel.visibility_changed.connect(_sync_hints)
	_name_edit.text_submitted.connect(func(_t: String) -> void: _submit_name())
	_name_edit.text_changed.connect(func(_t: String) -> void: _update_counter())
	%Note.text = tr("UI_NAME_NOTE")
	%NameHints.set_hints([["Enter", tr("UI_START")], ["Esc", tr("UI_CANCEL")]])

	_set_hints()
	Events.language_changed.connect(_set_hints)

	_refresh()
	_cards[0].grab_focus()


func _set_hints() -> void:
	%Hints.set_hints([[["←", "→"], tr("UI_CHOOSE_SLOT")], ["Enter", tr("UI_SELECT")],
		["Del", tr("UI_DELETE")], ["Esc", tr("UI_BACK")]])


func _sync_hints() -> void:
	%Hints.visible = not (_confirm.visible or _name_panel.visible)


## Each card is the same tree, so the pieces are reached by path rather than
## by a unique name per slot.
func _refresh() -> void:
	for i in SLOTS:
		var card := _cards[i]
		var info := SaveManager.summary(i + 1)
		var used := not info.is_empty()

		card.get_node("Pad/Box/Art/Filled").visible = used
		card.get_node("Pad/Box/Art/Empty").visible = not used
		(card.get_node("Pad/Box/Name") as Label).text = \
			info.name if used else tr("UI_NEW_GAME")
		(card.get_node("Pad/Box/Line") as Label).text = \
			info.line if used else tr("UI_EMPTY_SLOT_LINE")
		_show_party(card, info.get("party", []) if used else [])
	_select(_pending_slot)


## Who has been recruited into this profile, as the faces the battle uses.
## An empty party leaves the row out rather than leaving a gap behind.
func _show_party(card: Button, party: Array) -> void:
	var row: HBoxContainer = card.get_node("Pad/Box/Party")
	for old in row.get_children():
		row.remove_child(old)
		old.queue_free()
	row.visible = not party.is_empty()
	for who in party:
		var art := UIKit.cropped_texture(Rules.opponent_art(String(who)))
		if art == null:
			continue
		var face := PARTY_FACE.instantiate()
		face.get_node("%Face").texture = art
		face.tooltip_text = String(who)
		row.add_child(face)


func _select(slot: int) -> void:
	_pending_slot = slot
	var info := SaveManager.summary(slot)
	var used := not info.is_empty()

	%PName.text = info.name if used else tr("UI_NEW_GAME")
	%PLine.text = info.line if used else tr("UI_EMPTY_SLOT_LINE")
	%Continue.text = tr("UI_CONTINUE") if used else tr("UI_NEW_GAME")
	%Rename.disabled = not used
	%DeleteProfile.disabled = not used

	# A disabled button cannot hold focus, so keep it out of the cycle.
	var live: Array = [%Continue]
	if used:
		live.append(%Rename)
		live.append(%DeleteProfile)
	UIKit.trap_focus(live)


# ---------- actions ----------

func _enter_panel(slot: int) -> void:
	_pending_slot = slot
	%Continue.grab_focus()


func _panel_has_focus() -> bool:
	return get_viewport().gui_get_focus_owner() in [%Continue, %Rename, %DeleteProfile]


func _open_slot(slot: int) -> void:
	_pending_slot = slot
	if SaveManager.exists(slot):
		GameManager.load_slot(slot)
	else:
		_ask_name(false)


func _ask_name(renaming: bool) -> void:
	_renaming = renaming
	var info := SaveManager.summary(_pending_slot)
	_name_edit.text = info.name if renaming and not info.is_empty() else ""
	%NameTitle.text = tr("UI_RENAME") if renaming else tr("UI_NEW_GAME")
	%Prompt.text = tr("UI_RENAME_PROMPT") if renaming else tr("UI_NAME_PROMPT")
	_update_counter()
	_name_panel.show()
	_name_edit.grab_focus()
	_name_edit.select_all()


func _update_counter() -> void:
	%Counter.text = "%d / %d" % [_name_edit.text.length(), _name_edit.max_length]


func _close_name_panel() -> void:
	_name_panel.hide()
	_cards[_pending_slot - 1].grab_focus()


func _submit_name() -> void:
	var n := _name_edit.text.strip_edges()
	if n.is_empty():
		if _renaming:
			return
		n = tr("UI_DEFAULT_NAME")
	_name_panel.hide()

	if not _renaming:
		GameManager.start_new_game(_pending_slot, n)
		return

	var save := SaveManager.load_slot(_pending_slot)
	if not save.is_empty():
		save.name = n
		SaveManager.write(_pending_slot, save)
	_refresh()
	_cards[_pending_slot - 1].grab_focus()


func _on_continue_pressed() -> void:
	_open_slot(_pending_slot)


func _on_rename_pressed() -> void:
	if SaveManager.exists(_pending_slot):
		_ask_name(true)


func _on_delete_profile_pressed() -> void:
	_ask_delete(_pending_slot)


func _ask_delete(slot: int) -> void:
	if not SaveManager.exists(slot):
		return
	_pending_slot = slot
	_confirm.ask(tr("UI_DELETE_CONFIRM") % SaveManager.summary(slot).name,
		tr("UI_DELETE_BODY"), tr("UI_DELETE"), tr("UI_CANCEL"))


func _ask_quit() -> void:
	_pending = "quit"
	_confirm.ask(tr("UI_QUIT_CONFIRM"), "", tr("UI_QUIT"), tr("UI_CANCEL"))


## One confirm box serves both questions, so it has to know which was asked.
func _on_confirmed(yes: bool) -> void:
	if _pending == "quit":
		_pending = ""
		if yes:
			get_tree().quit()
			return
		_cards[maxi(_pending_slot - 1, 0)].grab_focus()
		return

	if yes:
		SaveManager.delete(_pending_slot)
		_refresh()
	_cards[_pending_slot - 1].grab_focus()


# ---------- input ----------

## Runs before any control sees the event, so Esc closes the name panel
## rather than leaving the screen.
func _input(event: InputEvent) -> void:
	if _name_panel.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_name_panel()


func _unhandled_input(event: InputEvent) -> void:
	if _confirm.is_open() or _name_panel.visible:
		return

	if event.is_action_pressed("ui_cancel"):
		if _panel_has_focus():
			_cards[_pending_slot - 1].grab_focus()
		else:
			SceneRouter.back()
	elif event.is_action_pressed("delete"):
		_ask_delete(_pending_slot)

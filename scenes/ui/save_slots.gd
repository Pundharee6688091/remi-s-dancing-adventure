extends Control

## Layout lives in save_slots.tscn. Three cards on the left, a detail panel on
## the right for whichever card is highlighted. Left and right choose a slot,
## Enter steps into the panel, Esc steps back out.

const SLOTS := 3

var _cards: Array[Button] = []
var _partys: Array[Party] = []
var _pending_slot := 1
## Which question the shared confirm box is currently asking.
var _pending := ""
var _renaming := false

@onready var _confirm: ConfirmBox = %Confirm
@onready var _name_panel: Control = %NamePanel
@onready var _name_edit: LineEdit = %NameEdit


func _ready() -> void:
	_cards = [%Slot1, %Slot2, %Slot3]
	_partys = [%party1, %party2, %party3]
	for i in SLOTS:
		var slot := i + 1
		var card := _cards[i]
		var party := _partys[i]
		party.set_slot(slot)
		# Enter picks the slot and steps into the panel rather than loading.
		card.pressed.connect(func() -> void: _enter_panel(slot))
		# Highlighting a card is what drives the panel, by keyboard or mouse.
		card.focus_entered.connect(func() -> void:
			_select(slot)
			# So coming back down off Quit lands on the card you left from
			# rather than always on the first one.
			_point_quit_at(card))
		# Hovering a card highlights it, but not once the panel has been
		# stepped into: otherwise the first mouse move afterwards drags the
		# panel over to whichever card the cursor happened to cross.
		card.mouse_entered.connect(func() -> void:
			if not _panel_has_focus():
				card.grab_focus())

	# Left and right walk the cards, up steps off them onto Quit and down
	# comes back. Quit was mouse only before, which left no way out of here
	# without one.
	%ExitGame.focus_mode = Control.FOCUS_ALL
	UIKit.trap_focus(_cards, "x")
	for card in _cards:
		card.focus_neighbor_top = card.get_path_to(%ExitGame)
		card.focus_neighbor_bottom = card.get_path_to(%ExitGame)
	_point_quit_at(_cards[0])
	_confirm.answered.connect(_on_confirmed)
	%ExitGame.pressed.connect(_ask_quit)
	_confirm.visibility_changed.connect(_sync_hints)
	_name_panel.visibility_changed.connect(_sync_hints)
	_wire_name_panel()
	_name_edit.text_submitted.connect(func(_t: String) -> void: _submit_name())
	_name_edit.text_changed.connect(func(_t: String) -> void: _update_counter())
	%Note.text = tr("UI_NAME_NOTE")
	%NameHints.set_hints([["Enter", tr("UI_START"), _submit_name],
		["Esc", tr("UI_CANCEL"), _close_name_panel]])

	_set_hints()
	Events.language_changed.connect(_set_hints)

	_refresh()
	_cards[0].grab_focus()


## The name panel is a small form: the field, then Start and Cancel under it.
## Both buttons were set to take no focus at all, so the keyboard had nothing
## to move to and down did nothing. Down from the field steps into them now,
## left and right pick between them, and up comes back to the field.
func _wire_name_panel() -> void:
	var start: Button = %Start
	var cancel: Button = %Cancel
	for b in [start, cancel]:
		b.focus_mode = Control.FOCUS_ALL

	# A LineEdit eats the down key itself, so the neighbour below is never
	# consulted. Taking it here is what actually gets out of the field.
	_name_edit.gui_input.connect(func(e: InputEvent) -> void:
		if e.is_action_pressed("ui_down"):
			_name_edit.accept_event()
			start.grab_focus())

	# Every side of every control points at another part of this panel, so
	# the focus cannot wander off onto the cards behind it. Without the ones
	# that wrap, a second press of down walks straight out of the dialog.
	_name_edit.focus_neighbor_bottom = _name_edit.get_path_to(start)
	_name_edit.focus_neighbor_top = _name_edit.get_path_to(cancel)
	_name_edit.focus_neighbor_left = _name_edit.get_path_to(_name_edit)
	_name_edit.focus_neighbor_right = _name_edit.get_path_to(_name_edit)
	_name_edit.focus_next = _name_edit.get_path_to(start)
	_name_edit.focus_previous = _name_edit.get_path_to(cancel)

	start.focus_neighbor_top = start.get_path_to(_name_edit)
	start.focus_neighbor_bottom = start.get_path_to(_name_edit)
	start.focus_neighbor_left = start.get_path_to(cancel)
	start.focus_neighbor_right = start.get_path_to(cancel)
	start.focus_next = start.get_path_to(cancel)
	start.focus_previous = start.get_path_to(_name_edit)

	cancel.focus_neighbor_top = cancel.get_path_to(_name_edit)
	cancel.focus_neighbor_bottom = cancel.get_path_to(_name_edit)
	cancel.focus_neighbor_left = cancel.get_path_to(start)
	cancel.focus_neighbor_right = cancel.get_path_to(start)
	cancel.focus_next = cancel.get_path_to(_name_edit)
	cancel.focus_previous = cancel.get_path_to(start)


func _set_hints() -> void:
	%Hints.set_hints([[["←", "→"], tr("UI_CHOOSE_SLOT")], ["Enter", tr("UI_SELECT")],
		["Del", tr("UI_DELETE"), func() -> void: _ask_delete(_pending_slot)],
		["Esc", tr("UI_BACK"), SceneRouter.back]])


func _sync_hints() -> void:
	%Hints.visible = not (_confirm.visible or _name_panel.visible)


## Each card is the same tree, so the pieces are reached by path rather than
## by a unique name per slot.
func _refresh() -> void:
	for i in SLOTS:
		var card := _cards[i]
		var info := SaveManager.summary(i + 1)
		var used := not info.is_empty()

		# The picture is the art, and the panel over it is only the frame
		# the wireframe draws around that art. The dashed box takes over on
		# a slot nobody has used yet.
		_partys[i].visible = used
		card.get_node("Pad/Box/Art/Filled").visible = used
		card.get_node("Pad/Box/Art/Empty").visible = not used
		(card.get_node("Pad/Box/Name") as Label).text = \
			info.name if used else tr("UI_NEW_GAME")
		(card.get_node("Pad/Box/Line") as Label).text = \
			info.line if used else tr("UI_EMPTY_SLOT_LINE")
		_partys[i].set_slot(i + 1)
	_select(_pending_slot)


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


## Every way off Quit goes back to one card, because it is the only thing on
## its own row and a loop of one is just a dead end.
func _point_quit_at(card: Control) -> void:
	var to := %ExitGame.get_path_to(card)
	%ExitGame.focus_neighbor_top = to
	%ExitGame.focus_neighbor_bottom = to
	%ExitGame.focus_neighbor_left = to
	%ExitGame.focus_neighbor_right = to
	%ExitGame.focus_next = to
	%ExitGame.focus_previous = to


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

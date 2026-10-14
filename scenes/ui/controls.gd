extends Control
## The controls page, built from Controls.dc.html: one row per action, with a
## keyboard column and a gamepad column, and a line at the top saying whether
## a pad is plugged in.
##
## The rows are built from InputManager.ROWS rather than laid out by hand, so
## adding an action there puts it on this page without touching the scene.

const ROW_H := 50.0
const ACTION_W := 220.0
const GAP := 16.0

## Which row the player is on, and which one is waiting for a press. The
## reset button counts as one row past the last, so the arrow keys walk onto
## it the same way they walk between the rows.
var _row := 0
var _listening := -1

## Set when a press was refused, so the row can say why until the next one.
var _clash := ""

var _rows: Array[PanelContainer] = []


func _stops() -> int:
	return _rows.size() + 1


func _on_reset() -> bool:
	return _row == _rows.size()

## True when SceneRouter owns this page. False when it is a panel opened from
## the settings overlay, which closes itself instead of popping the stack.
var routed := true

signal closed()


func _ready() -> void:
	_build()
	Events.language_changed.connect(_refresh)
	InputManager.rebound.connect(_refresh)
	%Reset.pressed.connect(_reset)
	# Hovering it picks it, the same as hovering a row, so the cursor and the
	# arrow keys never disagree about where you are.
	%Reset.mouse_entered.connect(func() -> void: _pick(_rows.size()))
	_refresh()


func _build() -> void:
	for r in InputManager.ROWS:
		var box := PanelContainer.new()
		box.custom_minimum_size = Vector2(0, ROW_H)
		box.mouse_filter = Control.MOUSE_FILTER_PASS
		box.gui_input.connect(_on_row_input.bind(_rows.size()))

		var grid := HBoxContainer.new()
		grid.add_theme_constant_override("separation", int(GAP))
		grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(grid)

		# action, then the two columns it is bound on
		var what := Label.new()
		what.custom_minimum_size = Vector2(ACTION_W, 0)
		what.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		what.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(what)

		for i in 2:
			var value := Label.new()
			value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			value.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid.add_child(value)

		%Rows.add_child(box)
		_rows.append(box)


func _refresh() -> void:
	_set_hints()
	%PadLine.text = tr("UI_CTRL_PAD_ON") if _pad_here() else tr("UI_CTRL_PAD_OFF")
	%PadDot.color = Color("#4a8a3a") if _pad_here() else Palette.HAIRLINE

	for i in InputManager.ROWS.size():
		var id: String = InputManager.ROWS[i].id
		var grid := _rows[i].get_child(0)
		(grid.get_child(0) as Label).text = tr(String(InputManager.ROWS[i].label))

		var key_label := grid.get_child(1) as Label
		var pad_label := grid.get_child(2) as Label
		if i == _listening:
			# the whole row becomes the prompt while it waits, and says so
			# when a press was turned down rather than silently ignoring it
			key_label.text = tr("UI_CTRL_TAKEN") % tr(_clash) if _clash != "" \
				else tr("UI_CTRL_PRESS")
			pad_label.text = ""
		else:
			key_label.text = InputManager.key_name(id)
			pad_label.text = InputManager.pad_name(id)

		# the row being worked on is the one wearing the highlight
		var on: bool = i == _row
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#fff3dd") if on else Palette.WHITE
		style.set_border_width_all(4 if on else 2)
		style.border_color = Palette.AMBER if on else Palette.INK
		style.content_margin_left = 16
		style.content_margin_right = 16
		_rows[i].add_theme_stylebox_override("panel", style)

	_mark_reset()


## The button is not a row, so it wears the highlight by hand. Godot's own
## focus ring is off because the rows do not have one either, and two kinds of
## "you are here" on one page reads as two cursors.
func _mark_reset() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#fff3dd") if _on_reset() else Palette.WHITE
	style.set_border_width_all(4 if _on_reset() else 2)
	style.border_color = Palette.AMBER if _on_reset() else Palette.INK
	style.set_corner_radius_all(6)
	for slot in ["normal", "hover", "pressed", "focus"]:
		%Reset.add_theme_stylebox_override(slot, style)


func _set_hints() -> void:
	if _listening >= 0:
		%Hints.set_hints([["Esc", tr("UI_CANCEL"), _stop_listening]])
		return
	%Hints.set_hints([[["↑", "↓"], tr("UI_MOVE")],
		["Enter", tr("UI_CTRL_USE") if _on_reset() else tr("UI_CHANGE")],
		["R", tr("UI_RESET"), _reset],
		["Esc", tr("UI_BACK"), _close]])


## A pad counts as here if Godot can see one.
func _pad_here() -> bool:
	return not Input.get_connected_joypads().is_empty()


func _on_row_input(event: InputEvent, which: int) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_row = which
		_listen()


func _pick(which: int) -> void:
	if _row == which or _listening >= 0:
		return
	_row = which
	Audio.play("hover")
	_refresh()


func _listen() -> void:
	if _on_reset():
		_reset()
		return
	_clash = ""
	_listening = _row
	_refresh()


func _stop_listening() -> void:
	_listening = -1
	_clash = ""
	_refresh()


func _reset() -> void:
	_stop_listening()
	InputManager.reset()


func _close() -> void:
	if routed:
		SceneRouter.back()
		return
	closed.emit()
	queue_free()


## The page's own background, so it covers the map or the fight it was opened
## over. A Control paints itself before its children, so this lands behind the
## rows rather than across them.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.BONE)


## While a row is waiting, every press belongs to it: taking the event here
## rather than in _unhandled_input is what stops the press also walking the
## menu or leaving the page.
func _input(event: InputEvent) -> void:
	if _listening < 0:
		return
	if not (event is InputEventKey or event is InputEventJoypadButton):
		return
	if not event.is_pressed() or event.is_echo():
		return
	get_viewport().set_input_as_handled()

	if event is InputEventKey \
			and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		_stop_listening()
		return
	var id := String(InputManager.ROWS[_listening].id)
	var clash := InputManager.taken_by(id, event)
	if clash != "":
		# Kept waiting rather than cancelled, so the answer to "that one is
		# taken" is to press another key, not to start again.
		_clash = clash
		Audio.play("locked")
		_refresh()
		return
	if InputManager.rebind(id, event):
		Audio.play("click")
		_stop_listening()


func _unhandled_input(event: InputEvent) -> void:
	if _listening >= 0:
		return
	if event.is_action_pressed("ui_down"):
		get_viewport().set_input_as_handled()
		_pick(wrapi(_row + 1, 0, _stops()))
	elif event.is_action_pressed("ui_up"):
		get_viewport().set_input_as_handled()
		_pick(wrapi(_row - 1, 0, _stops()))
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_listen()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
	elif event is InputEventKey and event.pressed \
			and (event as InputEventKey).physical_keycode == KEY_R:
		get_viewport().set_input_as_handled()
		_reset()

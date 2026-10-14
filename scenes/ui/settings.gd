extends Control
## Layout lives in settings.tscn, built from Settings.dc.html. One list, no
## tabs. Up and down move between rows, left and right adjust the focused one,
## and every change applies and saves the moment it happens.

const ROWS := ["Music", "Sfx", "Speed", "Offset", "Language", "Fullscreen", "Controls"]
const STEP := 5          # volume rows move in fives

var _row := 0

## True when SceneRouter owns this screen. False when it is an overlay inside
## another screen, which closes itself instead of popping the stack.
var routed := true

signal closed()


func _ready() -> void:
	_wire_mouse()
	_set_hints()
	Events.language_changed.connect(_on_language_changed)
	_refresh()


## Rows are not Buttons, so the mouse is wired by hand: hovering highlights a
## row, dragging a bar sets its value, clicking a pill picks it.
func _wire_mouse() -> void:
	for i in ROWS.size():
		var idx := i
		var row: Control = get_node("%" + ROWS[i])
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.mouse_entered.connect(func() -> void: _hover(idx))

		var bar: Control = row.get_node_or_null("Box/Bar")
		if bar != null:
			bar.mouse_filter = Control.MOUSE_FILTER_STOP
			bar.mouse_entered.connect(func() -> void: _hover(idx))
			bar.gui_input.connect(func(e: InputEvent) -> void: _bar_input(idx, bar, e))

		for pill in [["Box/OptA", -1], ["Box/OptB", 1]]:
			var node: Control = row.get_node_or_null(pill[0])
			if node != null:
				node.mouse_filter = Control.MOUSE_FILTER_STOP
				node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				node.mouse_entered.connect(func() -> void: _hover(idx))
				var dir: int = pill[1]
				node.gui_input.connect(func(e: InputEvent) -> void: _pill_input(idx, dir, e))

		var open: Control = row.get_node_or_null("Box/Open")
		if open != null:
			open.mouse_filter = Control.MOUSE_FILTER_STOP
			open.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			open.mouse_entered.connect(func() -> void: _hover(idx))
			open.gui_input.connect(func(e: InputEvent) -> void: _open_input(idx, e))


## The one place the selected row changes, so the arrow keys and the mouse
## both sound the same.
func _hover(idx: int) -> void:
	if _row != idx:
		_row = idx
		Audio.play("hover")
		_refresh()


static func _is_drag(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	if event is InputEventMouseMotion:
		return (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	return false


func _bar_input(idx: int, bar: Control, event: InputEvent) -> void:
	if not _is_drag(event):
		return
	_hover(idx)
	var t := clampf(event.position.x / maxf(bar.size.x, 1.0), 0.0, 1.0)
	match ROWS[idx]:
		"Music":
			Settings.set_value("music", roundi(t * 100.0 / STEP) * STEP)
		"Sfx":
			Settings.set_value("sfx", roundi(t * 100.0 / STEP) * STEP)
		"Speed":
			Settings.set_value("note_speed", 1 + roundi(t * (Settings.SPEED_STEPS - 1)))
		"Offset":
			var ms := t * Settings.OFFSET_RANGE * 2.0 - Settings.OFFSET_RANGE
			Settings.set_value("offset",
				roundi(ms / Settings.OFFSET_STEP) * Settings.OFFSET_STEP)
	_refresh()


func _pill_input(idx: int, dir: int, event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT
			and event.pressed):
		return
	_hover(idx)
	Audio.play("click")
	_adjust(dir)


func _open_input(idx: int, event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		_hover(idx)
		Audio.play("click")
		_activate()


func _set_hints() -> void:
	%Hints.set_hints([[["↑", "↓"], tr("UI_MOVE")], [["←", "→"], tr("UI_ADJUST")],
		["Enter", tr("UI_OPEN")], ["Esc", tr("UI_BACK"), close]])


## This screen re-texts itself, so it must not be rebuilt by the router, or
## the language row would free the screen the moment you used it.
func blocks_reload() -> bool:
	return true


## The language row changes this screen's own text, so it rebuilds in place
## rather than letting SceneRouter swap the scene under the cursor.
func _on_language_changed() -> void:
	_set_hints()
	_refresh()


func _refresh() -> void:
	for i in ROWS.size():
		var row: PanelContainer = get_node("%" + ROWS[i])
		row.theme_type_variation = &"RowOn" if i == _row else &"Row"
		var hint := row.get_node("Box/Hint") as Label
		if hint != null:
			hint.text = tr("UI_ADJUST_HINT") if i == _row and i < 4 else ""

	_slider("Music", Settings.music, 100, str(Settings.music))
	_slider("Sfx", Settings.sfx, 100, str(Settings.sfx))
	_slider("Speed", Settings.note_speed, Settings.SPEED_STEPS,
		"%d / %d" % [Settings.note_speed, Settings.SPEED_STEPS])
	# The bar runs from -200 to +200, so zero sits in the middle.
	_slider("Offset", Settings.offset + Settings.OFFSET_RANGE,
		Settings.OFFSET_RANGE * 2, tr("UI_MS") % Settings.offset)

	_refresh_preview()
	_choice("Language", Loc.current() == "en")
	_choice("Fullscreen", Settings.fullscreen)


## The caption says what the picture means, since "25 px past the line" is
## only useful if you know which way that pushes your timing.
func _refresh_preview() -> void:
	%Preview.queue_redraw()
	var px := roundi(absf(float(Settings.offset) * Rules.note_speed()))
	if Settings.offset == 0:
		%PreviewCaption.text = tr("UI_OFFSET_ON") % Settings.offset
	elif Settings.offset > 0:
		%PreviewCaption.text = tr("UI_OFFSET_PAST") % [Settings.offset, px]
	else:
		%PreviewCaption.text = tr("UI_OFFSET_SHORT") % [Settings.offset, px]


func _slider(name: String, value: int, out_of: int, label: String) -> void:
	var box := get_node("%" + name).get_node("Box")
	(box.get_node("Bar") as Bar).value = float(value) / float(out_of)
	(box.get_node("Value") as Label).text = label


func _choice(name: String, first: bool) -> void:
	var box := get_node("%" + name).get_node("Box")
	box.get_node("OptA").theme_type_variation = &"ChoiceOn" if first else &"Choice"
	box.get_node("OptB").theme_type_variation = &"Choice" if first else &"ChoiceOn"


func close() -> void:
	if routed:
		SceneRouter.back()
	else:
		hide()
		closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_down"):
		_move(1)
	elif event.is_action_pressed("ui_up"):
		_move(-1)
	elif event.is_action_pressed("ui_right"):
		_adjust(1)
	elif event.is_action_pressed("ui_left"):
		_adjust(-1)
	elif event.is_action_pressed("ui_accept"):
		_activate()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _move(step: int) -> void:
	_hover(wrapi(_row + step, 0, ROWS.size()))


func _adjust(dir: int) -> void:
	match ROWS[_row]:
		"Music":
			Settings.set_value("music", Settings.music + dir * STEP)
		"Sfx":
			Settings.set_value("sfx", Settings.sfx + dir * STEP)
		"Speed":
			Settings.set_value("note_speed", Settings.note_speed + dir)
		"Offset":
			Settings.set_value("offset", Settings.offset + dir * Settings.OFFSET_STEP)
		"Language":
			Loc.apply("en" if dir < 0 else "th")
			return          # _on_language_changed refreshes
		"Fullscreen":
			# ON is the left pill, so left means on, matching Language.
			Settings.set_value("fullscreen", dir < 0)
		_:
			return
	_refresh()


func _activate() -> void:
	if ROWS[_row] == "Controls":
		# The remap screen is not built yet, so say so rather than appear
		# to have done something.
		Audio.play("locked")

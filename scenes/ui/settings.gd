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
	_set_hints()
	Events.language_changed.connect(_on_language_changed)
	_refresh()


func _set_hints() -> void:
	%Hints.set_hints([[["↑", "↓"], tr("UI_MOVE")], [["←", "→"], tr("UI_ADJUST")],
		["Enter", tr("UI_OPEN")], ["Esc", tr("UI_BACK")]])


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

	_choice("Language", Loc.current() == "en")
	_choice("Fullscreen", Settings.fullscreen)


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
	_row = wrapi(_row + step, 0, ROWS.size())
	_refresh()


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
			Settings.set_value("fullscreen", dir > 0)
		_:
			return
	_refresh()


func _activate() -> void:
	if ROWS[_row] == "Controls":
		pass             # the remap screen is not built yet

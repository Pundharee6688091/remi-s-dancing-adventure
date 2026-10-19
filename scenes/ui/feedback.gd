extends Control
## The tester's own answers, on a five point scale, written into one csv that
## every session appends to so the whole set opens in Excel as one table.
##
## The rows are built here rather than in the scene file because they are all
## the same shape: a question, and five pills. One list, up and down to move,
## left and right to answer, exactly like the settings page, so a tester who
## has already changed the volume knows how to work it.
##
## No free text box. The paper sheet asks what was confusing and what they
## would change first, and those answers are worth more written longhand than
## typed on a game screen with four lanes bound to the letter keys.

## key, and what the 1 end and the 5 end mean. Order is the order on screen.
const QUESTIONS := [
	["learn", "UI_FB_LEARN", "UI_FB_HARD", "UI_FB_EASY"],
	["timing", "UI_FB_TIMING", "UI_FB_UNFAIR", "UI_FB_FAIR"],
	["meter", "UI_FB_METER", "UI_FB_UNCLEAR", "UI_FB_CLEAR"],
	["difficulty", "UI_FB_DIFFICULTY", "UI_FB_TOO_EASY", "UI_FB_TOO_HARD"],
	["looks", "UI_FB_LOOKS", "UI_FB_POOR", "UI_FB_GREAT"],
	["again", "UI_FB_AGAIN", "UI_FB_NEVER", "UI_FB_DEFINITELY"],
]

## Asked because it changes how every answer above should be read. A five from
## someone who plays these every day is not the same five.
const EXPERIENCE := ["played_before", "UI_FB_PLAYED_BEFORE"]

const UNANSWERED := 0

var _row := 0
var _answers := {}
var _played_before := -1        # -1 unanswered, 0 no, 1 yes
var _sent := false

var _rows: Array[Control] = []
var _list: VBoxContainer
var _send: Button
var _note: Label


func _ready() -> void:
	for q in QUESTIONS:
		_answers[q[0]] = UNANSWERED
	_build()
	Events.language_changed.connect(_rebuild)
	_refresh()


func _build() -> void:
	var title := Label.new()
	title.text = "UI_FB_TITLE"
	title.position = Vector2(40, 24)
	title.size = Vector2(700, 52)
	title.add_theme_font_size_override("font_size", 40)
	add_child(title)

	var rule := ColorRect.new()
	rule.color = Palette.INK
	rule.position = Vector2(40, 84)
	rule.size = Vector2(1200, 2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rule)

	_note = Label.new()
	_note.text = "UI_FB_INTRO"
	_note.position = Vector2(40, 96)
	_note.size = Vector2(1200, 30)
	_note.add_theme_font_size_override("font_size", 18)
	_note.add_theme_color_override("font_color", Palette.MUTED)
	add_child(_note)

	_list = VBoxContainer.new()
	_list.position = Vector2(40, 142)
	_list.size = Vector2(1200, 420)
	_list.add_theme_constant_override("separation", 10)
	add_child(_list)

	for q in QUESTIONS:
		var r := _scale_row(q)
		_rows.append(r)
		_list.add_child(r)

	var yn := _yes_no_row()
	_rows.append(yn)
	_list.add_child(yn)

	_send = Button.new()
	_send.text = "UI_FB_SEND"
	_send.position = Vector2(40, 592)
	_send.size = Vector2(240, 48)
	_send.focus_mode = Control.FOCUS_NONE
	_send.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_send.pressed.connect(_submit)
	add_child(_send)

	var hints := HintBar.new()
	add_child(hints)
	hints.set_hints([
		[["W", "S"], tr("UI_FB_MOVE")],
		[["A", "D"], tr("UI_FB_ANSWER")],
		["Enter", tr("UI_FB_SEND"), _submit],
		["Esc", tr("UI_BACK"), SceneRouter.back],
	])


## A question and five pills. The pills carry the number as their text, and
## the two ends are labelled, because "3" on its own means nothing.
func _scale_row(q: Array) -> Control:
	var row := PanelContainer.new()
	row.set_meta("kind", "scale")
	row.set_meta("key", q[0])
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var line := HBoxContainer.new()
	line.name = "Line"
	line.add_theme_constant_override("separation", 12)
	row.add_child(line)

	var label := Label.new()
	label.text = q[1]
	label.custom_minimum_size = Vector2(520, 44)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	line.add_child(label)

	var low := Label.new()
	low.text = q[2]
	low.custom_minimum_size = Vector2(150, 44)
	low.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	low.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	low.add_theme_font_size_override("font_size", 16)
	low.add_theme_color_override("font_color", Palette.MUTED)
	line.add_child(low)

	var pills := HBoxContainer.new()
	pills.name = "Pills"
	pills.add_theme_constant_override("separation", 8)
	for v in range(1, 6):
		pills.add_child(_pill(q[0], v, str(v)))
	line.add_child(pills)

	var high := Label.new()
	high.text = q[3]
	high.custom_minimum_size = Vector2(150, 44)
	high.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	high.add_theme_font_size_override("font_size", 16)
	high.add_theme_color_override("font_color", Palette.MUTED)
	line.add_child(high)

	return row


func _yes_no_row() -> Control:
	var row := PanelContainer.new()
	row.set_meta("kind", "yesno")
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var line := HBoxContainer.new()
	line.name = "Line"
	line.add_theme_constant_override("separation", 12)
	row.add_child(line)

	var label := Label.new()
	label.text = EXPERIENCE[1]
	label.custom_minimum_size = Vector2(520, 44)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	line.add_child(label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(150, 1)
	line.add_child(spacer)

	var pills := HBoxContainer.new()
	pills.name = "Pills"
	pills.add_theme_constant_override("separation", 8)
	pills.add_child(_pill("played_before", 0, tr("UI_NO")))
	pills.add_child(_pill("played_before", 1, tr("UI_YES")))
	line.add_child(pills)

	return row


func _pill(key: String, value: int, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(56 if key != "played_before" else 96, 44)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.set_meta("value", value)
	b.pressed.connect(func() -> void: _answer(key, value))
	return b


# ---------- answering ----------

func _answer(key: String, value: int) -> void:
	if _sent:
		return
	if key == "played_before":
		_played_before = value
		_row = _rows.size() - 1
	else:
		_answers[key] = value
		for i in QUESTIONS.size():
			if QUESTIONS[i][0] == key:
				_row = i
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		SceneRouter.back()
		return
	if _sent:
		return
	if event.is_action_pressed("ui_down"):
		_move(1)
	elif event.is_action_pressed("ui_up"):
		_move(-1)
	elif event.is_action_pressed("ui_right"):
		_nudge(1)
	elif event.is_action_pressed("ui_left"):
		_nudge(-1)
	elif event.is_action_pressed("ui_accept"):
		_submit()
	else:
		return
	get_viewport().set_input_as_handled()


## Wraps, so the list loops the way the main menu does.
func _move(by: int) -> void:
	_row = wrapi(_row + by, 0, _rows.size())
	Audio.play("hover")
	_refresh()


## Left and right answer the focused row. An unanswered scale row starts at 3
## rather than at 1, so one press either way is never the whole scale.
func _nudge(by: int) -> void:
	var row := _rows[_row]
	if String(row.get_meta("kind")) == "yesno":
		_played_before = 1 if by > 0 else 0
	else:
		var key := String(row.get_meta("key"))
		var now: int = _answers[key]
		_answers[key] = clampi((3 if now == UNANSWERED else now) + by, 1, 5)
	Audio.play("click")
	_refresh()


# ---------- drawing ----------

func _refresh() -> void:
	for i in _rows.size():
		var row := _rows[i]
		var box := StyleBoxFlat.new()
		box.bg_color = Palette.FILL if i == _row else Palette.WHITE
		box.border_color = Palette.AMBER if i == _row else Palette.HAIRLINE
		box.set_border_width_all(2 if i == _row else 1)
		box.set_corner_radius_all(6)
		box.content_margin_left = 14
		box.content_margin_right = 14
		box.content_margin_top = 4
		box.content_margin_bottom = 4
		row.add_theme_stylebox_override("panel", box)

		var chosen := _played_before if String(row.get_meta("kind")) == "yesno" \
			else int(_answers[String(row.get_meta("key"))])
		for pill in row.get_node("Line/Pills").get_children():
			_paint(pill, int(pill.get_meta("value")) == chosen)

	# Nothing is sent half finished, and the button says which it is.
	var left := _missing()
	_send.disabled = left > 0
	_send.text = tr("UI_FB_SEND") if left == 0 else tr("UI_FB_LEFT") % left


func _paint(pill: Button, picked: bool) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.AMBER if picked else Palette.WHITE
	box.border_color = Palette.INK
	box.set_border_width_all(2)
	box.set_corner_radius_all(5)
	for slot in ["normal", "hover", "pressed", "disabled"]:
		pill.add_theme_stylebox_override(slot, box)
	for slot in ["font_color", "font_hover_color", "font_pressed_color"]:
		pill.add_theme_color_override(slot, Palette.INK)


func _missing() -> int:
	var n := 0
	for q in QUESTIONS:
		if int(_answers[q[0]]) == UNANSWERED:
			n += 1
	if _played_before < 0:
		n += 1
	return n


# ---------- sending ----------

func _submit() -> void:
	if _sent or _missing() > 0:
		return
	var row := {"played_before": _played_before}
	for q in QUESTIONS:
		row[q[0]] = int(_answers[q[0]])
	if not Telemetry.feedback(row):
		_note.text = tr("UI_FB_FAILED")
		_note.add_theme_color_override("font_color", Palette.RED)
		return

	_sent = true
	_list.hide()
	_send.hide()
	_note.text = tr("UI_FB_THANKS")
	_note.add_theme_color_override("font_color", Palette.INK)
	_note.add_theme_font_size_override("font_size", 28)


func _rebuild() -> void:
	# The pill captions and the two end labels are translated, so the whole
	# list is built again rather than walked and patched.
	var keep := _answers.duplicate()
	var before := _played_before
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_rows.clear()
	_build()
	_answers = keep
	_played_before = before
	_refresh()

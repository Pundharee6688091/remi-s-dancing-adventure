class_name HintBar
extends Control
## The strip along the bottom of every screen: [Enter] Open   [Esc] Main menu

const HEIGHT := 56.0

## Caps the player is allowed to rebind, written here as the key they start
## on. Screens still say ["Enter", "Open"], and the bar asks what Enter is
## bound to now before it prints it, so one rebind shows up on every screen
## instead of each of them having to remember.
const LIVE := {
	"Enter": "confirm", "Esc": "back",
	"W": "up", "A": "left", "S": "down", "D": "right",
}

## A cap is a few letters wide, so the long names are cut down to what is
## actually printed on the key. The controls page has room for the full name
## and keeps it.
const SHORT := {"Escape": "Esc", "Delete": "Del", "BackSpace": "Bksp"}

var _row: HBoxContainer
var _hints: Array = []
var _with_language := true
var _cap := StyleBoxFlat.new()
var _cap_hover: StyleBoxFlat
var _cap_down: StyleBoxFlat

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_fit)
	if get_parent() is Control:
		(get_parent() as Control).resized.connect(_fit)
	_fit()

	_cap.bg_color = Palette.WHITE
	_cap.border_color = Palette.INK
	_cap.set_border_width_all(2)
	_cap.border_width_bottom = 4
	_cap.set_corner_radius_all(5)
	_cap.content_margin_left = 8
	_cap.content_margin_right = 8
	_cap.content_margin_top = 1
	_cap.content_margin_bottom = 1
	
	_cap_hover = _cap.duplicate()
	_cap_hover.bg_color = Palette.FILL

	# The cap travels down 2px when held, and the margin makes up the height
	# so the letter does not jump.
	_cap_down = _cap.duplicate()
	_cap_down.bg_color = Palette.FILL
	_cap_down.border_width_bottom = 2
	_cap_down.content_margin_bottom = 3

	_row = HBoxContainer.new()
	_row.position = Vector2(40, 14)
	_row.add_theme_constant_override("separation", 28)
	add_child(_row)

	# A rebind on the controls page has to reach the bar of every screen that
	# is still up behind it, including the ones that refuse to be rebuilt.
	InputManager.rebound.connect(_reprint)


## The bar sits on the bottom edge of whatever it is inside, which is not
## always 1280x720.
##
## Every ordinary screen is a Control of exactly that size, so the old
## hardcoded numbers were right there. The visual novel is not: it puts its bar
## in a CanvasLayer, where the space is the whole window, and Dialogic draws
## its background and text box across that whole window too. On a window that
## was not 16:9 the hardcoded 720 left the bar floating in the middle of the
## text box instead of under it.
func _fit() -> void:
	var room: Vector2 = get_parent().size if get_parent() is Control \
		else get_viewport_rect().size
	position = Vector2(0.0, room.y - HEIGHT)
	size = Vector2(room.x, HEIGHT)


## hints is a list of [key, label] pairs, optionally with a Callable third.
## key is one cap, or an array of caps that share the one description.
## Every bar ends with the language toggle, so it is reachable from any screen.
func set_hints(hints: Array, with_language := true) -> void:
	_hints = hints
	_with_language = with_language
	for c in _row.get_children():
		_row.remove_child(c)
		c.queue_free()

	for pair in hints:
		var cb := Callable()
		if pair.size() > 2 and pair[2] is Callable:
			cb = pair[2]
		_row.add_child(_cell(pair[0], str(pair[1]), cb))

	if with_language:
		_row.add_child(_cell("F2", tr("UI_LANGUAGE"), Loc.toggle))


## Printed again with whatever is bound now. The bar keeps what it was asked
## to show, so this costs the screens nothing.
func _reprint() -> void:
	if not _hints.is_empty():
		set_hints(_hints, _with_language)


func _cell(keys: Variant, label: String, cb: Callable) -> HBoxContainer:
	var cell := HBoxContainer.new()
	cell.add_theme_constant_override("separation", 7)
	var printed: Array[String] = []
	for k in (keys if keys is Array else [keys]):
		var cap := _live(str(k))
		# Binding a lane to an arrow would otherwise print that arrow twice,
		# once for the lane and once for the arrow that is always bound.
		if cap in printed:
			continue
		printed.append(cap)
		cell.add_child(_cap_node(cap, cb))

	var word := Label.new()
	word.text = label
	word.add_theme_font_size_override("font_size", 17)
	word.add_theme_color_override("font_color", Palette.INK)
	word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cell.add_child(word)
	return cell


## The key this cap stands for today.
func _live(cap: String) -> String:
	if not LIVE.has(cap):
		return cap
	var name := InputManager.key_name(LIVE[cap])
	return SHORT.get(name, name)


func _cap_node(text: String, cb: Callable) -> Control:
	if not cb.is_valid():
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", _cap)
		box.add_child(_cap_label(text))
		return box

	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 14)
	for slot in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(slot, Palette.INK)
	b.add_theme_stylebox_override("normal", _cap)
	b.add_theme_stylebox_override("hover", _cap_hover)
	b.add_theme_stylebox_override("pressed", _cap_down)
	b.pressed.connect(cb)
	return b


func _cap_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Palette.INK)
	return l


func _draw() -> void:
	draw_dashed_line(Vector2(0, 0), Vector2(size.x, 0), Palette.HAIRLINE, 2.0, 9.0)

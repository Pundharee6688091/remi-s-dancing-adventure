class_name HintBar
extends Control
## The strip along the bottom of every screen: [Enter] Open   [Esc] Main menu

const HEIGHT := 56.0

var _row: HBoxContainer
var _cap := StyleBoxFlat.new()

func _ready() -> void:
	position = Vector2(0.0, 720.0 - HEIGHT)
	size = Vector2(1280.0, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_cap.bg_color = Palette.WHITE
	_cap.border_color = Palette.INK
	_cap.set_border_width_all(2)
	_cap.border_width_bottom = 4
	_cap.set_corner_radius_all(5)
	_cap.content_margin_left = 8
	_cap.content_margin_right = 8
	_cap.content_margin_top = 1
	_cap.content_margin_bottom = 1

	_row = HBoxContainer.new()
	_row.position = Vector2(40, 14)
	_row.add_theme_constant_override("separation", 28)
	add_child(_row)


## hints is a list of [key, label] pairs, e.g. [["Enter", "Open"]]
func set_hints(hints: Array) -> void:
	for c in _row.get_children():
		c.queue_free()

	for pair in hints:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 7)

		var cap := Label.new()
		cap.text = str(pair[0])
		cap.add_theme_font_size_override("font_size", 14)
		cap.add_theme_color_override("font_color", Palette.INK)

		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", _cap)
		box.add_child(cap)
		cell.add_child(box)

		var word := Label.new()
		word.text = str(pair[1])
		word.add_theme_font_size_override("font_size", 17)
		word.add_theme_color_override("font_color", Palette.INK)
		cell.add_child(word)

		_row.add_child(cell)


func _draw() -> void:
	draw_dashed_line(Vector2(0, 0), Vector2(size.x, 0), Palette.MUTED, 2.0, 9.0)

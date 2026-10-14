extends Control
## The group picture with a tag pointing at each face, drawn in that
## character's own colour.
##
## The colours are the ones Dialogic already gives each character, so the tag
## beside a face matches the name above their dialogue. Nobody has to keep a
## second list of colours in step with the first.

## Where each line ends, as a fraction of the picture's width and height, and
## which side the tag hangs on. The point sits beside the head rather than on
## it, so the mark never lands on a face. Read off the art itself, so moving a
## character in the picture means moving the number here with them.
const TAGS: Array[Dictionary] = [
	{"who": "Theo", "at": Vector2(0.530, 0.310), "side": 1},
	{"who": "Remi", "at": Vector2(0.355, 0.458), "side": -1},
	{"who": "Elion", "at": Vector2(0.820, 0.455), "side": 1},
	{"who": "Cassia", "at": Vector2(0.070, 0.615), "side": -1},
]

const DOT := 6.0        ## the mark left on the face
const LINE := 3.0       ## how heavy the leader line is
const EDGE := 56.0      ## how far from the screen edge a tag sits
const GAP := 14.0       ## between the line and the tag it arrives at

@onready var _party: Party = $party

## The leader lines go on their own canvas above the picture. A control paints
## itself before its children, so drawing them here would bury them under the
## artwork they are supposed to point into.
var _lines: Control
var _boxes := {}


func _ready() -> void:
	_build()
	_set_hints()
	Events.language_changed.connect(_refresh)
	get_viewport().size_changed.connect(_place)
	_refresh()


func _set_hints() -> void:
	%Hints.set_hints([["Esc", tr("UI_BACK"), SceneRouter.back]])


## One tag per character, each in their own colour.
func _build() -> void:
	_lines = Control.new()
	_lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lines)
	_lines.draw.connect(_draw_lines)

	for tag in TAGS:
		var who := String(tag.who)
		var colour := _colour_of(who)

		var frame := StyleBoxFlat.new()
		frame.bg_color = Palette.WHITE
		frame.set_border_width_all(3)
		frame.border_color = colour
		frame.set_corner_radius_all(6)
		frame.content_margin_left = 16
		frame.content_margin_right = 16
		frame.content_margin_top = 6
		frame.content_margin_bottom = 6

		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", frame)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var lines := VBoxContainer.new()
		lines.add_theme_constant_override("separation", 0)
		lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(lines)

		var name_label := Label.new()
		name_label.add_theme_font_size_override("font_size", 24)
		name_label.add_theme_color_override("font_color", Palette.INK)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lines.add_child(name_label)

		# what they do, under the name, in their own colour so the two lines
		# read as one tag rather than two
		var job_label := Label.new()
		job_label.add_theme_font_size_override("font_size", 16)
		job_label.add_theme_color_override("font_color", colour)
		job_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lines.add_child(job_label)

		add_child(box)
		_boxes[who] = box


## Dialogic keeps a colour on every character, which is what paints their name
## above their dialogue. The same colour marks them here. Loaded by path
## rather than through Dialogic's own lookup, which is keyed by a name that
## does not always match the file.
func _colour_of(who: String) -> Color:
	var path := "res://characters/%s/%s.dch" % [who, who.to_lower()]
	if not ResourceLoader.exists(path):
		return Palette.INK
	var character = load(path)
	return character.color if "color" in character else Palette.INK


func _refresh() -> void:
	_set_hints()
	var party: Array = GameManager.save.get("party", [])
	for tag in TAGS:
		var who := String(tag.who)
		# Remi is the one playing, so he is always known. The rest keep their
		# name to themselves until they have joined, the way the chapters do.
		var known: bool = who == "Remi" or party.has(who)
		var lines: VBoxContainer = _boxes[who].get_child(0)
		var name_label: Label = lines.get_child(0)
		var job_label: Label = lines.get_child(1)
		name_label.text = Rules.character_name(who) if known else "???"
		job_label.text = tr("UI_JOB_" + who.to_upper()) if known else ""
		job_label.visible = known
		_boxes[who].modulate = Color.WHITE if known else Color(1, 1, 1, 0.45)
	_place()


## The picture keeps its shape inside its box, so the tags hang off where it
## is actually drawn rather than off the box around it.
func _picture_rect() -> Rect2:
	var box := Rect2(_party.position, _party.size)
	var layer: TextureRect = _party.get_node("%Elion")
	if layer.texture == null:
		return box
	var art := layer.texture.get_size()
	if art.x <= 0.0 or art.y <= 0.0:
		return box
	var shown := minf(box.size.x / art.x, box.size.y / art.y)
	var drawn := art * shown
	return Rect2(box.position + (box.size - drawn) / 2.0, drawn)


func _place() -> void:
	var pic := _picture_rect()
	for tag in TAGS:
		var box: PanelContainer = _boxes[String(tag.who)]
		var at: Vector2 = pic.position + pic.size * (tag.at as Vector2)
		var wide: float = box.get_minimum_size().x
		var tall: float = box.get_minimum_size().y
		var x: float = EDGE if tag.side < 0 else size.x - EDGE - wide
		box.position = Vector2(x, at.y - tall / 2.0)
		box.size = Vector2(wide, tall)
	_lines.queue_redraw()


func _draw_lines() -> void:
	var pic := _picture_rect()
	for tag in TAGS:
		var who := String(tag.who)
		var box: PanelContainer = _boxes[who]
		var at: Vector2 = pic.position + pic.size * (tag.at as Vector2)
		var colour := _colour_of(who)
		colour.a = box.modulate.a
		# straight out from the face to the near edge of the tag
		var to_x: float = box.position.x + box.size.x + GAP if tag.side < 0 \
			else box.position.x - GAP
		_lines.draw_line(at, Vector2(to_x, at.y), colour, LINE)
		# a pale ring under the mark, so a dark character cannot swallow it
		var ring := Palette.WHITE
		ring.a = box.modulate.a
		_lines.draw_circle(at, DOT + 2.0, ring)
		_lines.draw_circle(at, DOT, colour)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		SceneRouter.back()

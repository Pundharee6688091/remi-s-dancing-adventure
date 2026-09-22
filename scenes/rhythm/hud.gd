class_name BattleHUD
extends Control

var song_bar: Bar
var monster_bar: Bar
var monster_pct: Label

var _length_ms := 1.0

var combo_value: Label
var combo_word: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# song progress, top left
	_label("SONG", Vector2(40, 22), 18, Palette.MUTED)
	song_bar = _bar(Vector2(40, 48), Vector2(360, 10), Palette.INK)

	# combo, left of the lanes
	combo_value = _label("", Vector2(40, 330), 46, Palette.INK)
	combo_word = _label("COMBO", Vector2(44, 392), 16, Palette.MUTED)
	combo_word.visible = false

	# monster health, just above the lanes on the right
	_label("MONSTER HP", Vector2(700, 356), 18, Palette.MUTED)
	monster_pct = _label("100%", Vector2(1080, 350), 26, Palette.INK)
	monster_pct.size = Vector2(160, 32)
	monster_pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	monster_bar = _bar(Vector2(700, 386), Vector2(540, 20), Palette.RED)

	Events.hp_changed.connect(_on_hp_changed)
	Events.combo_changed.connect(_on_combo_changed)


func setup(song_length_ms: float) -> void:
	_length_ms = maxf(song_length_ms, 1.0)


func update_progress(now_ms: float) -> void:
	song_bar.value = now_ms / _length_ms


func _on_hp_changed(hp: float) -> void:
	monster_bar.value = hp / 100.0
	monster_pct.text = "%d%%" % Rules.hp_display(hp)

func _on_combo_changed(combo: int) -> void:
	combo_value.text = str(combo) if combo >= 2 else ""
	combo_word.visible = combo >= 2

func _label(text: String, pos: Vector2, size_px := 18, color := Palette.INK) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	add_child(l)
	return l


func _bar(pos: Vector2, s: Vector2, c: Color) -> Bar:
	var b := Bar.new()
	b.position = pos
	b.size = s
	b.fill_color = c
	add_child(b)
	return b

class_name BattleHUD
extends Control

var song_bar: Bar
var monster_bar: Bar
var monster_pct: Label

var _length_ms := 1.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_label("SONG", Vector2(40, 22))
	song_bar = _bar(Vector2(40, 48), Vector2(360, 10), Color(0.6, 0.75, 0.9))

	_label("MONSTER HP", Vector2(760, 22))
	monster_pct = _label("100%", Vector2(1180, 22))
	monster_bar = _bar(Vector2(760, 48), Vector2(480, 20), Color(0.85, 0.42, 0.3))

	Events.hp_changed.connect(_on_hp_changed)


func setup(song_length_ms: float) -> void:
	_length_ms = maxf(song_length_ms, 1.0)


func update_progress(now_ms: float) -> void:
	song_bar.value = now_ms / _length_ms


func _on_hp_changed(hp: float) -> void:
	monster_bar.value = hp / 100.0
	monster_pct.text = "%d%%" % Rules.hp_display(hp)


func _label(text: String, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	add_child(l)
	return l


func _bar(pos: Vector2, s: Vector2, c: Color) -> Bar:
	var b := Bar.new()
	b.position = pos
	b.size = s
	b.fill_color = c
	add_child(b)
	return b

class_name BattleHUD
extends Control
## Layout lives in hud.tscn. This only moves the live values.

var _length_ms := 1.0

@onready var song_bar: Bar = %SongBar
@onready var monster_bar: Bar = %MonsterBar
@onready var monster_pct: Label = %MonsterPct
@onready var combo_value: Label = %ComboValue
@onready var combo_word: Label = %ComboWord


func _ready() -> void:
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

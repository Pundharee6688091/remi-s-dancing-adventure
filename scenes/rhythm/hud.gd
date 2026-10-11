class_name BattleHUD
extends Control
## Layout lives in hud.tscn. This only moves the live values.

const COMBO_COLOUR := Palette.AMBER
## Every tenth hit is worth making more of than the nine before it.
const COMBO_MILESTONE := 10
const COMBO_HOT := Color("#e86a2f")

var _length_ms := 1.0
var _combo_tween: Tween = null
var _ghost_tween: Tween = null

@onready var song_bar: Bar = %SongBar
@onready var monster_bar: Bar = %MonsterBar
@onready var monster_pct: Label = %MonsterPct
@onready var combo_value: Label = %ComboValue
@onready var combo_word: Label = %ComboWord
@onready var monster_label: Label = %MonsterLabel


func _ready() -> void:
	Events.hp_changed.connect(_on_hp_changed)
	Events.combo_changed.connect(_on_combo_changed)


func setup(song_length_ms: float, win_percent: float) -> void:
	_length_ms = maxf(song_length_ms, 1.0)
	# The line the monster's health has to fall below to clear the stage.
	monster_bar.marker = clampf(win_percent / 100.0, 0.0, 1.0)


## A stage with nobody to fight has no health to show, so the whole monster
## side of the hud goes away rather than sitting there reading 100%.
func show_monster(shown: bool) -> void:
	monster_bar.visible = shown
	monster_pct.visible = shown
	monster_label.visible = shown
	for n in [monster_bar, monster_pct, monster_label]:
		n.modulate.a = 1.0


## Shown faintly and breathing, so the tutorial can point at the health bar and
## say what it is for without pretending there is a monster behind it.
func ghost_monster(on: bool) -> void:
	if _ghost_tween != null and _ghost_tween.is_valid():
		_ghost_tween.kill()
	for n in [monster_bar, monster_pct, monster_label]:
		n.visible = on
		n.modulate.a = 0.0
	if not on:
		return
	monster_bar.value = 1.0
	monster_pct.text = "100%"
	_ghost_tween = create_tween().set_loops()
	for n in [monster_bar, monster_pct, monster_label]:
		_ghost_tween.parallel().tween_property(n, "modulate:a", 0.55, 0.7)
	for n in [monster_bar, monster_pct, monster_label]:
		_ghost_tween.parallel().tween_property(n, "modulate:a", 0.18, 0.7).set_delay(0.7)


func update_progress(now_ms: float) -> void:
	song_bar.value = now_ms / _length_ms


func _on_hp_changed(hp: float) -> void:
	monster_bar.value = hp / 100.0
	monster_pct.text = "%d%%" % Rules.hp_display(hp)


func _on_combo_changed(combo: int) -> void:
	var had := combo_value.text
	combo_value.text = str(combo) if combo >= 2 else ""
	combo_word.visible = combo >= 2
	if combo >= 2 and combo_value.text != had:
		_punch_combo(combo)


## The number kicks on every hit and kicks harder on a round number, so a run
## building up reads as something happening rather than a counter ticking.
func _punch_combo(combo: int) -> void:
	combo_value.pivot_offset = combo_value.size / 2.0
	var big := combo % COMBO_MILESTONE == 0
	combo_value.scale = Vector2.ONE * (1.55 if big else 1.25)
	combo_value.add_theme_color_override("font_color", COMBO_HOT if big else COMBO_COLOUR)

	if _combo_tween != null and _combo_tween.is_valid():
		_combo_tween.kill()
	_combo_tween = create_tween()
	_combo_tween.set_parallel(true)
	_combo_tween.tween_property(combo_value, "scale", Vector2.ONE, 0.26 if big else 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if big:
		_combo_tween.tween_property(combo_value, "theme_override_colors/font_color",
			COMBO_COLOUR, 0.4)

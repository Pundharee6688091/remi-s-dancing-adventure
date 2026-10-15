extends Node

var data: Dictionary = {}
var stages: Dictionary = {}
var node_order: Array = []

func _ready() -> void:
	data = _load("res://data/gameRule.json")
	_load_stages()
	
func _load_stages() -> void:
	var raw := _load("res://data/stages.json")
	for n in raw.get("nodes", []):
		stages[n.id] = n
		node_order.append(n.id)
		
## A character is held by their English name everywhere it has to stay put:
## stages.json, the save file's party list, and which sprite to draw. Only
## what the player reads goes through here. A name nobody has written a row
## for comes back unchanged rather than as a raw key.
func character_name(who: String) -> String:
	if who == "":
		return ""
	var key := "UI_NAME_" + who.to_upper()
	var named := tr(key)
	return who if named == key else named


func stage(id: String) -> Dictionary:
	return stages.get(id, {})
	
func song_path(song_id: String) -> String:
	return "res://songs/%s/song.mp3" % song_id
	
func chart_path(song_id: String) -> String:
	return "res://songs/%s/chart.txt" % song_id

## Everyone who can join, in the order they are met. Read off the stages
## rather than listed again here, so a character added there joins this
## without being named twice.
func roster() -> Array[String]:
	var out: Array[String] = []
	for id in node_order:
		var who := String(stage(id).get("opponent", ""))
		if who != "" and not out.has(who):
			out.append(who)
	return out


func enemy_path(song_id: String) -> String:
	return "res://songs/%s/Enemy.png" % song_id


func enemy_art(song_id: String) -> Texture2D:
	if song_id == "":
		return null
	var path := enemy_path(song_id)
	return load(path) if ResourceLoader.exists(path) else null


## Backgrounds are named rather than pathed, so stages.json stays readable and
## the art can be renamed or moved without the data following it around.
func bg_path(bg_id: String) -> String:
	return "res://backgrounds/%s.webp" % bg_id

## The background a node asked for, or the default for whatever kind of node
## it is. "map" is a kind too, since the map screen has no node of its own.
func background(kind: String, stage_id := "") -> Texture2D:
	var named := String(stage(stage_id).get("bg", ""))
	if named == "":
		named = String(data.get("backgrounds", {}).get(kind, ""))
	if named == "":
		return null
	var path := bg_path(named)
	if not ResourceLoader.exists(path):
		push_warning("No background art at " + path)
		return null
	return load(path)

func window(judgement: String) -> float:
	return float(data.windows_ms[judgement])

func residual(judgement: String) -> float:
	return float(data.residual[judgement])

func damage(judgement: String) -> float:
	return 100.0 - residual(judgement)

## The chart's base speed, scaled by the player's note speed setting.
func note_speed() -> float:
	return float(data.note_speed_px_per_ms) * Settings.speed_scale()

## The meter is shown to a tenth, and judged on that same figure rather than
## on the number hiding behind it. Rounded, not floored: floor turned 0.9 into
## 0, which handed out a three star run to anyone who had not quite got there.
const STEP := 0.1


func hp_display(hp: float) -> float:
	return maxf(0.0, snappedf(hp, STEP))


## The one place the meter is worded, so every screen says it the same way.
func hp_text(hp: float) -> String:
	return "%.1f" % hp_display(hp)


func is_win(hp: float) -> bool:
	return hp_display(hp) <= float(data.win_hp_percent)

func stars_for_hp(hp: float) -> int:
	var h := hp_display(hp)
	var t: Dictionary = data.stars_hp_percent
	if h <= float(t["3"]): return 3
	if h <= float(t["2"]): return 2
	if h <= float(t["1"]): return 1
	return 0


func _load(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Cannot open " + path)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Bad JSON in " + path)
		return {}
	return parsed

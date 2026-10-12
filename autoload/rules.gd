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
		
func stage(id: String) -> Dictionary:
	return stages.get(id, {})
	
func song_path(song_id: String) -> String:
	return "res://songs/%s/song.mp3" % song_id
	
func chart_path(song_id: String) -> String:
	return "res://songs/%s/chart.txt" % song_id

func enemy_path(song_id: String) -> String:
	return "res://songs/%s/Enemy.png" % song_id

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

## The picture for a character, reached through the stage they are fought on,
## so a party face is the same art the battle and the result screen use rather
## than a second path that could go stale on its own.
func opponent_art(opponent: String) -> String:
	if opponent == "":
		return ""
	for id in node_order:
		var n := stage(id)
		if String(n.get("opponent", "")) == opponent:
			return enemy_path(String(n.get("song", "")))
	return ""


func window(judgement: String) -> float:
	return float(data.windows_ms[judgement])

func residual(judgement: String) -> float:
	return float(data.residual[judgement])

func damage(judgement: String) -> float:
	return 100.0 - residual(judgement)

## The chart's base speed, scaled by the player's note speed setting.
func note_speed() -> float:
	return float(data.note_speed_px_per_ms) * Settings.speed_scale()

func hp_display(hp: float) -> int:
	return maxi(0, floori(hp))

func is_win(hp: float) -> bool:
	return hp_display(hp) <= int(data.win_hp_percent)

func stars_for_hp(hp: float) -> int:
	var h := hp_display(hp)
	var t: Dictionary = data.stars_hp_percent
	if h <= int(t["3"]): return 3
	if h <= int(t["2"]): return 2
	if h <= int(t["1"]): return 1
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

extends Node

const BATTLE := "res://scenes/rhythm/battle.tscn"
const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const WORLD_MAP := "res://scenes/ui/world_map.tscn"

var slot := 0
var save: Dictionary = {}
var current_stage_id := ""


func _ready() -> void:
	Events.stage_cleared.connect(_on_stage_cleared)
	Events.stage_failed.connect(_on_stage_failed)


func start_new_game(new_slot: int, player_name: String) -> void:
	slot = new_slot
	save = SaveManager.create(slot, player_name)
	SceneRouter.goto(MAIN_MENU)


func load_slot(chosen: int) -> void:
	slot = chosen
	save = SaveManager.load_slot(slot)
	SceneRouter.goto(MAIN_MENU)

# ------------ World Map ---------------
func is_cleared(id: String) -> bool:
	if Rules.stage(id).get("type") == "story":
		return save.get("seen", []).has(id)
	return save.get("stars", {}).has(id)

func is_unlocked(id: String) -> bool:
	for req in Rules.stage(id).get("requires", []):
		if not is_cleared(req):
			return false
	return true
	
func stars_for(id: String) -> int:
	return int(save.get("stars", {}).get(id, 0))
	
func enter_node(id: String) -> void:
	match String(Rules.stage(id).get("type", "")):
		"story":
			_play_story(id)
		"fight":
			start_stage(id)

# ------------ Battle ----------------
func start_stage(stage_id: String) -> void:
	current_stage_id = stage_id
	SceneRouter.goto(BATTLE, {"stage_id": stage_id})


func leave_stage() -> void:
	SceneRouter.back()


func evaluate_win(stage_id: String, hp: float) -> bool:
	var rule: Dictionary = Rules.stage(stage_id).get(
		"win", {"type": "hp_below", "value": 30})
	match String(rule.get("type", "hp_below")):
		"hp_below":
			return Rules.hp_display(hp) <= int(rule.value)
		_:
			return false


func _on_stage_cleared(stage_id: String, stars: int) -> void:
	var best := int(save.stars.get(stage_id, 0))
	save.stars[stage_id] = maxi(best, stars)

	var opponent: String = Rules.stage(stage_id).get("opponent", "")
	if opponent != "" and not save.party.has(opponent):
		save.party.append(opponent)

	SaveManager.write(slot, save)


func _on_stage_failed(_stage_id: String) -> void:
	pass      # nothing changed, so nothing is written


# ------------ Visual Novel -------------
func _play_story(id: String) -> void:
	print("Story ", id, " -> timeline ", Rules.stage(id).get("timeline", ""))
	if not save.seen.has(id):
		save.seen.append(id)
		SaveManager.write(slot, save)
	current_stage_id = id
	Events.progress_changed.emit()

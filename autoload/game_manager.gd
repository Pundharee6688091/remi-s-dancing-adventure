extends Node

const BATTLE := "res://scenes/rhythm/battle.tscn"
const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const WORLD_MAP := "res://scenes/ui/world_map.tscn"
const VN_VIEW := "res://scenes/ui/vn_view.tscn"
const SETTINGS := "res://scenes/ui/settings.tscn"

var slot := 0
var save: Dictionary = {}
var current_stage_id := ""

## Set while a stage's own intro chapter is playing, so the chapter hands over
## to that stage instead of walking back to the map the way a story node does.
var _intro_for := ""


func _ready() -> void:
	Events.stage_cleared.connect(_on_stage_cleared)
	Events.stage_failed.connect(_on_stage_failed)
	Events.story_finished.connect(_on_story_finished)


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
	
func best_hp_for(id: String) -> int:
	return int(save.get("best_hp", {}).get(id, 100))

func stars_for(id: String) -> int:
	return int(save.get("stars", {}).get(id, 0))
	
func enter_node(id: String) -> void:
	match String(Rules.stage(id).get("type", "")):
		"story":
			_play_story(id)
		"fight":
			var intro := String(Rules.stage(id).get("intro", ""))
			if intro != "" and not save.get("seen", []).has(intro_key(id)):
				_play_intro(id, intro)
			else:
				start_stage(id)


## A stage can carry its own opening chapter rather than needing a node of its
## own on the map. It plays once, the first time the stage is entered, and is
## remembered under its own key so it never shadows the stage being cleared.
func intro_key(stage_id: String) -> String:
	return "intro:" + stage_id


func _play_intro(stage_id: String, timeline: String) -> void:
	current_stage_id = stage_id
	_intro_for = stage_id
	SceneRouter.goto(VN_VIEW, {"timeline": timeline})

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


func _on_stage_cleared(stage_id: String, hp: int) -> void:
	var best := mini(int(save.best_hp.get(stage_id, 100)), hp)
	save.best_hp[stage_id] = best
	save.stars[stage_id] = Rules.stars_for_hp(best)

	var opponent: String = Rules.stage(stage_id).get("opponent", "")
	if opponent != "" and not save.party.has(opponent):
		save.party.append(opponent)

	SaveManager.write(slot, save)


func _on_stage_failed(_stage_id: String) -> void:
	pass      # nothing changed, so nothing is written


# ------------ Visual Novel -------------
func _play_story(id: String) -> void:
	current_stage_id = id
	SceneRouter.goto(VN_VIEW, {"timeline": Rules.stage(id).get("timeline", "")})


func _on_story_finished() -> void:
	if _intro_for != "":
		var stage := _intro_for
		_intro_for = ""
		if not save.seen.has(intro_key(stage)):
			save.seen.append(intro_key(stage))
			SaveManager.write(slot, save)
		# Replacing rather than pushing, so leaving the stage goes back to the
		# map rather than back into the chapter that introduced it.
		current_stage_id = stage
		SceneRouter.replace(BATTLE, {"stage_id": stage})
		return

	if not save.seen.has(current_stage_id):
		save.seen.append(current_stage_id)
		SaveManager.write(slot, save)
	SceneRouter.back()
	Events.progress_changed.emit()

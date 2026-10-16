extends Node
## What the player has earned, worked out from the profile rather than tracked
## as it happens, so an achievement added later is still awarded for things
## already done. The list itself lives in data/achievements.json.

signal earned(id: String)

const PATH := "res://data/achievements.json"

## The card that says so. Put over the whole game from here rather than
## dropped into each screen, so it survives a scene change and no screen has
## to remember to carry it.
const TOAST := "res://scenes/ui/parts/achievement_toast.tscn"

var list: Array = []


func _ready() -> void:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		push_error("Cannot open " + PATH)
		return
	var raw: Variant = JSON.parse_string(f.get_as_text())
	if raw is Dictionary:
		list = raw.get("achievements", [])
	# Deferred because the root is still being built while autoloads ready.
	call_deferred("_put_up_the_card")


func _put_up_the_card() -> void:
	get_tree().root.add_child(load(TOAST).instantiate())


func is_earned(id: String) -> bool:
	return GameManager.save.get("achievements", {}).has(id)


## When it was earned, as the ISO day it happened, or "" if it has not been.
func earned_on(id: String) -> String:
	return String(GameManager.save.get("achievements", {}).get(id, ""))


## How close the profile is to earning [param entry], from 0 to 1. Used to show
## something for the ones still out of reach.
func progress(entry: Dictionary) -> float:
	var rule: Dictionary = entry.get("rule", {})
	var want := float(rule.get("value", 1))
	match String(rule.get("type", "")):
		"total_stars":
			return clampf(float(_total_stars()) / maxf(want, 1.0), 0.0, 1.0)
		"best_combo":
			return clampf(float(_best_combo()) / maxf(want, 1.0), 0.0, 1.0)
		"stars_for":
			var got := GameManager.stars_for(String(rule.get("stage", "")))
			return clampf(float(got) / maxf(want, 1.0), 0.0, 1.0)
		"full_combo":
			return 1.0 if not GameManager.save.get("full_combo", []).is_empty() else 0.0
	return 0.0


## Notes what a finished run was worth, then looks over everything again.
func record_run(stage_id: String, counts: Dictionary) -> void:
	# A clean run: nothing missed and nothing merely good.
	if int(counts.get("miss", 1)) == 0 and int(counts.get("good", 1)) == 0:
		if not GameManager.save.has("full_combo"):
			GameManager.save["full_combo"] = []
		if not GameManager.save.full_combo.has(stage_id):
			GameManager.save.full_combo.append(stage_id)
	refresh()


## Awards anything now deserved. Returns what was new, so a caller can say so.
##
## [param announce] is false when a profile is being caught up on everything
## it already deserved, which is not the moment to pop a card for each one.
func refresh(announce := true) -> Array[String]:
	var fresh: Array[String] = []
	if not GameManager.save.has("achievements"):
		GameManager.save["achievements"] = {}
	for entry in list:
		var id := String(entry.get("id", ""))
		if id == "" or is_earned(id):
			continue
		if progress(entry) < 1.0:
			continue
		GameManager.save.achievements[id] = Time.get_date_string_from_system()
		fresh.append(id)
		if announce:
			earned.emit(id)
			Telemetry.event("achievement_earned", {"id": id})
	if not fresh.is_empty():
		SaveManager.write(GameManager.slot, GameManager.save)
	return fresh


func _total_stars() -> int:
	var total := 0
	for id in GameManager.save.get("stars", {}):
		total += int(GameManager.save.stars[id])
	return total


func _best_combo() -> int:
	var best := 0
	for id in GameManager.save.get("best_combo", {}):
		best = maxi(best, int(GameManager.save.best_combo[id]))
	return best

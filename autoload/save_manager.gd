extends Node

const SLOTS := 3
const VERSION := 1
const DEFAULTS := {"stars": {}, "best_hp": {}, "best_combo": {}, "seen": [], "party": []}


func exists(slot: int) -> bool:
	return FileAccess.file_exists(_path(slot))


func create(slot: int, player_name: String) -> Dictionary:
	var today := Time.get_date_string_from_system()
	var save := {
		"version": VERSION,
		"name": player_name,
		"created": today,
		"last_played": today,
		"stars": {},
		"best_hp": {},
		"seen": [],
		"party": [],
	}
	write(slot, save)
	return save


func load_slot(slot: int) -> Dictionary:
	if not exists(slot):
		return {}
	var f := FileAccess.open(_path(slot), FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return _fill_defaults(parsed)

func write(slot: int, save: Dictionary) -> void:
	save.version = VERSION
	save.last_played = Time.get_date_string_from_system()
	var f := FileAccess.open(_path(slot), FileAccess.WRITE)
	if f == null:
		push_error("Cannot write save: " + _path(slot))
		return
	f.store_string(JSON.stringify(save, "  "))


func delete(slot: int) -> void:
	var d := DirAccess.open("user://")
	var file := "slot_%d.json" % slot
	if d != null and d.file_exists(file):
		d.remove(file)


## What a slot card shows. Empty dictionary for an empty slot.
func summary(slot: int) -> Dictionary:
	var s := load_slot(slot)
	if s.is_empty():
		return {}
	return {
		"name": s.get("name", "?"),
		"line": tr("UI_SLOT_LINE") % [
			progress_label(s), _pretty_date(s.get("last_played", ""))],
	}


func _path(slot: int) -> String:
	return "user://slot_%d.json" % slot


func progress_label(save: Dictionary) -> String:
	var stars: Dictionary = save.get("stars", {})
	var last := "1-1"
	for id in Rules.node_order:
		var n := Rules.stage(id)
		if n.get("type") != "fight":
			continue
		last = n.get("label", id)
		if not stars.has(id):
			break
	return tr("UI_STAGE") % last


func _pretty_date(iso: String) -> String:
	var parts := iso.split("-")
	if parts.size() != 3:
		return iso
	return "%d %s" % [int(parts[2]), tr("UI_MON_%d" % int(parts[1]))]


## Adds any field a save file is missing, so an old profile gains best_hp
## without being rewritten, and a new profile read by older code still works.
func _fill_defaults(save: Dictionary) -> Dictionary:
	for key in DEFAULTS:
		if not save.has(key):
			save[key] = DEFAULTS[key].duplicate()
	return save

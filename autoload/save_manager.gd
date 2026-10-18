extends Node

const SLOTS := 3
const VERSION := 1

## A profile under this name has every stage open from the start, it is
## wiped when the game closes.
const CHEAT_NAME := "PISHITJAI"
const DEFAULTS := {"stars": {}, "best_hp": {}, "best_combo": {},
	"achievements": {}, "full_combo": [], "seen": [], "party": []}


func _ready() -> void:
	_wipe_cheats()


func _exit_tree() -> void:
	_wipe_cheats()


## True for the demo profile, by name and nothing else, so no real save can
## be caught by this however it was made.
func is_cheat(save: Dictionary) -> bool:
	return String(save.get("name", "")).strip_edges() == CHEAT_NAME


func _wipe_cheats() -> void:
	for slot in range(1, SLOTS + 1):
		if exists(slot) and is_cheat(load_slot(slot)):
			delete(slot)


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


## A profile, or an empty dictionary when there is not a sound one there.
##
## A file that exists but will not parse is a broken save, not an empty slot.
## It used to come back as {} and be opened anyway: the card read "new game"
## while the profile behind it had no stars, no party and no seen list, and
## the first stage clear reached for one of them and took the game down. It is
## moved aside now and said out loud, so the slot really is empty.
func load_slot(slot: int) -> Dictionary:
	if not exists(slot):
		return {}
	var f := FileAccess.open(_path(slot), FileAccess.READ)
	if f == null:
		push_error("Cannot read save: " + _path(slot))
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Broken save in slot %d, setting it aside" % slot)
		_set_aside(slot)
		return {}
	return _fill_defaults(parsed)


## The broken file is kept rather than thrown away. It is the only copy of
## whatever the player had done, and it is worth more to a bug report than to
## the bin.
func _set_aside(slot: int) -> void:
	var d := DirAccess.open("user://")
	if d == null:
		return
	d.rename("slot_%d.json" % slot,
		"slot_%d.broken_%d.json" % [slot, Time.get_unix_time_from_system()])


## Written beside the real file and moved into place, so a crash or a closed
## lid partway through leaves the last save whole instead of making exactly
## the half-written file above.
func write(slot: int, save: Dictionary) -> void:
	save.version = VERSION
	save.last_played = Time.get_date_string_from_system()

	var temp := _path(slot) + ".tmp"
	var f := FileAccess.open(temp, FileAccess.WRITE)
	if f == null:
		push_error("Cannot write save: " + _path(slot))
		return
	f.store_string(JSON.stringify(save, "  "))
	f.close()

	var d := DirAccess.open("user://")
	if d == null:
		push_error("Cannot reach user:// to finish the save")
		return
	var final := "slot_%d.json" % slot
	if d.file_exists(final):
		d.remove(final)
	if d.rename(final + ".tmp", final) != OK:
		push_error("Cannot finish save for slot %d" % slot)


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
		last = tr(String(n.get("label", id)))
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
		# Type as well as presence. A hand edited save with "stars": 5 used to
		# sail through here and fail much later, somewhere that looked
		# nothing like the cause.
		if not save.has(key) or typeof(save[key]) != typeof(DEFAULTS[key]):
			save[key] = DEFAULTS[key].duplicate()
	return save

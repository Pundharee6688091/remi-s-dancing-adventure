extends Node

const SLOTS := 3
const VERSION := 1

## A profile under this name has every stage open from the start, it is
## wiped when the game closes and start.
const CHEAT_NAME := "PISHITJAI"
const DEFAULTS := {"stars": {}, "best_hp": {}, "best_combo": {},
	"achievements": {}, "full_combo": [], "seen": [], "party": []}

## False when the folder saves live in cannot be written to, which is a real
## possibility on a lab or school machine. Everything here fails quietly by
## design, so without this nobody would find out until their progress was
## gone: the game would say it had saved and the file would never appear.
var can_write := true

signal cannot_write()


func _ready() -> void:
	can_write = _probe_write()
	if not can_write:
		push_error("user:// is not writable: progress and logs cannot be saved")
		cannot_write.emit()
	_wipe_cheats()


## Writes a token file and takes it away again. Asking the folder rather than
## assuming, because the answer differs per machine and we only get one go at
## Tuesday.
func _probe_write() -> bool:
	var path := "user://.writable"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string("ok")
	f.close()
	if not FileAccess.file_exists(path):
		return false
	var d := DirAccess.open("user://")
	if d != null:
		d.remove(".writable")
	return true


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


## A profile, or an empty dictionary if there is not a sound one there.
##
## A file that exists but will not parse is a broken save, not an empty slot,
## and it used to come back as {} and be loaded anyway: the slot card read
## "new game" while the profile behind it had no stars, no party and no seen
## list, and the first stage clear reached for one of them and died. It is
## moved aside now and reported, so the slot really is empty and the evidence
## is still on disk.
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


## The broken file is kept rather than deleted. It is the only copy of
## whatever the player had done, and a bug report is worth more with it.
func _set_aside(slot: int) -> void:
	var d := DirAccess.open("user://")
	if d == null:
		return
	d.rename("slot_%d.json" % slot,
		"slot_%d.broken_%d.json" % [slot, Time.get_unix_time_from_system()])


## Written beside the real file and moved into place, so a crash or a closed
## lid partway through leaves the old save whole rather than half a file that
## will not parse. Returns false when nothing reached the disk, which the
## callers use to stop telling the player their progress is safe.
func write(slot: int, save: Dictionary) -> bool:
	save.version = VERSION
	save.last_played = Time.get_date_string_from_system()

	var temp := _path(slot) + ".tmp"
	var f := FileAccess.open(temp, FileAccess.WRITE)
	if f == null:
		push_error("Cannot write save: " + _path(slot))
		can_write = false
		cannot_write.emit()
		return false
	f.store_string(JSON.stringify(save, "  "))
	f.close()

	var d := DirAccess.open("user://")
	if d == null:
		push_error("Cannot reach user:// to finish the save")
		return false
	if d.file_exists("slot_%d.json" % slot):
		d.remove("slot_%d.json" % slot)
	var moved := d.rename("slot_%d.json.tmp" % slot, "slot_%d.json" % slot)
	if moved != OK:
		push_error("Cannot finish save for slot %d" % slot)
		Telemetry.event("save_write", {"slot": slot, "ok": false})
		return false
	# The name is counted, not recorded: these are other people's sessions and
	# their own names are none of the log's business.
	Telemetry.event("save_write", {"slot": slot, "ok": true,
		"name_len": String(save.get("name", "")).length()})
	return true


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
		if not save.has(key):
			save[key] = DEFAULTS[key].duplicate()
	return save

class_name Judge
extends RefCounted

var hp := 100.0
var combo := 0
var max_combo := 0
var counts := {"perfect": 0, "great": 0, "good": 0, "miss": 0}

var _field: NoteField = null
var _total := 0

## How far the miss sweep has walked. The chart is sorted by time, so
## everything before this has had its moment and nothing after it has.
var _swept := 0

func setup(field: NoteField) -> void:
	_field = field
	_total = maxi(field.notes.size(), 1)
	_swept = 0
	hp = 100.0
	combo = 0
	max_combo = 0
	counts = {"perfect": 0, "great": 0, "good": 0, "miss": 0}


## A key was pressed. Returns the judgement, or "" if no note was near.
func press(lane: int, now: float) -> String:
	var best = null
	var best_d := INF

	for n in _field.notes:
		if n.judged or n.lane != lane:
			continue
		var d: float = absf(n.t_ms - now)
		if d > Rules.window("good"):
			continue
		if d < best_d:
			best_d = d
			best = n

	if best == null:
		return ""

	var judgement := _judgement_for(best_d)
	# Signed, not the absolute distance used to pick the note: early and late
	# are different mistakes, and a machine running its audio late shows up as
	# every lane leaning the same way.
	Telemetry.note_hit(lane, now - best.t_ms, judgement)
	_apply(best, judgement)
	return judgement


## Notes that slid past their window without being hit.
##
## Walks on from where it stopped rather than over the whole chart. The notes
## are in time order, so the first one still inside its window is proof that
## every note after it is too, and a note already behind the cursor cannot
## come back. Scanning the lot every frame meant re-reading notes judged
## minutes ago.
func sweep(now: float) -> void:
	var window := Rules.window("good")
	while _swept < _field.notes.size():
		var n: Dictionary = _field.notes[_swept]
		if now - n.t_ms <= window:
			return
		if not n.judged:
			_apply(n, "miss")
		_swept += 1


## The song ended. Anything still unjudged is a miss.
func sweep_all() -> void:
	for n in _field.notes:
		if not n.judged:
			_apply(n, "miss")


func result() -> Dictionary:
	return {
		"hp": Rules.hp_display(hp),
		"stars": Rules.stars_for_hp(hp),
		"won": Rules.is_win(hp),
		"counts": counts.duplicate(),
		"max_combo": max_combo,
	}


func _judgement_for(d: float) -> String:
	if d <= Rules.window("perfect"):
		return "perfect"
	if d <= Rules.window("great"):
		return "great"
	return "good"


func _apply(n: Dictionary, judgement: String) -> void:
	n.judged = true
	counts[judgement] += 1
	hp = maxf(0.0, hp - Rules.damage(judgement) / float(_total))

	if n.node != null:
		if judgement == "miss":
			n.node.modulate.a = 0.3      # fades but keeps sliding out
		else:
			_field.recycle(n)            # a hit note vanishes at once

	if judgement == "perfect" or judgement == "great":
		combo += 1
		max_combo = maxi(max_combo, combo)
	else:
		combo = 0                     # Good and Miss break the combo

	Events.note_judged.emit(judgement, n.lane)
	Events.combo_changed.emit(combo)
	Events.hp_changed.emit(hp)

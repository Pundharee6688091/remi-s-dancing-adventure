extends Node
## What every test file in here is built on.
##
## Each check prints one line keyed to the case number in the test plan, so
## the output can be read straight against the document rather than against
## the code. A run ends with a count and a non-zero exit when anything failed,
## so this can be wired to anything that cares.

## A suite that throws partway through never reaches finish(), and a headless
## Godot with nothing left to do simply sits there. This gives every run a
## deadline so a broken test fails the run instead of hanging it.
const DEADLINE := 90.0

var _passed := 0
var _failed: Array[String] = []


func _enter_tree() -> void:
	var clock := Timer.new()
	clock.wait_time = DEADLINE
	clock.one_shot = true
	clock.timeout.connect(func() -> void:
		print("  FAIL deadline  the suite did not finish within %d seconds"
			% int(DEADLINE))
		print("FAILS: 1 of %d" % (_passed + 1))
		get_tree().quit(1))
	add_child(clock)
	clock.start()


## One case from the plan. [param id] is its number there.
func check(id: String, held: bool, what: String) -> void:
	if held:
		_passed += 1
		print("  ok   %s  %s" % [id, what])
	else:
		_failed.append("%s  %s" % [id, what])
		print("  FAIL %s  %s" % [id, what])


## Same, for a value that should equal another, since "expected 3, got 2" is
## worth more than "failed".
func equals(id: String, got: Variant, want: Variant, what: String) -> void:
	check(id, got == want, "%s (wanted %s, got %s)" % [what, want, got])


func about(id: String, got: float, want: float, what: String,
		tolerance := 0.05) -> void:
	check(id, absf(got - want) <= tolerance,
		"%s (wanted %s, got %s)" % [what, want, got])


func finish() -> void:
	print("FAILS: %d of %d" % [_failed.size(), _passed + _failed.size()])
	for f in _failed:
		print("   - " + f)
	get_tree().quit(1 if _failed.size() > 0 else 0)


# ---------- building a stage without playing one ----------

## A note field and a judge holding the notes given, so timing can be driven
## exactly rather than waited for. [param notes] is a list of [lane, t_ms].
func make_field(notes: Array) -> NoteField:
	var field := NoteField.new()
	add_child(field)
	var chart: Array = []
	for n in notes:
		chart.append({"lane": int(n[0]), "t_ms": float(n[1]), "beat": 0.0})
	field.setup(chart)
	return field


## One note per lane, far enough apart that nothing overlaps.
func spaced(count: int, gap := 1000.0, lane := 0) -> Array:
	var out: Array = []
	for i in count:
		out.append([lane, 1000.0 + i * gap])
	return out


## Wipes every profile. Called at the start of anything that touches saves.
func clear_saves() -> void:
	var d := DirAccess.open("user://")
	if d == null:
		return
	for name in d.get_files():
		if name.begins_with("slot_"):
			d.remove(name)

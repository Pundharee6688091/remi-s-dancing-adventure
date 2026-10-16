class_name NoteField
extends Control

const POOL_SIZE := 32

var speed := 0.6
var notes: Array = []

var _next_spawn := 0
var _pool: Array[Note] = []

## The notes that are actually on screen. Kept separately because the movement
## loop used to walk the whole chart every frame to find them, which on a long
## chart is thousands of entries to skip for the handful that are visible.
var _live: Array = []

func setup(chart_notes: Array) -> void:
	_refresh_speed()
	# Changing note speed mid-song should be visible straight away, and the
	# positions are recomputed every frame, so refreshing the value is enough.
	if not Settings.changed.is_connected(_refresh_speed):
		Settings.changed.connect(_refresh_speed)
	notes.clear()
	for n in chart_notes:
		notes.append({
			"t_ms": n.t_ms,
			"lane": n.lane,
			"judged": false,
			"node": null,
		})
	_next_spawn = 0

	if _pool.is_empty():
		for i in POOL_SIZE:
			_pool.append(_new_note())


func _refresh_speed() -> void:
	speed = Rules.note_speed()


func approach_ms() -> float:
	return (TrackPanel.HIT_X - TrackPanel.LEFT) / speed


func update(now: float) -> void:
	var lead := approach_ms()

	while _next_spawn < notes.size() and notes[_next_spawn].t_ms - now <= lead:
		_spawn(notes[_next_spawn])
		_next_spawn += 1

	# Backwards, so a note taken out of the list on its way past does not
	# shuffle the one behind it out of this pass.
	for i in range(_live.size() - 1, -1, -1):
		var n: Dictionary = _live[i]
		if n.node == null:
			_live.remove_at(i)
			continue
		n.node.position.x = TrackPanel.HIT_X \
			- (n.t_ms - now) * speed \
			- NoteArt.SIZE / 2.0
		if n.node.position.x > TrackPanel.RIGHT + 60.0:
			recycle(n)
			_live.remove_at(i)


## Counted rather than taken from the list's length: a note hit this frame is
## recycled straight away but only leaves the list on the next pass, and the
## log should not say it is still on screen.
func alive_count() -> int:
	var c := 0
	for n in _live:
		if n.node != null:
			c += 1
	return c


func _spawn(n: Dictionary) -> void:
	var node: Note = _pool.pop_back() if _pool.size() > 0 else _new_note()
	node.direction = n.lane
	node.position.y = TrackPanel.row_y(n.lane) \
		+ (TrackPanel.ROW_H - NoteArt.SIZE) / 2.0
	node.modulate.a = 1.0
	node.show()
	n.node = node
	_live.append(n)


func _new_note() -> Note:
	var node := Note.new()
	node.size = Vector2(NoteArt.SIZE, NoteArt.SIZE)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.hide()
	add_child(node)
	return node


## Leaves the note in the live list for the movement loop to drop on its next
## pass. Judge calls this on a hit, from outside that loop, and taking it out
## here would mean searching the list for it.
func recycle(n: Dictionary) -> void:
	if n.node == null:
		return
	n.node.hide()
	_pool.append(n.node)
	n.node = null


func reset() -> void:
	for n in notes:
		if n.node != null:
			recycle(n)
		n.judged = false
	_live.clear()
	_next_spawn = 0

class_name NoteField
extends Control

const POOL_SIZE := 32

var speed := 0.6
var notes: Array = []

var _next_spawn := 0
var _pool: Array[Note] = []

func setup(chart_notes: Array) -> void:
	speed = Rules.note_speed()
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


func approach_ms() -> float:
	return (TrackPanel.HIT_X - TrackPanel.LEFT) / speed


func update(now: float) -> void:
	var lead := approach_ms()

	while _next_spawn < notes.size() and notes[_next_spawn].t_ms - now <= lead:
		_spawn(notes[_next_spawn])
		_next_spawn += 1

	for n in notes:
		if n.node == null:
			continue
		n.node.position.x = TrackPanel.HIT_X \
			- (n.t_ms - now) * speed \
			- NoteArt.SIZE / 2.0
		if n.node.position.x > TrackPanel.RIGHT + 60.0:
			recycle(n)


func alive_count() -> int:
	var c := 0
	for n in notes:
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


func _new_note() -> Note:
	var node := Note.new()
	node.size = Vector2(NoteArt.SIZE, NoteArt.SIZE)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.hide()
	add_child(node)
	return node


func recycle(n: Dictionary) -> void:
	n.node.hide()
	_pool.append(n.node)
	n.node = null


func reset() -> void:
	for n in notes:
		if n.node != null:
			recycle(n)
		n.judged = false
	_next_spawn = 0

class_name GhostArrow
extends Control

@export_range(0, 3) var direction := 0 : set = _set_direction

var _pressed := false

func _set_direction(v: int) -> void:
	direction = v
	queue_redraw()

func set_pressed(on: bool) -> void:
	if _pressed == on:
		return
	_pressed = on
	queue_redraw()

func _draw() -> void:
	var centre := size / 2.0
	var pts := PackedVector2Array()
	for p in NoteArt.arrow_points(direction, NoteArt.SIZE):
		pts.append(p + centre)

	if _pressed:
		draw_colored_polygon(pts, Color(1, 1, 1, 0.9))
	else:
		var loop := pts.duplicate()
		loop.append(pts[0])
		draw_polyline(loop, Color(1, 1, 1, 0.3), 2.0)

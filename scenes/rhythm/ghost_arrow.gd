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
	var pts := NoteArt.at(direction, size / 2.0, NoteArt.SIZE + 2.0)
	draw_colored_polygon(pts, Color(Palette.RED, 0.45 if _pressed else 0.12))

	var loop := NoteArt.closed(pts)
	if _pressed:
		draw_polyline(loop, Palette.RED, 3.0, true)
	else:
		for i in pts.size():
			draw_dashed_line(loop[i], loop[i + 1], Palette.RED, 2.5, 5.0)

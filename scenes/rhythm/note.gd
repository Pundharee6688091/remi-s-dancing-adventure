class_name Note
extends Control

var direction := 0 : set = _set_direction

func _set_direction(v: int) -> void:
	direction = v
	queue_redraw()

func _draw() -> void:
	var centre := size / 2.0
	var pts := PackedVector2Array()
	for p in NoteArt.arrow_points(direction, NoteArt.SIZE):
		pts.append(p + centre)
	draw_colored_polygon(pts, Color.WHITE)

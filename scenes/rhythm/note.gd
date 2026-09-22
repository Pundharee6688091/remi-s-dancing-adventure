class_name Note
extends Control

var direction := 0 : set = _set_direction

func _set_direction(v: int) -> void:
	direction = v
	queue_redraw()

func _draw() -> void:
	var pts := NoteArt.at(direction, size / 2.0)
	draw_colored_polygon(pts, Palette.WHITE)
	draw_colored_polygon(pts, Palette.lane_color(direction))

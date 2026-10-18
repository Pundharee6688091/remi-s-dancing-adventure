class_name Bar
extends Control

@export var value := 1.0 : set = _set_value
@export var fill_color := Color(0.85, 0.42, 0.3)
## A vertical line across the bar, 0..1. Negative hides it. Used for the
## win line on the result screen.
@export var marker := -1.0 : set = _set_marker
@export var marker_color := Palette.RED

func _set_value(v: float) -> void:
	value = clampf(v, 0.0, 1.0)
	queue_redraw()

func _set_marker(v: float) -> void:
	marker = v
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.WHITE)
	draw_rect(Rect2(0.0, 0.0, size.x * value, size.y), fill_color)
	draw_rect(Rect2(Vector2.ZERO, size), Palette.INK, false, 2.0)
	if marker >= 0.0:
		var mx := size.x * clampf(marker, 0.0, 1.0)
		draw_rect(Rect2(mx - 1.5, -6.0, 3.0, size.y + 12.0), marker_color)

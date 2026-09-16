class_name Bar
extends Control

@export var value := 1.0 : set = _set_value
@export var fill_color := Color(0.85, 0.42, 0.3)

func _set_value(v: float) -> void:
	value = clampf(v, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.12), true)
	draw_rect(Rect2(0.0, 0.0, size.x * value, size.y), fill_color, true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.3), false, 1.0)

class_name DashedBox
extends MarginContainer
## A box that hugs whatever is inside it and draws a dashed outline.

@export var line_color := Palette.MUTED
@export var thickness := 2.0
@export var dash := 8.0


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var c := [r.position, Vector2(r.end.x, r.position.y),
		r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		draw_dashed_line(c[i], c[(i + 1) % 4], line_color, thickness, dash)

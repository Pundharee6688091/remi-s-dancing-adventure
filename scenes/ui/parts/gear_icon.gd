extends Control
## A settings cog, drawn rather than imported so it follows the ink palette
## like the lock and the speech bubble on the map do. It lives inside the
## button rather than on it, because a child is painted after its parent's
## background whereas the button's own _draw would go underneath.

const TEETH := 8
const TOOTH := 5.0


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) * 0.26
	for i in TEETH:
		var a := TAU * float(i) / float(TEETH)
		var d := Vector2(cos(a), sin(a))
		draw_line(c + d * (r - 1.0), c + d * (r + TOOTH), Palette.INK, 3.0)
	draw_arc(c, r, 0.0, TAU, 32, Palette.INK, 3.0)
	draw_arc(c, r * 0.40, 0.0, TAU, 16, Palette.INK, 2.5)

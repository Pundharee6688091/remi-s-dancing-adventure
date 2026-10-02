class_name OffsetPreview
extends Control
## Shows where the arrow actually is at the instant the beat plays, for the
## audio offset row. A positive offset puts the arrow past the line, which is
## another way of saying you have to press early.

const PAD := 30.0


func _draw() -> void:
	var mid := size.y / 2.0
	var line_x := size.x / 2.0
	var dx: float = float(Settings.offset) * Rules.note_speed()
	var arrow_x := clampf(line_x + dx, PAD, size.x - PAD)

	# the lane
	draw_rect(Rect2(Vector2.ZERO, size), Palette.FILL)
	draw_line(Vector2(0, 0), Vector2(size.x, 0), Palette.INK, 2.0)
	draw_line(Vector2(0, size.y), Vector2(size.x, size.y), Palette.INK, 2.0)

	# where the arrow should be: the ghost sits on the line
	draw_polyline(NoteArt.closed(NoteArt.at(2, Vector2(line_x, mid))),
		Palette.ghost_color(2), 2.0)
	draw_line(Vector2(line_x, 4.0), Vector2(line_x, size.y - 4.0), Palette.RED, 3.0)

	# how far off it actually is
	if absf(dx) > 1.0:
		draw_dashed_line(Vector2(line_x, mid), Vector2(arrow_x, mid),
			Palette.MUTED, 2.0, 6.0)

	var live := NoteArt.at(2, Vector2(arrow_x, mid))
	draw_polygon(live, PackedColorArray([Palette.lane_color(2)]))
	draw_polyline(NoteArt.closed(live), Palette.INK, 2.0)

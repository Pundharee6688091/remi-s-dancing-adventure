class_name TrackPanel
extends Control

const ROW_H := 62.0
const LEFT := 0.0
const RIGHT := 1280.0
const HIT_X := 1120.0
const LANE_COUNT := 4
const SCREEN_W := 1280.0

var ghosts: Array[GhostArrow] = []

func _ready() -> void:
	for lane in LANE_COUNT:
		var g := GhostArrow.new()
		g.direction = lane
		g.size = Vector2(NoteArt.SIZE, NoteArt.SIZE)
		g.position = Vector2(
			HIT_X - NoteArt.SIZE / 2.0,
			row_y(lane) + (ROW_H - NoteArt.SIZE) / 2.0)
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(g)
		move_child(g, 0)        # behind the notes, so a note slides over its ghost
		ghosts.append(g)

static func row_y(lane: int) -> float:
	return lane * ROW_H

func _draw() -> void:
	var h := ROW_H * LANE_COUNT

	# the dark band, edge to edge
	draw_rect(Rect2(0, 0, SCREEN_W, h), Color(Palette.INK, 0.85))

	# four rows, alternating white, each with a faint guide through the middle
	for lane in LANE_COUNT:
		var y := row_y(lane)
		var shade := 0.92 if lane % 2 == 0 else 0.8
		draw_rect(Rect2(LEFT, y, RIGHT - LEFT, ROW_H), Color(Palette.WHITE, shade))
		draw_line(Vector2(LEFT, y), Vector2(RIGHT, y), Palette.INK, 2.0)
		draw_line(Vector2(LEFT, y + ROW_H / 2.0), Vector2(RIGHT, y + ROW_H / 2.0),
			Color(Palette.INK, 0.3), 2.0)
	draw_line(Vector2(LEFT, h), Vector2(RIGHT, h), Palette.INK, 2.0)

	# the hit line, a little taller than the band
	draw_line(Vector2(HIT_X, -10), Vector2(HIT_X, h + 10), Color(Palette.RED, 0.5), 2.0)

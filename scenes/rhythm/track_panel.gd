class_name TrackPanel
extends Control

const ROW_H := 62.0
const LEFT := 0.0
const RIGHT := 12800.0
const HIT_X := 1120.0
const LANE_COUNT := 4

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
		ghosts.append(g)

static func row_y(lane: int) -> float:
	return lane * ROW_H

func _draw() -> void:
	var h := ROW_H * LANE_COUNT
	draw_rect(Rect2(LEFT, 0, RIGHT - LEFT, h), Color(0, 0, 0, 0.25), true)
	for i in range(LANE_COUNT + 1):
		var y := i * ROW_H
		draw_line(Vector2(LEFT, y), Vector2(RIGHT, y), Color(1, 1, 1, 0.12), 1.0)
	draw_line(Vector2(HIT_X, 0), Vector2(HIT_X, h), Color(1, 1, 1, 0.45), 2.0)

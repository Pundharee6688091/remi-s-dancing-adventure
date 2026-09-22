class_name MapView
extends Control

const STORY_R := 16.0
const FIGHT := Vector2(72, 56)

const COL_LOCKED := Palette.FILL
const COL_OPEN := Palette.WHITE
const COL_CLEARED := Palette.AMBER

var cursor := 0
var _shake := 0.0


func shake() -> void:
	_shake = 1.0


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 3.0)
		queue_redraw()


func _draw() -> void:
	var order: Array = Rules.node_order

	for id in order:
		var lit := GameManager.is_unlocked(id)
		for req in Rules.stage(id).get("requires", []):
			draw_line(_pos(req), _pos(id),
				Color(Palette.INK, 0.6 if lit else 0.2))

	var font := get_theme_default_font()
	for i in order.size():
		_draw_node(order[i], i == cursor, font)


func _draw_node(id: String, focused: bool, font: Font) -> void:
	var n := Rules.stage(id)
	var p := _pos(id)
	if focused and _shake > 0.0:
		p.x += sin(Time.get_ticks_msec() * 0.06) * _shake * 10.0

	var fill := COL_LOCKED
	if GameManager.is_cleared(id):
		fill = COL_CLEARED
	elif GameManager.is_unlocked(id):
		fill = COL_OPEN

	if n.get("type") == "story":
		draw_circle(p, STORY_R, fill)
		draw_arc(p, STORY_R, 0.0, TAU, 40, Palette.INK, 2.0)
		if focused:
			draw_arc(p, STORY_R + 7.0, 0.0, TAU, 40, Palette.AMBER, 2.0)
		return

	var r := Rect2(p - FIGHT / 2.0, FIGHT)
	draw_rect(r, fill, true)
	draw_rect(r, Palette.INK, false, 2.0)
	if focused:
		draw_rect(r.grow(6.0), Palette.AMBER, false, 2.0)

	draw_string(font, Vector2(p.x - 40.0, p.y + 6.0), n.get("label", ""),
		HORIZONTAL_ALIGNMENT_CENTER, 80.0, 16, Palette.INK)

	var s := GameManager.stars_for(id)
	if s > 0:
		draw_string(font, Vector2(p.x - 40.0, p.y + 50.0), "★".repeat(s),
			HORIZONTAL_ALIGNMENT_CENTER, 80.0, 14, Palette.INK)


func _pos(id: String) -> Vector2:
	var a: Array = Rules.stage(id).get("pos", [0, 0])
	return Vector2(float(a[0]), float(a[1]))

class_name TipCard
extends Control
## A line of help that parks itself next to whatever it is talking about and
## points at it. Nothing stops for it: it fades in, sits there, and fades out.

const WIDTH := 540.0
const GAP := 22.0          # between the card and the thing it points at
const EDGE := 24.0         # kept this far inside the screen
const PADDING := 44.0      # the panel's own margins, left plus right
const FADE := 0.3

var _target := Rect2()
var _tween: Tween = null

@onready var _card: PanelContainer = %Card
@onready var _text: Label = %Text
@onready var _pointer: Control = %Pointer


func _ready() -> void:
	modulate.a = 0.0
	visible = false
	_card.custom_minimum_size.x = WIDTH
	# Without this the label wraps against an unknown width when it is first
	# measured, every word lands on its own line, and the card comes out the
	# height of the screen.
	_text.custom_minimum_size.x = WIDTH - PADDING


## [param target] is in screen coordinates; an empty rect just centres the card
## with no arrow, for anything that has nothing to point at.
func show_tip(body: String, target: Rect2) -> void:
	_text.text = body
	_target = target
	_place()
	visible = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE)


func hide_tip() -> void:
	if not visible:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, FADE)
	_tween.tween_callback(func() -> void: visible = false)


## Below the target if it fits, otherwise above, and never off the screen.
func _place() -> void:
	_card.size = Vector2(WIDTH, 0.0)
	var h: float = maxf(_card.get_combined_minimum_size().y, 60.0)
	_card.size = Vector2(WIDTH, h)

	if _target.size == Vector2.ZERO:
		_card.position = Vector2((size.x - WIDTH) / 2.0, 150.0)
		_pointer.queue_redraw()
		return

	var below := _target.end.y + GAP
	var above := _target.position.y - GAP - h
	var y := below if below + h <= size.y - EDGE else above
	y = clampf(y, EDGE, size.y - EDGE - h)
	var x := clampf(_target.get_center().x - WIDTH / 2.0, EDGE, size.x - EDGE - WIDTH)
	_card.position = Vector2(x, y)
	_pointer.queue_redraw()


## Drawn by the Pointer child so it sits under the card rather than across it.
func draw_pointer() -> void:
	if _target.size == Vector2.ZERO or not visible:
		return
	var card := Rect2(_card.position, _card.size)
	var from := Vector2(clampf(_target.get_center().x, card.position.x + 20.0,
		card.end.x - 20.0), 0.0)
	var to := Vector2(from.x, 0.0)

	if _target.get_center().y < card.get_center().y:
		from.y = card.position.y               # target is above the card
		to.y = _target.end.y + 4.0
	else:
		from.y = card.end.y                    # target is below it
		to.y = _target.position.y - 4.0
	to.x = clampf(from.x, _target.position.x + 6.0, _target.end.x - 6.0)

	_pointer.draw_line(from, to, Palette.INK, 3.0)
	var dir := (to - from).normalized()
	var side := Vector2(-dir.y, dir.x) * 7.0
	_pointer.draw_colored_polygon(PackedVector2Array([
		to, to - dir * 14.0 + side, to - dir * 14.0 - side]), Palette.INK)

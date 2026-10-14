class_name TipCard
extends Control
## A line of help that parks itself next to whatever it is talking about and
## points at it. Nothing stops for it: it fades in, sits there, and fades out.

const WIDTH := 540.0
const GAP := 22.0          # between the card and the thing it points at
const EDGE := 24.0         # kept this far inside the screen
const PADDING := 44.0      # the panel's own margins, left plus right
const INSET := 8.0         # how near a corner the pointer may leave the card
const FADE := 0.3

## The parts of the screen a card must never cover: the strip the arrows
## travel down, and the opponent's health. The card stays off them whatever it
## is pointing at, so nothing is ever read through a card.
var keep_clear: Array[Rect2] = []

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


## Same tip, new wording. The card is measured again because the translation
## is a different length.
func set_body(body: String) -> void:
	if not visible:
		return
	_text.text = body
	_place()


func hide_tip() -> void:
	if not visible:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, FADE)
	_tween.tween_callback(func() -> void: visible = false)


## Below the target if that works, otherwise above. "Works" means on screen
## and off everything in keep_clear. Failing both, the card tries the gap
## above each of those in turn, highest first, and the top of the screen last.
func _place() -> void:
	_card.size = Vector2(WIDTH, 0.0)
	var h: float = maxf(_card.get_combined_minimum_size().y, 60.0)
	_card.size = Vector2(WIDTH, h)

	if _target.size == Vector2.ZERO:
		_card.position = Vector2((size.x - WIDTH) / 2.0, 150.0)
		_pointer.queue_redraw()
		return

	var x := clampf(_target.get_center().x - WIDTH / 2.0, EDGE, size.x - EDGE - WIDTH)

	var tries: Array[float] = [_target.end.y + GAP, _target.position.y - GAP - h]
	# The gap above each thing being kept clear, nearest the top first, so a
	# card that cannot sit by its target still lands somewhere readable.
	var tops: Array[float] = []
	for rect in keep_clear:
		tops.append(rect.position.y - GAP - h)
	tops.sort()
	tries.append_array(tops)
	tries.append(EDGE)

	var y: float = EDGE
	for option in tries:
		var at := clampf(option, EDGE, size.y - EDGE - h)
		if at != option:
			continue              # it only fits by being shoved, so it is no fit
		if _blocked(x, at, h):
			continue
		y = at
		break

	_card.position = Vector2(x, y)
	_pointer.queue_redraw()


## A full rectangle test, not just the y band: a card off to the left is clear
## of the health readout even while it is level with it.
func _blocked(x: float, y: float, h: float) -> bool:
	var card := Rect2(x, y, WIDTH, h)
	for rect in keep_clear:
		if rect.size != Vector2.ZERO and card.intersects(rect):
			return true
	return false


## Drawn by the Pointer child so it sits under the card rather than across it.
func draw_pointer() -> void:
	if _target.size == Vector2.ZERO or not visible:
		return
	var card := Rect2(_card.position, _card.size)
	var from := Vector2(0.0, card.end.y)       # target is below the card
	var to := Vector2(0.0, _target.position.y - 4.0)
	if _target.get_center().y < card.get_center().y:
		from.y = card.position.y               # target is above it
		to.y = _target.end.y + 4.0

	var x := _line_x(card, minf(from.y, to.y), maxf(from.y, to.y))
	from.x = x
	to.x = x

	_pointer.draw_line(from, to, Palette.INK, 3.0)
	var dir := (to - from).normalized()
	var side := Vector2(-dir.y, dir.x) * 7.0
	_pointer.draw_colored_polygon(PackedVector2Array([
		to, to - dir * 14.0 + side, to - dir * 14.0 - side]), Palette.INK)


## Straight down the middle, unless that would rule a line across something
## being kept clear. Then it goes down whichever side of that still reaches
## both the card and the thing it is pointing at.
func _line_x(card: Rect2, low: float, high: float) -> float:
	var lo := maxf(card.position.x + INSET, _target.position.x + 6.0)
	var hi := minf(card.end.x - INSET, _target.end.x - 6.0)
	if lo > hi:            # they barely line up; stay under the card
		return clampf(_target.get_center().x, card.position.x + INSET,
			card.end.x - INSET)

	var middle := clampf(_target.get_center().x, lo, hi)
	if not _crosses(middle, low, high):
		return middle
	for rect in _dodge():
		for side in [rect.position.x - INSET, rect.end.x + INSET]:
			if side >= lo and side <= hi and not _crosses(side, low, high):
				return side
	return middle


## Does a line down x run across anything on its way between the two?
func _crosses(x: float, low: float, high: float) -> bool:
	for rect in _dodge():
		if x > rect.position.x and x < rect.end.x \
				and high > rect.position.y and low < rect.end.y:
			return true
	return false


## What the line has to get round. Not whatever the tip is pointing at, nor
## the strip that thing lives in: a line has to reach its own target.
func _dodge() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for rect in keep_clear:
		if rect.size != Vector2.ZERO and not rect.intersects(_target):
			out.append(rect)
	return out

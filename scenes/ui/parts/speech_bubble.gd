class_name SpeechBubble
extends Control
## A line of encouragement that pops up beside a fighter, holds, and fades.
## Layout lives in speech_bubble.tscn.
##
## The art is one drawn oval, cut into nine so the middle can stretch to
## however long the line is while the outline keeps its weight and the tail
## keeps its shape. The numbers below all come from where that cut was made,
## so changing the margins in the scene means changing them here too.

## The nine-patch has nothing left to stretch below this, since the two side
## columns are drawn at their native size whatever the rect says.
const MIN_SIZE := Vector2(467.0, 205.0)
const MAX_WIDTH := 640.0

## The oval's safe area, inside which text does not run over the outline.
## Wider on the right because the tail eats into that corner.
const PAD_L := 64.0
const PAD_R := 104.0

## Where the tail's point sits, measured back from the bubble's bottom-right.
## The tail lives wholly inside the bottom-right patch, which is never
## stretched, so this offset holds at every size.
const TIP := Vector2(-22.0, -66.0)

## How close to the screen edge the bubble may sit.
const MARGIN := 12.0

const POP := 0.18
const FADE := 0.3

var _tween: Tween


func _ready() -> void:
	modulate.a = 0.0
	hide()


## key is a translation key rather than prose, so the line follows the
## language like everything else on screen. target is the point the tail
## should aim at, in this node's parent's coordinates.
func say(key: String, target: Vector2) -> void:
	var line := tr(key)
	if line == key:
		# A stage can name a line before anyone has written it. Say nothing
		# rather than showing the player a raw key.
		push_warning("No line written for " + key)
		return

	var label: Label = %Text
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text = line
	var wanted := label.get_minimum_size().x + PAD_L + PAD_R
	if wanted > MAX_WIDTH:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		wanted = MAX_WIDTH
	size = Vector2(maxf(wanted, MIN_SIZE.x), MIN_SIZE.y)

	# Hang the bubble off the tail's point, then push it back on screen if a
	# tall opponent has shoved it over an edge. The tail then misses them by
	# however far it moved, which is better than losing half the line.
	var tail := size + TIP
	var room := get_viewport_rect().size - size - Vector2(MARGIN, MARGIN)
	position = (target - tail).clamp(Vector2(MARGIN, MARGIN), room)
	pivot_offset = tail           # it grows out of the tail, not out of the middle
	_play()


func _play() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	show()
	modulate.a = 0.0
	scale = Vector2(0.7, 0.7)
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, POP)
	_tween.tween_property(self, "scale", Vector2.ONE, POP) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.set_parallel(false)
	_tween.tween_interval(hold_time())
	_tween.tween_property(self, "modulate:a", 0.0, FADE)
	_tween.tween_callback(hide)


## Long lines need longer on screen, and Thai packs more into fewer characters
## than English does, so this counts what is drawn rather than the letters.
func hold_time() -> float:
	var label: Label = %Text
	return clampf(label.text.length() * 0.09, 1.6, 4.0)


## Nothing should still be fading while the next stage builds itself.
func clear() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	modulate.a = 0.0
	hide()

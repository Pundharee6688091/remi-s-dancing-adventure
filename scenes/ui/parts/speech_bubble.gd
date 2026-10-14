class_name SpeechBubble
extends Control
## A line of encouragement that pops up beside a fighter, holds, and fades.
## Layout lives in speech_bubble.tscn.
##
## The art is a nine-slice: the corners and the tail are drawn at their own
## size and only the middle stretches, so the border keeps its weight however
## wide the line is. That makes every measurement below a pixel count rather
## than a fraction of the bubble, and they are read off the art in
## ui/bubble_grid.png: a 300px square with a 24px wall on the top and left
## and a 54px corner on the right and the bottom holding the tail.

## The wall, plus a little breathing room, on each side of the line. The two
## sides match: the tail only eats into the band below the text, so the line
## does not have to be pushed left to stay off it.
const PAD_L := 30.0
const PAD_R := 30.0
## The top and bottom do not match: the tail hangs off the bottom right, so
## the drawn box's own middle sits above the middle of this rect. Giving the
## top the larger share drops the line onto the box's middle instead of
## leaving it floating above it.
const PAD_T := 34.0
const PAD_B := 46.0

## Where the tail's point sits, measured back from the bottom right corner.
## The tail is drawn at its own size whatever the bubble does, so this is
## fixed rather than a share of the picture.
const TIP_BACK := Vector2(8.0, 11.0)

## The bubble is cut to the line. The floors are the smallest a nine-slice
## can be drawn at without the corners meeting and squashing the drawing:
## the two walls, and a little of the middle between them.
const MIN_WIDTH := 150.0
const MIN_HEIGHT := 104.0
const MAX_WIDTH := 640.0

## How close to the screen edge the bubble may sit.
const MARGIN := 12.0

const POP := 0.18
const FADE := 0.3

var _tween: Tween

## The key behind the line on screen, so a language change mid-line can set
## it again. The label holds a finished sentence, which cannot be translated
## a second time.
var _key := ""

## Where the tail was aimed, so a re-layout can aim it there again.
var _target := Vector2.ZERO


func _ready() -> void:
	modulate.a = 0.0
	hide()
	Events.language_changed.connect(_on_language_changed)


func _on_language_changed() -> void:
	# The label holds a finished sentence, which cannot be translated twice,
	# and the other language is a different width. Lay the line out again
	# without restarting the pop, so it does not jump back to the start.
	if visible and _key != "":
		_draw_line()


## key is a translation key rather than prose, so the line follows the
## language like everything else on screen. target is the point the tail
## should aim at, in this node's parent's coordinates.
func say(key: String, target: Vector2) -> void:
	if tr(key) == key:
		# A stage can name a line before anyone has written it. Say nothing
		# rather than showing the player a raw key.
		push_warning("No line written for " + key)
		return
	_key = key
	_target = target
	_draw_line()
	_play()


## The line, the oval around it, and where that oval hangs. Separate from
## say() so a language change can redo all three without starting over.
func _draw_line() -> void:
	var label: Label = %Text
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text = tr(_key)

	# The walls take the same pixels whatever the bubble is, so the bubble is
	# the line plus those, in both directions. A line past the cap folds, and
	# the bubble grows downward by however many lines that comes to.
	var one := label.get_minimum_size().x
	var w := clampf(one + PAD_L + PAD_R, MIN_WIDTH, MAX_WIDTH)
	var inner := w - PAD_L - PAD_R
	if one > inner:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# The label is given its width on its own first. A wrapped label works out
	# how tall it is from the width it has, so asking it before it has been
	# narrowed gets the height it was at some other width.
	label.size = Vector2(inner, 0.0)
	var tall := label.get_minimum_size().y
	size = Vector2(w, maxf(tall + PAD_T + PAD_B, MIN_HEIGHT))
	_place(label)

	# Hang the bubble off the tail's point, then push it back on screen if a
	# tall opponent has shoved it over an edge. The tail then misses them by
	# however far it moved, which is better than losing half the line.
	var tail := size - TIP_BACK
	var room := get_viewport_rect().size - size - Vector2(MARGIN, MARGIN)
	position = (_target - tail).clamp(Vector2(MARGIN, MARGIN), room)
	pivot_offset = tail           # it grows out of the tail, not out of the middle


## The room inside the walls. Set here rather than left to anchors, because
## measuring a wrapped line means setting the label's width by hand first, and
## a width set by hand is one the anchors no longer own.
func _place(label: Label) -> void:
	label.position = Vector2(PAD_L, PAD_T)
	label.size = Vector2(size.x - PAD_L - PAD_R, size.y - PAD_T - PAD_B)


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
	_key = ""
	if _tween != null and _tween.is_valid():
		_tween.kill()
	modulate.a = 0.0
	hide()

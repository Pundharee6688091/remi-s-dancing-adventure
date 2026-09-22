class_name Palette
extends RefCounted
## Every colour in the game, named once. Taken straight from the wireframes.

const BONE  := Color("#f7f5f0")   # page background
const INK   := Color("#2b2b2b")   # text, borders, the song bar
const MUTED := Color("#8a877f")   # secondary text, dividers
const FILL  := Color("#e6e3dc")   # placeholder boxes
const RED   := Color("#c9502f")   # monster HP, win line, hit line, ghosts
const AMBER := Color("#e8a33d")   # judgement text, focus highlight
const WHITE := Color("#ffffff")

## One colour per lane: up, left, right, down.
const LANE := [
	Color("#e8a33d"),   # 0 up     yellow
	Color("#8fbf6a"),   # 1 left   green
	Color("#9cc4d8"),   # 2 right  blue
	Color("#c9502f"),   # 3 down   red
]

## The judgement words, same four colours as the result screen in your mockup.
const JUDGEMENT := {
	"perfect": Color("#e8a33d"),
	"great": Color("#8fbf6a"),
	"good": Color("#9cc4d8"),
	"miss": Color("#c9502f"),
}

static func lane_color(lane: int) -> Color:
	return LANE[clampi(lane, 0, LANE.size() - 1)]

## The same hue with the colour drained out of it, for the ghost arrows.
static func ghost_color(lane: int) -> Color:
	var c := lane_color(lane)
	return Color.from_hsv(c.h, c.s * 0.5, c.v * 0.8)

static func judgement_color(judgement: String) -> Color:
	return JUDGEMENT.get(judgement, INK)

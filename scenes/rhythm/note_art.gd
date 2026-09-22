class_name NoteArt
extends RefCounted

const SIZE := 50.0

## The arrow from the wireframes, pointing up, in a 44-unit box around (0, 0).
const _UP := [
	Vector2(0, -18), Vector2(16, 0), Vector2(6, 0), Vector2(6, 18),
	Vector2(-6, 18), Vector2(-6, 0), Vector2(-16, 0),
]

static func arrow_points(direction: int, s: float) -> PackedVector2Array:
	var angle := 0.0
	match direction:
		0: angle = 0.0          # up
		1: angle = -PI / 2.0    # left
		2: angle = PI / 2.0     # right
		3: angle = PI           # down

	var k := s / 44.0
	var out := PackedVector2Array()
	for p in _UP:
		out.append((p * k).rotated(angle))
	return out


## The arrow moved so its middle sits at `centre`.
static func at(direction: int, centre: Vector2, s: float = SIZE) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in arrow_points(direction, s):
		out.append(p + centre)
	return out


## The same points with the first repeated at the end, so an outline closes.
static func closed(pts: PackedVector2Array) -> PackedVector2Array:
	var loop := pts.duplicate()
	loop.append(pts[0])
	return loop

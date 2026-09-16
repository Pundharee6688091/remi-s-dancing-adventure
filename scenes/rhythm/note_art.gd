class_name NoteArt
extends RefCounted

const SIZE := 44.0

static func arrow_points(direction: int, s: float) -> PackedVector2Array:
	var h := s * 0.5
	var w := s * 0.2
	var base := PackedVector2Array([
		Vector2(0, -h), Vector2(h, 0), Vector2(w, 0),
		Vector2(w, h), Vector2(-w, h), Vector2(-w, 0), Vector2(-h, 0),
	])

	var angle := 0.0
	match direction:
		0: angle = 0.0         # up
		1: angle = -PI / 2.0   # left
		2: angle = PI / 2.0    # right
		3: angle = PI          # down

# up left right down
	var out := PackedVector2Array()
	for p in base:
		out.append(p.rotated(angle))
	return out

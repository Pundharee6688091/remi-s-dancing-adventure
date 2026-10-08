class_name MapView
extends Control

const STORY_R := 18.0
const FIGHT_R := 33.0
const ROAD_W := 10.0
const TOP := 84.0
const BOTTOM := 664.0

const GREEN := Color("#d7ead7")
const GOLD := Color("#f7e3b4")
const LOCKED := Color("#d6d2c8")
const ROAD := Color("#efe9dc")

const PIN_ART := "res://sprite/Remi/Remi_pin.webp"

var cursor := 0
var _shake := 0.0
var _pin_art: Texture2D = null
var _art_loaded := false


func shake() -> void:
	_shake = 1.0


## _draw runs on every redraw, so the art is fetched once and kept.
func _load_art() -> void:
	if _art_loaded:
		return
	_art_loaded = true
	if ResourceLoader.exists(PIN_ART):
		_pin_art = load(PIN_ART)


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 3.0)
		queue_redraw()


## The road and the nodes on it. Everything else on this screen, the grass
## behind it and the chrome in front, is laid out in world_map.tscn.
func _draw() -> void:
	_load_art()
	_draw_road()
	for i in Rules.node_order.size():
		_draw_node(Rules.node_order[i], i == cursor, get_theme_default_font())

func _road_nodes() -> Array:
	var linked := {}
	for id in Rules.node_order:
		for req in Rules.stage(id).get("requires", []):
			linked[id] = true
			linked[req] = true

	var out := []
	for id in Rules.node_order:
		if linked.has(id):
			out.append(id)
	return out


func _road_points() -> PackedVector2Array:
	var chain := _road_nodes()
	if chain.size() < 2:
		return PackedVector2Array()

	var pts: Array[Vector2] = []
	for id in chain:
		pts.append(_pos(id))

	var c := Curve2D.new()
	for i in pts.size():
		var prev: Vector2 = pts[maxi(i - 1, 0)]
		var next: Vector2 = pts[mini(i + 1, pts.size() - 1)]
		var pull := (next - prev) * 0.3
		c.add_point(pts[i], -pull, pull)
	return c.tessellate(5, 2)


func _draw_road() -> void:
	var road := _road_points()
	if road.size() < 2:
		return
	draw_polyline(road, Palette.INK, ROAD_W + 6.0, true)
	draw_polyline(road, ROAD, ROAD_W, true)
	for i in road.size() - 1:
		if i % 4 < 2:
			draw_line(road[i], road[i + 1], Color(Palette.INK, 0.3), 2.0)


func _draw_node(id: String, focused: bool, font: Font) -> void:
	var n := Rules.stage(id)
	var p := _pos(id)
	if focused and _shake > 0.0:
		p.x += sin(Time.get_ticks_msec() * 0.06) * _shake * 10.0

	var open := GameManager.is_unlocked(id)
	var done := GameManager.is_cleared(id)
	var fight: bool = n.get("type") == "fight"
	var r := FIGHT_R if fight else STORY_R

	var stars: int = GameManager.stars_for(id) if fight else 0
	var mastered := done and stars >= 3

	var fill := LOCKED
	if mastered:
		fill = GOLD
	elif done:
		fill = GREEN
	elif open:
		fill = Palette.WHITE

	draw_circle(p, r, fill)
	draw_arc(p, r, 0.0, TAU, 48, Palette.INK, 3.0)
	# A perfect clear gets a second ring, drawn inside the outline so it never
	# reads as the focus ring, which sits outside it.
	if mastered:
		draw_arc(p, r - 7.0, 0.0, TAU, 40, Palette.AMBER, 2.5)
	if focused:
		draw_arc(p, r + 9.0, 0.0, TAU, 48, Palette.AMBER, 5.0)

	if not open:
		_draw_lock(p, r * 0.5)
	elif fight:
		var w := r * 0.9
		draw_rect(Rect2(p - Vector2(w, w * 0.7) / 2.0, Vector2(w, w * 0.7)),
			Palette.WHITE, true)
		draw_rect(Rect2(p - Vector2(w, w * 0.7) / 2.0, Vector2(w, w * 0.7)),
			Palette.INK, false, 2.0)
	else:
		_draw_bubble(p, r * 0.55)

	var label: String = n.get("label", "")
	if fight:
		if label != "":
			_boxed_label(font, label, Vector2(p.x, p.y + r + 32.0))
		_draw_stars(font, Vector2(p.x, p.y + r + 60.0), stars)
	elif label != "":
		draw_string(font, Vector2(p.x - 80.0, p.y - r - 14.0), label,
			HORIZONTAL_ALIGNMENT_CENTER, 160.0, 15, Palette.MUTED)

	if focused:
		_draw_pin(font, Vector2(p.x, p.y - r - 40.0))


func _boxed_label(font: Font, text: String, centre: Vector2) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 22.0
	var box := Rect2(centre.x - w / 2.0, centre.y - 15.0, w, 28.0)
	draw_rect(box, Palette.WHITE, true)
	draw_rect(box, Palette.INK, false, 2.0)
	draw_string(font, Vector2(box.position.x, centre.y + 6.0), text,
		HORIZONTAL_ALIGNMENT_CENTER, w, 16, Palette.INK)


func _draw_stars(font: Font, centre: Vector2, stars: int) -> void:
	var text := "★".repeat(stars) + "☆".repeat(3 - stars)
	draw_string(font, Vector2(centre.x - 60.0, centre.y), text,
		HORIZONTAL_ALIGNMENT_CENTER, 120.0, 20,
		Palette.AMBER if stars > 0 else Palette.MUTED)


func _draw_lock(p: Vector2, s: float) -> void:
	var body := Rect2(p.x - s * 0.6, p.y - s * 0.15, s * 1.2, s * 0.95)
	draw_rect(body, Palette.MUTED, true)
	draw_arc(Vector2(p.x, p.y - s * 0.15), s * 0.42, PI, TAU, 16, Palette.MUTED, 3.0)


func _draw_bubble(p: Vector2, s: float) -> void:
	var box := Rect2(p.x - s, p.y - s * 0.8, s * 2.0, s * 1.4)
	draw_rect(box, Palette.INK, false, 2.5)
	draw_line(Vector2(p.x - s * 0.3, p.y + s * 0.6),
		Vector2(p.x - s * 0.1, p.y + s * 1.1), Palette.INK, 2.5)


## Remi rides the tag next to his name. The box grows around the art rather
## than the art being squeezed into a fixed box.
func _draw_pin(font: Font, bottom: Vector2) -> void:
	var pad := 8.0
	var art_h := 34.0
	var art_w := 0.0
	if _pin_art != null:
		art_w = art_h * _pin_art.get_width() / float(_pin_art.get_height())
	var gap := 6.0 if _pin_art != null else 0.0
	var name_w := font.get_string_size("Remi", HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x

	var w := pad + art_w + gap + name_w + pad
	var h := art_h + 12.0
	var box := Rect2(bottom.x - w / 2.0, bottom.y - h - 10.0, w, h)
	draw_rect(box, Palette.WHITE, true)
	draw_rect(box, Palette.INK, false, 2.5)
	draw_colored_polygon(PackedVector2Array([
		Vector2(bottom.x - 9.0, box.position.y + h),
		Vector2(bottom.x + 9.0, box.position.y + h),
		Vector2(bottom.x, bottom.y + 2.0)]), Palette.AMBER)

	if _pin_art != null:
		draw_texture_rect(_pin_art,
			Rect2(box.position + Vector2(pad, 6.0), Vector2(art_w, art_h)), false)
	draw_string(font, Vector2(box.position.x + pad + art_w + gap,
		box.position.y + h - 14.0), "Remi",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.INK)


## Index of the map node under a point, or -1. Used for mouse clicks.
func node_at(point: Vector2) -> int:
	var best := -1
	var best_d := INF
	for i in Rules.node_order.size():
		var id: String = Rules.node_order[i]
		var r: float = FIGHT_R if Rules.stage(id).get("type") == "fight" else STORY_R
		var d := _pos(id).distance_to(point)
		if d <= r + 6.0 and d < best_d:
			best_d = d
			best = i
	return best


func _pos(id: String) -> Vector2:
	var a: Array = Rules.stage(id).get("pos", [0, 0])
	return Vector2(float(a[0]), float(a[1]))

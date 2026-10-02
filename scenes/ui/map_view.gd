class_name MapView
extends Control

const STORY_R := 18.0
const FIGHT_R := 33.0
const ROAD_W := 10.0
const TOP := 84.0
const BOTTOM := 664.0

const GREEN := Color("#d7ead7")
const LOCKED := Color("#d6d2c8")
const ROAD := Color("#efe9dc")

var cursor := 0
var _shake := 0.0
var _song_cache := {}


func shake() -> void:
	_shake = 1.0


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 3.0)
		queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()

	draw_rect(Rect2(0, TOP, size.x, BOTTOM - TOP), Palette.FILL)

	_draw_road()
	for i in Rules.node_order.size():
		_draw_node(Rules.node_order[i], i == cursor, font)

	_draw_zones(font)
	_draw_info_card(font)
	_draw_legend(font)

## Nodes grouped by their "zone" field. Nodes without one are skipped,
## so the headers disappear entirely until the data asks for them.
func _zones() -> Dictionary:
	var out := {}
	for id in Rules.node_order:
		var z: int = int(Rules.stage(id).get("zone", 0))
		if z <= 0:
			continue
		if not out.has(z):
			out[z] = []
		out[z].append(id)
	return out


func _draw_zones(font: Font) -> void:
	for z in _zones():
		var ids: Array = _zones()[z]
		var left := INF
		var done := 0
		for id in ids:
			left = minf(left, _pos(id).x)
			if GameManager.is_cleared(id):
				done += 1
		var x: float = left - FIGHT_R
		draw_string(font, Vector2(x, TOP + 36.0), tr("UI_ZONE") % z,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Palette.INK)
		draw_string(font, Vector2(x, TOP + 58.0), "%d / %d" % [done, ids.size()],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.MUTED)


## Chart title and audio length, looked up once per song.
func _song_info(song_id: String) -> Dictionary:
	if _song_cache.has(song_id):
		return _song_cache[song_id]
	var info := {"title": song_id, "length": 0.0}
	if FileAccess.file_exists(Rules.chart_path(song_id)):
		info.title = ChartParser.parse(Rules.chart_path(song_id)).title
	if ResourceLoader.exists(Rules.song_path(song_id)):
		var stream: AudioStream = load(Rules.song_path(song_id))
		if stream != null:
			info.length = stream.get_length()
	_song_cache[song_id] = info
	return info


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

	var fill := LOCKED
	if done:
		fill = GREEN
	elif open:
		fill = Palette.WHITE

	draw_circle(p, r, fill)
	draw_arc(p, r, 0.0, TAU, 48, Palette.INK, 3.0)
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
		_draw_stars(font, Vector2(p.x, p.y + r + 60.0), GameManager.stars_for(id))
	elif label != "":
		draw_string(font, Vector2(p.x - 80.0, p.y - r - 14.0), label,
			HORIZONTAL_ALIGNMENT_CENTER, 160.0, 15, Palette.MUTED)

	if focused:
		_draw_pin(font, Vector2(p.x, p.y - r - 40.0))


## The card at the bottom left, describing whatever the cursor is on.
func _draw_info_card(font: Font) -> void:
	if cursor >= Rules.node_order.size():
		return
	var id: String = Rules.node_order[cursor]
	var n := Rules.stage(id)

	var card := Rect2(50, 536, 560, 104)
	draw_rect(card, Palette.WHITE, true)
	draw_rect(card, Palette.INK, false, 2.0)

	var ph := Rect2(card.position + Vector2(14, 14), Vector2(110, 76))
	draw_rect(ph, Palette.FILL, true)
	draw_rect(ph, Palette.INK, false, 2.0)
	var who: String = n.get("opponent", "")
	draw_string(font, Vector2(ph.position.x, ph.position.y + 46),
		who if who != "" else "[art]",
		HORIZONTAL_ALIGNMENT_CENTER, ph.size.x, 15, Palette.MUTED)

	var fight: bool = n.get("type") == "fight"
	var title: String = n.get("label", tr("UI_STORY"))
	var x := card.position.x + 144
	draw_string(font, Vector2(x, card.position.y + 46), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Palette.INK)
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	draw_string(font, Vector2(x + tw + 10, card.position.y + 46),
		tr("UI_DOT_FIGHT") if fight else tr("UI_DOT_STORY"),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Palette.MUTED)

	var line := ""
	if not GameManager.is_unlocked(id):
		line = tr("UI_LOCKED")
	elif fight:
		var stars := GameManager.stars_for(id)
		var si := _song_info(n.get("song", ""))
		var secs := int(si.length)
		line = "%s · %d:%02d · %s" % [si.title, secs / 60, secs % 60,
			tr("UI_CLEARED") if stars > 0 else tr("UI_NOT_CLEARED")]
	else:
		line = tr("UI_SEEN") if GameManager.is_cleared(id) else tr("UI_NOT_SEEN")
	draw_string(font, Vector2(x, card.position.y + 78), line,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Palette.MUTED)


## Stage count and the key to the node shapes, bottom right.
func _draw_legend(font: Font) -> void:
	var fights := 0
	var cleared := 0
	for id in Rules.node_order:
		if Rules.stage(id).get("type") != "fight":
			continue
		fights += 1
		if GameManager.is_cleared(id):
			cleared += 1

	draw_string(font, Vector2(900, 588), tr("UI_STAGE_CLEAR_COUNT") % [cleared, fights],
		HORIZONTAL_ALIGNMENT_RIGHT, 330, 18, Palette.MUTED)

	var box := Rect2(900, 600, 330, 44)
	draw_rect(box, Palette.WHITE, true)
	draw_rect(box, Palette.INK, false, 2.0)

	var y := box.position.y + box.size.y / 2.0
	var x := box.position.x + 22.0
	for item in [[tr("UI_LEGEND_STORY"), Palette.WHITE, 7.0], [tr("UI_LEGEND_FIGHT"), Palette.WHITE, 11.0],
			[tr("UI_LEGEND_DONE"), GREEN, 9.0]]:
		var radius: float = item[2]
		draw_circle(Vector2(x, y), radius, item[1])
		draw_arc(Vector2(x, y), radius, 0.0, TAU, 24, Palette.INK, 2.0)
		draw_string(font, Vector2(x + 16.0, y + 6.0), item[0],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Palette.INK)
		x += 16.0 + font.get_string_size(item[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 28.0


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


func _draw_pin(font: Font, bottom: Vector2) -> void:
	var w := 92.0
	var h := 34.0
	var box := Rect2(bottom.x - w / 2.0, bottom.y - h - 10.0, w, h)
	draw_rect(box, Palette.WHITE, true)
	draw_rect(box, Palette.INK, false, 2.5)
	draw_colored_polygon(PackedVector2Array([
		Vector2(bottom.x - 9.0, box.position.y + h),
		Vector2(bottom.x + 9.0, box.position.y + h),
		Vector2(bottom.x, bottom.y + 2.0)]), Palette.AMBER)
	draw_string(font, Vector2(box.position.x, box.position.y + 24.0), "Remi",
		HORIZONTAL_ALIGNMENT_CENTER, w, 18, Palette.INK)


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

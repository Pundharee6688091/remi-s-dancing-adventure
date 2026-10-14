extends Control
## Layout lives in world_map.tscn. MapView draws only the road and the nodes
## on it; the grass, the zone headers, the info card and the legend are all
## nodes in the scene, filled in from the data here.

const ZONE_HEADER := preload("res://scenes/ui/parts/zone_header.tscn")

@onready var _view: MapView = %Map
@onready var _detail: StageDetail = %Detail
@onready var _progress: Bar = %ProgressBar
@onready var _steps: Label = %Steps
@onready var _party: Label = %Party
@onready var _settings: Control = %Settings

var _song_cache := {}


func _ready() -> void:
	_detail.fight_pressed.connect(GameManager.enter_node)
	# An open popup carries its own hints, so the screen's would double up.
	_detail.visibility_changed.connect(_sync_hints)

	# Opened over the map rather than routed to, so walking back does not
	# lose the cursor the player left on a node.
	_settings.routed = false
	_settings.closed.connect(_sync_hints)
	_settings.visibility_changed.connect(_sync_hints)
	%Gear.pressed.connect(_settings.show)
	# Hovering it walks the cursor onto it, so the mouse and the arrow keys
	# never disagree about where you are.
	%Gear.mouse_entered.connect(func() -> void:
		if not _busy():
			_set_cursor(Rules.node_order.size()))

	%Bg.texture = Rules.background("map")

	_set_hints()
	Events.language_changed.connect(_on_language_changed)
	Events.progress_changed.connect(_refresh)
	_view.cursor = _start_cursor()
	_refresh()


## Zone headers come and go with the data, so they are built rather than placed.
func _sync_zones() -> void:
	for old in %Zones.get_children():
		%Zones.remove_child(old)
		old.queue_free()

	var zones := _zones()
	for z in zones:
		var ids: Array = zones[z]
		var left := INF
		var done := 0
		for id in ids:
			left = minf(left, _node_x(id))
			if GameManager.is_cleared(id):
				done += 1

		var head := ZONE_HEADER.instantiate()
		%Zones.add_child(head)
		head.position = Vector2(left - MapView.FIGHT_R, MapView.TOP + 14.0)
		head.get_node("%Title").text = tr("UI_ZONE") % z
		head.get_node("%Count").text = "%d / %d" % [done, ids.size()]


## Nodes grouped by their "zone" field. Nodes without one are skipped, so the
## headers disappear entirely until the data asks for them.
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


func _node_x(id: String) -> float:
	var a: Array = Rules.stage(id).get("pos", [0, 0])
	return float(a[0])


## The card at the bottom left, describing whatever the cursor is on.
func _sync_card() -> void:
	if _view.cursor >= Rules.node_order.size():
		return
	var id: String = Rules.node_order[_view.cursor]
	var n := Rules.stage(id)
	var fight: bool = n.get("type") == "fight"

	var who: String = n.get("opponent", "")
	%Who.text = Rules.character_name(who)
	%Title.text = tr(String(n.get("label", "UI_STORY")))
	%Kind.text = tr("UI_DOT_FIGHT") if fight else tr("UI_DOT_STORY")

	if not GameManager.is_unlocked(id):
		%Line.text = tr("UI_LOCKED")
	elif fight:
		var si := _song_info(String(n.get("song", "")))
		var secs := int(si.length)
		%Line.text = "%s · %d:%02d · %s" % [si.title, secs / 60, secs % 60,
			tr("UI_CLEARED") if GameManager.stars_for(id) > 0 else tr("UI_NOT_CLEARED")]
	else:
		%Line.text = tr("UI_SEEN") if GameManager.is_cleared(id) else tr("UI_NOT_SEEN")


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


## Click a node to walk there and open it; hovering moves the cursor.
func _gui_input(event: InputEvent) -> void:
	if _busy():
		return

	if event is InputEventMouseMotion:
		var over := _view.node_at(event.position)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if over >= 0 \
			else Control.CURSOR_ARROW
		if over >= 0:
			_set_cursor(over)

	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var hit := _view.node_at(event.position)
		if hit >= 0:
			accept_event()
			_set_cursor(hit)
			_confirm()


func _set_hints() -> void:
	%Hints.set_hints([[["←", "→"], tr("UI_WALK")], ["Enter", tr("UI_OPEN")],
		["Esc", tr("UI_MAIN_MENU"), SceneRouter.back]])


func _sync_hints() -> void:
	%Hints.visible = not _busy()


## True while something sits over the map and should have the input to itself.
func _busy() -> bool:
	return _detail.visible or _settings.visible


## The language can be changed from the overlay, and blocking the rebuild that
## normally follows means the header and hints have to catch up themselves.
func _on_language_changed() -> void:
	_set_hints()
	_refresh()


## Rebuilding the map underneath its own settings overlay would throw the
## player out of it mid-change.
func blocks_reload() -> bool:
	return _settings.visible


func _unhandled_input(event: InputEvent) -> void:
	if _busy():
		return
	if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		_move(1)
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		_move(-1)
	elif event.is_action_pressed("ui_accept"):
		_confirm()
	elif event.is_action_pressed("ui_cancel"):
		SceneRouter.back()


## One stop past the last node is the gear. The map has no focus to move, so
## the cursor that walks the nodes walks onto it as well, rather than leaving
## settings as something only a mouse can open.
func _stops() -> int:
	return Rules.node_order.size() + 1


func _on_gear() -> bool:
	return _view.cursor >= Rules.node_order.size()


func _move(step: int) -> void:
	_set_cursor(clampi(_view.cursor + step, 0, _stops() - 1))


## The one place the cursor moves, so walking with the arrow keys sounds the
## same as sweeping the mouse over the map.
func _set_cursor(i: int) -> void:
	if _view.cursor == i:
		return
	_view.cursor = i
	Audio.play("hover")
	_sync_card()
	_mark_gear()
	_view.queue_redraw()


## The gear is not a node on the track, so it wears the cursor by hand. The
## box is empty but for its border, or it would cover the cog drawn inside it.
func _mark_gear() -> void:
	if not _on_gear():
		for slot in ["normal", "hover", "pressed"]:
			%Gear.remove_theme_stylebox_override(slot)
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.AMBER, 0.18)
	style.set_border_width_all(3)
	style.border_color = Palette.AMBER
	style.set_corner_radius_all(8)
	for slot in ["normal", "hover", "pressed"]:
		%Gear.add_theme_stylebox_override(slot, style)


func _confirm() -> void:
	if _on_gear():
		Audio.play("click")
		_settings.show()
		return
	var id: String = Rules.node_order[_view.cursor]
	if not GameManager.is_unlocked(id):
		# A locked node is not a selection: it shakes its head and says so.
		Audio.play("locked")
		_view.shake()
		return
	Audio.play("click")
	if Rules.stage(id).get("type") == "fight":
		_detail.open(id)
	else:
		GameManager.enter_node(id)


func _start_cursor() -> int:
	var order: Array = Rules.node_order
	var i := order.find(GameManager.current_stage_id)

	# Still on something unfinished, so stay there.
	if i >= 0 and not GameManager.is_cleared(order[i]):
		return i

	# Nothing in progress: the first thing still to do.
	if i < 0:
		return _next_open(order, -1)

	# Just finished order[i], so step forward to what comes next rather than
	# scanning from the start and landing back on the tutorial.
	return _next_open(order, i)


## First unlocked, uncleared node after [param from], wrapping around.
func _next_open(order: Array, from: int) -> int:
	for step in order.size():
		var j := (from + 1 + step) % order.size()
		if GameManager.is_unlocked(order[j]) and not GameManager.is_cleared(order[j]):
			return j
	return maxi(from, 0)


func _refresh() -> void:
	var total := Rules.node_order.size()
	var done := 0
	for id in Rules.node_order:
		if GameManager.is_cleared(id):
			done += 1

	_progress.value = float(done) / maxf(total, 1)
	_steps.text = tr("UI_STEPS") % [done, total]

	var party: Array = GameManager.save.get("party", [])
	_party.text = tr("UI_PARTY") % (party.size() + 1)

	var fights := 0
	var fights_done := 0
	for id in Rules.node_order:
		if Rules.stage(id).get("type") != "fight":
			continue
		fights += 1
		if GameManager.is_cleared(id):
			fights_done += 1
	%ClearCount.text = tr("UI_STAGE_CLEAR_COUNT") % [fights_done, fights]

	_sync_zones()
	_sync_card()
	_view.queue_redraw()

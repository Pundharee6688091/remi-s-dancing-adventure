extends Control

var _view: MapView
var _detail: StageDetail
var _progress: Label
var _party: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var title := Label.new()
	title.text = "World map"
	title.position = Vector2(40, 30)
	add_child(title)

	_progress = Label.new()
	_progress.position = Vector2(240, 30)
	add_child(_progress)

	_party = Label.new()
	_party.position = Vector2(40, 600)
	add_child(_party)

	_view = MapView.new()
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)

	var hint := Label.new()
	hint.text = "◀ ▶ Move     Enter Open     Esc Main menu"
	hint.position = Vector2(40, 660)
	add_child(hint)

	_detail = StageDetail.new()
	_detail.fight_pressed.connect(GameManager.enter_node)
	add_child(_detail)

	Events.progress_changed.connect(_refresh)

	_view.cursor = _start_cursor()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if _detail.visible:
		return
	if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		_move(1)
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		_move(-1)
	elif event.is_action_pressed("ui_accept"):
		_confirm()
	elif event.is_action_pressed("ui_cancel"):
		SceneRouter.back()


func _move(step: int) -> void:
	_view.cursor = clampi(_view.cursor + step, 0, Rules.node_order.size() - 1)
	_view.queue_redraw()


func _confirm() -> void:
	var id: String = Rules.node_order[_view.cursor]
	if not GameManager.is_unlocked(id):
		_view.shake()
		return
	if Rules.stage(id).get("type") == "fight":
		_detail.open(id)
	else:
		GameManager.enter_node(id)


func _start_cursor() -> int:
	var order: Array = Rules.node_order
	var i := order.find(GameManager.current_stage_id)
	if i >= 0:
		return i
	for j in order.size():
		if GameManager.is_unlocked(order[j]) and not GameManager.is_cleared(order[j]):
			return j
	return 0


func _refresh() -> void:
	var fights := 0
	var cleared := 0
	var stars := 0
	for id in Rules.node_order:
		if Rules.stage(id).get("type") != "fight":
			continue
		fights += 1
		stars += GameManager.stars_for(id)
		if GameManager.is_cleared(id):
			cleared += 1

	_progress.text = "Cleared %d / %d     Stars %d / %d" % [
		cleared, fights, stars, fights * 3]

	var party: Array = GameManager.save.get("party", [])
	_party.text = "Party: Remi" + ("" if party.is_empty()
		else ", " + ", ".join(PackedStringArray(party)))

	_view.queue_redraw()

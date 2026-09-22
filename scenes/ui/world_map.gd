extends Control

var _view: MapView
var _detail: StageDetail
var _progress: Bar
var _steps: Label
var _party: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_view = MapView.new()
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)

	_build_top_bar()

	var hints := HintBar.new()
	add_child(hints)
	hints.set_hints([["< >", "Walk"], ["Enter", "Open"], ["Esc", "Main menu"]])

	_detail = StageDetail.new()
	_detail.fight_pressed.connect(GameManager.enter_node)
	add_child(_detail)

	Events.progress_changed.connect(_refresh)
	_view.cursor = _start_cursor()
	_refresh()


func _build_top_bar() -> void:
	var strip := ColorRect.new()
	strip.color = Palette.WHITE
	strip.size = Vector2(1280, 82)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)

	var rule := ColorRect.new()
	rule.color = Palette.INK
	rule.position = Vector2(0, 82)
	rule.size = Vector2(1280, 2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rule)

	_text("World map", Vector2(40, 20), 32)
	_text("Progress", Vector2(240, 36), 18, Palette.MUTED)

	_progress = Bar.new()
	_progress.position = Vector2(340, 36)
	_progress.size = Vector2(300, 22)
	_progress.fill_color = Palette.AMBER
	add_child(_progress)

	_steps = _text("", Vector2(664, 36), 18, Palette.MUTED)

	_party = _text("", Vector2(1020, 36), 18, Palette.MUTED)
	_party.size = Vector2(220, 26)
	_party.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _text(value: String, pos: Vector2, size_px := 18, color := Palette.INK) -> Label:
	var l := Label.new()
	l.text = value
	l.position = pos
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


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
	var total := Rules.node_order.size()
	var done := 0
	for id in Rules.node_order:
		if GameManager.is_cleared(id):
			done += 1

	_progress.value = float(done) / maxf(total, 1)
	_steps.text = "%d / %d steps" % [done, total]

	var party: Array = GameManager.save.get("party", [])
	_party.text = "Party %d / 4" % (party.size() + 1)

	_view.queue_redraw()

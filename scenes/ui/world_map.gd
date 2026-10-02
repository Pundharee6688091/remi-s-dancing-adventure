extends Control
## Layout lives in world_map.tscn. MapView still draws itself.

@onready var _view: MapView = %Map
@onready var _detail: StageDetail = %Detail
@onready var _progress: Bar = %ProgressBar
@onready var _steps: Label = %Steps
@onready var _party: Label = %Party


func _ready() -> void:
	_detail.fight_pressed.connect(GameManager.enter_node)
	# An open popup carries its own hints, so the screen's would double up.
	_detail.visibility_changed.connect(_sync_hints)
	%Hints.set_hints([[["←", "→"], tr("UI_WALK")], ["Enter", tr("UI_OPEN")],
		["Esc", tr("UI_MAIN_MENU")]])

	Events.progress_changed.connect(_refresh)
	_view.cursor = _start_cursor()
	_refresh()


## Click a node to walk there and open it; hovering moves the cursor.
func _gui_input(event: InputEvent) -> void:
	if _detail.visible:
		return

	if event is InputEventMouseMotion:
		var over := _view.node_at(event.position)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if over >= 0 \
			else Control.CURSOR_ARROW
		if over >= 0 and over != _view.cursor:
			_view.cursor = over
			_view.queue_redraw()

	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var hit := _view.node_at(event.position)
		if hit >= 0:
			accept_event()
			_view.cursor = hit
			_view.queue_redraw()
			_confirm()


func _sync_hints() -> void:
	%Hints.visible = not _detail.visible


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
	_steps.text = tr("UI_STEPS") % [done, total]

	var party: Array = GameManager.save.get("party", [])
	_party.text = tr("UI_PARTY") % (party.size() + 1)

	_view.queue_redraw()

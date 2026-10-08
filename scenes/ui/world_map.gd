extends Control
## Layout lives in world_map.tscn. MapView still draws itself.

@onready var _view: MapView = %Map
@onready var _detail: StageDetail = %Detail
@onready var _progress: Bar = %ProgressBar
@onready var _steps: Label = %Steps
@onready var _party: Label = %Party
@onready var _settings: Control = %Settings


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

	_set_hints()
	Events.language_changed.connect(_on_language_changed)
	Events.progress_changed.connect(_refresh)
	_view.cursor = _start_cursor()
	_refresh()


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
		["Esc", tr("UI_MAIN_MENU")]])


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


func _move(step: int) -> void:
	_set_cursor(clampi(_view.cursor + step, 0, Rules.node_order.size() - 1))


## The one place the cursor moves, so walking with the arrow keys sounds the
## same as sweeping the mouse over the map.
func _set_cursor(i: int) -> void:
	if _view.cursor == i:
		return
	_view.cursor = i
	Audio.play("hover")
	_view.queue_redraw()


func _confirm() -> void:
	var id: String = Rules.node_order[_view.cursor]
	if not GameManager.is_unlocked(id):
		# The shake is the answer here; a locked node is not a selection.
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

	_view.queue_redraw()

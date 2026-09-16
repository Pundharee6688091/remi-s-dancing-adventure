extends Control

var _confirm: ConfirmBox
var _story: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var who := Label.new()
	who.text = GameManager.save.get("name", "")
	who.position = Vector2(1000, 50)
	add_child(who)

	var box := VBoxContainer.new()
	box.position = Vector2(80, 200)
	box.custom_minimum_size = Vector2(280, 0)
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	_story = _item(box, "Story", func() -> void: GameManager.start_stage("s1_1"))
	_item(box, "Collection", Callable()).disabled = true
	_item(box, "Achievements", Callable()).disabled = true
	_item(box, "Settings", Callable()).disabled = true
	_item(box, "Quit", func() -> void: _confirm.ask("Quit the game?", "Quit", "Cancel"))

	var hint := Label.new()
	hint.text = "▲ ▼ Move     Enter Select     Esc Change profile"
	hint.position = Vector2(80, 660)
	add_child(hint)

	_confirm = ConfirmBox.new()
	_confirm.answered.connect(_on_quit_answered)
	add_child(_confirm)

	_story.grab_focus()


func _item(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	if cb.is_valid():
		b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _on_quit_answered(yes: bool) -> void:
	if yes:
		get_tree().quit()
	else:
		_story.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _confirm.is_open():
		return
	if event.is_action_pressed("ui_cancel"):
		SceneRouter.back()

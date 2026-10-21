extends Control
## Layout lives in main_menu.tscn.

const KEY_ART := "res://characters/Remi/Remi_happy.png"

@onready var _story: Button = %Story
@onready var _confirm: ConfirmBox = %Confirm


func _ready() -> void:
	%Who.text = GameManager.save.get("name", "")
	%Stage.text = SaveManager.progress_label(GameManager.save)

	_confirm.answered.connect(_on_quit_answered)
	_confirm.visibility_changed.connect(_sync_hints)
	%Hints.set_hints([[["↑", "↓"], tr("UI_MOVE")], ["Enter", tr("UI_SELECT")],
		["Esc", tr("UI_BACK_TO_PROFILES"), SceneRouter.back]])

	# Down off the last item comes round to the first, instead of stopping
	# dead the way Godot's own neighbours do. Read off the row itself, so an
	# item added to the scene joins the loop without being named again here.
	var items: Array[Control] = []
	for n in _story.get_parent().get_children():
		if n is Button:
			items.append(n)
	UIKit.trap_focus(items, "y")

	_story.grab_focus()


func _sync_hints() -> void:
	%Hints.visible = not _confirm.visible


func _on_story_pressed() -> void:
	SceneRouter.goto(GameManager.WORLD_MAP)


func _on_collection_pressed() -> void:
	SceneRouter.goto(GameManager.COLLECTION)


func _on_achievements_pressed() -> void:
	SceneRouter.goto(GameManager.ACHIEVEMENTS)


func _on_settings_pressed() -> void:
	SceneRouter.goto(GameManager.SETTINGS)



func _on_quit_pressed() -> void:
	_confirm.ask(tr("UI_QUIT_CONFIRM"), "", tr("UI_QUIT"), tr("UI_CANCEL"))


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

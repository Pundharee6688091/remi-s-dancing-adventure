extends Control
## Layout lives in title.tscn. This only handles input and the art crop.

const SAVE_SLOTS := "res://scenes/ui/save_slots.tscn"
const KEY_ART := "res://characters/remi/Remi_happy.png"

@onready var _pill: Button = %Pill
@onready var _art: TextureRect = %Art


func _ready() -> void:
	_pill.text = Loc.current().to_upper()
	_pill.pressed.connect(Loc.toggle)
	_art.texture = _cropped(KEY_ART)

	var hints := HintBar.new()
	add_child(hints)
	hints.set_hints([["F2", tr("UI_LANGUAGE"), Loc.toggle]])


func _unhandled_input(event: InputEvent) -> void:
	# Checked first, otherwise "any button" would swallow it and advance.
	if event.is_action_pressed("toggle_language"):
		get_viewport().set_input_as_handled()
		Loc.toggle()
		return

	var is_button := event is InputEventKey or event is InputEventJoypadButton
	if is_button and event.is_pressed() and not event.is_echo():
		get_viewport().set_input_as_handled()
		SceneRouter.goto(SAVE_SLOTS)


## The art sits in a big transparent canvas, so crop to what is drawn.
func _cropped(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path)
	var used := tex.get_image().get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return tex
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(used)
	return atlas

extends Control
## Layout lives in title.tscn. This only handles input and the art crop.

const SAVE_SLOTS := "res://scenes/ui/save_slots.tscn"
const KEY_ART := "res://characters/Remi/Remi_happy.png"

## How far Remi rises, and how long each half of the hop takes.
const HOP := 14.0
const HOP_TIME := 0.9

## How much he stretches going up and squashes on landing.
const STRETCH := Vector2(0.97, 1.03)
const SQUASH := Vector2(1.06, 0.94)
const SETTLE := 0.22

@onready var _pill: Button = %Pill
@onready var _art: TextureRect = %Art


func _ready() -> void:
	_pill.text = Loc.current().to_upper()
	_pill.pressed.connect(Loc.toggle)
	_art.texture = UIKit.cropped_texture(KEY_ART)
	_hop()

	var hints := HintBar.new()
	add_child(hints)
	hints.set_hints([])


## Remi bobs on the spot while the title waits. Slowing on the way up and
## gathering pace on the way down reads as a hop rather than a drift, and he
## stretches as he rises and squashes as he lands.
func _hop() -> void:
	# Scaled from his feet, so a squash flattens him onto the floor rather
	# than shrinking him towards the middle of the picture.
	_art.pivot_offset = Vector2(_art.size.x * 0.5, _art.size.y)

	var t := create_tween().set_loops()
	t.set_parallel(true)
	t.tween_property(_art, "position:y", -HOP, HOP_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(_art, "scale", STRETCH, HOP_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	t.set_parallel(false)
	t.tween_interval(0.0)
	t.set_parallel(true)
	t.tween_property(_art, "position:y", 0.0, HOP_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(_art, "scale", SQUASH, HOP_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	t.set_parallel(false)
	t.tween_property(_art, "scale", Vector2.ONE, SETTLE) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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

@tool
extends DialogicPortrait

@export_group("Main")
@export_file var image := ""

const LIT := Color(1.0, 1.0, 1.0)
const DIM := Color(0.60, 0.60, 0.62)
const FADE := 0.15

var _art: CanvasItem = null
var _tween: Tween = null
var _lit := true

func _update_portrait(passed_character: DialogicCharacter, passed_portrait: String) -> void:
	apply_character_and_portrait(passed_character, passed_portrait)
	apply_texture($Portrait, image)
	if Engine.is_editor_hint():
		_tint(LIT)
		return
	_tint(LIT if _lit else DIM)
	_sync_to_speaker.call_deferred()


## Dialogic nests a portrait as container -> character node -> portrait, and
## draw order is sibling order. Moving the character node inside its own
## container does nothing, since it is the only thing in there; it is the
## container that has to come last among the containers.
func _bring_to_front() -> void:
	var holder := get_parent()
	if holder == null:
		return
	var container := holder.get_parent()
	if container == null:
		return
	container.move_child(holder, -1)
	var layer := container.get_parent()
	if layer != null:
		layer.move_child(container, -1)


func _sync_to_speaker() -> void:
	var speaker = Dialogic.Text.get_current_speaker()
	if speaker == null:
		return  # narrator line: keep the current state
	_lit = (speaker == character)
	_tint(LIT if _lit else DIM)
	if _lit:
		_bring_to_front()


func _highlight() -> void:
	_lit = true
	_fade_to(LIT)
	_bring_to_front()


func _unhighlight() -> void:
	_lit = false
	_fade_to(DIM)


## The sprite, not the root. DialogicPortrait extends Node, which has no modulate.
func _art_node() -> CanvasItem:
	if _art == null or not is_instance_valid(_art):
		_art = get_node_or_null("Portrait") as CanvasItem
	return _art


func _tint(target: Color) -> void:
	var art := _art_node()
	if art != null:
		art.modulate = target

func _who() -> String:
	return character.display_name if character != null else "<no character>"

func _fade_to(target: Color) -> void:
	var art := _art_node()
	if art == null:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if Engine.is_editor_hint():
		art.modulate = target
		return
	#create_tween().tween_property(art, "modulate", target, FADE)
	_tween = create_tween()
	_tween.tween_property(art, "modulate", target, FADE)

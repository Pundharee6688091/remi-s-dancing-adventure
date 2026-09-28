@tool
extends DialogicPortrait

@export_group("Main")
@export_file var image := ""

const LIT := Color(1.0, 1.0, 1.0)
const DIM := Color(0.60, 0.60, 0.62)
const FADE := 0.15

var _art: CanvasItem = null


func _update_portrait(passed_character: DialogicCharacter, passed_portrait: String) -> void:
	apply_character_and_portrait(passed_character, passed_portrait)
	apply_texture($Portrait, image)
	if Engine.is_editor_hint():
		_tint(LIT)
		return
	_tint(LIT if Dialogic.Text.get_current_speaker() == character else DIM)


func _highlight() -> void:
	_fade_to(LIT)
	var holder := get_parent()
	if holder != null and holder.get_parent() != null:
		holder.get_parent().move_child(holder, -1)


func _unhighlight() -> void:
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


func _fade_to(target: Color) -> void:
	var art := _art_node()
	if art == null:
		return
	if Engine.is_editor_hint():
		art.modulate = target
		return
	create_tween().tween_property(art, "modulate", target, FADE)

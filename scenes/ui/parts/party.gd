@tool
class_name Party
extends PanelContainer
## The group picture, drawn as five layers on one canvas, with whoever has not
## been recruited yet left as a silhouette.
##
## Every layer gets the same window, which is what keeps them lined up with
## each other. The window belongs to the instance, not to this script: a save
## card wants the waist up, a wider panel may want the whole picture. Set it in
## the inspector and it redraws as you drag the numbers.

## The part of the art to show, in the picture's own pixels. The default trims
## the empty margin off the sides and cuts below the waists. A window with no
## width or height shows the whole picture, uncut.
@export var window := Rect2(87, 104, 1351, 1486):
	set(value):
		window = value
		_recrop()

const DARK := Color(0.12, 0.12, 0.15)

## Cassia is drawn across two layers, a piece of her behind the others and her
## body in front, so both have to change together.
@onready var _parts := {
	"Cassia": [%Cassia2, %Cassia],
	"Theo": [%Theo],
	"Elion": [%Elion],
}

var _slot := 0

## The uncut pictures, kept so the window can be moved, resized or dropped
## again. Without these the first cut would be the only one possible.
var _source := {}


func _ready() -> void:
	for child in get_children():
		var layer := child as TextureRect
		if layer == null or layer.texture == null:
			continue
		# A window saved into the scene by accident would otherwise be cut a
		# second time, so unwrap back to the picture underneath.
		var tex := layer.texture
		if tex is AtlasTexture:
			tex = (tex as AtlasTexture).atlas
		_source[layer] = tex
	_recrop()
	if not Engine.is_editor_hint():
		_apply()


## Point every layer at the chosen part of its picture.
func _recrop() -> void:
	for layer in _source:
		var src: Texture2D = _source[layer]
		if window.size.x <= 0.0 or window.size.y <= 0.0:
			layer.texture = src
			continue
		var cut := AtlasTexture.new()
		cut.atlas = src
		cut.region = window
		layer.texture = cut


## Which profile this picture is showing. Remi is always lit; he is the one
## playing. The rest light up as they are recruited.
func set_slot(slot: int) -> void:
	_slot = slot
	if is_node_ready() and not Engine.is_editor_hint():
		_apply()


func _apply() -> void:
	var party: Array = []
	if _slot > 0:
		party = SaveManager.load_slot(_slot).get("party", [])
	else:
		party = GameManager.save.get("party", [])
	for who in _parts:
		var lit: bool = party.has(who)
		for part in _parts[who]:
			part.self_modulate = Color.WHITE if lit else DARK

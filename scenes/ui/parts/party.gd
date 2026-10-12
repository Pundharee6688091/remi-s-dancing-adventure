class_name Party
extends PanelContainer
## The group picture, drawn as five layers on one canvas. Shown from the waist
## up so the faces are big enough to read at the size of a save card, with
## whoever has not been recruited yet left as a silhouette.

## Where the characters actually are on the canvas: the empty margin trimmed
## off the sides, and cut below the waists. Every layer gets the same window,
## which is what keeps them lined up with each other.
const WINDOW := Rect2(87, 104, 1351, 1486)

const DARK := Color(0.12, 0.12, 0.15)

## Cassia is drawn across two layers, a piece of her behind the others and her
## body in front, so both have to change together.
@onready var _parts := {
	"Cassia": [%Cassia2, %Cassia],
	"Theo": [%Theo],
	"Elion": [%Elion],
}

var _slot := 0


func _ready() -> void:
	for child in get_children():
		var layer := child as TextureRect
		if layer == null or layer.texture == null or layer.texture is AtlasTexture:
			continue
		var window := AtlasTexture.new()
		window.atlas = layer.texture
		window.region = WINDOW
		layer.texture = window
	_apply()


## Which profile this picture is showing. Remi is always lit; he is the one
## playing. The rest light up as they are recruited.
func set_slot(slot: int) -> void:
	_slot = slot
	if is_node_ready():
		_apply()


func _apply() -> void:
	var party: Array = []
	if _slot > 0:
		party = SaveManager.load_slot(_slot).get("party", [])
	for who in _parts:
		var lit: bool = party.has(who)
		for part in _parts[who]:
			part.self_modulate = Color.WHITE if lit else DARK

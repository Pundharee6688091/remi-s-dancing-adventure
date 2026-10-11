extends Control
## Draws the arrow for its parent TipCard, as a child so the line passes under
## the card rather than over it.

func _draw() -> void:
	var card := get_parent()
	if card is TipCard:
		card.draw_pointer()

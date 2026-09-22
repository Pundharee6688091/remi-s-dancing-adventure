class_name UIKit
extends RefCounted
## Small builders for the shapes the mockups repeat.

## The see-through wash behind a popup. Light, like the mockups, not black.
static func dim(parent: Node) -> ColorRect:
	var d := ColorRect.new()
	d.color = Color(Palette.INK, 0.35)
	d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(d)
	return d


## A white card with an ink border. Returns the VBox to put things in.
## The border and padding come from the theme's PanelContainer style.
static func card(parent: Node, pos: Vector2, width: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.position = pos
	panel.custom_minimum_size = Vector2(width, 0)
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	return box

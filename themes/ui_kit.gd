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


## Keep keyboard focus inside a popup, looping from the last back to the
## first. [param axis] says which arrows walk the loop: "both" by default,
## "x" for a row and "y" for a column, so the other pair is free to mean
## something else on that screen.
static func trap_focus(controls: Array, axis := "both") -> void:
	var n := controls.size()
	for i in n:
		var c: Control = controls[i]
		var prev: Control = controls[(i - 1 + n) % n]
		var next: Control = controls[(i + 1) % n]
		if axis != "y":
			c.focus_neighbor_left = c.get_path_to(prev)
			c.focus_neighbor_right = c.get_path_to(next)
		if axis != "x":
			c.focus_neighbor_top = c.get_path_to(prev)
			c.focus_neighbor_bottom = c.get_path_to(next)
		c.focus_previous = c.get_path_to(prev)
		c.focus_next = c.get_path_to(next)


## Art often sits in a big transparent canvas. Crop to what is actually drawn
## so a TextureRect can fit it without the padding throwing the scale off.
static func cropped_texture(path: String) -> Texture2D:
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

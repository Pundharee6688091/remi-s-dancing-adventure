extends Node

const TITLE := "res://scenes/ui/title.tscn"

## The shape the whole game is drawn at. The window can be any shape at all;
## this is the part of it the game itself uses.
const STAGE := Vector2(1280.0, 720.0)

## What goes either side of the stage when the window is not 16:9. Drawn
## rather than left black: the engine's own letterbox is outside the viewport
## and nothing can be put in it, which is why the stretch mode had to change.
const PADDING := "res://backgrounds/Padding.png"

## The art is drawn big, so its checks come out about 190 pixels across if it
## is tiled as it is, which reads as stripes rather than a pattern. A third
## puts them around 64, which is a backdrop rather than a feature.
const PAD_SCALE := 1.0 / 3.0

var _stack: Array[Dictionary] = []
var _current: Node = null
var _current_path := ""
var _current_params := {}

## Screens live in here rather than directly under the router, so every one of
## them still measures itself against 1280x720 whatever the window is doing.
var _stage: Control
var _pad: TextureRect


func _ready() -> void:
	_build_stage()
	Events.language_changed.connect(reload)
	call_deferred("clear_to", TITLE)


func _build_stage() -> void:
	var back_layer := CanvasLayer.new()
	back_layer.layer = -100
	add_child(back_layer)

	_pad = TextureRect.new()
	var pad := _pad
	pad.texture = load(PADDING)
	# Tiled, not stretched: the checks are hand drawn and stretching them to
	# whatever strip is left over would show.
	pad.stretch_mode = TextureRect.STRETCH_TILE
	# Without this a TextureRect refuses to be smaller than its own texture,
	# and this one is 3059 wide, so it would not shrink to the window.
	pad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pad.scale = Vector2(PAD_SCALE, PAD_SCALE)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_layer.add_child(pad)

	_stage = Control.new()
	_stage.size = STAGE
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)

	get_viewport().size_changed.connect(_centre_stage)
	_centre_stage()


## Centred by hand rather than by anchors, because it must stay exactly
## 1280x720 and anchors would stretch it to the window.
func _centre_stage() -> void:
	if _stage == null:
		return
	# get_viewport_rect() belongs to Control; this is a plain Node.
	var room := get_viewport().get_visible_rect().size
	_stage.size = STAGE
	_stage.position = ((room - STAGE) * 0.5).floor()
	# Scaled down, so it has to be laid out that much larger to still cover
	# the window. Anchors cannot do this; the scale would fight them.
	if _pad != null:
		_pad.size = room / PAD_SCALE


## Go deeper. The current screen is remembered.
func goto(path: String, params: Dictionary = {}) -> void:
	if _current != null:
		_stack.push_back({"path": _current_path, "params": _current_params})
	_swap(path, params)


## Return to whatever opened this screen.
func back() -> void:
	if _stack.is_empty():
		return
	var prev: Dictionary = _stack.pop_back()
	_swap(prev.path, prev.params)


## Swap without remembering — for a screen you should not come back to.
func replace(path: String, params: Dictionary = {}) -> void:
	_swap(path, params)


## Wipe the history and start again.
func clear_to(path: String, params: Dictionary = {}) -> void:
	_stack.clear()
	_swap(path, params)


## Where the game sits inside the window, for the few things that live above
## the screens rather than inside one.
func stage_rect() -> Rect2:
	if _stage == null:
		return Rect2(Vector2.ZERO, STAGE)
	return Rect2(_stage.position, STAGE)


func depth() -> int:
	return _stack.size()


func _swap(path: String, params: Dictionary) -> void:
	if _current != null:
		_stage.remove_child(_current)
		_current.queue_free()
		_current = null

	var packed: PackedScene = load(path)
	var inst: Node = packed.instantiate()

	if inst.has_method("setup"):
		inst.setup(params)

	_current_path = path
	_current_params = params
	_current = inst
	# Timed around the whole swap rather than the teardown, because building
	# the new screen is the part that would be felt as a stutter.
	var began := Time.get_ticks_usec()
	_stage.add_child(inst)
	Telemetry.screen(path.get_file())
	Telemetry.event("screen_built", {"to": path.get_file(),
		"took_ms": "%.1f" % ((Time.get_ticks_usec() - began) / 1000.0)})


func reload() -> void:
	if _current_path == "":
		return
	# A screen mid-song or mid-timeline would lose its place if rebuilt.
	if _current != null and _current.has_method("blocks_reload") and _current.blocks_reload():
		return
	_swap(_current_path, _current_params)

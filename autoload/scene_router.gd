extends Node

const TITLE := "res://scenes/ui/title.tscn"

var _stack: Array[Dictionary] = []
var _current: Node = null
var _current_path := ""
var _current_params := {}


func _ready() -> void:
	call_deferred("clear_to", TITLE)


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


func depth() -> int:
	return _stack.size()


func _swap(path: String, params: Dictionary) -> void:
	if _current != null:
		remove_child(_current)
		_current.queue_free()
		_current = null

	var packed: PackedScene = load(path)
	var inst: Node = packed.instantiate()

	if inst.has_method("setup"):
		inst.setup(params)

	_current_path = path
	_current_params = params
	_current = inst
	add_child(inst)

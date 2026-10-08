extends Node
## Every short sound in one place. Buttons wire themselves up as they enter
## the tree, so a new screen gets click and hover for free.

const SOUNDS := {
	"click": "res://sfx/click.wav",
	"hover": "res://sfx/hover.wav",
	"arrow": "res://sfx/arrow.wav",
	"win": "res://sfx/win.wav",
	"lose": "res://sfx/lose.wav",
}

## Overlapping notes need more than one player or each hit cuts the last off.
const VOICES := 8

## The presses that count as moving a selection, keyboard or d-pad.
const NAV_ACTIONS := ["ui_up", "ui_down", "ui_left", "ui_right"]

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _cache := {}

## Set while a directional press is being dispatched. Focus that moves because
## of it sounds; a screen grabbing focus as it opens stays silent.
var _navigating := false


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_players.append(p)

	get_tree().node_added.connect(_on_node_added)
	Events.note_judged.connect(_on_note_judged)
	Events.stage_cleared.connect(func(_id: String, _hp: int) -> void: play("win"))
	Events.stage_failed.connect(func(_id: String) -> void: play("lose"))


func play(sound: String) -> void:
	if not SOUNDS.has(sound):
		return
	if not _cache.has(sound):
		if not ResourceLoader.exists(SOUNDS[sound]):
			return
		_cache[sound] = load(SOUNDS[sound])

	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _cache[sound]
	p.play()


## Input is dispatched before _process every frame, so any focus the press
## moved has already been reported by the time this clears the flag.
func _input(event: InputEvent) -> void:
	for action in NAV_ACTIONS:
		if event.is_action_pressed(action):
			_navigating = true
			return


func _process(_delta: float) -> void:
	_navigating = false


## Any button anywhere, including ones built at runtime like the hint bar caps.
func _on_node_added(n: Node) -> void:
	if not (n is BaseButton):
		return
	n.pressed.connect(play.bind("click"))
	n.mouse_entered.connect(play.bind("hover"))
	n.focus_entered.connect(_on_focus_entered)


## Clicking a button focuses it too, so this only fires for the arrow keys.
func _on_focus_entered() -> void:
	if _navigating:
		play("hover")


func _on_note_judged(judgement: String, _lane: int) -> void:
	if judgement != "miss":
		play("arrow")

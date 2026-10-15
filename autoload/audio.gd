extends Node
## Every short sound in one place. Buttons wire themselves up as they enter
## the tree, so a new screen gets click and hover for free.

const SOUNDS := {
	"click": "res://sfx/click.wav",
	"hover": "res://sfx/hover.wav",
	"arrow": "res://sfx/arrow.wav",
	"win": "res://sfx/win.wav",
	"lose": "res://sfx/lose.wav",
	# the answer when something is not open yet
	"locked": "res://sfx/Lock.wav",
}

## Overlapping notes need more than one player or each hit cuts the last off.
const VOICES := 8

## The presses that count as moving a selection, keyboard or d-pad.
const NAV_ACTIONS := ["ui_up", "ui_down", "ui_left", "ui_right"]

## The bed that runs under the menus, the map and anywhere else that has no
## music of its own.
const MUSIC := "res://music/The Bard\u2019s Proclamation.wav"

## Trim, measured against the track: it peaks at -0.1 dBFS over a -15.1 dBFS
## body, which is a finished master rather than something meant to sit under a
## menu. This puts the bed near -32 dBFS at the default music slider, the same
## level the chapter music was tuned to.
const MUSIC_DB := -9.0
const SILENT_DB := -60.0

## Getting out of the way is quick, since whatever wants the floor is about to
## start. Coming back afterwards takes its time.
const DUCK_FADE := 0.25
const FADE := 1.5

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _cache := {}

## Set while a directional press is being dispatched. Focus that moves because
## of it sounds; a screen grabbing focus as it opens stays silent.
var _navigating := false

var _music: AudioStreamPlayer
var _music_fade: Tween

## Other players on the Music bus: a stage song, or a chapter's own track.
var _rival_music: Array[AudioStreamPlayer] = []
var _ducked := false

## Held down for as long as a stage wants the floor, rather than only while
## its song happens to be sounding. A paused song is not playing, so watching
## the bus alone would let the bed back in over a pause menu.
var _held := false


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_players.append(p)

	_music = AudioStreamPlayer.new()
	_music.bus = &"Music"
	_music.volume_db = SILENT_DB
	add_child(_music)
	_start_music()

	get_tree().node_added.connect(_on_node_added)
	Events.note_judged.connect(_on_note_judged)
	Events.stage_cleared.connect(func(_id: String, _hp: float) -> void: play("win"))
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

	var busy := _held
	var i := _rival_music.size()
	while i > 0:
		i -= 1
		var p := _rival_music[i]
		if not is_instance_valid(p):
			_rival_music.remove_at(i)
		elif p.playing:
			busy = true
	if busy != _ducked:
		_ducked = busy
		if busy:
			_fade_music(SILENT_DB, DUCK_FADE)
		else:
			_fade_music(MUSIC_DB)


## Keeps the bed down until it is let go, whatever the bus is doing.
func hold(on: bool) -> void:
	if _held == on:
		return
	_held = on
	if on and not _ducked:
		_ducked = true
		_fade_music(SILENT_DB, DUCK_FADE)


## Loops, so it carries a menu for as long as the player sits there.
func _start_music() -> void:
	if not ResourceLoader.exists(MUSIC):
		push_warning("No background music at " + MUSIC)
		return
	var stream: AudioStream = load(MUSIC)
	# The bed used to stop dead after one play. The line meant to loop it
	# looked for a "loop" property, which an imported wav does not have, so it
	# never ran. Setting the loop in the import does not take either, on this
	# Godot, so the track is started again when it ends, the same way the
	# chapter music already handles it.
	_music.stream = stream
	if not _music.finished.is_connected(_restart_music):
		_music.finished.connect(_restart_music)
	_music.play()
	_fade_music(MUSIC_DB)


## Only ever reached if the track is not looping on its own.
func _restart_music() -> void:
	_music.play()


## Fading rather than cutting, and paused once it is silent so it holds its
## place instead of running on under a whole stage.
func _fade_music(target_db: float, secs := FADE) -> void:
	if _music.stream == null:
		return
	if _music_fade != null and _music_fade.is_valid():
		_music_fade.kill()
	if target_db > SILENT_DB:
		_music.stream_paused = false
	_music_fade = create_tween()
	_music_fade.tween_property(_music, "volume_db", target_db, secs)
	if target_db <= SILENT_DB:
		_music_fade.finished.connect(func() -> void: _music.stream_paused = true)


## Any button anywhere, including ones built at runtime like the hint bar caps.
func _on_node_added(n: Node) -> void:
	if n is AudioStreamPlayer and n != _music and n.bus == &"Music":
		_rival_music.append(n)
		return
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

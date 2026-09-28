extends Control

enum State { COUNTDOWN, PLAYING, PAUSED, RESULT }

@onready var song: AudioStreamPlayer = $Song
@onready var conductor: Conductor = $Conductor
@onready var remi: Sprite2D = $Remi
@onready var enemy: Sprite2D = $Enemy
@onready var track: TrackPanel = $TrackPanel
@onready var field: NoteField = $TrackPanel/Notes
@onready var countdown_label: Label = $Judgement
@onready var hud: BattleHUD = $HUD
@onready var pause_overlay: PauseOverlay = $Pause
@onready var result_overlay: ResultOverlay = $Result
@onready var debug: Label = $Debug


var judge := Judge.new()
var state := State.COUNTDOWN
var _countdown_id := 0
var stage_id := "s1_1"

## Remi stands nearer the camera than the boss, so she is drawn bigger.
const REMI_SCALE := 0.25
const ENEMY_SCALE := 0.20
## Nearer things sit lower on the screen.
const REMI_FLOOR := 400.0
const ENEMY_FLOOR := 360.0
const REMI_X := 210.0
const ENEMY_X := 1060.0

const POSE_HOLD := 0.25
const REMI_POSES := [
	"res://sprite/Remi/Up.png",
	"res://sprite/Remi/Left.png",
	"res://sprite/Remi/Right.png",
	"res://sprite/Remi/Down.png",
]
const REMI_IDLE := "res://sprite/Remi/Remi.png"
const IDLE := 4

var _poses: Array = []
var _pose_time := 0.0


func _ready() -> void:
	var st := Rules.stage(stage_id)
	var song_id: String = st.get("song", "song_tutorial")
	var chart := ChartParser.parse(Rules.chart_path(song_id))
	field.setup(chart.notes)

	_setup_remi()
	_show_enemy(song_id)
	
	song.stream = load(Rules.song_path(song_id))
	song.finished.connect(_on_song_finished)
	conductor.setup(song)
	hud.setup(conductor.song_length_ms())

	pause_overlay.resume_pressed.connect(_resume)
	pause_overlay.restart_pressed.connect(_restart)
	pause_overlay.quit_pressed.connect(GameManager.leave_stage)
	
	Events.note_judged.connect(_on_note_judged)
	_restart()

func setup(params: Dictionary) -> void:
	stage_id = params.get("stage_id", "s1_1")

func _process(delta: float) -> void:
	if _pose_time > 0.0:
		_pose_time = maxf(0.0, _pose_time - delta)
		if _pose_time == 0.0:
			_show_pose(IDLE)

	if state != State.PLAYING:
		return
	var now: float = conductor.song_time_ms()
	field.update(now)
	judge.sweep(now)
	hud.update_progress(now)


func _unhandled_input(event: InputEvent) -> void:
	match state:
		State.PLAYING:
			if event.is_action_pressed("ui_cancel"):
				_pause()
			else:
				_lane_input(event, true)
		State.COUNTDOWN:
			if event.is_action_pressed("ui_cancel"):
				_pause()
			else:
				_lane_input(event, false)
		State.PAUSED:
			if event.is_action_pressed("ui_cancel"):
				_resume()
		State.RESULT:
			if event.is_action_pressed("ui_accept"):
				_restart()
			elif event.is_action_pressed("ui_cancel"):
				GameManager.leave_stage()
				
				

func _lane_input(event: InputEvent, judging: bool) -> void:
	for lane in 4:
		var action := InputManager.lane_action(lane)
		if event.is_action_pressed(action):
			track.ghosts[lane].set_pressed(true)
			if event.is_action_pressed(action):
				track.ghosts[lane].set_pressed(true)
				_show_pose(lane)
				_pose_time = POSE_HOLD
				if judging:
					judge.press(lane, conductor.song_time_ms())
			if judging:
				judge.press(lane, conductor.song_time_ms())
		elif event.is_action_released(action):
			track.ghosts[lane].set_pressed(false)


## Put this stage's opponent on screen. No art means no opponent.
func _show_enemy(song_id: String) -> void:
	_apply(enemy, _pose(Rules.enemy_path(song_id), ENEMY_SCALE, ENEMY_FLOOR),
		ENEMY_X, ENEMY_SCALE)


## Measure each of Remi's pictures once, so changing pose later costs nothing.
func _setup_remi() -> void:
	_poses.clear()
	for path in REMI_POSES:
		_poses.append(_pose(path, REMI_SCALE, REMI_FLOOR))
	_poses.append(_pose(REMI_IDLE, REMI_SCALE, REMI_FLOOR))
	_show_pose(IDLE)


## Show the dance pose for a lane. Missing art falls back to idle.
func _show_pose(which: int) -> void:
	var pose: Dictionary = _poses[which]
	if pose.is_empty():
		pose = _poses[IDLE]
	_apply(remi, pose, REMI_X, REMI_SCALE)


## Measure a picture once: the part actually drawn, and the y that stands it on
## its floor line. Reading pixels is slow, so this never runs during play.
func _pose(path: String, scale: float, floor_y: float) -> Dictionary:
	if not ResourceLoader.exists(path):
		return {}
	var tex: Texture2D = load(path)
	var used := tex.get_image().get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return {}
	return {"texture": tex, "region": Rect2(used),
		"y": floor_y - used.size.y * scale / 2.0}


func _apply(sprite: Sprite2D, pose: Dictionary, x: float, scale: float) -> void:
	if pose.is_empty():
		sprite.hide()
		return
	sprite.texture = pose.texture
	sprite.region_enabled = true
	sprite.region_rect = pose.region
	sprite.scale = Vector2(scale, scale)
	sprite.position = Vector2(x, pose.y)
	sprite.show()


func _restart() -> void:
	pause_overlay.hide()
	result_overlay.hide()
	song.stream_paused = false
	conductor.stop()

	field.reset()
	judge.setup(field)
	Events.hp_changed.emit(judge.hp)
	hud.update_progress(0.0)
	for g in track.ghosts:
		g.set_pressed(false)

	state = State.COUNTDOWN
	if not await _countdown():
		return
	conductor.start()
	state = State.PLAYING


func _pause() -> void:
	_countdown_id += 1                       # invalidate a running countdown
	state = State.PAUSED
	song.stream_paused = true
	countdown_label.modulate.a = 0.0
	pause_overlay.open()


func _resume() -> void:
	pause_overlay.hide()

	if not conductor.is_running():
		_restart()                           # paused before the song ever began
		return

	state = State.COUNTDOWN
	if not await _countdown():
		return
	song.stream_paused = false
	state = State.PLAYING


func _on_song_finished() -> void:
	if state == State.RESULT:
		return
	state = State.RESULT
	judge.sweep_all()
	conductor.stop()
	Events.song_finished.emit()

	var r := judge.result()
	r.won = GameManager.evaluate_win(stage_id, judge.hp)
	r.previous_best = GameManager.best_hp_for(stage_id)
	result_overlay.show_result(r)

	if r.won:
		Events.stage_cleared.emit(stage_id, r.hp)
	else:
		Events.stage_failed.emit(stage_id)


func _countdown() -> bool:
	_countdown_id += 1
	var my_id := _countdown_id

	for n in [3, 2, 1]:
		countdown_label.text = str(n)
		countdown_label.modulate.a = 1.0
		await get_tree().create_timer(0.6).timeout
		if my_id != _countdown_id:
			return false          # something superseded us

	countdown_label.modulate.a = 0.0
	return true
	

func _on_note_judged(judgement: String, lane: int) -> void:
	track.pop_judgement(lane, judgement)

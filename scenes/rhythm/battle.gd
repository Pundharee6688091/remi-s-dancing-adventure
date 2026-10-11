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
@onready var settings_overlay: Control = $Settings
@onready var debug: Label = $Debug


var judge := Judge.new()
var state := State.COUNTDOWN
var _countdown_id := 0
var _count_tween: Tween = null
var stage_id := "s1_1"
var _chart: Dictionary = {}

## Remi stands nearer the camera than the boss, so she is drawn bigger.
const REMI_SCALE := 0.15
const ENEMY_SCALE := 0.20
## Nearer things sit lower on the screen.
const REMI_FLOOR := 400.0
const ENEMY_FLOOR := 360.0
const REMI_X := 210.0
const ENEMY_X := 1060.0

const POSE_HOLD := 0.5
const REMI_POSES := [
	"res://sprite/Remi/Remi_up.png",
	"res://sprite/Remi/Remi_left.png",
	"res://sprite/Remi/Remi_right.png",
	"res://sprite/Remi/Remi_down.png",
]
const REMI_IDLE := "res://sprite/Remi/Remi_middle.png"
const IDLE := 4

var _has_enemy := true
var _poses: Array = []
var _pose_time := 0.0


func _ready() -> void:
	var st := Rules.stage(stage_id)
	var song_id: String = st.get("song", "song_tutorial")
	_chart = ChartParser.parse(Rules.chart_path(song_id))
	field.setup(_chart.notes)

	%Bg.texture = Rules.background("fight", stage_id)
	_setup_remi()
	_has_enemy = String(st.get("opponent", "")) != ""
	enemy.visible = _has_enemy
	if _has_enemy:
		_show_enemy(song_id)
	
	song.stream = load(Rules.song_path(song_id))
	song.finished.connect(_on_song_finished)
	conductor.setup(song)
	var win_rule: Dictionary = st.get("win", {})
	hud.setup(conductor.song_length_ms(),
		float(win_rule.get("value", Rules.data.get("win_hp_percent", 30))))
	hud.show_monster(_has_enemy)

	pause_overlay.resume_pressed.connect(_resume)
	pause_overlay.restart_pressed.connect(_restart)
	pause_overlay.quit_pressed.connect(GameManager.leave_stage)
	pause_overlay.settings_pressed.connect(_open_settings)
	settings_overlay.routed = false
	settings_overlay.closed.connect(_close_settings)
	settings_overlay.visibility_changed.connect(_sync_hints)
	result_overlay.continue_pressed.connect(GameManager.leave_stage)
	result_overlay.retry_pressed.connect(_restart)
	
	Events.note_judged.connect(_on_note_judged)

	_set_hints()
	Events.language_changed.connect(_set_hints)
	for o in [pause_overlay, result_overlay]:
		o.visibility_changed.connect(_sync_hints)
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
	# Settings is a full overlay and owns every key while it is up.
	if settings_overlay.visible:
		return
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
			# Enter belongs to the focused button on the result screen now.
			# Esc stays as a shortcut straight back to the map.
			if event.is_action_pressed("ui_cancel"):
				GameManager.leave_stage()
				
				

func _lane_input(event: InputEvent, judging: bool) -> void:
	for lane in 4:
		var action := InputManager.lane_action(lane)
		if event.is_action_released(action):
			track.ghosts[lane].set_pressed(false)
			continue
		if not event.is_action_pressed(action):
			continue

		track.ghosts[lane].set_pressed(true)
		_show_pose(lane)
		_pose_time = POSE_HOLD
		if judging:
			judge.press(lane, conductor.song_time_ms())


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


func _pause_info() -> String:
	var secs := int(conductor.song_time_ms() / 1000.0)
	var opp: String = Rules.stage(stage_id).get("opponent", "")
	return tr("UI_PAUSE_INFO") % [_chart.get("title", ""), secs / 60, secs % 60,
		opp if opp != "" else "—", Rules.hp_display(judge.hp)]


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
	pause_overlay.open(_pause_info())


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
	pause_overlay.hide()
	judge.sweep_all()
	conductor.stop()
	Events.song_finished.emit()

	var st := Rules.stage(stage_id)
	var r := judge.result()
	r.won = GameManager.evaluate_win(stage_id, judge.hp)
	r.stage = st.get("label", "")
	r.song = _chart.get("title", "")
	r.song_id = st.get("song", "")
	r.opponent = st.get("opponent", "")
	r.win_at = int(st.get("win", {}).get("value", 30))
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
		_flash_count()
		await get_tree().create_timer(0.6).timeout
		if my_id != _countdown_id:
			return false          # something superseded us

	countdown_label.modulate.a = 0.0
	return true


## Each number lands rather than appearing: it drops in oversized, snaps to
## size, holds, then fades out before the next one.
func _flash_count() -> void:
	var l := countdown_label
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2.ONE * 1.7
	l.modulate.a = 0.0
	if _count_tween != null and _count_tween.is_valid():
		_count_tween.kill()
	_count_tween = create_tween()
	_count_tween.set_parallel(true)
	_count_tween.tween_property(l, "scale", Vector2.ONE, 0.24) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_count_tween.tween_property(l, "modulate:a", 1.0, 0.1)
	_count_tween.set_parallel(false)
	_count_tween.tween_interval(0.2)
	_count_tween.tween_property(l, "modulate:a", 0.0, 0.22)
	

func _on_note_judged(judgement: String, lane: int) -> void:
	track.pop_judgement(lane, judgement)

## Rebuilding this mid-song would restart the stage, so a language change
## leaves it alone. Its labels hold translation keys, so Godot re-translates
## them in place.
func blocks_reload() -> bool:
	return true


func _set_hints() -> void:
	%Hints.set_hints([[["W", "A", "S", "D", "↑", "←", "↓", "→"], tr("UI_HIT_ON_GHOST")],
		["Esc", tr("UI_PAUSE")]])


## An open overlay brings its own hints, so the battle's would double up.
func _sync_hints() -> void:
	%Hints.visible = not (pause_overlay.visible or result_overlay.visible
		or settings_overlay.visible)


## Settings opens over the paused song rather than routing away, so the stage
## is still here when it closes. Routing would rebuild battle.tscn and the
## song would start again from the top.
func _open_settings() -> void:
	pause_overlay.hide()
	settings_overlay.show()


func _close_settings() -> void:
	pause_overlay.open(_pause_info())

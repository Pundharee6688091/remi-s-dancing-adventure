extends Control

enum State { COUNTDOWN, PLAYING, PAUSED, RESULT }

@onready var song: AudioStreamPlayer = $Song
@onready var conductor: Conductor = $Conductor
@onready var track: TrackPanel = $TrackPanel
@onready var field: NoteField = $TrackPanel/Notes
@onready var judgement_label: Label = $Judgement
@onready var hud: BattleHUD = $HUD
@onready var pause_overlay: PauseOverlay = $Pause
@onready var result_overlay: ResultOverlay = $Result
@onready var debug: Label = $Debug


var judge := Judge.new()
var state := State.COUNTDOWN
var _countdown_id := 0
var stage_id := "s1_1"


func _ready() -> void:
	var st := Rules.stage(stage_id)
	var song_id: String = st.get("song", "song_tutorial")
	var chart := ChartParser.parse(Rules.chart_path(song_id))
	field.setup(chart.notes)

	song.stream = load(Rules.song_path(song_id))
	song.finished.connect(_on_song_finished)
	conductor.setup(song)
	hud.setup(conductor.song_length_ms())

	pause_overlay.resume_pressed.connect(_resume)
	pause_overlay.restart_pressed.connect(_restart)
	pause_overlay.quit_pressed.connect(GameManager.leave_stage)
	
	print("router depth: ", SceneRouter.depth())
	_restart()

func setup(params: Dictionary) -> void:
	stage_id = params.get("stage_id", "s1_1")

func _process(_delta: float) -> void:
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
			if judging:
				var j := judge.press(lane, conductor.song_time_ms())
				if j != "":
					_show_judgement(j)
		elif event.is_action_released(action):
			track.ghosts[lane].set_pressed(false)


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
	judgement_label.modulate.a = 0.0
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
	result_overlay.show_result(r)

	if r.won:
		Events.stage_cleared.emit(stage_id, r.stars)
	else:
		Events.stage_failed.emit(stage_id)


func _countdown() -> bool:
	_countdown_id += 1
	var my_id := _countdown_id

	for n in [3, 2, 1]:
		judgement_label.text = str(n)
		judgement_label.modulate.a = 1.0
		await get_tree().create_timer(0.6).timeout
		if my_id != _countdown_id:
			return false          # something superseded us

	judgement_label.modulate.a = 0.0
	return true


func _show_judgement(j: String) -> void:
	judgement_label.text = j.to_upper()
	judgement_label.modulate.a = 1.0
	create_tween().tween_property(judgement_label, "modulate:a", 0.0, 0.4)

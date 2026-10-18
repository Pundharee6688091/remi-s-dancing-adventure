extends Control

enum State { COUNTDOWN, PLAYING, PAUSED, RESULT }

@onready var song: AudioStreamPlayer = $Song
@onready var countdown: AudioStreamPlayer = $Countdown
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
@onready var bubble: SpeechBubble = %Bubble


var judge := Judge.new()

## The opponent's HP marks this stage carries a line for, highest first, and
## the ones already said. Crossing a mark is a one-off: the HP bar can wobble
## back up without the line repeating.
var _quotes: Array = []
var _quoted := {}

## The last thing the opponent said this run, for the result screen to show.
## Kept rather than worked out again from the final HP, because the bar can
## climb back up: a run that dipped to 25 and recovered to 45 did hear the
## 30 line, and reading it off the final 45 would claim it did not.
var _last_quote := ""
var state := State.COUNTDOWN
var _countdown_id := 0
var countdownSong = "res://sfx/Countdown.wav"
var _count_tween: Tween = null

## Windows of empty track where a tip is shown, worked out from the chart.
var _tips: Array[Dictionary] = []
var _before_tips: Array[Dictionary] = []
var _tip_showing := -1
var _tip_key := ""
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

## How far he squashes on the beat, as a fraction of his height.
const SQUISH := 0.08
## Beats per squash. 1.0 is every beat; 2.0 for every other one.
var beats_per_squish := 1.0

const ENEMY_BEAT_SHIFT := 0

var _pose_now := IDLE
var _enemy_pose: Dictionary = {}

var _has_enemy := true
var _poses: Array = []
var _pose_time := 0.0


func _ready() -> void:
	var st := Rules.stage(stage_id)
	var song_id: String = st.get("song", "song_tutorial")
	_chart = ChartParser.parse(Rules.chart_path(song_id))
	field.setup(_chart.notes)
	beats_per_squish = int(st.get("squish"))

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
	_read_quotes(st)
	_plan_tips(st)

	Events.hp_changed.connect(_on_hp_changed)
	pause_overlay.resume_pressed.connect(_resume)
	pause_overlay.restart_pressed.connect(_restart)
	pause_overlay.quit_pressed.connect(_quit_to_map)
	pause_overlay.settings_pressed.connect(_open_settings)
	settings_overlay.routed = false
	settings_overlay.closed.connect(_close_settings)
	settings_overlay.visibility_changed.connect(_sync_hints)
	result_overlay.continue_pressed.connect(GameManager.leave_stage)
	result_overlay.retry_pressed.connect(_restart)
	
	Events.note_judged.connect(_on_note_judged)

	_set_hints()
	Events.language_changed.connect(_on_language_changed)
	for o in [pause_overlay, result_overlay]:
		o.visibility_changed.connect(_sync_hints)

	# The stage has the floor from here until it is over, pauses included.
	Audio.hold(true)

	# The opening lines come before anything moves. Retrying skips them: by
	# then the player has read them once.
	await _show_before_tips()
	if not is_inside_tree():
		return
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
	_run_tips(now)
	_squish(remi, _poses[_pose_now], REMI_SCALE, _beat_pulse(now))
	_squish(enemy, _enemy_pose, ENEMY_SCALE, _beat_pulse(now, ENEMY_BEAT_SHIFT))


## Straight to the pass or the fail screen, for showing either of them
## without playing the stage out. Function keys, so they cannot collide with
## anything the controls page lets the player rebind.
const CHEAT_PASS := KEY_F5
const CHEAT_FAIL := KEY_F6


## Only while running from the editor, or on the demo profile. An exported
## release build handed to a playtester has neither, so nobody stumbles into
## it mid-song and wonders what happened.
func _cheats_on() -> bool:
	return OS.is_debug_build() or SaveManager.is_cheat(GameManager.save)


## Put the meter where the win line wants it, then go down the same path the
## end of the song takes, so the result screen is built the usual way and the
## run is banked the usual way.
func _cheat_end(pass_it: bool) -> void:
	judge.hp = 0.0 if pass_it else 100.0
	Events.hp_changed.emit(judge.hp)
	song.stop()
	_on_song_finished()


func _unhandled_input(event: InputEvent) -> void:
	# Settings is a full overlay and owns every key while it is up.
	if settings_overlay.visible:
		return
	if state == State.PLAYING and _cheats_on() and event is InputEventKey \
			and event.is_pressed() and not event.is_echo():
		var code: int = (event as InputEventKey).physical_keycode
		if code == CHEAT_PASS or code == CHEAT_FAIL:
			get_viewport().set_input_as_handled()
			_cheat_end(code == CHEAT_PASS)
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


## stages.json keys the lines by the HP they are said at, which JSON can only
## write as strings. Sorting them high to low means a single pass finds the
## lowest mark the bar has just dropped past, so a big hit that skips a mark
## still says the right line rather than the one it flew by.
func _read_quotes(st: Dictionary) -> void:
	_quotes.clear()
	_quoted.clear()
	_last_quote = ""
	bubble.clear()
	if not _has_enemy:
		return
	for at in st.get("quotes", {}):
		_quotes.append(float(at))
	_quotes.sort()
	_quotes.reverse()


func _on_hp_changed(hp: float) -> void:
	var line := ""
	for at in _quotes:
		if hp > at or _quoted.has(at):
			continue
		# Every mark the bar has passed counts as said, so a big hit that
		# clears two of them does not say the second one on the next note.
		# The loop runs high to low, so what is left is the lowest.
		_quoted[at] = true
		line = String(Rules.stage(stage_id).get("quotes", {}).get(_quote_key(at), ""))
	if line != "":
		_last_quote = line
		bubble.say(line, _bubble_target())


## JSON wrote the mark as a string, and 0.0 has to come back out as "0" rather
## than "0.0" to find it again.
func _quote_key(at: float) -> String:
	return str(int(at))


## The tail aims just inside the opponent's shoulder, so the line reads as
## coming from them. Measured off the sprite rather than written down, so
## moving the opponent moves the bubble with them.
func _bubble_target() -> Vector2:
	var rect := enemy.get_rect()
	var left := enemy.position.x + rect.position.x * enemy.scale.x
	var top := enemy.position.y + rect.position.y * enemy.scale.y
	return Vector2(left - 40.0, top + 70.0)


## Put this stage's opponent on screen. No art means no opponent.
func _show_enemy(song_id: String) -> void:
	_enemy_pose = _pose(Rules.enemy_path(song_id), ENEMY_SCALE, ENEMY_FLOOR)
	_apply(enemy, _enemy_pose, ENEMY_X, ENEMY_SCALE)


## Measure each of Remi's pictures once, so changing pose later costs nothing.
func _setup_remi() -> void:
	_poses.clear()
	for path in REMI_POSES:
		if path == "res://sprite/Remi/Remi_up.png":
			_poses.append(_pose(path, REMI_SCALE, REMI_FLOOR - 75))
		else:
			_poses.append(_pose(path, REMI_SCALE, REMI_FLOOR))
	_poses.append(_pose(REMI_IDLE, REMI_SCALE, REMI_FLOOR))
	_show_pose(IDLE)


func _show_pose(which: int) -> void:
	var pose: Dictionary = _poses[which]
	if pose.is_empty():
		pose = _poses[IDLE]
		which = IDLE
	_pose_now = which
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


## The folder this stage's song lives in, which is also its name.
func _song_id() -> String:
	return String(Rules.stage(stage_id).get("song", ""))


func _pause_info() -> String:
	var secs := int(conductor.song_time_ms() / 1000.0)
	var opp: String = Rules.stage(stage_id).get("opponent", "")
	return tr("UI_PAUSE_INFO") % [Rules.song_title(_song_id()), secs / 60, secs % 60,
		Rules.character_name(opp) if opp != "" else "—", Rules.hp_text(judge.hp)]


## How many times this stage has been played since the screen opened. _ready()
## ends by calling _restart(), so without this the first run would be logged
## as a retry of a run that never happened.
var _runs := 0


func _restart() -> void:
	# Read before the conductor is stopped, because where in the song they
	# gave up is the interesting half of a retry.
	if _runs > 0:
		Telemetry.event("retry", {"stage": stage_id,
			"at_ms": int(conductor.song_time_ms()),
			"hp": Rules.hp_display(judge.hp), "combo": judge.combo})
	# Retrying from the result screen means the bed is playing again. Take the
	# floor back now rather than leaving it under the countdown until the
	# stage's own song starts and pushes it out.
	Audio.hold(true)
	pause_overlay.hide()
	result_overlay.hide()
	song.stream_paused = false
	conductor.stop()

	field.reset()
	judge.setup(field)
	_quoted.clear()
	_last_quote = ""
	bubble.clear()
	Events.hp_changed.emit(judge.hp)
	Events.combo_changed.emit(judge.combo)
	hud.update_progress(0.0)
	for g in track.ghosts:
		g.set_pressed(false)

	state = State.COUNTDOWN
	if not await _countdown():
		return
	conductor.start()
	_runs += 1
	Telemetry.stage_started(stage_id, {"song": _song_id(),
		"notes": _chart.notes.size(), "bpm": _chart.bpm,
		"note_speed": Settings.note_speed, "offset_ms": Settings.offset})
	state = State.PLAYING


func _pause() -> void:
	_countdown_id += 1                       # invalidate a running countdown
	countdown.stop()
	state = State.PAUSED
	song.stream_paused = true
	countdown_label.modulate.a = 0.0
	Telemetry.event("pause", {"stage": stage_id,
		"at_ms": int(conductor.song_time_ms())})
	pause_overlay.open(_pause_info())


func _resume() -> void:
	Telemetry.event("resume", {"stage": stage_id})
	pause_overlay.hide()

	if not conductor.is_running():
		_restart()                           # paused before the song ever began
		return

	state = State.COUNTDOWN
	if not await _countdown():
		return
	song.stream_paused = false
	state = State.PLAYING


## Leaving part way through is worth a line of its own. A stage that is
## cleared and a stage that is walked out of both end up back on the map, and
## nothing else in the log would tell them apart.
func _quit_to_map() -> void:
	Telemetry.event("quit_to_map", {"stage": stage_id,
		"at_ms": int(conductor.song_time_ms()),
		"hp": Rules.hp_display(judge.hp)})
	GameManager.leave_stage()


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
	r.stage = tr(String(st.get("label", "")))
	r.song = Rules.song_title(_song_id())
	r.song_id = st.get("song", "")
	r.opponent = st.get("opponent", "")
	r.win_at = int(st.get("win", {}).get("value", 30))
	# Both read before anything from this run is banked, so the result can
	# tell whether this run is the one that set the record.
	r.previous_best = GameManager.best_hp_for(stage_id)
	r.previous_combo = GameManager.best_combo_for(stage_id)
	r.last_quote = _last_quote

	# Banked before the screen is built, so what it shows as the record
	# already counts this run.
	GameManager.record_combo(stage_id, int(r.get("max_combo", 0)))
	if r.won:
		Events.stage_cleared.emit(stage_id, r.hp)
	else:
		Events.stage_failed.emit(stage_id)

	# Over now, so the bed comes back under the result.
	Audio.hold(false)
	Achievements.record_run(stage_id, r.counts)

	r.best_hp = GameManager.best_hp_for(stage_id)
	r.best_combo = GameManager.best_combo_for(stage_id)
	Telemetry.stage_ended(r)
	result_overlay.show_result(r)


func _countdown() -> bool:
	_countdown_id += 1
	var my_id := _countdown_id
	countdown.play()
	for n in [3, 2, 1, tr("UI_GO")]:
		if not is_inside_tree():
			countdown.stop()
			return false          # the stage was left during the count-in
		countdown_label.text = str(n)
		_flash_count()
		await get_tree().create_timer(0.6).timeout
		if my_id != _countdown_id:
			countdown.stop()
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
	

## Splits what the stage wants to say into the lines that come before the song
## and the lines that go in the chart's quiet stretches. Working the gaps out
## from the notes means the tips follow the chart if it is ever rewritten.
func _plan_tips(stage: Dictionary) -> void:
	_tips.clear()
	_before_tips.clear()
	_tip_showing = -1
	%Tip.hide_tip()
	var wanted: Array = stage.get("tips", [])
	if wanted.is_empty():
		return

	var in_gaps: Array = []
	for raw in wanted:
		var tip: Dictionary = raw if raw is Dictionary else {"text": String(raw)}
		if String(tip.get("at", "gap")) == "before":
			_before_tips.append(tip)
		else:
			in_gaps.append(tip)

	const MIN_GAP := 2500.0
	const LEAD := 250.0        # let the last arrow clear the line first
	const TAIL := 250.0        # and be gone before the next one is due
	var gaps: Array[Vector2] = []
	for i in range(1, _chart.notes.size()):
		var from: float = _chart.notes[i - 1].t_ms
		var to: float = _chart.notes[i].t_ms
		if to - from > MIN_GAP:
			gaps.append(Vector2(from + LEAD, to - TAIL))

	for i in mini(in_gaps.size(), gaps.size()):
		var tip: Dictionary = in_gaps[i].duplicate()
		tip["window"] = gaps[i]
		_tips.append(tip)


## Shown one after another before anything starts, so the player reads them
## with nothing moving. Awaited by the opening, so the song waits for them.
func _show_before_tips() -> void:
	if _before_tips.is_empty():
		return
	await get_tree().process_frame        # let the hud lay out before pointing at it
	for tip in _before_tips:
		if not is_inside_tree():
			return            # the stage was left while the opening was running
		_tip_key = String(tip.text)
		_show_tip(_tip_target(String(tip.get("point", ""))))
		await get_tree().create_timer(3.4).timeout
		%Tip.hide_tip()
		await get_tree().create_timer(0.35).timeout


## No pausing: a tip fades in over the empty track and fades out again as the
## next run of arrows comes up.
func _run_tips(now: float) -> void:
	var wanted := -1
	for i in _tips.size():
		var w: Vector2 = _tips[i].window
		if now >= w.x and now <= w.y:
			wanted = i
			break
	if wanted == _tip_showing:
		return

	var was: int = _tip_showing
	_tip_showing = wanted
	if was != -1 and String(_tips[was].get("point", "")) == "monster_bar" and not _has_enemy:
		hud.ghost_monster(false)

	if wanted == -1:
		_tip_key = ""
		%Tip.hide_tip()
		return

	var point := String(_tips[wanted].get("point", ""))
	if point == "monster_bar" and not _has_enemy:
		hud.ghost_monster(true)
	_tip_key = String(_tips[wanted].text)
	_show_tip(_tip_target(point))


## Measured every time rather than once, because the health readout is not laid
## out yet when the stage is planned and it comes and goes with the opponent.
func _show_tip(target: Rect2) -> void:
	%Tip.keep_clear = _tip_blocks()
	%Tip.show_tip(tr(_tip_key), target)


## What a tip must not cover: the lane the arrows travel down, and the
## opponent's health, which is the one thing on screen a tip is likely to
## land on and the one the player checks while it is up.
func _tip_blocks() -> Array[Rect2]:
	var blocks: Array[Rect2] = [Rect2(0.0, track.global_position.y,
		TrackPanel.SCREEN_W, TrackPanel.ROW_H * TrackPanel.LANE_COUNT)]
	if hud.monster_bar.visible:
		blocks.append(hud.monster_label.get_global_rect()
			.merge(hud.monster_pct.get_global_rect())
			.merge(hud.monster_bar.get_global_rect()))
	return blocks


## Where on screen each thing a tip can point at actually is.
func _tip_target(point: String) -> Rect2:
	match point:
		"song_bar":
			return hud.song_bar.get_global_rect()
		"monster_bar":
			return hud.monster_bar.get_global_rect()
		"combo":
			return hud.combo_value.get_global_rect()
		"hit_line":
			var lanes := TrackPanel.ROW_H * TrackPanel.LANE_COUNT
			return Rect2(TrackPanel.HIT_X - 34.0, track.global_position.y,
				68.0, lanes)
		"lanes":
			return Rect2(420.0, track.global_position.y,
				480.0, TrackPanel.ROW_H * TrackPanel.LANE_COUNT)
	return Rect2()


func _on_note_judged(judgement: String, lane: int) -> void:
	track.pop_judgement(lane, judgement)

## Rebuilding this mid-song would restart the stage, so a language change
## leaves it alone. Its labels hold translation keys, so Godot re-translates
## them in place.
## Quitting part way through gives the floor back too.
func _exit_tree() -> void:
	Audio.hold(false)


func blocks_reload() -> bool:
	return true


## The hints and whatever tip is on screen both hold wording rather than keys,
## so both have to be redone when the language changes.
func _on_language_changed() -> void:
	_set_hints()
	if _tip_key != "":
		%Tip.set_body(tr(_tip_key))
	# This screen refuses a rebuild, so anything already drawn has to be
	# drawn again. The pause card's line was built when the pause opened.
	if pause_overlay.visible:
		pause_overlay.open(_pause_info())


func _set_hints() -> void:
	var hints: Array = [[["W", "A", "S", "D", "↑", "←", "↓", "→"],
		tr("UI_HIT_ON_GHOST")], ["Esc", tr("UI_PAUSE"), _pause]]
	if _cheats_on():
		hints.append(["F5", tr("UI_CHEAT_PASS")])
		hints.append(["F6", tr("UI_CHEAT_FAIL")])
	%Hints.set_hints(hints)


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
	

func _beat_pulse(now_ms: float, shift := 0.0) -> float:
	var bpm: float = maxf(float(_chart.get("bpm", 120.0)), 1.0)
	var beat_ms := 60000.0 / bpm * beats_per_squish
	# From the chart's own start, not the file's, or a chart with an offset
	# would put the squash between the beats.
	var since := now_ms - float(_chart.get("offset_ms", 0.0))
	var phase := fposmod(since / beat_ms - shift, 1.0)
	return pow(1.0 - phase, 4.0)


## Keeps whoever it is on the floor; only their shape moves.
func _squish(sprite: Sprite2D, pose: Dictionary, base: float, pulse: float) -> void:
	if pose.is_empty() or not sprite.visible:
		return
	sprite.scale = Vector2(base * (1.0 + SQUISH * pulse),
		base * (1.0 - SQUISH * pulse))
	# A centred sprite shrinks towards its middle, so half the height it loses
	# has to come back off the position or it floats off the floor.
	var half: float = pose.region.size.y * 0.5
	sprite.position.y = pose.y + half * (base - sprite.scale.y)

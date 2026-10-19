extends Node
## What the game records about itself while someone plays it.
##
## Playtesters sit at lab machines we cannot attach Godot's profiler to, so the
## game has to be its own instrument. Everything the test plan asks for on
## page 14 is gathered here and written beside the game, and we collect the
## files afterwards.
##
## Three rules. Nothing leaves the machine, so there is no network code here at
## all. Nothing personal is recorded, so a typed profile name is counted rather
## than copied. And every event is flushed as it is written, because a session
## that ends in a crash is the one whose log matters most.
##
## Two files per session:
##
##   session_<when>_<machine>.txt           everything, in reading order
##   session_<when>_<machine>_attempts.csv  one row per attempt, for a spreadsheet
##
## There is deliberately no row-per-second table. The earlier version had one
## and it was more data than anybody was going to read; the numbers that
## matter are per attempt, and that is how they are kept now.

## Beside the game itself, not buried in the player's AppData. The game runs
## off a USB stick: the tester plays, hands the stick back, and the session is
## sitting in a folder next to the exe. Nobody has to go looking.
##
## Falls back to the usual save folder if the folder the game sits in is read
## only, which a locked-down lab machine might well be.
const FOLDER := "sessions"

## Where the engine puts its own log, which is the only place script errors and
## engine errors actually land. Set in project.godot, read back here.
const ENGINE_LOG := "debug/file_logging/log_path"

## Four beats to a bar, matching the chart format, so a missed note's beat can
## be reported as the bar a reader would find it in.
const BEATS_PER_BAR := 4.0

## The feedback questions, in the order they are asked and in the order the
## columns come out, named here so the screen and the csv cannot drift apart.
const FEEDBACK_ORDER := ["learn", "timing", "meter", "difficulty", "looks",
	"again"]

var recording := false

var _dir := ""
var _log: FileAccess
var _csv: FileAccess
var _session := ""
var _started_ms := 0.0

## Frame times, gathered every frame. An average of 60 with one 200 ms hitch
## in it is a bad rhythm game, so the hitch has to be seen rather than
## sampled past.
var _frames: Array[float] = []
## The same frames, already added up and thrown away, so an hour of them is
## not being held in memory just to average it at the end.
var _whole_run_n := 0
var _whole_run_sum := 0.0
var _worst_frame := 0.0
var _worst_where := ""

## Where the player is, and for how long. Both halves of "time per node": the
## screen they are looking at, and the map node they are inside.
var _screen := ""
var _screen_since := 0.0
var _screen_time := {}
var _node := ""
var _node_since := 0.0
var _node_time := {}

## stage id -> {"attempts": n, "clears": n, "fails": n}, and separately how
## many times each node was walked into, which is what "replayed" means.
var _tries := {}
var _chosen := {}

## The attempt in progress.
var _stage := ""
var _attempt := 0
var _attempt_ms := 0.0
var _attempt_frames: Array[float] = []
## [lane, signed error in ms, judgement] per press, written out when the
## stage ends. Held in memory rather than flushed per press, because a press
## is the one thing here that happens faster than a file wants to be written.
var _presses: Array = []
## [lane, index in the chart, bar] per miss. A count of misses says the stage
## was hard; these say which part of it was.
var _misses: Array = []
## How busy the chart is, carried from stage_start so it can sit in the row.
var _nps := 0.0

## The audio against the wall clock, and how far apart they ever got during
## this attempt. Memory is kept as its peak, since growth over a session is
## the only thing worth knowing about it.
var _drift_ms := 0.0
var _drift_worst := 0.0
var _mem_peak := 0.0
var _live_notes := 0

## Audio drift and output latency need a real sound card to mean anything.
## With no display server there is no audio device either, so the song clock
## advances at the mixer's own rate and the drift figure measures that rather
## than the game. Those cells are left blank instead of filled with a number
## nobody should trust.
var _real_audio := true

## Which of the two the player is actually using, and how much.
var _device := ""
var _device_presses := {"keyboard": 0, "gamepad": 0}

## The engine log is appended to across runs, so remember where this session
## starts in it and read only from there.
var _engine_log_path := ""
var _engine_log_from := 0
var _problems := 0


func _ready() -> void:
	# Keeps counting while the game is paused, which is the point: a pause is
	# part of the session, and time spent in a pause menu is time spent.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_start()


func _exit_tree() -> void:
	if not recording:
		return
	_leave_screen()
	_leave_node()
	event("session_end", {"clean": true})
	_copy_engine_errors()
	_write_summary()
	_log.close()
	_csv.close()


# ---------- starting up ----------

func _start() -> void:
	_dir = _pick_folder()
	if _dir == "":
		push_warning("No session log: nowhere writable to put it")
		return

	var now := Time.get_datetime_dict_from_system()
	_session = "session_%04d-%02d-%02d_%02d%02d_%s" % [now.year, now.month,
		now.day, now.hour, now.minute, _machine()]
	_log = FileAccess.open("%s/%s.txt" % [_dir, _session], FileAccess.WRITE)
	_csv = FileAccess.open("%s/%s_attempts.csv" % [_dir, _session],
		FileAccess.WRITE)
	if _log == null or _csv == null:
		push_warning("No session log: could not open the files")
		return

	recording = true
	_real_audio = DisplayServer.get_name() != "headless"
	_started_ms = Time.get_ticks_msec()
	_note_engine_log()
	_write_header()

	# One row per attempt. Short enough to read, wide enough that the report's
	# numbers can all be taken from this one table.
	# fps_min is deliberately absent: it is 1000/worst_frame_ms, the same fact
	# written twice. frame_ms_p99 is here instead, which is the one frame
	# figure the other two cannot be turned into, and the honest number for a
	# rhythm game: the shape of the bad frames rather than the single worst.
	_csv.store_line("stage,attempt,won,stars,meter_pct,perfect,great,good,"
		+ "miss,max_combo,mean_offset_ms,spread_ms,seconds,nps,fps_avg,"
		+ "frame_ms_p99,worst_frame_ms,mem_mb,drift_ms")
	_csv.flush()


## Next to the game if that will take it, otherwise the usual save folder.
## Returns "" when neither will.
func _pick_folder() -> String:
	var tries: Array[String] = []
	# Only in an exported build. Run from the editor and "the folder the game
	# is in" is Godot's own application bundle, which is not where anybody
	# wants a playtest log, and writing there once already made a mess.
	if OS.has_feature("standalone"):
		tries.append(OS.get_executable_path().get_base_dir())
	tries.append("user://")
	for base in tries:
		var d := DirAccess.open(base)
		if d == null:
			continue
		if not d.dir_exists(FOLDER) and d.make_dir(FOLDER) != OK:
			continue
		var path: String = base.path_join(FOLDER)
		var probe := FileAccess.open(path.path_join(".check"), FileAccess.WRITE)
		if probe == null:
			continue
		probe.close()
		DirAccess.open(path).remove(".check")
		return path
	return ""


func _write_header() -> void:
	var mem := OS.get_memory_info()
	var about := {
		"session": _session,
		"started": Time.get_datetime_string_from_system(),
		"godot": Engine.get_version_info().get("string", "?"),
		"os": "%s %s" % [OS.get_name(), OS.get_version()],
		"cpu": "%s x%d" % [OS.get_processor_name(), OS.get_processor_count()],
		"gpu": "%s (%s)" % [RenderingServer.get_video_adapter_name(),
			RenderingServer.get_video_adapter_vendor()],
		"ram_total": mem.get("physical", -1),
		"screen": DisplayServer.screen_get_size(),
		"refresh_hz": DisplayServer.screen_get_refresh_rate(),
		"window": DisplayServer.window_get_size(),
		"fullscreen": Settings.fullscreen,
		# The song clock compensates for this, so a machine with unusual
		# latency explains a whole session's worth of complaints about timing.
		"audio_latency_ms": ("%.1f" % (AudioServer.get_output_latency() * 1000.0)
			if DisplayServer.get_name() != "headless" else "no audio device"),
		"language": Loc.current(),
		"note_speed": Settings.note_speed,
		"offset_ms": Settings.offset,
		"keys": _keys(),
		"engine_log": _engine_log_path,
	}
	for key in about:
		_log.store_line("# %s: %s" % [key, about[key]])
	_log.store_line("# ---")
	_log.flush()


## What the four lanes and the two menu keys are bound to at the start of the
## session. Any change after this is a rebind event, so the two together say
## what the player was pressing at any point.
func _keys() -> String:
	var parts: Array[String] = []
	for r in InputManager.ROWS:
		parts.append("%s=%s" % [r.id, InputManager.key_name(r.id)])
	return " ".join(parts)


func _machine() -> String:
	var who := OS.get_environment("COMPUTERNAME")
	if who == "":
		who = OS.get_environment("HOSTNAME")
	if who == "":
		who = OS.get_name()
	return who.validate_filename()


# ---------- events ----------

func now_ms() -> int:
	return int(Time.get_ticks_msec() - _started_ms)


func event(what: String, fields := {}) -> void:
	if not recording:
		return
	if what == "error" or fields.get("ok") == false:
		_problems += 1
	var parts: Array[String] = ["%d" % now_ms(), what]
	for key in fields:
		parts.append("%s=%s" % [key, str(fields[key]).replace("\n", " ")])
	_log.store_line("\t".join(parts))
	_log.flush()


# ---------- where the player is ----------

## The screen changed. Closes the time on the old one before opening the new.
func screen(which: String) -> void:
	if not recording or which == _screen:
		return
	_leave_screen()
	_screen = which
	_screen_since = Time.get_ticks_msec()
	event("screen", {"to": which})


func _leave_screen() -> void:
	if _screen == "":
		return
	var secs: float = (Time.get_ticks_msec() - _screen_since) / 1000.0
	_screen_time[_screen] = float(_screen_time.get(_screen, 0.0)) + secs
	_screen = ""


## A map node was walked into. Counts as a choice every time, so choosing the
## same node twice is what shows up as a replay.
func node_chosen(id: String, kind: String) -> void:
	if not recording:
		return
	_chosen[id] = int(_chosen.get(id, 0)) + 1
	_leave_node()
	_node = id
	_node_since = Time.get_ticks_msec()
	event("node_chosen", {"node": id, "type": kind,
		"time_chosen": _chosen[id]})


func node_left() -> void:
	if not recording:
		return
	_leave_node()


func _leave_node() -> void:
	if _node == "":
		return
	var secs: float = (Time.get_ticks_msec() - _node_since) / 1000.0
	_node_time[_node] = float(_node_time.get(_node, 0.0)) + secs
	_node = ""


# ---------- a run at a stage ----------

func stage_started(stage_id: String, fields := {}) -> void:
	if not recording:
		return
	_stage = stage_id
	_nps = float(fields.get("nps", 0.0))
	_misses.clear()
	_drift_worst = 0.0
	if not _tries.has(stage_id):
		_tries[stage_id] = {"attempts": 0, "clears": 0, "fails": 0}
	_tries[stage_id].attempts += 1
	_attempt = int(_tries[stage_id].attempts)
	_attempt_ms = Time.get_ticks_msec()
	_attempt_frames.clear()
	_presses.clear()
	var all := fields.duplicate()
	all["attempt"] = _attempt
	event("stage_start", all)


## One press that landed on a note. The signed offset is the measurement the
## whole plan hangs on: it says whether the windows are fair, whether this
## machine's audio is running late, and whether one lane is harder than the
## rest. Early is negative.
func note_hit(lane: int, error_ms: float, judgement: String) -> void:
	if not recording:
		return
	_presses.append([lane, error_ms, judgement])


## A note slid past without being hit. The position is the whole point: a
## count of misses says the stage was hard, this says which bar of it was.
func note_missed(lane: int, index: int, beat: float, _t_ms: float) -> void:
	if not recording:
		return
	_misses.append([lane, index, int(beat / BEATS_PER_BAR)])


## Called every frame while a song is actually running.
func playing(drift_ms: float, live_notes: int) -> void:
	if not recording:
		return
	_drift_ms = drift_ms
	_live_notes = live_notes
	if absf(drift_ms) > absf(_drift_worst):
		_drift_worst = drift_ms


func stage_ended(result: Dictionary) -> void:
	if not recording:
		return
	# A stage can be ended without having been started: the song's finished
	# signal does not care whether the countdown ever got out of the way.
	# Writing the row anyway would put an attempt 0 with no stage id in the
	# table, which is worse than saying plainly that it happened.
	if _stage == "":
		event("stage_end_unstarted", {"note":
			"a stage ended that never started, so no attempt was recorded"})
		return
	var won: bool = bool(result.get("won", false))
	if _tries.has(_stage):
		if won:
			_tries[_stage].clears += 1
		else:
			_tries[_stage].fails += 1

	var secs: float = (Time.get_ticks_msec() - _attempt_ms) / 1000.0
	var frames := _spread(_attempt_frames)
	var offs := _offset_stats()
	var counts: Dictionary = result.get("counts", {})

	var fields := result.duplicate()
	fields.erase("counts")
	# Dialogue lines and translated labels are for the screen, not the log,
	# and the stage id below says which stage it was far more usefully.
	for noise in ["last_quote", "stage", "song"]:
		fields.erase(noise)
	fields["stage"] = _stage
	fields["attempt"] = _attempt
	for key in counts:
		fields["n_" + key] = counts[key]
	fields["seconds"] = "%.0f" % secs
	fields["mean_offset_ms"] = "%.1f" % offs.mean
	fields["spread_ms"] = "%.1f" % offs.spread
	fields["mem_mb"] = "%.1f" % _mem_mb()
	if _real_audio:
		fields["drift_ms"] = "%.1f" % _drift_worst
		fields["audio_latency_ms"] = "%.1f" \
			% (AudioServer.get_output_latency() * 1000.0)
	if frames.known:
		fields["fps_avg"] = "%.1f" % frames.fps_avg
		fields["frame_ms_p99"] = "%.1f" % frames.p99
		fields["worst_frame_ms"] = "%.1f" % frames.worst
	event("stage_end", fields)

	# Every press of this attempt, kept per lane and in the order they were
	# made, so the shape of a player's timing can be seen and not guessed at.
	for lane in 4:
		var mine: Array = []
		for p in _presses:
			if int(p[0]) == lane:
				mine.append("%.0f" % float(p[1]))
		if mine.is_empty():
			continue
		event("press_offsets", {"stage": _stage, "attempt": _attempt,
			"lane": lane, "n": mine.size(), "ms": ",".join(mine)})

	# Which notes were missed, per lane and in order, so a run of misses at one
	# point in the song shows up as a run rather than as a total.
	for lane in 4:
		var bars: Array[String] = []
		for m in _misses:
			if int(m[0]) == lane:
				bars.append(str(int(m[2])))
		if bars.is_empty():
			continue
		event("misses", {"stage": _stage, "attempt": _attempt, "lane": lane,
			"n": bars.size(), "bars": ",".join(bars)})

	# And the answer to the question itself, worked out rather than left for
	# somebody to count by hand: the bars where the misses pile up.
	if not _misses.is_empty():
		var per_bar := {}
		for m in _misses:
			var bar := int(m[2])
			per_bar[bar] = int(per_bar.get(bar, 0)) + 1
		var worst_bars: Array = per_bar.keys()
		worst_bars.sort_custom(func(a, b): return per_bar[a] > per_bar[b])
		var named: Array[String] = []
		for bar in worst_bars.slice(0, mini(5, worst_bars.size())):
			named.append("%d(%d)" % [bar, per_bar[bar]])
		event("miss_clusters", {"stage": _stage, "attempt": _attempt,
			"bars_worst_first": " ".join(named)})

	_csv.store_line(",".join([
		_stage, str(_attempt), "1" if won else "0",
		str(result.get("stars", 0)), "%.1f" % float(result.get("hp", 0.0)),
		str(counts.get("perfect", 0)), str(counts.get("great", 0)),
		str(counts.get("good", 0)), str(counts.get("miss", 0)),
		str(result.get("max_combo", 0)),
		"%.1f" % offs.mean, "%.1f" % offs.spread, "%.0f" % secs,
		"%.2f" % _nps,
		# Left blank rather than zeroed when no frame went by, so a
		# spreadsheet averages the attempts that were actually measured.
		"%.1f" % frames.fps_avg if frames.known else "",
		"%.1f" % frames.p99 if frames.known else "",
		"%.1f" % frames.worst if frames.known else "",
		"%.1f" % _mem_mb(),
		"%.1f" % _drift_worst if _real_audio else "",
	]))
	_csv.flush()

	_presses.clear()
	_misses.clear()
	_attempt_frames.clear()
	_stage = ""


## Mean tells you whether the player, or the machine, is running early or
## late. Spread tells you whether they were consistent about it, which is the
## difference between a bad offset setting and a player who cannot keep time.
func _offset_stats() -> Dictionary:
	if _presses.is_empty():
		return {"mean": 0.0, "spread": 0.0}
	var total := 0.0
	for p in _presses:
		total += float(p[1])
	var mean: float = total / _presses.size()
	var sq := 0.0
	for p in _presses:
		sq += pow(float(p[1]) - mean, 2.0)
	return {"mean": mean, "spread": sqrt(sq / _presses.size())}


# ---------- frames ----------

func _process(delta: float) -> void:
	if not recording:
		return
	var ms: float = delta * 1000.0
	_frames.append(ms)
	if _stage != "":
		_attempt_frames.append(ms)
	var mem := _mem_mb()
	if mem > _mem_peak:
		_mem_peak = mem
	if ms > _worst_frame:
		_worst_frame = ms
		_worst_where = _screen if _stage == "" else _stage
	# Kept bounded. The session summary wants the whole run's average, and a
	# running one costs nothing next to holding an hour of frames in memory.
	if _frames.size() >= 600:
		_whole_run_n += _frames.size()
		for f in _frames:
			_whole_run_sum += f
		_frames.clear()


func _mem_mb() -> float:
	return Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0


## Returns known = false when no frames went by, which happens for an attempt
## that ended inside a single frame. Zero would be read as a measurement.
func _spread(frames: Array[float]) -> Dictionary:
	if frames.is_empty():
		return {"known": false, "fps_avg": 0.0, "p99": 0.0, "worst": 0.0}
	var total := 0.0
	var worst := 0.0
	for ms in frames:
		total += ms
		if ms > worst:
			worst = ms
	var avg: float = total / frames.size()
	# Sorted only for the percentile, which is the one figure that needs the
	# whole distribution rather than a running total.
	var sorted := frames.duplicate()
	sorted.sort()
	var p99: float = sorted[mini(int(sorted.size() * 0.99), sorted.size() - 1)]
	return {
		"known": true,
		"fps_avg": 1000.0 / maxf(avg, 0.001),
		"p99": p99,
		"worst": worst,
	}


# ---------- input device ----------

## Which of the two they are actually using. A tester who never touches the
## pad and one who never touches the keyboard are having different sessions,
## and nothing else in the log would say which happened.
func _input(event_in: InputEvent) -> void:
	if not recording:
		return
	var kind := ""
	if event_in is InputEventKey and (event_in as InputEventKey).pressed:
		kind = "keyboard"
	elif event_in is InputEventJoypadButton \
			and (event_in as InputEventJoypadButton).pressed:
		kind = "gamepad"
	elif event_in is InputEventJoypadMotion \
			and absf((event_in as InputEventJoypadMotion).axis_value) > 0.5:
		# Sticks report constantly, so only a real push counts as using one.
		kind = "gamepad"
	if kind == "":
		return
	_device_presses[kind] = int(_device_presses[kind]) + 1
	if kind != _device:
		_device = kind
		event("input_device", {"now": kind})


# ---------- what the tester says ----------

## One row per tester, appended to a single csv that every session adds to, so
## the whole set opens in Excel as one table rather than as a folder of files
## somebody has to paste together.
##
## Returns false when it could not be written, so the screen can say so rather
## than thanking somebody for an answer that went nowhere.
func feedback(answers: Dictionary) -> bool:
	if _dir == "":
		return false
	var path := _dir.path_join("feedback.csv")
	var fresh := not FileAccess.file_exists(path)
	var f := FileAccess.open(path, FileAccess.READ_WRITE if not fresh
		else FileAccess.WRITE)
	if f == null:
		push_warning("Could not write the feedback csv")
		return false

	var columns: Array[String] = ["when", "session", "played_before"]
	for q in FEEDBACK_ORDER:
		columns.append(q)
	if fresh:
		f.store_line(",".join(columns))
	else:
		f.seek_end()

	var row: Array[String] = [Time.get_datetime_string_from_system(), _session]
	row.append(str(int(answers.get("played_before", -1))))
	for q in FEEDBACK_ORDER:
		row.append(str(int(answers.get(q, 0))))
	f.store_line(",".join(row))
	f.close()

	event("feedback", answers)
	return true


# ---------- errors ----------

## Script errors and engine errors only ever land in Godot's own log, so the
## session file points at it and, at the end, copies this session's share of
## it in. Remembering the offset first is what keeps a previous run's errors
## from being reported as this one's.
func _note_engine_log() -> void:
	_engine_log_path = String(ProjectSettings.get_setting(ENGINE_LOG, ""))
	if _engine_log_path == "":
		return
	var f := FileAccess.open(_engine_log_path, FileAccess.READ)
	if f == null:
		_engine_log_from = 0
		return
	_engine_log_from = f.get_length()
	f.close()


func _copy_engine_errors() -> void:
	if _engine_log_path == "":
		return
	var f := FileAccess.open(_engine_log_path, FileAccess.READ)
	if f == null:
		return
	f.seek(mini(_engine_log_from, f.get_length()))
	var lines: Array[String] = []
	while not f.eof_reached():
		var line := f.get_line()
		if line.contains("ERROR") or line.contains("SCRIPT ERROR") \
				or line.contains("WARNING"):
			lines.append(line.strip_edges())
	f.close()
	if lines.is_empty():
		return
	_log.store_line("")
	_log.store_line("--- what the engine complained about ---")
	for line in lines:
		if line.contains("ERROR"):
			_problems += 1
		_log.store_line(line)
	_log.flush()


# ---------- the ending ----------

## The last thing in the file, in plain words. Whoever opens it should be able
## to tell how the session went without reading the events above it.
func _write_summary() -> void:
	var secs: float = (Time.get_ticks_msec() - _started_ms) / 1000.0
	var n := _whole_run_n + _frames.size()
	var sum := _whole_run_sum
	for f in _frames:
		sum += f

	_log.store_line("")
	_log.store_line("--- how it went ---")
	_log.store_line("played for:  %s" % _spell_time(secs))
	_log.store_line("language:    %s" % Loc.current())
	_log.store_line("input:       %s" % _spell_device())
	if n > 0:
		_log.store_line("average fps: %.1f" % (1000.0 / maxf(sum / n, 0.001)))
	_log.store_line("worst frame: %.0f ms%s" % [_worst_frame,
		"" if _worst_where == "" else " on " + _worst_where])
	_log.store_line("peak memory: %.1f MB" % _mem_peak)
	if _real_audio:
		_log.store_line("audio delay: %.1f ms as reported by the sound card"
			% (AudioServer.get_output_latency() * 1000.0))
	else:
		_log.store_line("audio delay: not measured, no audio device")
	_log.store_line("problems:    %d" % _problems)

	_log.store_line("")
	_log.store_line("time per screen:")
	for which in _screen_time:
		_log.store_line("  %-20s %s"
			% [which, _spell_time(_screen_time[which])])

	_log.store_line("")
	_log.store_line("time per node, and how often it was walked into:")
	for id in _node_time:
		_log.store_line("  %-12s %-12s chosen %d time(s)"
			% [id, _spell_time(_node_time[id]), int(_chosen.get(id, 0))])

	_log.store_line("")
	_log.store_line("attempts per stage:")
	if _tries.is_empty():
		_log.store_line("  none")
	for id in _tries:
		var t: Dictionary = _tries[id]
		_log.store_line("  %-12s %d attempt(s), %d cleared, %d failed"
			% [id, t.attempts, t.clears, t.fails])
	_log.flush()


func _spell_time(secs: float) -> String:
	# A tenth under ten seconds, because a screen passed through in a fifth of
	# a second is not "0 seconds". Minutes once there are any, because
	# "0 minutes" is not an answer either.
	if secs < 10.0:
		return "%.1f seconds" % secs
	if secs < 90.0:
		return "%.0f seconds" % secs
	return "%.0f minutes" % (secs / 60.0)


func _spell_device() -> String:
	var k := int(_device_presses.keyboard)
	var g := int(_device_presses.gamepad)
	if k + g == 0:
		return "nothing pressed"
	if g == 0:
		return "keyboard only (%d presses)" % k
	if k == 0:
		return "gamepad only (%d presses)" % g
	return "both (%d keyboard, %d gamepad)" % [k, g]

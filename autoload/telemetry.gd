extends Node
## What the game records about itself while someone plays it.
##
## Playtesters sit at machines we cannot attach a profiler to, so the game has
## to be its own instrument: a header saying what machine it is on, a row of
## counters every second, and a line for everything that happens. We collect
## the files afterwards.
##
## Three rules. Nothing leaves the machine, so there is no network code here at
## all. Nothing personal is recorded, so a typed profile name is counted rather
## than copied. And every line is flushed as it is written, because a session
## that ends in a crash is the one whose log matters most.

const DIR := "user://sessions"

## How often a row of counters is written. The frame times behind it are
## gathered every frame, not sampled at this rate: an average of 60 FPS with
## one 200 ms hitch in it is a bad rhythm game, and sampling once a second
## would miss the hitch entirely.
const SAMPLE_SECS := 1.0

## Hit error is kept as a histogram rather than a line per note: 10 ms wide,
## out to a fifth of a second either side, which covers the judgement windows
## several times over.
const BUCKET_MS := 10.0
const BUCKET_SPAN := 200.0

var recording := false

var _csv: FileAccess
var _log: FileAccess
var _session := ""

## Gathered every frame, emptied every second.
var _frames: Array[float] = []
var _since_sample := 0.0
var _started_ms := 0.0

## lane -> {bucket: count}, emptied when a stage ends.
var _hits := {}
var _stage := ""
var _context := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_start()


func _exit_tree() -> void:
	if not recording:
		return
	_flush_sample()
	event("session_end", {"clean": true})
	_csv.close()
	_log.close()


# ---------- the session ----------

func _start() -> void:
	if not SaveManager.can_write:
		push_warning("No session log: user:// cannot be written to")
		return
	var d := DirAccess.open("user://")
	if d == null:
		return
	if not d.dir_exists("sessions"):
		d.make_dir("sessions")

	_session = "%s_%s" % [
		Time.get_datetime_string_from_system().replace(":", "-"), _machine()]
	_csv = FileAccess.open("%s/%s.csv" % [DIR, _session], FileAccess.WRITE)
	_log = FileAccess.open("%s/%s.log" % [DIR, _session], FileAccess.WRITE)
	if _csv == null or _log == null:
		push_warning("No session log: could not open the files")
		return

	recording = true
	_started_ms = Time.get_ticks_msec()
	_write_header()
	# Eleven columns, not twenty-four. Everything here is either something no
	# other column can tell you, or something the event log does not already
	# say. frame_ms_avg and frame_ms_max went first: they are 1000/fps_avg
	# and 1000/fps_min, the same two facts written twice.
	_csv.store_line("t_ms,fps_avg,fps_min,frame_ms_p99,mem_static,"
		+ "node_count,orphan_count,draw_calls,scene,stage_id,"
		+ "live_notes,audio_drift_ms")
	_csv.flush()


## In the log rather than the CSV, so the CSV stays one clean table that a
## spreadsheet opens without being told how.
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
		"audio_latency_ms": "%.1f" % (AudioServer.get_output_latency() * 1000.0),
		"locale": Loc.current(),
		"note_speed": Settings.note_speed,
		"offset_ms": Settings.offset,
		"user_dir_writable": SaveManager.can_write,
	}
	for key in about:
		_log.store_line("# %s: %s" % [key, about[key]])
	_log.store_line("# ---")
	_log.flush()


func _machine() -> String:
	var who := OS.get_environment("COMPUTERNAME")
	if who == "":
		who = OS.get_environment("HOSTNAME")
	if who == "":
		who = OS.get_name()
	return who.validate_filename()


# ---------- the counters ----------

func _process(delta: float) -> void:
	if not recording:
		return
	_frames.append(delta * 1000.0)
	_since_sample += delta
	if _since_sample >= SAMPLE_SECS:
		_flush_sample()


func _flush_sample() -> void:
	if not recording or _frames.is_empty():
		return

	var sorted := _frames.duplicate()
	sorted.sort()
	var total := 0.0
	for ms in sorted:
		total += ms
	var avg: float = total / sorted.size()
	var worst: float = sorted[-1]
	var p99: float = sorted[mini(int(sorted.size() * 0.99), sorted.size() - 1)]

	var row: Array = [
		roundi(Time.get_ticks_msec() - _started_ms),
		"%.1f" % (1000.0 / maxf(avg, 0.001)),
		"%.1f" % (1000.0 / maxf(worst, 0.001)),
		# Kept beside the two above because it is the one frame figure they
		# cannot be turned into: the shape of the bad frames, not the worst.
		"%.2f" % p99,
		int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		_context.get("scene", ""),
		_context.get("stage_id", ""),
		_context.get("live_notes", 0),
		"%.1f" % float(_context.get("audio_drift_ms", 0.0)),
	]
	var text: Array[String] = []
	for cell in row:
		text.append(str(cell))
	_csv.store_line(",".join(text))
	_csv.flush()
	_frames.clear()
	_since_sample = 0.0


## What the game is doing right now, so a spike in the counters can be pinned
## to a screen and a moment rather than guessed at. Anything left out keeps
## its last value.
func context(now: Dictionary) -> void:
	for key in now:
		_context[key] = now[key]


# ---------- the events ----------

func event(what: String, fields := {}) -> void:
	if not recording:
		return
	var parts: Array[String] = ["%d" % (Time.get_ticks_msec() - _started_ms), what]
	for key in fields:
		parts.append("%s=%s" % [key, str(fields[key]).replace("\n", " ")])
	_log.store_line("\t".join(parts))
	_log.flush()


## Kept per lane and written out when the stage ends. This is the measurement
## that answers whether the windows are fair, whether this machine's audio is
## running late, and whether one lane is harder than the others.
func note_hit(lane: int, error_ms: float, judgement: String) -> void:
	if not recording:
		return
	if not _hits.has(lane):
		_hits[lane] = {}
	var bucket := roundi(clampf(error_ms, -BUCKET_SPAN, BUCKET_SPAN) / BUCKET_MS)
	_hits[lane][bucket] = int(_hits[lane].get(bucket, 0)) + 1


func stage_started(stage_id: String, fields := {}) -> void:
	_stage = stage_id
	_hits.clear()
	event("stage_start", fields)


func stage_ended(result: Dictionary) -> void:
	var fields := result.duplicate()
	fields.erase("counts")
	for key in result.get("counts", {}):
		fields["n_" + key] = result.counts[key]
	event("stage_end", fields)
	for lane in _hits:
		event("hit_error", {"stage": _stage, "lane": lane,
			"bucket_ms": BUCKET_MS, "buckets": _hits[lane]})
	_hits.clear()
	_stage = ""

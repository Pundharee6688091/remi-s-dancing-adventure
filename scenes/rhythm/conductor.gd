class_name Conductor
extends Node

var offset_ms := 0.0

var _song: AudioStreamPlayer = null
var _running := false

## Wall clock reading from the moment the audio was actually heard to be
## playing, which is what the song's own clock gets compared against.
var _began_ms := 0.0
var _clock_set := false

func setup(song: AudioStreamPlayer) -> void:
	_song = song
	_refresh_offset()
	# So the offset row can be nudged while the song is paused and felt on
	# the very next note, rather than only on the next stage.
	if not Settings.changed.is_connected(_refresh_offset):
		Settings.changed.connect(_refresh_offset)


## The data file sets the baseline; the player's setting shifts it.
func _refresh_offset() -> void:
	offset_ms = float(Rules.data.get("user_offset_ms", 0)) + float(Settings.offset)

func start() -> void:
	_song.play()
	_running = true
	_clock_set = false

func stop() -> void:
	_song.stop()
	_running = false
	
func is_running() -> bool:
	return _running

func song_time_ms() -> float:
	if not _running or _song == null:
		return 0.0
	return (_song.get_playback_position()
		+ AudioServer.get_time_since_last_mix()
		- AudioServer.get_output_latency()) * 1000.0 + offset_ms

## How far the audio has slipped against the wall clock, in milliseconds.
## Deliberately the raw playback position, with neither the offset setting nor
## the mix compensation in it: those are constants, and what matters here is
## whether the gap grows. Desync has no symptom a frame counter can see, so
## this is the only thing that makes it a number.
func drift_ms() -> float:
	if not _running or _song == null:
		return 0.0
	var pos: float = _song.get_playback_position()
	# The baseline waits until the audio is genuinely playing. Taken at
	# play() instead, it measures the sound card's start-up delay once and
	# then reports that same delay forever as though it were drift, which is
	# exactly the wrong answer: what matters is whether the gap grows.
	# A finished stream reports position 0 while this clock keeps running, so
	# the last frames of every song produced a reading of minus the whole
	# song length. Across 181 playtest attempts that spurious value was the
	# largest seen every single time, and it was the only thing the drift
	# column ever reported. Position 0 means not playing, not drifted.
	if pos <= 0.0:
		return 0.0
	if not _clock_set:
		_clock_set = true
		_began_ms = Time.get_ticks_msec() - pos * 1000.0
	return pos * 1000.0 - (Time.get_ticks_msec() - _began_ms)


func song_length_ms() -> float:
	if _song == null or _song.stream == null:
		return 0.0
	return _song.stream.get_length() * 1000.0

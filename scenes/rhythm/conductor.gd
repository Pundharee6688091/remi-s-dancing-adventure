class_name Conductor
extends Node

var offset_ms := 0.0

var _song: AudioStreamPlayer = null
var _running := false

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

func song_length_ms() -> float:
	if _song == null or _song.stream == null:
		return 0.0
	return _song.stream.get_length() * 1000.0

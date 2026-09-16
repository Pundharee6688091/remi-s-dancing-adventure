class_name Conductor
extends Node

var offset_ms := 0.0

var _song: AudioStreamPlayer = null
var _running := false

func setup(song: AudioStreamPlayer) -> void:
	_song = song
	offset_ms = float(Rules.data.get("user_offset_ms", 0))

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

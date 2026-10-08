extends Node
## The six settings from Settings.dc.html, saved to user://settings.cfg.
## Changes apply and save immediately, so there is no Apply button.

signal changed()

const PATH := "user://settings.cfg"

## Note speed is an index 1..10. 5 means the speed in gameRule.json, so a
## player can go slower or faster without the data file being wrong.
const SPEED_STEPS := 10
const SPEED_DEFAULT := 5

## Audio offset in milliseconds. Positive means the chart is read later, for
## headphones or a TV that lag behind.
const OFFSET_RANGE := 200
const OFFSET_STEP := 5

## How far below full the quietest audible slider step sits.
const MIN_DB := -40.0

var music := 80
var sfx := 70
var note_speed := SPEED_DEFAULT
var fullscreen := false
var offset := 0


func _ready() -> void:
	load_settings()


## The multiplier gameplay should apply to the chart's base note speed.
func speed_scale() -> float:
	return float(note_speed) / float(SPEED_DEFAULT)


func set_value(key: String, value: Variant) -> void:
	match key:
		"music":
			music = clampi(int(value), 0, 100)
		"sfx":
			sfx = clampi(int(value), 0, 100)
		"note_speed":
			note_speed = clampi(int(value), 1, SPEED_STEPS)
		"fullscreen":
			fullscreen = bool(value)
		"offset":
			offset = clampi(int(value), -OFFSET_RANGE, OFFSET_RANGE)
		_:
			return
	apply()
	save_settings()
	changed.emit()


func apply() -> void:
	_set_bus("Music", music)
	_set_bus("SFX", sfx)

	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen
		else DisplayServer.WINDOW_MODE_WINDOWED)


## Silence is -inf dB, not 0, so a zero slider mutes rather than playing
## very quietly.
##
## The slider is read as decibels rather than as raw amplitude. Loudness is
## not linear in amplitude: a straight percentage puts the whole top half of
## the travel inside 6 dB, which is barely a change, and crams everything
## audible into the last few steps before zero. Spread over MIN_DB instead,
## every step of 5 is a steady 2 dB.
func _set_bus(name: String, percent: int) -> void:
	var bus := AudioServer.get_bus_index(name)
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, percent == 0)
	if percent > 0:
		AudioServer.set_bus_volume_db(bus, lerpf(MIN_DB, 0.0, percent / 100.0))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music)
	cfg.set_value("audio", "sfx", sfx)
	cfg.set_value("gameplay", "note_speed", note_speed)
	cfg.set_value("gameplay", "offset", offset)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.save(PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		music = clampi(int(cfg.get_value("audio", "music", music)), 0, 100)
		sfx = clampi(int(cfg.get_value("audio", "sfx", sfx)), 0, 100)
		note_speed = clampi(int(cfg.get_value("gameplay", "note_speed", note_speed)),
			1, SPEED_STEPS)
		offset = clampi(int(cfg.get_value("gameplay", "offset", offset)),
			-OFFSET_RANGE, OFFSET_RANGE)
		fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))
	apply()

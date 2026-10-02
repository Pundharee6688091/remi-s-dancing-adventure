class_name PauseOverlay
extends Control
## Layout lives in pause_overlay.tscn.

signal resume_pressed
signal restart_pressed
signal quit_pressed

@onready var _info: Label = %Info
@onready var _resume: Button = %Resume


func _ready() -> void:
	UIKit.trap_focus([%Resume, %Restart, %Quit])

	_set_hints()
	Events.language_changed.connect(_set_hints)

	hide()


func _set_hints() -> void:
	%Hints.set_hints([[["↑", "↓"], tr("UI_MOVE")], ["Enter", tr("UI_SELECT")],
		["Esc", tr("UI_RESUME")]])


func open(info := "") -> void:
	_info.text = info
	show()
	_resume.grab_focus()


func _on_resume_pressed() -> void:
	resume_pressed.emit()


func _on_restart_pressed() -> void:
	restart_pressed.emit()


func _on_quit_pressed() -> void:
	quit_pressed.emit()

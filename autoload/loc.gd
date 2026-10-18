extends Node

const LOCALES := ["en", "th"]
const PATH := "user://language.cfg"


func _ready() -> void:
	var saved := "en"
	if FileAccess.file_exists(PATH):
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			saved = f.get_as_text().strip_edges()
	apply(saved if saved in LOCALES else "en")


## Switches menus and dialogue together, and remembers the choice.
func apply(code: String) -> void:
	if not code in LOCALES:
		return
	TranslationServer.set_locale(code)
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(code)
	Events.language_changed.emit()


func current() -> String:
	return TranslationServer.get_locale().substr(0, 2)


func toggle() -> void:
	apply("th" if current() == "en" else "en")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_language"):
		get_viewport().set_input_as_handled()
		toggle()

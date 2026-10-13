extends Control
## The list from data/achievements.json, one row each, earned ones first.
## Layout lives in achievements.tscn and achievement_row.tscn.

const ROW := preload("res://scenes/ui/parts/achievement_row.tscn")
const MONTHS := ["UI_MON_1", "UI_MON_2", "UI_MON_3", "UI_MON_4", "UI_MON_5", "UI_MON_6",
	"UI_MON_7", "UI_MON_8", "UI_MON_9", "UI_MON_10", "UI_MON_11", "UI_MON_12"]


func _ready() -> void:
	_set_hints()
	Events.language_changed.connect(_refresh)
	_refresh()
	%List.get_parent().grab_focus()


func _set_hints() -> void:
	%Hints.set_hints([[["↑", "↓"], tr("UI_SCROLL")], ["Esc", tr("UI_BACK")]])


func _refresh() -> void:
	_set_hints()
	for old in %List.get_children():
		%List.remove_child(old)
		old.queue_free()

	var earned := 0
	for entry in Achievements.list:
		if Achievements.is_earned(String(entry.get("id", ""))):
			earned += 1
	%Count.text = tr("UI_ACH_COUNT") % [earned, Achievements.list.size()]

	# Earned first, so what has been done reads before what has not.
	var sorted: Array = Achievements.list.duplicate()
	sorted.sort_custom(_done_first)
	for entry in sorted:
		%List.add_child(_row_for(entry))


func _done_first(a: Dictionary, b: Dictionary) -> bool:
	var ea := Achievements.is_earned(String(a.get("id", "")))
	var eb := Achievements.is_earned(String(b.get("id", "")))
	if ea != eb:
		return ea
	return false


func _row_for(entry: Dictionary) -> Control:
	var row := ROW.instantiate()
	var id := String(entry.get("id", ""))
	row.get_node("%Name").text = tr(String(entry.get("name", "")))
	row.get_node("%Desc").text = tr(String(entry.get("desc", "")))
	
	var state: Label = row.get_node("%State")
	if Achievements.is_earned(id):
		state.text = tr("UI_ACH_UNLOCKED") % _pretty(Achievements.earned_on(id))
		state.add_theme_color_override("font_color", Palette.AMBER_INK)
		row.get_node("%Complete?").color = Color(Palette.AMBER)
	else:
		state.text = "%d%%" % roundi(Achievements.progress(entry) * 100.0)
		state.add_theme_color_override("font_color", Palette.MUTED)
		# a swatch, not a word, so it keeps the light grey rather than the
		# darker one secondary text uses now
		row.get_node("%Complete?").color = Color(Palette.HAIRLINE)
		row.modulate.a = 0.75
	return row


## "2026-10-11" as "11 Oct", in whichever language is on.
func _pretty(iso: String) -> String:
	var bits := iso.split("-")
	if bits.size() != 3:
		return iso
	var month := int(bits[1])
	if month < 1 or month > 12:
		return iso
	return "%d %s" % [int(bits[2]), tr(MONTHS[month - 1])]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		SceneRouter.back()

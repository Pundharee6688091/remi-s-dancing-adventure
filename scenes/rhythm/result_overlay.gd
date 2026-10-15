class_name ResultOverlay
extends Control
## Layout lives in result_overlay.tscn, built from ResultClear.dc.html.
## A full-screen page rather than a card: opponent on the left, the numbers
## on the right. No score panel, since the monster's HP is the score.

signal continue_pressed
signal retry_pressed

const JUDGEMENTS := ["perfect", "great", "good", "miss"]

## The run this screen is showing. Kept because the battle refuses to be
## rebuilt, so switching language here has to redraw the page from the same
## numbers rather than waiting for a rebuild that never comes.
var _shown := {}

## The small line under the combo, and the stamp across the meter panel.
## Made here rather than in the scene so the blocks they hang on keep
## whatever shape the layout gives them.
var _combo_tag: Label
var _stamp: Label


func _ready() -> void:
	_make_record_tags()
	_set_hints()
	Events.language_changed.connect(_on_language_changed)
	hide()


func _on_language_changed() -> void:
	_set_hints()
	if not visible or _shown.is_empty():
		return
	# Whichever button the player was on stays the one they are on.
	var had: Control = get_viewport().gui_get_focus_owner()
	_fill(_shown)
	_set_buttons(_shown.won)          # the button labels are translated too
	if had != null and is_instance_valid(had):
		had.grab_focus()


const STAMP_TILT := -7.0
const STAMP_INSET := Vector2(26.0, 14.0)


func _make_record_tags() -> void:
	_combo_tag = Label.new()
	_combo_tag.add_theme_font_size_override("font_size", 13)
	_combo_tag.add_theme_color_override("font_color", Palette.AMBER_INK)
	_combo_tag.visible = false
	%BestCombo.add_child(_combo_tag)

	# Across the top right of the meter panel, leaning, like something
	# stamped on a page rather than another figure in a column. Hung off the
	# page itself rather than put in the panel's row, because a container
	# lays its children out square and a stamp in one would sit up straight.
	_stamp = Label.new()
	_stamp.add_theme_font_size_override("font_size", 30)
	_stamp.add_theme_color_override("font_color", Palette.AMBER_INK)
	_stamp.rotation_degrees = STAMP_TILT
	_stamp.visible = false
	add_child(_stamp)
	%Hp.item_rect_changed.connect(_place_stamp)


## Pinned to the meter panel's own top right corner, so it follows the panel
## whatever the wording underneath does to the layout.
func _place_stamp() -> void:
	if _stamp == null:
		return
	var panel: Control = %Hp
	var wide: float = maxf(_stamp.size.x, _stamp.get_minimum_size().x)
	_stamp.pivot_offset = Vector2(wide, 0.0)
	_stamp.global_position = panel.global_position \
		+ Vector2(panel.size.x - wide - STAMP_INSET.x, STAMP_INSET.y)


func _set_hints() -> void:
	%Hints.set_hints([[["←", "→"], tr("UI_MOVE")], ["Enter", tr("UI_CONFIRM")]])


func show_result(r: Dictionary) -> void:
	_shown = r
	_fill(r)
	_set_buttons(r.won)
	show()


## Everything the page says, from the run alone. Separate from show_result so
## a language change can run it again without re-opening the screen.
func _fill(r: Dictionary) -> void:
	var won: bool = r.won
	var opponent: String = r.get("opponent", "")
	var named := Rules.character_name(opponent)
	var win_at: int = r.get("win_at", 30)

	%Title.text = tr("UI_STAGE_CLEAR_TITLE") if won else tr("UI_STAGE_FAILED_TITLE")
	%Title.add_theme_color_override("font_color", Palette.INK if won else Palette.RED_INK)
	%Sub.text = tr("UI_RESULT_SUB") % [tr("UI_STAGE") % r.get("stage", ""), r.get("song", "")]

	var art := UIKit.cropped_texture(Rules.enemy_path(r.get("song_id", "")))
	%Portrait.texture = art
	# The tutorial has no opponent, so an empty placeholder box would read
	# as a missing asset rather than as "there is nobody here".
	%Art.visible = art != null
	%RemiDoneNotDone._done(won)
	if opponent == "":
		%Flavour.text = ""
	elif r.get("last_quote", "") != "":
		# What they actually said this run beats anything written about them.
		%Flavour.text = tr("UI_QUOTED") % tr(r.last_quote)
	elif won:
		%Flavour.text = tr("UI_TOO_TIRED") % named
	else:
		# A losing run already has the reason under this line, in numbers.
		# Cheering the player on above it only said the same thing twice.
		%Flavour.text = ""
	%Reason.text = "" if won else tr("UI_FAIL_REASON") % [Rules.hp_text(r.hp), win_at]

	%Join.visible = won and opponent != ""
	%JoinText.text = tr("UI_JOINED") % named
	%RewardText.text = tr("UI_JOINED") % named if won and opponent != "" \
		else tr("UI_NO_REWARD")

	# Nothing to beat means nothing to pass or fail, so the health panel and
	# the reward line would both be answering a question nobody asked.
	var judged := opponent != ""
	%Hp.visible = judged
	%Reward.visible = judged
	if judged:
		%HpValue.text = "%s%%" % Rules.hp_text(r.hp)
		%WinLine.text = tr("UI_WIN_LINE") % win_at
		%HpBar.value = r.hp / 100.0
		%HpBar.marker = win_at / 100.0

	# The best meter is gone: it said the same thing as the big figure at the
	# top of the page, only older.
	%BestCombo.visible = true
	%BestComboValue.text = str(int(r.get("best_combo", r.get("max_combo", 0))))

	# Said only where this run is the one that set the record. The numbers
	# already count it, so without this there is nothing to tell a record
	# just taken from one standing since weeks ago.
	_stamp.text = tr("UI_NEW_RECORD")
	_stamp.visible = judged \
		and int(r.get("hp", 100)) < int(r.get("previous_best", 100))
	_place_stamp()
	_combo_tag.text = tr("UI_NEW_RECORD")
	_combo_tag.visible = int(r.get("max_combo", 0)) > int(r.get("previous_combo", 0))

	var c: Dictionary = r.counts
	var total := 0
	for j in JUDGEMENTS:
		total += int(c[j])
	for j in JUDGEMENTS:
		var cap: String = String(j).capitalize()
		get_node("%Bar" + cap).value = float(c[j]) / maxf(total, 1)
		(get_node("%Count" + cap) as Label).text = str(c[j])

	%NotesValue.text = "%d / %d" % [total - int(c.miss), total]
	%StarsValue.text = "★".repeat(r.stars) + "☆".repeat(3 - r.stars)


## A cleared stage offers Continue first. A failed one offers Retry first and
## never offers Continue, since there is nothing to continue to.
func _set_buttons(won: bool) -> void:
	if won:
		%Continue.text = tr("UI_CONTINUE")
		%Continue.custom_minimum_size = Vector2(220, 0)
		%Retry.text = tr("UI_RETRY")
		%Retry.custom_minimum_size = Vector2(260, 0)
		%Buttons.move_child(%Continue, 0)
		%Continue.grab_focus()
	else:
		%Continue.text = tr("UI_BACK_TO_MAP")
		%Continue.custom_minimum_size = Vector2(220, 0)
		%Retry.text = tr("UI_RETRY_SHORT")
		%Retry.custom_minimum_size = Vector2(220, 0)
		%Buttons.move_child(%Retry, 0)
		%Retry.grab_focus()
	UIKit.trap_focus([%Buttons.get_child(0), %Buttons.get_child(1)])


func _on_continue_pressed() -> void:
	continue_pressed.emit()


func _on_retry_pressed() -> void:
	retry_pressed.emit()

class_name ResultOverlay
extends Control
## Layout lives in result_overlay.tscn, built from ResultClear.dc.html.
## A full-screen page rather than a card: opponent on the left, the numbers
## on the right. No score panel, since the monster's HP is the score.

signal continue_pressed
signal retry_pressed

const JUDGEMENTS := ["perfect", "great", "good", "miss"]


func _ready() -> void:
	_set_hints()
	Events.language_changed.connect(_set_hints)
	hide()


func _set_hints() -> void:
	%Hints.set_hints([[["←", "→"], tr("UI_MOVE")], ["Enter", tr("UI_CONFIRM")]])


func show_result(r: Dictionary) -> void:
	var won: bool = r.won
	var opponent: String = r.get("opponent", "")
	var win_at: int = r.get("win_at", 30)

	%Title.text = tr("UI_STAGE_CLEAR_TITLE") if won else tr("UI_STAGE_FAILED_TITLE")
	%Title.add_theme_color_override("font_color", Palette.INK if won else Palette.RED)
	%Sub.text = tr("UI_RESULT_SUB") % [tr("UI_STAGE") % r.get("stage", ""), r.get("song", "")]

	var art := UIKit.cropped_texture(Rules.enemy_path(r.get("song_id", "")))
	%Portrait.texture = art
	# The tutorial has no opponent, so an empty placeholder box would read
	# as a missing asset rather than as "there is nobody here".
	%Art.visible = art != null

	if opponent == "":
		%Flavour.text = ""
	elif r.get("last_quote", "") != "":
		# What they actually said this run beats anything written about them.
		%Flavour.text = tr("UI_QUOTED") % tr(r.last_quote)
	elif won:
		%Flavour.text = tr("UI_TOO_TIRED") % opponent
	else:
		%Flavour.text = tr("UI_STILL_FIGHT") % opponent
	%Reason.text = "" if won else tr("UI_FAIL_REASON") % [r.hp, win_at]

	%Join.visible = won and opponent != ""
	%JoinText.text = tr("UI_JOINED") % opponent
	%RewardText.text = tr("UI_JOINED") % opponent if won and opponent != "" \
		else tr("UI_NO_REWARD")

	# Nothing to beat means nothing to pass or fail, so the health panel and
	# the reward line would both be answering a question nobody asked.
	var judged := opponent != ""
	%Hp.visible = judged
	%Reward.visible = judged
	if judged:
		%HpValue.text = "%d%%" % r.hp
		%WinLine.text = tr("UI_WIN_LINE") % win_at
		%HpBar.value = r.hp / 100.0
		%HpBar.marker = win_at / 100.0

	# The records, already counting this run.
	%Best.visible = judged
	%BestValue.text = "%d%%" % int(r.get("best_hp", r.hp))
	%BestCombo.visible = true
	%BestComboValue.text = str(int(r.get("best_combo", r.get("max_combo", 0))))

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

	_set_buttons(won)
	show()


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

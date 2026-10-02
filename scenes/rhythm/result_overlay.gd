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
	%Title.text = tr("UI_STAGE_CLEAR_TITLE") if r.won else tr("UI_STAGE_FAILED_TITLE")
	%Sub.text = tr("UI_RESULT_SUB") % [tr("UI_STAGE") % r.get("stage", ""), r.get("song", "")]

	var opponent: String = r.get("opponent", "")
	%Portrait.texture = UIKit.cropped_texture(Rules.enemy_path(r.get("song_id", "")))
	%Flavour.text = tr("UI_TOO_TIRED") % opponent if r.won and opponent != "" else ""
	%Join.visible = r.won and opponent != ""
	%JoinText.text = tr("UI_JOINED") % opponent
	%Reward.visible = r.won and opponent != ""
	%RewardText.text = tr("UI_JOINED") % opponent

	var win_at: int = r.get("win_at", 30)
	%HpValue.text = "%d%%" % r.hp
	%WinLine.text = tr("UI_WIN_LINE") % win_at
	%HpBar.value = r.hp / 100.0
	%HpBar.marker = win_at / 100.0

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

	show()
	%Continue.grab_focus()
	UIKit.trap_focus([%Continue, %Retry])


func _on_continue_pressed() -> void:
	continue_pressed.emit()


func _on_retry_pressed() -> void:
	retry_pressed.emit()

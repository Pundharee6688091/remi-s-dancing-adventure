extends PanelContainer

const REMI_DONE = preload("res://Others/Achievement_done.png")
const REMI_NOT_DONE = preload("res://Others/Achievement_notdone.png")

func _done (done: bool) -> void:
	if done:
		%Complete.color = Color(Palette.AMBER)
		%RemiIcon.texture = REMI_DONE
	else:
		%Complete.color = Color(Palette.HAIRLINE)
		%RemiIcon.texture = REMI_NOT_DONE
	

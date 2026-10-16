extends CanvasLayer
## The card that slides in when something is earned. Lives above every screen,
## put there by the Achievements autoload, so it survives a scene change and
## no screen has to remember to carry it.
##
## Earning two things at once is normal, since everything is looked over at
## the end of a run, so they queue and come one after another rather than
## landing on top of each other.

const HOLD := 2.6
const MOVE := 0.35
const FADE := 0.4
const SLIDE := 60.0

var _queue: Array[Dictionary] = []
var _busy := false

## What is on the card now, so a language change can set it again. The labels
## hold finished words, which cannot be translated a second time.
var _showing := {}

@onready var _card: Control = %Card


func _ready() -> void:
	# This sits above every screen rather than inside one, so it is anchored
	# to the window and has to be nudged back onto the game: on a screen that
	# is not 16:9 the window's bottom right corner is out in the padding.
	get_viewport().size_changed.connect(_follow_stage)
	_follow_stage()
	_card.modulate.a = 0.0
	# The same badge the achievements screen uses, always in its earned
	# state, since nothing unearned ever gets a card.
	%Icon._done(true)
	Achievements.earned.connect(_on_earned)
	Events.language_changed.connect(_retext)


func _follow_stage() -> void:
	offset = -SceneRouter.stage_rect().position


func _on_earned(id: String) -> void:
	Audio.play("achievement")
	for entry in Achievements.list:
		if String(entry.get("id", "")) == id:
			_queue.append(entry)
			break
	_next()


func _next() -> void:
	if _busy or _queue.is_empty():
		return
	_busy = true
	_showing = _queue.pop_front()
	_retext()

	# Measured after the words are in, or a long name slides in from the
	# wrong place and jumps once the card has been laid out.
	await get_tree().process_frame
	var home := _card.position
	_card.position = home + Vector2(SLIDE, 0.0)

	# parallel() and chain() rather than set_parallel: set_parallel(true)
	# joins whatever came before, which put the fade out alongside the hold
	# instead of after it and flashed the card by in half a second.
	var t := create_tween()
	t.tween_property(_card, "modulate:a", 1.0, FADE)
	t.parallel().tween_property(_card, "position", home, MOVE) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_interval(HOLD)
	t.chain().tween_property(_card, "modulate:a", 0.0, FADE)
	t.parallel().tween_property(_card, "position", home + Vector2(SLIDE, 0.0), MOVE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(func() -> void:
		_card.position = home
		_busy = false
		_showing = {}
		_next())


func _retext() -> void:
	if _showing.is_empty():
		return
	%Got.text = tr("UI_ACH_GOT")
	%Name.text = tr(String(_showing.get("name", "")))
	%Desc.text = tr(String(_showing.get("desc", "")))

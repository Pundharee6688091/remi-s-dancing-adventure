extends Node

signal hp_changed(hp: float)
signal combo_changed(combo: int)
signal note_judged(judgement: String, lane: int)
signal song_finished()
signal stage_cleared(stage_id: String, hp: float)
signal stage_failed(stage_id: String)
signal progress_changed()
signal story_finished()
signal language_changed()

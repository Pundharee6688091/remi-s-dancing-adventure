extends Node

signal hp_changed(hp: float)
signal note_judged(judgement: String)
signal song_finished()
signal stage_cleared(stage_id: String, stars: int)
signal stage_failed(stage_id: String)

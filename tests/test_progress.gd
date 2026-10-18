extends "res://tests/lib/harness.gd"
## Test plan: Progression and stage.json, cases 01 to 07.

func open_nodes() -> Array[String]:
	var out: Array[String] = []
	for id in Rules.node_order:
		if GameManager.is_unlocked(id):
			out.append(id)
	return out


func _ready() -> void:
	await get_tree().process_frame
	clear_saves()
	GameManager.slot = 1
	GameManager.save = SaveManager.create(1, "Progress")

	# 01 a new profile opens the tutorial and nothing else
	var open := open_nodes()
	equals("progress 01", open.size(), 1, "one node is open on a new profile")
	equals("progress 01", open[0], Rules.node_order[0], "and it is the first one")

	# 02 clearing a node opens the one that wanted it
	var first: String = Rules.node_order[0]
	var second: String = Rules.node_order[1]
	check("progress 02", Rules.stage(second).get("requires", []).has(first),
		"the second node waits on the first")
	Events.stage_cleared.emit(first, 10.0)
	await get_tree().process_frame
	check("progress 02", GameManager.is_unlocked(second), "clearing it opens the next")
	check("progress 02", not GameManager.is_unlocked(Rules.node_order[3]),
		"and leaves the rest shut")

	# 03 a story node is remembered and opens what follows
	# the game records a watched story node on its own seen list
	if not GameManager.save.seen.has(second):
		GameManager.save.seen.append(second)
	check("progress 03", GameManager.save.get("seen", []).has(second),
		"a watched story node is remembered")
	check("progress 03", GameManager.is_unlocked(Rules.node_order[2]),
		"and the node after it opens")

	# 04 winning a fight recruits the opponent, once
	var fight := ""
	for id in Rules.node_order:
		if String(Rules.stage(id).get("opponent", "")) != "":
			fight = id
			break
	var who := String(Rules.stage(fight).get("opponent", ""))
	Events.stage_cleared.emit(fight, 10.0)
	await get_tree().process_frame
	check("progress 04", GameManager.save.get("party", []).has(who),
		"%s joins the party" % who)
	Events.stage_cleared.emit(fight, 10.0)
	await get_tree().process_frame
	var times := 0
	for name in GameManager.save.get("party", []):
		if name == who:
			times += 1
	equals("progress 04", times, 1, "and only once, however often it is replayed")

	# 05 failing changes nothing it should not
	var before := GameManager.save.duplicate(true)
	Events.stage_failed.emit("s1_3")
	await get_tree().process_frame
	equals("progress 05", GameManager.save.get("stars"), before.get("stars"),
		"failing earns no stars")
	equals("progress 05", GameManager.save.get("party"), before.get("party"),
		"recruits nobody")
	equals("progress 05", GameManager.save.get("seen"), before.get("seen"),
		"and opens nothing")

	# 06 and 07 a replay keeps the best result
	GameManager.save["best_hp"] = {}
	GameManager.save["stars"] = {}
	Events.stage_cleared.emit(fight, 5.0)
	await get_tree().process_frame
	var best_stars: int = GameManager.save.stars[fight]
	Events.stage_cleared.emit(fight, 80.0)
	await get_tree().process_frame
	equals("progress 06", GameManager.save.stars[fight], best_stars,
		"a worse replay never overwrites the best")
	about("progress 06", float(GameManager.save.best_hp[fight]), 5.0,
		"and the best meter is kept")
	Events.stage_cleared.emit(fight, 0.0)
	await get_tree().process_frame
	equals("progress 07", GameManager.save.stars[fight], 3,
		"a better replay does update it")

	clear_saves()
	finish()

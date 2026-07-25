extends Node
## THE SAGA BEATS PLAY GROUND-NATIVE (user, 2026-07-25: story first — Epharon must be
## completely playable). The two planet campaign beats are dirtside_run (hand the crate to
## Imari) and the_hermit (hear the Counter in his cave). Both used to route through the
## spatialized dock panel — a desk pip behind a tab behind [E]. Now [E] on the PERSON
## presents the conversation right there over the town, and finishing it advances the
## quest. This proves the whole chain: landing queues the talk → the NPC has business →
## [E] presents a DialoguePanel → closing it advances the campaign.
##   <godot> --headless --path . res://tools/test_ground_saga.tscn

var _fails := 0


func _ready() -> void:
	var town: Node = load("res://scenes/ground/epharon_town.tscn").instantiate()
	add_child(town)
	for _i in 4:
		await get_tree().physics_frame

	# ---- BEAT 1: dirtside_run — the crate hand-off ----
	Quests.pending_talks.clear()
	Quests.active.clear()
	Quests.completed.clear()
	Quests.active["dirtside_run"] = {"stage": 0, "count": 0}
	Quests.on_dock(false, null, true)   # landing at the colony queues the talk stage
	_chk(not Quests.talks_for("imari").is_empty(), "landing queued Imari's crate talk")

	var npcs: Array = town.get("_npcs")
	var imari: Dictionary
	for n in npcs:
		if str(n["name"]) == "Imari":
			imari = n
	var player: Node2D = town.get("_player")

	# Her business light comes on (the approach system), and the player walks up + [E]s.
	for _i in 4:
		await get_tree().process_frame
	_chk(imari["wants_talk"] or imari["approaching"] or imari["delivered"],
		"Imari knows she has business with you")
	player.global_position = imari["node"].global_position + Vector2(60, 0)
	player.stop()
	for _i in 3:
		await get_tree().process_frame
	town.call("_interact")
	await get_tree().process_frame

	var panel := _find_panel(town)
	_chk(panel != null, "[E] on Imari presented her conversation OVER THE TOWN (no dock panel)")
	_chk(town.get("_active") == false, "the town holds still during the conversation")
	if panel != null:
		panel.close()
		for _i in 3:
			await get_tree().process_frame
	_chk(Quests.completed.has("dirtside_run"),
		"finishing the conversation completed the crate delivery")
	_chk(not Quests.talks_for("ruel").is_empty(),
		"Ruel's debrief is queued for the STATION (held, not shown here)")
	# The chain must hand the town back once every talk this person held has played.
	for _i in 6:
		await get_tree().process_frame
	if _find_panel(town) == null:
		_chk(town.get("_active") == true, "the town thaws when the conversation chain ends")

	# ---- BEAT 2: the_hermit — the Counter in his cave ----
	Quests.pending_talks.clear()
	Quests.active["the_hermit"] = {"stage": 0, "count": 0}
	Quests.on_dock(false, null, true)
	_chk(not Quests.talks_for("hermit").is_empty(), "landing queued the Counter's talk")

	# The guide points OUT to the cave (he's a recluse, not a town NPC).
	var obj: Vector2 = town.call("_current_objective_pos")
	_chk(obj.distance_to(town.CAVE_MOUTH) < 1.0, "the guide chevron points at the cave mouth")

	town.call("_do_action", "enter:?")
	await get_tree().process_frame
	var hermit: Node2D = town.get("_hermit")
	player.global_position = hermit.global_position + Vector2(50, 40)
	player.stop()
	for _i in 3:
		await get_tree().process_frame
	town.call("_interact")
	await get_tree().process_frame

	panel = _find_panel(town)
	_chk(panel != null, "[E] on the Counter presents his conversation in the cave")
	if panel != null:
		panel.close()
		for _i in 3:
			await get_tree().process_frame
	_chk(Quests.completed.has("the_hermit"), "hearing the Counter completed the beat")

	print("test_ground_saga: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _find_panel(town: Node) -> DialoguePanel:
	for c in town.get_children():
		if c is DialoguePanel:
			return c
	return null


func _chk(cond: bool, msg: String) -> void:
	print(("  ok  " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1

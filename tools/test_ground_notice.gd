extends Node
## Intent-driven NPC notice (user's spec): an NPC with business (wants_talk) breaks its wander
## and WALKS OVER to the player; an NPC with nothing only GLANCES (notices, doesn't approach).
## Run as a SCENE (physics runs headless):
##   <godot> --headless --path . res://tools/test_ground_notice.tscn

var _fails := 0

func _ready() -> void:
	var town: Node = load("res://scenes/ground/epharon_town.tscn").instantiate()
	add_child(town)
	for _i in 6:
		await get_tree().physics_frame
	var npcs: Array = town.get("_npcs")
	var player: Node2D = town.get("_player")
	var imari := _find(npcs, "Imari")        # wants_talk = true
	var colonist := _find(npcs, "Colonist")  # wants_talk = false
	var imari_node: Node2D = imari["node"]
	var col_node: Node2D = colonist["node"]
	# Business is now quest/tutor-driven (default OFF); grant Imari some so she approaches. The
	# per-frame _refresh_npc_business only turns wants_talk ON, so this survives until delivery.
	town.call("set_wants_talk", "Imari", true)

	# 1) A wants_talk NPC APPROACHES and closes to talking range.
	player.global_position = imari_node.global_position + Vector2(250, 0)
	player.stop()
	var min_d := 1.0e9
	for _i in 160:
		await get_tree().physics_frame
		min_d = minf(min_d, imari_node.global_position.distance_to(player.global_position))
	_chk(min_d < 130.0, "Imari (wants_talk) walked over to talking range (closest %.0f)" % min_d)
	_chk(imari["wants_talk"] == false, "Imari's business is delivered once she reaches you")

	# 2) A no-business NPC only GLANCES — notices but never approaches.
	player.global_position = col_node.global_position + Vector2(250, 0)
	player.stop()
	for _i in 90:
		await get_tree().physics_frame
	_chk(colonist["noticed"] == true, "Colonist noticed the player (glanced)")
	_chk(colonist["approaching"] == false, "Colonist did NOT approach (no business)")

	# 3) QUEST-DRIVEN business (the tutorial↔quests seam): a pending quest talk alone — no manual
	#    flag, no tutor — makes an NPC walk over, and the guide points to them.
	Quests.pending_talks.clear()
	Quests.pending_talks.append({"giver": "sella", "text": "A word, pilot."})
	var sella := _find(npcs, "Sella")
	var sella_node: Node2D = sella["node"]
	sella_node.global_position = Vector2(1600, 900)   # open sand — clear of the guild/farm cluster
	_chk(town.call("_current_objective_pos").distance_to(sella_node.global_position) < 1.0,
		"the guide points to the quest-business NPC")
	player.global_position = sella_node.global_position + Vector2(250, 0)
	player.stop()
	var sd := 1.0e9
	for _i in 180:
		await get_tree().physics_frame
		sd = minf(sd, sella_node.global_position.distance_to(player.global_position))
	_chk(sd < 130.0, "Sella approached on a queued QUEST talk alone (closest %.0f)" % sd)
	Quests.pending_talks.clear()

	# 4) LOOP GUARD — the reported "panel reopens the instant you dismiss it" bug. Once an NPC has
	#    walked over, a STILL-pending talk must not re-summon her every frame (she never opens the
	#    panel anyway now — the player does). She arrives, then holds; no re-arm spam.
	Quests.pending_talks.clear()
	Quests.pending_talks.append({"giver": "imari", "text": "Crate's here, pilot."})
	imari["delivered"] = false
	imari["noticed"] = false
	imari["approaching"] = false
	imari["wants_talk"] = false
	imari_node.global_position = Vector2(1400, 1200)   # open sand
	imari["home"] = imari_node.global_position          # keep her idle wander local (no long walk back)
	player.global_position = imari_node.global_position + Vector2(150, 0)
	player.stop()
	for _i in 140:
		await get_tree().physics_frame
	_chk(imari["delivered"] == true, "Imari walked over and now WAITS (delivered)")
	var stable := true
	for _i in 60:
		await get_tree().physics_frame
		if imari["wants_talk"]:
			stable = false
	_chk(stable, "Imari does NOT re-summon herself while waiting — the reopen loop is gone")
	Quests.pending_talks.clear()

	print("test_ground_notice: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _find(npcs: Array, nm: String) -> Dictionary:
	for n in npcs:
		if str(n["name"]) == nm:
			return n
	return {}


func _chk(cond: bool, msg: String) -> void:
	print(("  ok  " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1

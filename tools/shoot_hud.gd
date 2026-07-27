extends Node
## Dev-only: raise the flight scene and shoot the objective corner, so the tracker's
## per-kind colours and the READY-TO-TURN-IN state can be eyeballed. Run WINDOWED.
const DIR := "C:/Users/charl/AppData/Local/Temp/claude/E--Seared-Games-repos-Bleakflame-bleakflame/3a9df3e2-fa85-477f-96c4-c9436e26c8ad/scratchpad"

func _ready() -> void:
	# NEVER WRITE THE PLAYER'S PILOT. This boots the real flight scene, and the real
	# flight scene checkpoints on touchdown and on the tutorial paying out.
	SaveGame.read_only = true

	var scene: Node = load("res://scenes/flight/flight_test.tscn").instantiate()
	add_child(scene)
	for _i in 20:
		await get_tree().process_frame
	var ship = get_tree().get_first_node_in_group("player_ship")
	if ship.docked_at != null:
		ship.undock()
	for _i in 10:
		await get_tree().process_frame
	# One of each kind: a campaign beat, two contracts, and a live expedition lead.
	Quests.active["overdue"] = {"stage": 0, "count": 0}
	MissionLog.ensure_offers()
	MissionLog.accept(0)
	MissionLog.accept(0)
	Research.chain_stage["wayfinder_core"] = 1          # survey_rocks, counted
	Research.survey_progress = 3                        # ...and FULL, so it reads READY
	Research.chain_stage["cinderheart"] = 1             # fragments, partial
	ship.commodities["cinder_fragment"] = 1
	for _i in 12:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(DIR + "/hud_tracker.png")
	print("saved hud_tracker.png")
	await _rank_shot(ship)
	get_tree().quit()


## THE TARGET READOUT with a rank on it. Ranked ships live tens of thousands of units out
## (the Vulture's haunt, RECLUSE's leg of the Long Lane), so rather than fly there this
## drags one to the player and targets it — the readout only cares what is selected.
func _rank_shot(ship) -> void:
	var picks := {}
	for grp in ["hostile_team", "player_team"]:
		for n in get_tree().get_nodes_in_group(grp):
			if not (n is BuildShip) or n == ship:
				continue
			var rk := Threat.rank_of(n)
			var key := Threat.label(rk)
			if not picks.has(key):
				picks[key] = n
	print("  ranks present in the world: ", picks.keys())
	for key in ["MILITARY", "ELITE", "NORMAL"]:
		if not picks.has(key):
			continue
		var mark = picks[key]
		mark.global_position = ship.global_position + Vector2(420, -120)
		ship.target = mark
		for _i in 8:
			await get_tree().process_frame
		var f := "hud_rank_%s.png" % key.to_lower().replace(" ", "_")
		get_viewport().get_texture().get_image().save_png(DIR + "/" + f)
		print("saved ", f)

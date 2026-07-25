extends Node
## ENTERABLE BUILDINGS (user, 2026-07-25): interiors are data (epharon_town.INTERIORS) —
## the cave proved the pattern, and the MARKET (Bram, Sella's ownership economy) and the
## AQUAPONICS farm (Tam, Sella's farmhand) joined it. This asserts the machinery: entering
## sets the room, seats its RESIDENT, swaps town NPCs out; leaving restores the street at
## the right door. Residents are real cast (Npcs.CAST) so portraits/idle lines drop in.
##   <godot> --headless --path . res://tools/test_ground_interiors.tscn

var _fails := 0


func _ready() -> void:
	var town: Node = load("res://scenes/ground/epharon_town.tscn").instantiate()
	add_child(town)
	for _i in 4:
		await get_tree().physics_frame

	# Every INTERIORS def has a door spot that opens it, and the two new residents are
	# registered cast (portraits + idle lines come from the registry, not hardcoded).
	_chk(Npcs.CAST.has("tam") and Npcs.CAST.has("bram"), "Tam and Bram are registered cast")
	for id in town.INTERIORS:
		var found := false
		for s in town.get("_spots"):
			if str(s.get("action", "")) == "enter:%s" % id:
				found = true
		_chk(found, "a town door opens the '%s' interior" % id)

	# ---- THE MARKET: Bram's floor ----
	town.call("_do_action", "enter:MARKET")
	await get_tree().process_frame
	_chk(str(town.get("_interior_id")) == "MARKET", "entering the market sets the room")
	_chk((town.get("_trader") as Node2D).visible, "Bram stands his counter inside")
	_chk(not (town.get("_farmhand") as Node2D).visible, "Tam is NOT in the market")
	var bram_spot := false
	var exit_spot := false
	for s in town.get("_spots"):
		if str(s.get("action", "")) == "shop:bram":
			bram_spot = true
		if str(s.get("action", "")) == "leave":
			exit_spot = true
	_chk(bram_spot, "[E] on Bram is the shop — the counter is a PERSON")
	_chk(exit_spot, "the room has a way out")
	town.call("_do_action", "leave")
	await get_tree().process_frame
	_chk(str(town.get("_interior_id")) == "", "leaving restores the street")
	var player: Node2D = town.get("_player")
	_chk(player.global_position.distance_to(Vector2(560, 470)) < 6.0,
		"you come out at the MARKET's own door, not the cave's")

	# ---- THE FARM: Tam keeps Sella's tanks ----
	town.call("_do_action", "enter:AQUAPONICS")
	await get_tree().process_frame
	_chk(str(town.get("_interior_id")) == "AQUAPONICS", "entering the farm sets the room")
	_chk((town.get("_farmhand") as Node2D).visible, "Tam is at the tanks")
	_chk(not (town.get("_trader") as Node2D).visible, "Bram is NOT at the farm")
	town.call("_do_action", "leave")
	await get_tree().process_frame

	# ---- THE UNION: Sella is a TOWN NPC hosting her own room ----
	# The new machinery: a wandering NPC steps inside as the room's resident, and steps
	# BACK OUT to her street haunt on exit (without the restore she'd be stranded in the
	# far-off room space, invisible to the whole notice/approach system).
	var sella: Dictionary
	for n in town.get("_npcs"):
		if str(n["name"]) == "Sella":
			sella = n
	town.call("_do_action", "enter:EXPLORERS GUILD")
	await get_tree().process_frame
	var sella_node: Node2D = sella["node"]
	_chk(sella_node.visible, "Sella hosts her own Union")
	_chk(sella_node.global_position.distance_to(Vector2(12000, 0)) < 600.0,
		"she stands in the room, at her chart wall")
	var postings := false
	for s in town.get("_spots"):
		if str(s.get("action", "")) == "board:sella":
			postings = true
	_chk(postings, "her survey postings hang inside the Union now")
	town.call("_do_action", "leave")
	await get_tree().process_frame
	_chk(sella_node.global_position.distance_to(sella["home"]) < 6.0,
		"leaving returns Sella to her street haunt (not stranded in room-space)")

	# ---- THE CAVE still works through the same machinery ----
	town.call("_do_action", "enter:?")
	await get_tree().process_frame
	_chk((town.get("_hermit") as Node2D).visible, "the Counter is still in his cave")
	town.call("_do_action", "leave")
	await get_tree().process_frame
	for n in town.get("_npcs"):
		_chk((n["node"] as Node2D).visible, "%s is back on the street after leaving" % n["name"])

	print("test_ground_interiors: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _chk(cond: bool, msg: String) -> void:
	print(("  ok  " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1

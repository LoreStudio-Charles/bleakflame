extends Node
## THE COLONY VISIT — the user's canonical planetside order (2026-07-25):
##   land -> meet Imari -> contract board turn-in -> meet Sella -> market prices ->
##   buy food -> spaceport -> launch  (the station sell is trade_return, at the station)
## This asserts the ground_intro lesson walks that exact sequence, each step completed
## by its in-world action, still gated on the flight tutorial. Run as a SCENE:
##   <godot> --headless --path . res://tools/test_ground_tutor.tscn

var _fails := 0


func _ready() -> void:
	Tutor.reset()
	SaveGame.tutorial_done = false
	var town: Node = load("res://scenes/ground/epharon_town.tscn").instantiate()
	add_child(town)
	for _i in 8:
		await get_tree().process_frame

	# GATE: withheld until the flight tutorial is done.
	_chk(Tutor.active == "", "ground_intro withheld before flight training (active='%s')" % Tutor.active)
	SaveGame.tutorial_done = true
	for _i in 6:
		await get_tree().process_frame
	_chk(Tutor.active == "ground_intro", "arms once flight training is done")
	_chk(Tutor.step == 0, "step 0 — meet Imari (step=%d)" % Tutor.step)
	_chk(Tutor.context == "ground", "town set the tutor context to 'ground'")

	# 0 -> 1: the PLAYER walks up to Imari and presses [E] (player always initiates).
	var npcs: Array = town.get("_npcs")
	var player: Node2D = town.get("_player")
	var imari := _find(npcs, "Imari")
	player.global_position = (imari["node"] as Node2D).global_position + Vector2(90, 0)
	player.stop()
	for _i in 6:
		await get_tree().process_frame
	town.call("_interact")
	for _i in 5:
		await get_tree().process_frame
	_chk(Tutor.step == 1, "meeting Imari advanced to the CONTRACT BOARD (step=%d)" % Tutor.step)

	# 1 -> 2: settle up at the board (visiting it is enough with nothing to turn in).
	Tutor.did("used_mission_uplink")
	for _i in 5:
		await get_tree().process_frame
	_chk(Tutor.step == 2, "the board advanced to MEET SELLA (step=%d)" % Tutor.step)

	# 2 -> 3: meet Sella.
	Tutor.did("met_sella")
	for _i in 5:
		await get_tree().process_frame
	_chk(Tutor.step == 3, "Sella advanced to MARKET PRICES (step=%d)" % Tutor.step)

	# 3 -> 4: open Bram's market.
	Tutor.did("used_market")
	for _i in 5:
		await get_tree().process_frame
	_chk(Tutor.step == 4, "the market advanced to BUY FOOD (step=%d)" % Tutor.step)

	# 4 -> 5: food in the hold — the town publishes cargo_food from the player ship.
	var hold := preload("res://tools/fake_hold.gd").new()
	hold.add_to_group("player_ship")
	add_child(hold)
	hold.add_commodity("food", 4)
	for _i in 6:
		await get_tree().process_frame
	_chk(Tutor.step == 5, "4 food advanced to the SPACEPORT (step=%d)" % Tutor.step)

	# 5 -> done: lift off.
	Tutor.did("launched")
	for _i in 5:
		await get_tree().process_frame
	_chk(Tutor.seen.has("ground_intro"), "launching completed the colony visit")

	print("test_ground_tutor: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
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

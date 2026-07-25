extends Node
## Ground onboarding: the walkable town drives the declarative Tutor with a "ground" context.
## ground_intro is GATED on the flight tutorial being done, then walks the pilot through the
## colony (move -> meet Imari -> trade -> launch), each step completed by an in-world action.
## Run as a SCENE:
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
	_chk(Tutor.step == 0, "step 0 — get out and walk (step=%d)" % Tutor.step)
	_chk(Tutor.context == "ground", "town set the tutor context to 'ground'")

	# step 0 -> 1: walking a bit completes the move step.
	Tutor.did("ground_moved")
	for _i in 5:
		await get_tree().process_frame
	_chk(Tutor.step == 1, "walking advanced to step 1 — meet Imari (step=%d)" % Tutor.step)

	# step 1 -> 2: the PLAYER walks up to Imari and presses [E]. She may walk over too, but she
	# never opens the interaction — the player does (user rule), so `met_imari` fires on [E].
	var npcs: Array = town.get("_npcs")
	var player: Node2D = town.get("_player")
	var imari := _find(npcs, "Imari")
	var imari_node: Node2D = imari["node"]
	player.global_position = imari_node.global_position + Vector2(90, 0)   # within the [E] focus range
	player.stop()
	for _i in 6:
		await get_tree().process_frame
	town.call("_interact")   # the player presses [E]
	for _i in 5:
		await get_tree().process_frame
	_chk(Tutor.step >= 2 or Tutor.seen.has("ground_intro"),
		"pressing [E] on Imari advanced past step 1 (step=%d)" % Tutor.step)

	# step 2 -> 3: using the Market.
	Tutor.did("used_market")
	for _i in 5:
		await get_tree().process_frame
	_chk(Tutor.step == 3 or Tutor.seen.has("ground_intro"),
		"using the Market advanced to step 3 (step=%d)" % Tutor.step)

	# step 3 -> done: launching.
	Tutor.did("launched")
	for _i in 5:
		await get_tree().process_frame
	_chk(Tutor.seen.has("ground_intro"), "launching completed the onboarding")

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

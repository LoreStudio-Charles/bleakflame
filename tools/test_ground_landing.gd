extends Node
## Integration smoke for the Epharon ground overlay wired into flight_test. Loads the real
## flight scene and drives _set_ground_visible directly (NOT ship.dock — that would write the
## save), proving the SubViewport town builds, shows, resets the pilot to the pad, and tears
## down cleanly. Run as a SCENE (autoloads needed):
##   <godot> --headless --path . res://tools/test_ground_landing.tscn

func _ready() -> void:
	var scene: Node = load("res://scenes/flight/flight_test.tscn").instantiate()
	add_child(scene)
	for _i in 8:
		await get_tree().process_frame

	var ok := true

	# Raise the town (the touchdown-at-Epharon path, minus the save-writing dock()).
	scene.call("_set_ground_visible", true)
	for _i in 5:
		await get_tree().process_frame
	var town: Node = scene.get("_town")
	var layer: CanvasLayer = scene.get("_ground_layer")
	ok = _chk(scene.get("_ground_active") == true, "ground active after show") and ok
	ok = _chk(town != null, "town instance built in the SubViewport") and ok
	ok = _chk(layer != null and layer.visible, "overlay layer visible") and ok
	if town != null:
		var p: Node2D = town.get("_player")
		ok = _chk(p != null, "town has a player") and ok
		if p != null:
			ok = _chk(p.global_position.distance_to(Vector2(0, 780)) < 6.0,
				"enter_town put the pilot on the pad (%s)" % p.global_position) and ok

	# THE GROUND NEVER RAISES THE DOCK (user, 2026-07-25): the spatialized dock panel was
	# transition scaffolding and is DELETED — every planetside service is ground-native
	# (ShopView / BoardView / StarportView / DialoguePanel talks). While the town is up,
	# the planet dock screen stays hidden, whatever happens.
	var pscr: Variant = scene.get("planet_screen")
	ok = _chk(not scene.has_method("_on_town_service"),
		"the town→dock service route is GONE (no _on_town_service)") and ok
	if town != null:
		for s in town.get("_spots"):
			ok = _chk(not str(s.get("action", "")).begins_with("svc:"),
				"no town spot routes to a dock panel ('%s')" % s.get("action", "")) and ok
	ok = _chk(not pscr.visible, "the planet dock screen stays hidden while grounded") and ok

	# The pilot dossier opens anywhere and both tabs populate.
	var sheet: Variant = null
	for c in scene.get_children():
		if c is CharacterSheet:
			sheet = c
	ok = _chk(sheet != null, "character sheet exists in the scene") and ok
	if sheet != null:
		sheet.open()
		for _i in 2:
			await get_tree().process_frame
		ok = _chk(sheet.visible, "dossier opens") and ok
		ok = _chk(sheet.get("_char_body").text.length() > 40, "character tab populated") and ok
		ok = _chk(sheet.get("_ship_body").text.length() > 40, "ship tab populated") and ok
		sheet.close()
		ok = _chk(not sheet.visible, "dossier closes") and ok

	# Tear it down (the launch/undock path re-hides the overlay).
	scene.call("_set_ground_visible", false)
	for _i in 3:
		await get_tree().process_frame
	ok = _chk(scene.get("_ground_active") == false, "ground inactive after hide") and ok
	ok = _chk(not scene.get("_ground_layer").visible, "overlay layer hidden") and ok

	print("test_ground_landing: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)


func _chk(cond: bool, msg: String) -> bool:
	print(("  ok  " if cond else "  FAIL ") + msg)
	return cond

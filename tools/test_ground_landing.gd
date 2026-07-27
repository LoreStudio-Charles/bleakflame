extends Node
## Integration smoke for the Epharon ground overlay wired into flight_test. Loads the real
## flight scene and drives _set_ground_visible directly (NOT ship.dock — that would write the
## save), proving the SubViewport town builds, shows, resets the pilot to the pad, and tears
## down cleanly. Run as a SCENE (autoloads needed):
##   <godot> --headless --path . res://tools/test_ground_landing.tscn

func _ready() -> void:
	# NEVER WRITE THE PLAYER'S PILOT. This boots the real flight scene, and the real
	# flight scene checkpoints on touchdown and on the tutorial paying out.
	SaveGame.read_only = true

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

	# THE PLANET DOCK SCREEN IS DELETED (cleanup, 2026-07-25). It was the tabbed menu a
	# landing used to raise; planetside is ground-native now, so it could not become
	# visible at all (Epharon raises the town, and the only other planetoid is unlandable)
	# while still costing a full DockScreen build every boot. Asserted GONE rather than
	# hidden, the same way the town→dock service route is.
	ok = _chk(scene.get("planet_screen") == null,
		"the planet DOCK SCREEN is gone (planets hand you a town, not a tab deck)") and ok
	ok = _chk(not scene.has_method("_on_town_service"),
		"the town→dock service route is GONE (no _on_town_service)") and ok
	if town != null:
		for s in town.get("_spots"):
			ok = _chk(not str(s.get("action", "")).begins_with("svc:"),
				"no town spot routes to a dock panel ('%s')" % s.get("action", "")) and ok

	# THE LANDING APRON (2026-07-25): your actual hull is parked south of the Starport and
	# the launch prompt lives ON it — you board the thing you can see. Guarded because the
	# ship renders only when its hull has art, so a silent art-path change would quietly
	# leave an empty berth, and the [E] that gets you off the planet would drift with it.
	if town != null:
		var pad: Vector2 = town.get("PAD_CENTER")
		var launch_here := false
		for s in town.get("_spots"):
			if str(s.get("action", "")) == "launch":
				launch_here = s.get("pos") != null and (s.get("pos") as Vector2).distance_to(pad) < 1.0
		ok = _chk(launch_here, "the launch prompt sits on the apron, at the parked ship") and ok
		# The starter Rooster HAS art, so a missing sprite here means the resolution broke.
		ok = _chk(town.get("_ship_sprite") != null, "the player's hull is parked on the apron") and ok
		var pad_size: Vector2 = town.get("PAD_SIZE")
		var biggest: float = float(town.get("GROUND_SHIP_W")[HullDef.SizeBand.SUPER_HEAVY])
		ok = _chk(pad_size.x > biggest and pad_size.y > biggest * 0.6,
			"the berth has room for a SUPER_HEAVY (%s vs %.0f)" % [pad_size, biggest]) and ok

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

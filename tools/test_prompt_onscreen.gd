extends Node
## Empirical: load the real flight scene, publish an interact_prompt, and prove the new
## standing _prompt label lands ON SCREEN — plus report where the old _center_note sits,
## to confirm the bottom-anchor combo was pushing flash notes off the bottom edge.

func _ready() -> void:
	# NEVER WRITE THE PLAYER'S PILOT. This boots the real flight scene, and the real
	# flight scene checkpoints on touchdown and on the tutorial paying out.
	SaveGame.read_only = true

	var scene: Node = load("res://scenes/flight/flight_test.tscn").instantiate()
	add_child(scene)
	for _i in 4:
		await get_tree().process_frame
	var ship: Node = get_tree().get_first_node_in_group("player_ship")
	var hud: Node = scene.get_node_or_null("HUD")
	if ship == null or hud == null:
		print("SETUP FAIL  ship=", ship, " hud=", hud)
		get_tree().quit()
		return
	# Stand a real gate ~400u off the ship and register it the way /gate does, so the
	# scene's own _update_gate_prompt publishes interact_prompt — full end-to-end path.
	var gate: Node = WayGate.create(ship.global_position + Vector2(400, 0))
	scene.add_child(gate)
	scene.set("_waygate", gate)
	scene.set("_dev_gate", true)
	for _j in 3:
		await get_tree().process_frame
	print("DIAG  docked=", ship.docked_at, "  dead=", ship.dead,
		"  ship_pos=", ship.global_position, "  gate_pos=", gate.position,
		"  dist=", ship.global_position.distance_to(gate.position))
	# Undock if the scene booted us on the pad, then drive the prompt update directly.
	ship.docked_at = null
	scene.call("_update_gate_prompt")
	print("DIAG  interact_prompt after update = '", ship.interact_prompt, "'")
	await get_tree().process_frame
	var vp: Rect2 = get_viewport().get_visible_rect()
	var prompt: Control = hud.get("_prompt")
	var note: Control = hud.get("_center_note")
	print("viewport: ", vp)
	print("PROMPT  text=", prompt.text, "  visible=", prompt.visible,
		"  rect=", prompt.get_global_rect(), "  on_screen=", vp.encloses(prompt.get_global_rect()))
	print("CENTER_NOTE  text=", note.text, "  visible=", note.visible,
		"  rect=", note.get_global_rect(), "  on_screen=", vp.encloses(note.get_global_rect()))
	print("RESULT: ", "PASS" if prompt.visible and prompt.text != "" and vp.encloses(prompt.get_global_rect()) else "FAIL")
	get_tree().quit()

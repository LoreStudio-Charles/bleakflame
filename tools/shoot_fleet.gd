extends Node
## Dev-only: warp to the capital and shoot the home fleet on station off the outpost.
const DIR := "C:/Users/charl/AppData/Local/Temp/claude/E--Seared-Games-repos-Bleakflame-bleakflame/3a9df3e2-fa85-477f-96c4-c9436e26c8ad/scratchpad"

func _ready() -> void:
	var scene: Node = load("res://scenes/flight/flight_test.tscn").instantiate()
	add_child(scene)
	for _i in 20:
		await get_tree().process_frame
	var ship = get_tree().get_first_node_in_group("player_ship")
	if ship.docked_at != null:
		ship.undock()
	var target = scene.get("ORIVEL") + scene.get("ORIVEL_ORBITAL_OFFSET") + scene.get("ORIVEL_FLEET_OFFSET")
	ship.global_position = target + Vector2(-900, 700)
	ship.velocity = Vector2.ZERO
	for c in ship.get_children():
		if c is Camera2D:
			c.zoom = Vector2(0.55, 0.55)
	for _i in 90:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(DIR + "/fleet_orivel.png")
	print("saved fleet_orivel.png")
	get_tree().quit()

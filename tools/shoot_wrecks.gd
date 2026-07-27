extends Node
## Dev-only: kill a few hulls in front of the camera and photograph what is left.
const DIR := "C:/Users/charl/AppData/Local/Temp/claude/E--Seared-Games-repos-Bleakflame-bleakflame/3a9df3e2-fa85-477f-96c4-c9436e26c8ad/scratchpad"

func _ready() -> void:
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
	# Drag a handful of hostiles into view and kill them.
	var victims: Array = []
	for n in get_tree().get_nodes_in_group("hostile_team"):
		if n is BuildShip and victims.size() < 5:
			victims.append(n)
	var i := 0
	for v in victims:
		v.global_position = ship.global_position + Vector2(-260 + i * 190, -170 + (i % 2) * 250)
		i += 1
	for _i in 4:
		await get_tree().process_frame
	for v in victims:
		if is_instance_valid(v):
			v.take_damage(1e7, null)
	for _i in 90:
		await get_tree().process_frame
	print("wrecks on screen: ", get_tree().get_nodes_in_group("wrecks").size())
	get_viewport().get_texture().get_image().save_png(DIR + "/wrecks_shot.png")
	print("saved wrecks_shot.png")
	get_tree().quit()

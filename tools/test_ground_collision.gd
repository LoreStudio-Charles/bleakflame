extends Node
## Prove building collision works: drop the pilot south of the SEALED hab and walk them
## straight north into it. With collision wired right they're stopped well short; a broken
## layer/mask lets them stroll through to the target. Run as a SCENE (physics runs headless):
##   <godot> --headless --path . res://tools/test_ground_collision.tscn

func _ready() -> void:
	var town: Node = load("res://scenes/ground/epharon_town.tscn").instantiate()
	add_child(town)
	for _i in 6:
		await get_tree().physics_frame
	var player: Node2D = town.get("_player")
	player.global_position = Vector2(-360, 70)   # just south of the SEALED footprint (-360, -80)
	player.stop()
	for _i in 4:
		await get_tree().physics_frame
	player.move_to(Vector2(-360, -400))          # try to walk straight through the building
	for _i in 140:
		await get_tree().physics_frame
	var y := player.global_position.y
	var blocked := y > -60.0
	print("test_ground_collision: player.y=%.1f  %s" % [y,
		"PASS" if blocked else "FAIL (walked through the wall)"])
	get_tree().quit(0 if blocked else 1)

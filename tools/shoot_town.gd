extends Node
## Dev-only: render the Epharon town to PNGs so we can eyeball the look. Run WINDOWED:
##   <godot> --path . res://tools/shoot_town.tscn
## Captures a wide establishing shot AND a close-up of the hermit's cave, then quits.

const DIR := "C:/Users/charl/AppData/Local/Temp/claude/E--Seared-Games-repos-Bleakflame-bleakflame/3a9df3e2-fa85-477f-96c4-c9436e26c8ad/scratchpad"

var _town: Node
var _player: Node2D
var _cam: Camera2D

func _ready() -> void:
	SaveGame.tutorial_done = true   # so the ground onboarding lesson shows in the shots
	_town = load("res://scenes/ground/epharon_town.tscn").instantiate()
	add_child(_town)
	await get_tree().process_frame
	_player = _town.get("_player")
	for c in _player.get_children():
		if c is Camera2D:
			_cam = c
	await _shot(Vector2(0, 120), 0.60, "town_shot.png")
	await _shot(Vector2(2100, -1650), 0.95, "cave_shot.png")
	# Walking shot: drive the pilot north so footstep dust kicks up mid-stride.
	_player.global_position = Vector2(-150, 360)
	_cam.zoom = Vector2(1.25, 1.25)
	for _i in 3:
		await get_tree().process_frame
	_player.move_to(Vector2(-150, -260))
	for _i in 48:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(DIR + "/walk_shot.png")
	print("saved walk_shot.png")
	# Roam shot: out in the dust beyond town to see the scattered rocks + dunes.
	_player.global_position = Vector2(1500, -1500)
	_cam.zoom = Vector2(0.5, 0.5)
	for _i in 30:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(DIR + "/roam_shot.png")
	print("saved roam_shot.png")
	await _plates_shot()
	get_tree().quit()


## THE SHOT THAT JUDGES THE NAMEPLATES AND UNIT FRAMES: standing in the warren with a
## scrit targeted and everyone damaged, so the plate's every branch is on screen at once —
## a hostile plate, a targeted plate with its bracket and foot ring, the player's own foot
## ring, and both unit frames with real numbers in them.
func _plates_shot() -> void:
	_player.global_position = Vector2(2300, 1500) + Vector2(-150, 90)   # WARREN
	_player.stop()
	_cam.zoom = Vector2(1.15, 1.15)
	for _i in 40:
		await get_tree().process_frame
	var foes := get_tree().get_nodes_in_group("ground_hostiles")
	print("  scrit in the warren: ", foes.size())
	# Bank everyone off full so the bars have something to say — a frame reading 100/100
	# next to a plate with no bar shows none of the states worth looking at.
	_player.health = _player.max_health * 0.62
	for i in foes.size():
		foes[i].health = foes[i].max_health * (0.45 if i % 2 == 0 else 0.85)
	if not foes.is_empty():
		_player.combat_target = foes[0]
	for _i in 20:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(DIR + "/plates_shot.png")
	print("saved plates_shot.png")

func _shot(pos: Vector2, zoom: float, name: String) -> void:
	_player.global_position = pos
	_player.stop()
	_cam.zoom = Vector2(zoom, zoom)
	for _i in 30:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(DIR + "/" + name)
	print("saved ", name)

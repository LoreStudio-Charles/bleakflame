extends Node
## Dev-only: the dune ambush on the road to the hermit — one shot holding OUTSIDE the
## trigger (nothing should be visible but sand) and one the instant it springs.
const DIR := "C:/Users/charl/AppData/Local/Temp/claude/E--Seared-Games-repos-Bleakflame-bleakflame/3a9df3e2-fa85-477f-96c4-c9436e26c8ad/scratchpad"

var _town: Node
var _player: Node2D
var _cam: Camera2D

func _ready() -> void:
	# NEVER WRITE THE PLAYER'S PILOT. This boots the real flight scene, and the real
	# flight scene checkpoints on touchdown and on the tutorial paying out.
	SaveGame.read_only = true

	SaveGame.tutorial_done = true
	_town = load("res://scenes/ground/epharon_town.tscn").instantiate()
	add_child(_town)
	await get_tree().process_frame
	_player = _town.get("_player")
	for c in _player.get_children():
		if c is Camera2D:
			_cam = c
	var dune: Vector2 = _town.get("AMBUSH_DUNE")
	# Approach: just OUTSIDE the trigger, walking up from town.
	await _shot(dune + Vector2(-120, 430), 0.85, "ambush_before.png")
	# Cross the line and let them break cover.
	_player.global_position = dune + Vector2(-40, 250)
	for _i in 40:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(DIR + "/ambush_after.png")
	print("saved ambush_after.png  sprung=", _town.get("_ambush_sprung"))
	get_tree().quit()

func _shot(pos: Vector2, zoom: float, name: String) -> void:
	_player.global_position = pos
	_player.stop()
	_cam.zoom = Vector2(zoom, zoom)
	for _i in 30:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(DIR + "/" + name)
	print("saved ", name)

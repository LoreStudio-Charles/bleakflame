extends Node
## Dev-only: render the LANDING APRON south of the Starport, so the parked hull, the
## berth markings and the walk-up read can be eyeballed. Run WINDOWED:
##   <godot> --path . res://tools/shoot_pad.tscn

const DIR := "C:/Users/charl/AppData/Local/Temp/claude/E--Seared-Games-repos-Bleakflame-bleakflame/3a9df3e2-fa85-477f-96c4-c9436e26c8ad/scratchpad"

var _town: Node
var _player: Node2D
var _cam: Camera2D


func _ready() -> void:
	SaveGame.tutorial_done = true
	_town = load("res://scenes/ground/epharon_town.tscn").instantiate()
	add_child(_town)
	await get_tree().process_frame
	_player = _town.get("_player")
	for c in _player.get_children():
		if c is Camera2D:
			_cam = c
	# Wide: the whole south end — Starport above, apron and ship below.
	await _shot(Vector2(0, 1150), 0.52, "pad_wide.png")
	# Walk-up: standing at the apron's north lip, the way a player arrives.
	await _shot(Vector2(0, 1180), 1.0, "pad_walkup.png")
	# Close: the parked hull beside the pilot, for scale.
	await _shot(Vector2(-170, 1470), 1.3, "pad_close.png")
	get_tree().quit()


func _shot(pos: Vector2, zoom: float, name: String) -> void:
	_player.global_position = pos
	_player.stop()
	_cam.zoom = Vector2(zoom, zoom)
	for _i in 30:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(DIR + "/" + name)
	print("saved ", name)

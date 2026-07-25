extends Node
## Dev-only: raise the flight scene and shoot the objective corner, so the tracker's
## per-kind colours and the READY-TO-TURN-IN state can be eyeballed. Run WINDOWED.
const DIR := "C:/Users/charl/AppData/Local/Temp/claude/E--Seared-Games-repos-Bleakflame-bleakflame/3a9df3e2-fa85-477f-96c4-c9436e26c8ad/scratchpad"

func _ready() -> void:
	var scene: Node = load("res://scenes/flight/flight_test.tscn").instantiate()
	add_child(scene)
	for _i in 20:
		await get_tree().process_frame
	var ship = get_tree().get_first_node_in_group("player_ship")
	if ship.docked_at != null:
		ship.undock()
	for _i in 10:
		await get_tree().process_frame
	# One of each kind: a campaign beat, two contracts, and a live expedition lead.
	Quests.active["overdue"] = {"stage": 0, "count": 0}
	MissionLog.ensure_offers()
	MissionLog.accept(0)
	MissionLog.accept(0)
	Research.chain_stage["wayfinder_core"] = 1          # survey_rocks, counted
	Research.survey_progress = 3                        # ...and FULL, so it reads READY
	Research.chain_stage["cinderheart"] = 1             # fragments, partial
	ship.commodities["cinder_fragment"] = 1
	for _i in 12:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(DIR + "/hud_tracker.png")
	print("saved hud_tracker.png")
	get_tree().quit()

extends Node
## WHAT [E] OFFERS YOU — the interactable resolution.
##
## The rule it encodes cost a playtest to find: loot used to be checked only when nothing
## else had claimed the prompt, and a room ALWAYS has a standing spot (its exit) covering
## the whole floor, so indoors the scavenge prompt could never appear and the cave corpses
## could not be searched at all. It was fixed to "nearest in reach wins" and then had no
## test, which is how it would come back.
##
##   <godot> --headless --path . res://tools/test_ground_spots.tscn --quit-after 300

var _fails: Array[String] = []
var _checks := 0


func _ready() -> void:
	_case_nearest_in_reach_wins()
	_case_out_of_reach_offers_nothing()
	_case_a_body_underfoot_outranks_the_room()
	_case_a_node_spot_tracks_its_node()
	_case_loot_candidates_come_from_the_world()

	if _fails.is_empty():
		print("test_ground_spots: ALL PASS (%d checks)" % _checks)
	else:
		for f in _fails:
			printerr("  FAIL: %s" % f)
		printerr("test_ground_spots: %d FAILED of %d checks" % [_fails.size(), _checks])
	get_tree().quit(0 if _fails.is_empty() else 1)


func _case_nearest_in_reach_wins() -> void:
	var far := {"pos": Vector2(200, 0), "range": 400.0, "prompt": "[E] Far", "action": "far"}
	var near := {"pos": Vector2(50, 0), "range": 400.0, "prompt": "[E] Near", "action": "near"}
	var got := GroundSpots.focus([far, near], Vector2.ZERO)
	_ok(got.get("action") == "near", "the nearest spot in reach wins")
	# Order must not matter — a rule that depends on registration order is a rule nobody
	# can reason about from the outside.
	var flipped := GroundSpots.focus([near, far], Vector2.ZERO)
	_ok(flipped.get("action") == "near", "...whichever order they were added in")


func _case_out_of_reach_offers_nothing() -> void:
	var s := {"pos": Vector2(900, 0), "range": 100.0, "prompt": "[E] Door", "action": "door"}
	_ok(GroundSpots.focus([s], Vector2.ZERO).is_empty(),
		"a spot out of its own range offers nothing")
	_ok(GroundSpots.focus([], Vector2.ZERO).is_empty(), "an empty world offers nothing")
	# Exactly at the boundary counts — an interactable you are standing precisely on the
	# edge of should not flicker.
	var edge := {"pos": Vector2(100, 0), "range": 100.0, "prompt": "[E] Edge", "action": "edge"}
	_ok(GroundSpots.focus([edge], Vector2.ZERO).get("action") == "edge",
		"a spot exactly at its range still counts")


## THE PLAYTEST BUG, pinned. The room's exit spot covers the entire floor, so under the old
## two-rule version it always claimed the prompt and the corpses were unsearchable.
func _case_a_body_underfoot_outranks_the_room() -> void:
	var exit_spot := {"pos": Vector2(0, 300), "range": 900.0,
		"prompt": "[E] Leave the cave", "action": "leave"}
	var body := {"pos": Vector2(10, 0), "range": GroundSpots.LOOT_REACH,
		"prompt": "[E] Scavenge the scrit", "action": "loot"}
	var got := GroundSpots.focus([exit_spot, body], Vector2.ZERO)
	_ok(got.get("action") == "loot",
		"a body underfoot outranks a room-wide exit spot (got '%s')" % str(got.get("action")))
	# ...and stepping away from the body hands the room back, rather than sticking.
	var away := GroundSpots.focus([exit_spot, body], Vector2(0, 260))
	_ok(away.get("action") == "leave", "...and walking off it returns the room's own prompt")


func _case_a_node_spot_tracks_its_node() -> void:
	var who := Node2D.new()
	add_child(who)
	who.global_position = Vector2(600, 0)
	var s := {"node": who, "range": 150.0, "prompt": "[E] Talk", "action": "talk", "npc": "Sella"}
	_ok(GroundSpots.focus([s], Vector2.ZERO).is_empty(), "a node spot is out of reach at range")
	who.global_position = Vector2(60, 0)
	var got := GroundSpots.focus([s], Vector2.ZERO)
	_ok(got.get("action") == "talk", "...and comes into reach when the NODE moves, not the spot")
	_ok(str(got.get("npc")) == "Sella", "...carrying whoever it belongs to")
	who.free()


func _case_loot_candidates_come_from_the_world() -> void:
	var body := Node2D.new()
	add_child(body)
	body.global_position = Vector2(30, 0)
	body.add_to_group("ground_loot")
	var cands := GroundSpots.loot_candidates(get_tree(), "[E] Scavenge")
	_ok(cands.size() == 1, "a searchable body becomes a candidate (%d)" % cands.size())
	_ok(GroundSpots.focus(cands, Vector2.ZERO).get("action") == "loot",
		"...and resolves like any other spot")
	# NOT EVERYTHING IN A GROUP IS A BODY. The group is a public namespace — anything can
	# join it — and a member with no position at all must be skipped rather than crash the
	# prompt for the whole scene. (Sabotaging the guard proved the earlier version of this
	# case never reached it: removing the body from the GROUP is a different claim from
	# handling a member that is not a Node2D, and only the first was being tested.)
	var odd := Node.new()
	add_child(odd)
	odd.add_to_group("ground_loot")
	var mixed := GroundSpots.loot_candidates(get_tree(), "[E] Scavenge")
	_ok(mixed.size() == 1, "a group member with no position is skipped, not offered (%d)"
		% mixed.size())
	_ok(GroundSpots.focus(mixed, Vector2.ZERO).get("action") == "loot",
		"...and the real body beside it still resolves")
	odd.free()

	body.remove_from_group("ground_loot")
	_ok(GroundSpots.loot_candidates(get_tree(), "[E] Scavenge").is_empty(),
		"a spent body stops being offered")
	body.free()


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(what)

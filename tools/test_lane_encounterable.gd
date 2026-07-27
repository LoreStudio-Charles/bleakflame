extends Node
## CAN YOU ACTUALLY MEET ANY OF IT? — the lane measured from the cockpit, not the map.
##
## USER, 2026-07-27: "I flew it twice yesterday to track down pirates and didn't see them."
## That is the SECOND time this has been reported. test_lane_traffic was written the first
## time and it passes: 59 contacts are out there. It counts what EXISTS, and existing is not
## the same claim as being findable — it never measured how far off the road anything sits.
##
## The geometry is brutal and already written down in flight_test: ~91k units of road
## against a 1,500-unit sensor. A contact 6,000 units off the centreline is as good as
## absent, however faithfully it was spawned.
##
## So this flies the lane and counts what a pilot would SEE.
##
##   <godot> --headless --path . res://tools/test_lane_encounterable.tscn --quit-after 900

const FT := preload("res://scenes/flight/flight_test.gd")

## What a decent suite actually reaches (Wayfarer). Deliberately not the best in the game:
## the question is what a NORMAL pilot meets.
const SENSOR := 1500.0

var _fails: Array[String] = []
var _checks := 0
var _scene: Node = null


func _ready() -> void:
	SaveGame.read_only = true
	_scene = load("res://scenes/flight/flight_test.tscn").instantiate()
	add_child(_scene)
	for _i in 8:
		await get_tree().physics_frame

	var a: Vector2 = FT.LANE_RIM
	var b: Vector2 = FT.ORIVEL + FT.ORIVEL_ORBITAL_OFFSET
	var ab := b - a
	var lane_len := ab.length()
	print("  lane: %.0f units, sensor %.0f" % [lane_len, SENSOR])

	var rows: Array = []
	for grp in ["hostile_team", "traders"]:
		for n in get_tree().get_nodes_in_group(grp):
			var s := n as Node2D
			if s == null or not is_instance_valid(s):
				continue
			var p := s.global_position
			var t: float = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			var on_lane := a + ab * t
			var perp := p.distance_to(on_lane)
			var hull := "?"
			var bs = s.get("build")
			if bs != null and bs.hull != null:
				hull = str(bs.hull.display_name)
			rows.append({"hull": hull, "grp": grp, "t": t, "perp": perp})

	rows.sort_custom(func(x, y): return float(x.perp) < float(y.perp))
	print("  --- how far OFF THE ROAD each contact sits (nearest first) ---")
	for r in rows:
		print("    %-14s %-14s t=%.2f  %7.0f u off-lane%s"
			% [r.hull, r.grp, r.t, r.perp, "   <-- VISIBLE" if float(r.perp) <= SENSOR else ""])

	var seen := 0
	var hostiles_seen := 0
	for r in rows:
		if float(r.perp) <= SENSOR:
			seen += 1
			if str(r.grp) == "hostile_team":
				hostiles_seen += 1
	print("  --- %d of %d contacts are within sensor range of the centreline (%d hostile) ---"
		% [seen, rows.size(), hostiles_seen])

	# THE CLAIM THAT MATTERS, and the one test_lane_traffic never made: a pilot who flies
	# the road end to end must MEET something. Not "something exists somewhere in the
	# region" — meet it, from the cockpit, without knowing where to look.
	_ok(hostiles_seen > 0,
		"flying the lane meets at least one hostile (%d of %d hostiles within %d u)"
			% [hostiles_seen, rows.size(), int(SENSOR)])
	_ok(seen >= 20,
		"the road is genuinely busy — %d contacts fall within sensor range of it" % seen)

	# And they must be SPREAD, not all bunched at one end: three encounters in the first
	# 10% and nothing after is still an empty road for most of the trip.
	var quarters := [0, 0, 0, 0]
	var hostile_quarters := [0, 0, 0, 0]
	for r in rows:
		if float(r.perp) <= SENSOR:
			var q := mini(3, int(float(r.t) * 4.0))
			quarters[q] += 1
			if str(r.grp) == "hostile_team":
				hostile_quarters[q] += 1
	print("  --- visible contacts by quarter of the road: %s ---" % str(quarters))
	# THE USER'S ACTUAL ERRAND (2026-07-27): "I flew it twice yesterday to track down
	# pirates and didn't see them." So the number that matters is not contacts, it is
	# HOSTILES, per stretch of road.
	print("  --- visible HOSTILES by quarter:                %s ---" % str(hostile_quarters))
	var off_lane_hostiles := 0
	for r in rows:
		if str(r.grp) == "hostile_team" and float(r.perp) > SENSOR:
			off_lane_hostiles += 1
	print("  --- %d hostiles exist but sit further off the road than anyone can see ---"
		% off_lane_hostiles)
	# TWO SEPARATE CLAIMS, and keeping them separate is the whole lesson of this fix.
	#
	# The first version of this test asserted "hostiles in most quarters", which sounds
	# reasonable and CONTRADICTS THE DESIGN: the Guardian quarter and the Navy quarter are
	# meant to be clear, and a fix driven by that assertion would have broken the sanctuary
	# pillar and emptied the Navy of meaning. The player's real complaint was not "no
	# pirates in the Guardian band" — it was that the band was VOID, which is a traffic
	# problem wearing a danger problem's clothes.

	# 1. COMPANY IS CONSTANT. Every quarter carries traffic, including the safe ones. This
	#    is what the loneliness beat is made of (user: "together, but alone") — a protected
	#    stretch with nobody on it reads as emptiness, not as protection.
	var thinnest := 999
	for q in quarters:
		thinnest = mini(thinnest, q)
	_ok(thinnest >= 4,
		"every quarter of the road carries traffic — thinnest has %d (by quarter: %s)"
			% [thinnest, str(quarters)])

	# 2. DANGER IS A CURVE. Quiet at BOTH ends and worst in the middle, and the two quiet
	#    ends are quiet for opposite reasons — Guardians clear the first quarter, the Navy
	#    holds the last, and the middle belongs to whoever will take it.
	var ends: int = hostile_quarters[0] + hostile_quarters[3]
	var middle: int = hostile_quarters[1] + hostile_quarters[2]
	_ok(hostile_quarters[0] == 0,
		"the Guardian quarter is CLEAR — they keep the lane (found %d)" % hostile_quarters[0])
	_ok(hostile_quarters[3] == 0,
		"the Navy quarter is CLEAR — the picket holds (found %d)" % hostile_quarters[3])
	# The total ALONE is a weak claim: with both ends at zero, "more in the middle than at
	# the ends" is nearly free, and a floor low enough to be safe survives losing half the
	# V-Shrike (it did — the sabotage went undetected). So assert the SHAPE: the danger is
	# spread across the whole middle half rather than bunched in one quarter of it, which is
	# what makes the crossing tense instead of a single spike you can run past.
	_ok(middle >= 12,
		"the middle half is genuinely dangerous — %d hostiles %s" % [middle, str(hostile_quarters)])
	_ok(hostile_quarters[1] >= 4 and hostile_quarters[2] >= 4,
		"...and BOTH middle quarters carry it, not one spike %s" % str(hostile_quarters))
	_ok(middle > ends * 3, "...and the ends stay quiet by comparison (%d vs %d)" % [middle, ends])

	if _fails.is_empty():
		print("test_lane_encounterable: ALL PASS (%d checks)" % _checks)
	else:
		for f in _fails:
			printerr("  FAIL: %s" % f)
		printerr("test_lane_encounterable: %d FAILED of %d checks" % [_fails.size(), _checks])
	get_tree().quit(0 if _fails.is_empty() else 1)


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(what)

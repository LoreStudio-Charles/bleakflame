extends Node
## DOES THE LONG LANE ACTUALLY HAVE TRAFFIC ON IT?
##   godot --headless --path . res://tools/test_lane_traffic.tscn
##
## test_lane checks the band CONSTANTS. It does not check that a single ship was
## ever spawned, which is the exact "a test that proves nothing" shape this project
## keeps getting bitten by — and the player reported flying out and meeting neither
## a freighter nor a pirate.
##
## So this stands up the REAL flight scene and counts what is actually out there,
## reporting each contact's distance from the station and its position along the
## lane, because "the ships exist" and "the ships are findable" are different claims.

const FT := preload("res://scenes/flight/flight_test.gd")

var _fails := 0
var _scene: Node = null


func _ready() -> void:
	# NEVER WRITE THE PLAYER'S PILOT. This boots the real flight scene, and the real
	# flight scene checkpoints on touchdown and on the tutorial paying out.
	SaveGame.read_only = true

	_scene = load("res://scenes/flight/flight_test.tscn").instantiate()
	add_child(_scene)
	# Let _ready + the spawn block run, then a few physics frames so anything that
	# frees itself immediately has the chance to.
	for i in 6:
		await get_tree().physics_frame
	_report()
	print("test_lane_traffic: %s" % ("ALL PASS" if _fails == 0 else "%d FAILURE(S)" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)


func _fail(msg: String) -> void:
	print("FAIL: " + msg)
	_fails += 1


## How far along the lane a point sits, 0 = rim anchor, 1 = Orivel outpost.
func _lane_t(p: Vector2) -> float:
	var a: Vector2 = FT.LANE_RIM
	var b: Vector2 = FT.ORIVEL + FT.ORIVEL_ORBITAL_OFFSET
	var ab := b - a
	return clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)


func _report() -> void:
	var lane_len: float = (FT.ORIVEL + FT.ORIVEL_ORBITAL_OFFSET).distance_to(FT.LANE_RIM)
	print("lane length: %.0f units, rim anchor %s" % [lane_len, FT.LANE_RIM])
	print("")

	var groups := {"traders": [], "hostile_team": [], "player_team": []}
	for g in groups:
		for n in get_tree().get_nodes_in_group(g):
			if n is Node2D:
				groups[g].append(n)

	# Anything sitting out along the lane is lane traffic.
	var on_lane: Array = []
	for g in groups:
		for n in groups[g]:
			var d: float = n.global_position.distance_to(FT.LANE_RIM)
			if d > 4000.0:
				on_lane.append({"n": n, "t": _lane_t(n.global_position), "d": d, "g": g})
	on_lane.sort_custom(func(a, b): return a.t < b.t)

	print("%-22s %-8s %-12s %s" % ["contact", "lane t", "from rim", "group"])
	for e in on_lane:
		var nm := str(e.n.name)
		if e.n.get("build") != null and e.n.build.hull != null:
			nm = str(e.n.build.hull.display_name)
		print("%-22s %-8.2f %-12.0f %s" % [nm, e.t, e.d, e.g])

	print("")
	print("traders total: %d   hostiles total: %d   lane contacts (>4k out): %d" % [
		groups.traders.size(), groups.hostile_team.size(), on_lane.size()])

	if on_lane.is_empty():
		_fail("NOTHING is on the lane — the spawn block produced no distant traffic")
		return

	# THE FINDABILITY CHECK. Existing is not the same as meetable: how far must a
	# pilot fly from the rim before the FIRST contact is within a stock sensor?
	var nearest: Dictionary = on_lane[0]
	for e in on_lane:
		if e.d < nearest.d:
			nearest = e
	print("nearest lane contact is %.0f units out (t=%.2f)" % [nearest.d, nearest.t])

	# THE FIX, ASSERTED. Traffic existing is useless if the road is invisible: with a
	# 1,500-unit sensor against a 91,000-unit lane, the corridor a pilot must hold is
	# ~7 degrees at the near end. Charted beacons rim-clamp on radar, so they give a
	# BEARING from any distance -- that is what makes the lane flyable at all.
	var beacons: Array = []
	for poi in PoiMap.pois:
		if str(poi.get("kind", "")) == "beacon":
			beacons.append(poi)
	print("charted lane beacons: %d" % beacons.size())
	if beacons.size() < 3:
		_fail("only %d lane beacons — without markers the lane is a ~7-degree corridor a pilot must hold blind" % beacons.size())
	for poi in beacons:
		if not poi.get("charted", false):
			_fail("beacon '%s' is not CHARTED — it will not rim-clamp on radar, which is the entire point" % poi.name)
	# One must sit on each authority boundary, or the three bands stay invisible.
	for edge in [FT.LANE_GUARD_LEG.y, FT.LANE_NAVY_LEG.x]:
		var want: Vector2 = FT.LANE_RIM.lerp(FT.ORIVEL + FT.ORIVEL_ORBITAL_OFFSET, edge)
		var found := false
		for poi in beacons:
			if poi.pos.distance_to(want) < 600.0:
				found = true
		if not found:
			_fail("no beacon marks the band boundary at t=%.2f — the Gap has no visible edge" % edge)
	if nearest.d > 20000.0:
		_fail("the closest traffic is %.0f units from the rim — a pilot flying out meets nothing for a very long time" % nearest.d)

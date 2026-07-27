extends Node
## DID THE AUTHORED RANKS ACTUALLY REACH THE SHIPS?
##   <godot> --headless --path . res://tools/test_ranks_in_world.tscn --quit-after 900
##
## test_threat proves the SCALE works — that a Guardian measures 3x a stock hull and that
## rank_of reads what it is told. It cannot prove that anybody ever told it anything.
##
## Rank is AUTHORED at the spawn site, which makes it exactly the "a correct helper nobody
## calls" shape this project has already paid for more than once: every spawner that
## forgets its line leaves a ship claiming to be ordinary forever, and nothing anywhere
## goes red. A mis-ranked Vulture is invisible in every other test in the suite.
##
## So this stands up the REAL flight scene and reads the rank off the ships that are
## actually out there, the way test_lane_traffic counts real traffic.

var _fails: Array[String] = []
var _checks := 0
var _scene: Node = null


func _ready() -> void:
	_scene = load("res://scenes/flight/flight_test.tscn").instantiate()
	add_child(_scene)
	for _i in 8:
		await get_tree().physics_frame

	var ships := _all_ships()
	print("  %d ships in the world at boot" % ships.size())

	# THE PIRATE VULTURE — ELITE (user, 2026-07-27). It haunts the deep east and is the
	# heaviest ambient thing a rim pilot can run into.
	var vult := _by_hull(ships, "Vulture")
	_ok(not vult.is_empty(), "a Vulture is spawned in the world (found %d)" % vult.size())
	for v in vult:
		_ok(Threat.rank_of(v) == Threat.Rank.ELITE,
			"the Vulture reads ELITE, not %s" % Threat.label(Threat.rank_of(v)))

	# RECLUSE — MILITARY. Named, level 25, and hunting the stretch just short of safety.
	var rec: Array = []
	for s in ships:
		if str(s.get("callsign")) == "Recluse":
			rec.append(s)
	_ok(rec.size() == 2, "both RECLUSE hunters are on the lane (found %d)" % rec.size())
	for r in rec:
		_ok(Threat.rank_of(r) == Threat.Rank.MILITARY,
			"RECLUSE reads MILITARY, not %s" % Threat.label(Threat.rank_of(r)))

	# THE COMMON CASE MUST STAY SILENT. If ordinary pirates crept up to ELITE the marks
	# would become wallpaper, which is the one way this feature fails quietly.
	var normals := 0
	for s in ships:
		if s is AIShip and not (s is VShrikeShip) and _hull_of(s) != "Vulture":
			if Threat.rank_of(s) == Threat.Rank.NORMAL:
				normals += 1
			else:
				_fails.append("an ordinary %s ranks %s — the common case must stay NORMAL"
					% [_hull_of(s), Threat.label(Threat.rank_of(s))])
			_checks += 1
	print("  %d ordinary pirates, all NORMAL" % normals)

	# GUARDIANS AND THE NAVY both fly GuardianShip — the Navy only BORROWS the class for
	# its friendly-patrol behaviour — so "the first GuardianShip" identifies neither.
	# (Asserting that it did is how this test failed on its first run: the Navy is spawned
	# at boot off the Orivel outpost, not only by the /fleet dev command, so the first one
	# found was a Navy escort correctly reading MILITARY.)
	#
	# The claim that holds for BOTH and is worth pinning: nothing wearing a uniform is
	# ever ordinary. Then the capital is checked by name.
	var uniformed := 0
	for s in ships:
		if s is GuardianShip:
			uniformed += 1
			var rk := Threat.rank_of(s)
			_ok(rk == Threat.Rank.ELITE or rk == Threat.Rank.MILITARY,
				"a uniformed hull (%s) is never NORMAL — got %s"
					% [_hull_of(s), Threat.label(rk)])
	print("  %d uniformed hulls (Guardian patrols + the Navy)" % uniformed)

	# THE NAVY CAPITAL — MILITARY, and the interesting case: GuardianShip.setup_guard
	# stamps ELITE, so the spawner has to correct it afterwards exactly like the hull tint.
	var caps := _by_hull(ships, "Supercruiser")
	_ok(not caps.is_empty(), "the Navy capital is on station (found %d)" % caps.size())
	for c in caps:
		_ok(Threat.rank_of(c) == Threat.Rank.MILITARY,
			"the Navy capital reads MILITARY — the borrowed ELITE was corrected (got %s)"
				% Threat.label(Threat.rank_of(c)))

	if _fails.is_empty():
		print("test_ranks_in_world: ALL PASS (%d checks)" % _checks)
	else:
		for f in _fails:
			printerr("  FAIL: %s" % f)
		printerr("test_ranks_in_world: %d FAILED of %d checks" % [_fails.size(), _checks])
	get_tree().quit(0 if _fails.is_empty() else 1)


func _all_ships() -> Array:
	var out: Array = []
	for grp in ["hostile_team", "player_team"]:
		for n in get_tree().get_nodes_in_group(grp):
			if n is BuildShip and not out.has(n):
				out.append(n)
	return out


func _hull_of(s) -> String:
	var b = s.get("build")
	if b == null or b.hull == null:
		return ""
	return str(b.hull.display_name)


func _by_hull(ships: Array, hull: String) -> Array:
	var out: Array = []
	for s in ships:
		if _hull_of(s) == hull:
			out.append(s)
	return out


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(what)

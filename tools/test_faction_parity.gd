extends Node
## STAGE 2: DO FACTIONS AGREE WITH THE GROUPS THEY ARE REPLACING?
##
## Combat is the game, so switching targeting from `enemy_group` to the faction matrix
## cannot be a leap. This walks EVERY ORDERED PAIR of ships in the live world and compares
## the two verdicts:
##
##   OLD: other.is_in_group(self.enemy_group)
##   NEW: Factions.hostile(self.faction, other.faction)
##
## Anywhere they agree, the switch is a no-op. Anywhere they disagree is either a BUG in
## the faction data — which must be fixed before anything is wired — or one of the small
## number of DELIBERATE new behaviours the matrix exists to make possible, which two teams
## could never express. Those are listed below and asserted as intended, so the report
## reads "these N differences and no others."
##
##   <godot> --headless --path . res://tools/test_faction_parity.tscn --quit-after 900

## The differences we WANT. Each is a pairing two teams could not hold, from the Long Lane's
## own fiction (user: the Widows "ruthlessly raid anyone, including Shoal pirates").
const INTENDED := [
	["widow", "shoal"],      # the Widows prey on pirates too
	["shoal", "widow"],      # and the Shoal returns it
]

var _fails: Array[String] = []
var _checks := 0


func _ready() -> void:
	SaveGame.read_only = true
	add_child(load("res://scenes/flight/flight_test.tscn").instantiate())
	# A FRESH PILOT, not whoever is in the save. The scene loads the real userdata, so
	# without this the test compares the world against the DEVELOPER'S played standing —
	# which is how it first reported the Shoal as friendly: the pilot on disk had made
	# peace with them years of game-time ago. The claim here is about the relationships a
	# world OPENS with, so it has to be asked of a pilot who has done nothing yet.
	PlayerState.local = PlayerState.new()
	for _i in 8:
		await get_tree().physics_frame

	var ships: Array = []
	for grp in ["hostile_team", "player_team", "traders"]:
		for n in get_tree().get_nodes_in_group(grp):
			if n is BuildShip and not ships.has(n):
				ships.append(n)
	print("  %d ships in the world" % ships.size())

	# Every hull must know what it belongs to, or the matrix is being asked about "".
	var unfactioned := {}
	for s in ships:
		if str(s.faction) == "":
			var hull := "?"
			if s.build != null and s.build.hull != null:
				hull = str(s.build.hull.display_name)
			unfactioned[hull] = int(unfactioned.get(hull, 0)) + 1
	_ok(unfactioned.is_empty(), "every ship declares a faction — missing: %s" % str(unfactioned))

	# The ordered pairs, aggregated by (faction, faction) so the report is readable rather
	# than 3,000 lines.
	var agree := {}
	var differ := {}
	for a in ships:
		for b in ships:
			if a == b or str(a.faction) == "" or str(b.faction) == "":
				continue
			var old_v: bool = a.enemy_group != "" and b.is_in_group(a.enemy_group)
			var new_v: bool = Factions.hostile(str(a.faction), str(b.faction))
			var key := "%s -> %s" % [a.faction, b.faction]
			if old_v == new_v:
				agree[key] = int(agree.get(key, 0)) + 1
			else:
				differ[key] = {"old": old_v, "new": new_v,
					"n": int(differ.get(key, {}).get("n", 0)) + 1}

	print("  --- pairings where the two agree: %d kinds ---" % agree.size())
	print("  --- pairings where they DIFFER ---")
	var unexpected: Array[String] = []
	for key in differ:
		var d: Dictionary = differ[key]
		var parts := str(key).split(" -> ")
		var intended := false
		for pair in INTENDED:
			if str(pair[0]) == parts[0] and str(pair[1]) == parts[1]:
				intended = true
		print("    %-26s groups:%s  factions:%s  x%d  %s"
			% [key, "HOSTILE" if d.old else "friendly",
				"HOSTILE" if d.new else "friendly", d.n,
				"<-- INTENDED" if intended else "<-- UNEXPECTED"])
		if not intended:
			unexpected.append(str(key))

	_ok(unexpected.is_empty(),
		"every difference from the old groups is one we meant — unexpected: %s"
			% str(unexpected))
	# And the intended ones must ACTUALLY be there, or the matrix is merely a rename of the
	# two-team system and buys nothing.
	_ok(differ.has("widow -> shoal"),
		"the Widows now prey on Shoal pirates — the pairing two teams could not hold")

	if _fails.is_empty():
		print("test_faction_parity: ALL PASS (%d checks)" % _checks)
	else:
		for f in _fails:
			printerr("  FAIL: %s" % f)
		printerr("test_faction_parity: %d FAILED of %d checks" % [_fails.size(), _checks])
	get_tree().quit(0 if _fails.is_empty() else 1)


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(what)

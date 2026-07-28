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

## The differences we WANT on a pilot who has done nothing yet. Each is a pairing two
## teams could not hold, from the Long Lane's own fiction (user: the Widows "ruthlessly
## raid anyone, including Shoal pirates").
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

	_played_pass(ships)

	if _fails.is_empty():
		print("test_faction_parity: ALL PASS (%d checks)" % _checks)
	else:
		for f in _fails:
			printerr("  FAIL: %s" % f)
		printerr("test_faction_parity: %d FAILED of %d checks" % [_fails.size(), _checks])
	get_tree().quit(0 if _fails.is_empty() else 1)


## ---- PASS 2: THE SAME WORLD, SEEN BY A PILOT WHO HAS PLAYED ----
##
## The fresh-pilot reset above is correct for the question it asks (what does a world
## OPEN with) and it is ALSO how this suite stayed green through two game-breaking bugs
## in one day. Both were invisible on a fresh boot and appeared the moment somebody had
## actually played: a fresh pilot has no truce, no declared war, and no standing, so
## every pair involving the player is decided by the ONE branch the matrix shares with
## the old two-team system. The interesting branches were never entered.
##
## So the same world is asked again as a VETERAN — scripted, not loaded from disk, so it
## stays deterministic. Two player-facing features move the answer:
##
##   the SHOAL TRUCE      standing lifts them out of hostile, so pirates stop being
##                        shootable-on-sight — the campaign's whole ending beat
##   DECLARING WAR        "play your way": haulers become fair game on a toggle
##
## Both are pairings the old enemy_group could not express in either direction, so both
## MUST show up as differences. If they do not, the feature does not reach the guns.
func _played_pass(ships: Array) -> void:
	var pid := Factions.player_id()
	Standing.add("privateer", 60)              # Krayt's truce: out of hostile
	Standing.set_peace("trader", false)        # declare war on the Long Lane
	_ok(not Standing.is_hostile("privateer"), "the truce actually took")
	_ok(Standing.at_war("trader"), "the declaration actually took")

	var differ := _scan(ships)
	var intended := INTENDED.duplicate()
	intended.append([pid, "shoal"])            # I may stop shooting them...
	intended.append(["shoal", pid])            # ...and they me
	# THE HAULER'S FACTION IS "civilian", not "trader" — the ledger it answers to is
	# `trader` (Factions.standing_key), and they are not the same string. Asserting on
	# the ledger name looked right and could never match a live ship.
	intended.append([pid, "civilian"])         # I may now shoot haulers

	print("  --- PLAYED PILOT: pairings where they DIFFER ---")
	var unexpected := _report(differ, intended)
	_ok(unexpected.is_empty(),
		"a PLAYED pilot moves only what we meant — unexpected: %s" % str(unexpected))

	# The features must REACH THE TARGETING LAYER, not merely sit in Standing.
	_ok(differ.has("%s -> shoal" % pid),
		"the truce reaches the guns — the Shoal stops being shootable on sight")
	_ok(differ.has("shoal -> %s" % pid),
		"...and stops shooting back, which two teams could never express")
	# WAR IS CHECKED AGAINST THE MATRIX, not against a live pair. Haulers launch on the
	# lane over time and may not be out yet this early, so a pair-level assertion would
	# pass or fail on a spawn timer rather than on the feature. Factions.hostile IS what
	# the guns call, so asking it directly is the honest form of "reaches the guns" —
	# and the live pair is asserted too, but only when there is actually a hauler to
	# assert it about, and the count is printed either way rather than silently skipped.
	_ok(Factions.hostile(pid, "civilian"),
		"declaring war reaches the targeting rule — haulers become fair game")
	var haulers := 0
	for s in ships:
		if str(s.faction) == "civilian":
			haulers += 1
	print("    (civilian hulls in the world at scan time: %d)" % haulers)
	if haulers > 0:
		_ok(differ.has("%s -> civilian" % pid),
			"...and the live pair agrees — a hauler is now a legal target")


## Every ordered pair, old verdict vs new, aggregated by (faction, faction).
func _scan(ships: Array) -> Dictionary:
	var differ := {}
	for a in ships:
		for b in ships:
			if a == b or str(a.faction) == "" or str(b.faction) == "":
				continue
			var old_v: bool = a.enemy_group != "" and b.is_in_group(a.enemy_group)
			var new_v: bool = Factions.hostile(str(a.faction), str(b.faction))
			if old_v == new_v:
				continue
			var key := "%s -> %s" % [a.faction, b.faction]
			differ[key] = {"old": old_v, "new": new_v,
				"n": int(differ.get(key, {}).get("n", 0)) + 1}
	return differ


## Print the differences and return the ones nobody asked for.
func _report(differ: Dictionary, intended: Array) -> Array:
	var unexpected: Array[String] = []
	for key in differ:
		var d: Dictionary = differ[key]
		var parts := str(key).split(" -> ")
		var meant := false
		for pair in intended:
			if str(pair[0]) == parts[0] and str(pair[1]) == parts[1]:
				meant = true
		print("    %-30s groups:%s  factions:%s  x%d  %s"
			% [key, "HOSTILE" if d.old else "friendly",
				"HOSTILE" if d.new else "friendly", d.n,
				"<-- INTENDED" if meant else "<-- UNEXPECTED"])
		if not meant:
			unexpected.append(str(key))
	return unexpected


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(what)

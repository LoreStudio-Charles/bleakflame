extends Node
## STAGE 3: DO THE GUNS ACTUALLY ASK THE FACTION MATRIX?
##
## test_faction_parity proved the DATA agrees with the teams it replaces. This proves the
## WEAPONS now consult it — the difference between a correct table nobody reads and a
## behaviour change, which is a failure this project has already paid for.
##
## THE HEADLINE CASE IS THE ONE TWO TEAMS COULD NOT EXPRESS: the Widows "ruthlessly raid
## anyone, including Shoal pirates" (user). Both ride hostile_team, and a ship cannot shoot
## its own group, so before this the line was fiction with nothing behind it.
##
##   <godot> --headless --path . res://tools/test_faction_fire.tscn --quit-after 300

var _fails: Array[String] = []
var _checks := 0


func _ready() -> void:
	SaveGame.read_only = true
	_case_widows_can_shoot_shoal()
	_case_a_faction_never_shoots_itself()
	_case_unfactioned_targets_still_work()
	_case_the_broad_phase_finds_across_teams()

	if _fails.is_empty():
		print("test_faction_fire: ALL PASS (%d checks)" % _checks)
	else:
		for f in _fails:
			printerr("  FAIL: %s" % f)
		printerr("test_faction_fire: %d FAILED of %d checks" % [_fails.size(), _checks])
	get_tree().quit(0 if _fails.is_empty() else 1)


## THE POINT OF THE WHOLE EXERCISE.
func _case_widows_can_shoot_shoal() -> void:
	var widow := _ship("widow", "hostile_team")
	var shoal := _ship("shoal", "hostile_team")
	# Same team, opposed factions: the old rule says friendly, the matrix says prey.
	_ok(shoal.is_in_group(widow.enemy_group) == false or widow.enemy_group != "hostile_team",
		"the two share a team, so the old rule could never have allowed this")
	_ok(BuildShip.may_engage(widow, shoal, "player_team"),
		"a Widow may fire on a Shoal raider")
	_ok(BuildShip.may_engage(shoal, widow, "player_team"),
		"...and the Shoal returns it")
	widow.queue_free()
	shoal.queue_free()


func _case_a_faction_never_shoots_itself() -> void:
	var a := _ship("widow", "hostile_team")
	var b := _ship("widow", "hostile_team")
	_ok(not BuildShip.may_engage(a, b, "player_team"),
		"the Widows hate everyone EXCEPT each other — 'hate everyone' must not mean itself")
	var g1 := _ship("guardian", "player_team")
	var g2 := _ship("navy", "player_team")
	_ok(not BuildShip.may_engage(g1, g2, "hostile_team"),
		"a Guardian never fires on the Navy — allied, and allied is not merely not-hostile")
	_ok(not BuildShip.may_engage(g1, g1, "hostile_team"), "nothing shoots itself")
	for n in [a, b, g1, g2]:
		n.queue_free()


## THE REGRESSION THE ADDITIVE RULE EXISTS TO PREVENT. A decoy is not a BuildShip and
## joins no faction; its entire job is to be shot at in the real hull's place. Filtering
## purely by faction would have made it invisible to every gun in the game.
func _case_unfactioned_targets_still_work() -> void:
	var hunter := _ship("shoal", "hostile_team")
	var bait := Node2D.new()
	bait.add_to_group("player_team")
	add_child(bait)
	_ok(BuildShip.may_engage(hunter, bait, "player_team"),
		"a factionless decoy on the target team is still engageable")
	var bystander := Node2D.new()
	bystander.add_to_group("traders")
	add_child(bystander)
	_ok(not BuildShip.may_engage(hunter, bystander, "player_team"),
		"...but something on no relevant team is still not")
	hunter.queue_free()
	bait.queue_free()
	bystander.queue_free()


## The broad phase must REACH the new target. may_engage() can be perfectly correct while
## engageable() never iterates the ship it would have approved — that is the same
## "correct helper nobody calls" shape, one level up.
func _case_the_broad_phase_finds_across_teams() -> void:
	var widow := _ship("widow", "hostile_team")
	widow.enemy_group = "player_team"        # its own team is NOT in its legacy group
	var shoal := _ship("shoal", "hostile_team")
	var found := BuildShip.engageable(get_tree(), widow, widow.enemy_group)
	_ok(found.has(shoal),
		"engageable() reaches a Shoal raider the legacy group would never have iterated")
	_ok(not found.has(widow), "...and never returns the shooter itself")
	var n := 0
	for f in found:
		if f == shoal:
			n += 1
	_ok(n == 1, "...exactly once, despite being reachable through two groups (%d)" % n)
	widow.queue_free()
	shoal.queue_free()


func _ship(fac: String, team: String) -> AIShip:
	var a := AIShip.new()
	add_child(a)
	a.setup(SampleBuilds.get_build(0))
	a.faction = fac
	if not a.is_in_group(team):
		a.add_to_group(team)
	return a


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(what)

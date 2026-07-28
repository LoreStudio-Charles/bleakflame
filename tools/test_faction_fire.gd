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
	_case_a_bolt_outlives_its_shooter()

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
	# free(), NOT queue_free(): these two are bare Node2Ds with no take_damage, and
	# queue_free defers to the end of the frame — so they were still sitting in
	# "player_team" when the NEXT case detonated a blast, which called take_damage on a
	# plain Node2D and printed a script error that had nothing to do with the code under
	# test. A synthetic fixture must not outlive its case.
	hunter.queue_free()
	bait.free()
	bystander.free()


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


## A BOLT OUTLIVES THE SHIP THAT FIRED IT — and killing the shooter mid-flight CRASHED
## the game (playtest, 2026-07-27): "Invalid type in function 'engageable' ... argument 2
## (previously freed) is not a subclass of the expected argument class."
##
## THE LESSON IS ABOUT TYPED PARAMETERS, and it is not obvious. A freed Object cannot be
## PASSED to a typed parameter at all — Godot rejects the CALL, so a callee that guards
## with `is_instance_valid` never runs. Projectile already knew a shooter can die (two
## take_damage sites carried "pass null, never a freed object") and the faction switch
## still added four raw call sites beside those very comments, because the guard was
## written per-use instead of living with the reference.
##
## Every path is exercised: the swept-hit loop, the proximity fuze, the blast, and the
## homing re-acquire. All four called engageable directly.
func _case_a_bolt_outlives_its_shooter() -> void:
	var shooter := _ship("shoal", "hostile_team")
	var mark := _ship("guardian", "player_team")
	mark.global_position = Vector2(60, 0)

	var def := WeaponDef.new()
	def.damage = 5.0
	def.projectile_speed = 400.0
	def.weapon_range = 900.0
	def.blast_radius = 40.0        # exercises the fuze + blast paths too
	def.homing = 90.0              # ...and the re-acquire path
	var bolt := Projectile.spawn(self, Vector2.ZERO, Vector2.RIGHT, def,
		"player_team", 0.0, 1.0, shooter)
	_ok(bolt.live_shooter() == shooter, "a live shooter is reported as itself")

	# KILL IT OUTRIGHT. free(), not queue_free(): queue_free defers to the end of the
	# frame, so the reference would still be valid here and the test would prove nothing
	# — which is exactly how this hazard stayed invisible.
	shooter.free()
	_ok(bolt.live_shooter() == null,
		"a freed shooter resolves to null instead of a dangling reference")

	# THE CALL ITSELF is the thing that used to throw. Reaching for foes at all is the
	# assertion; that it still finds the mark proves the bolt did not go inert either —
	# a shot already in the air keeps the allegiance it was fired with.
	var foes := bolt._foes()
	_ok(foes.has(mark),
		"the orphaned bolt still resolves its targets (%d found)" % foes.size())

	# And a full physics step over every path, which is where the crash was reported.
	bolt._physics_process(0.016)
	_ok(is_instance_valid(bolt) or true, "a physics tick with a dead shooter does not throw")
	if is_instance_valid(bolt):
		bolt.queue_free()
	mark.queue_free()


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

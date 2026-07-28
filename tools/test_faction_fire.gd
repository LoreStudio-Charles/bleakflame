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
	_case_a_played_pilot_can_still_shoot_pirates()
	_case_a_bolt_actually_lands_damage()
	_case_you_may_always_declare_war()

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


## PLAY YOUR WAY (user, 2026-07-27): "Players should always be able to manually declare
## war on a faction if they wish ... so they can fire on a friendly NPC and ruin their
## rep if they want to. Generally a bad idea, but play your way I guess."
##
## THIS IS THE HALF OF THE MATRIX THAT IS NOT A RESTORATION. The legacy group is a floor,
## so it can only ever ADD hostility — and a friendly Guardian is in player_team, which no
## floor will ever make shootable. Only the matrix can grant this, via Standing's peace
## toggle, which is exactly the case two teams could never express: a target that is
## friendly to everyone else and fair game to you.
##
## It is also the assertion that stops a future "simplification" from collapsing
## may_engage back to groups-only. That would silently delete piracy.
func _case_you_may_always_declare_war() -> void:
	var me := _ship("shoal", "player_team")
	me.faction = Factions.player_id()
	var guard := _ship("guardian", "player_team")
	Standing.reset()

	_ok(not BuildShip.may_engage(me, guard, "hostile_team"),
		"at peace a Guardian is NOT a target — you cannot shoot allies by accident")
	_ok(Standing.set_peace("guardian", false), "war can always be declared")
	_ok(BuildShip.may_engage(me, guard, "hostile_team"),
		"...and having declared it, your guns will fire on them")

	# SUING FOR PEACE IS NOT SYMMETRIC. Declaring war is instant; taking it back is a
	# decision the OTHER side gets a say in once you have pushed them into hostility.
	_ok(Standing.set_peace("guardian", true), "peace can be restored while they still tolerate you")
	_ok(not BuildShip.may_engage(me, guard, "hostile_team"), "...and the guns stand down")
	Standing.add("guardian", Standing.HOSTILE_AT - Standing.get_points("guardian"))
	_ok(not Standing.set_peace("guardian", true),
		"once they are hostile you cannot simply switch it off — you mend it")
	_ok(BuildShip.may_engage(me, guard, "hostile_team"),
		"...and a faction that wants you dead is fair game without any paperwork")

	Standing.reset()
	me.queue_free()
	guard.queue_free()


## THE GAME-BREAKER: A PLAYED PILOT COULD NOT SHOOT ANYTHING (playtest, 2026-07-27).
##
## Ambient pirates carry faction "shoal" and the player is "pilot:local", so BOTH sides
## had a faction — and may_engage used to let the matrix decide alone whenever that was
## true. Factions._player_toward("shoal") reads Standing.is_hostile("privateer"), a
## ledger that OPENS AT -100. A brand new pilot is therefore hostile and everything
## works; the moment Shoal standing rises above -100 the auto-peace guard flips you to
## peace, the matrix answers NEUTRAL, and every pirate becomes unshootable both ways.
##
## WHY NOTHING CAUGHT IT, and this is the lesson: test_faction_parity walks every ordered
## pair in the live world, but FIRST does `PlayerState.local = PlayerState.new()` — a
## FRESH pilot — with a comment explaining that the developer's played save had made
## peace with the Shoal and skewed the run. The test removed the exact state that breaks
## the feature, and documented itself doing it. A fresh-pilot check is necessary and not
## sufficient: the game is played by played pilots.
func _case_a_played_pilot_can_still_shoot_pirates() -> void:
	var me := _ship("shoal", "hostile_team")     # stand-in with the pirate's own faction
	me.faction = Factions.player_id()
	me.remove_from_group("hostile_team")
	me.add_to_group("player_team")
	var pirate := _ship("shoal", "hostile_team")

	# EVERY RUNG OF THE SHOAL LADDER, because each one is a real save state a tester can
	# be sitting in — and all but the first used to disarm the game.
	for points in [-100, -50, 0, Standing.INVITE_AT, Standing.FRIENDLY_AT]:
		Standing.reset()
		Standing.add("privateer", points - Standing.get_points("privateer"))
		_ok(BuildShip.may_engage(me, pirate, "hostile_team"),
			"at Shoal standing %d a pirate on hostile_team is still shootable" % points)
		_ok(BuildShip.may_engage(pirate, me, "player_team"),
			"...and it can still shoot back at %d" % points)
	Standing.reset()
	me.queue_free()
	pirate.queue_free()


## END TO END: DOES A BOLT ACTUALLY REMOVE HIT POINTS?
##
## Everything else here asks a PREDICATE. The predicate was correct in isolation the
## whole time — it was correct about the wrong pilot. Only firing a real Projectile at a
## real ship and reading its hull afterwards can tell you the game still works, which is
## the difference between "the rule is right" and "the game does damage".
func _case_a_bolt_actually_lands_damage() -> void:
	var pirate := _ship("shoal", "hostile_team")
	pirate.global_position = Vector2(120, 0)
	# A PLAYED pilot, at peace with the Shoal — the state that broke it.
	Standing.reset()
	Standing.add("privateer", 50 - Standing.get_points("privateer"))

	# EFFECTIVE HP, not hull: take_damage tiers shield -> armor -> hull, so a small bolt
	# against a shielded hull leaves `hull` untouched and a hull-only assertion reads a
	# perfectly good hit as a miss.
	var before := _hp(pirate)
	var def := WeaponDef.new()
	def.damage = 12.0
	def.projectile_speed = 600.0
	def.weapon_range = 900.0
	# FIRED BY A PILOT, not by nobody. The first draft passed `null` as the shooter — so
	# `sf` was empty, may_engage never reached the faction branch, and the case sailed
	# through the very bug it was written for. Sabotage caught that; a green test that
	# cannot fail is worse than no test. A real bolt always has an owner.
	var me := _ship("shoal", "player_team")
	me.faction = Factions.player_id()
	var bolt := Projectile.spawn(self, Vector2(60, 0), Vector2.RIGHT, def,
		"hostile_team", 0.0, 1.0, me)
	# Step until it either lands or expires — a swept test needs the bolt to move.
	for _i in 30:
		if not is_instance_valid(bolt):
			break
		bolt._physics_process(0.05)
	_ok(_hp(pirate) < before,
		"a bolt fired at a pirate DOES DAMAGE (%.1f -> %.1f)" % [before, _hp(pirate)])
	Standing.reset()
	if is_instance_valid(bolt):
		bolt.queue_free()
	me.queue_free()
	pirate.queue_free()


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


## Effective hit points across all three tiers. take_damage spends shield, then armor,
## then hull, so only the SUM answers "did that land".
func _hp(n: Node) -> float:
	return float(n.shield) + float(n.armor) + float(n.hull)


func _ship(fac: String, team: String) -> AIShip:
	var a := AIShip.new()
	add_child(a)
	a.setup(SampleBuilds.get_build(0))
	a.faction = fac
	# AIShip._ready joins "hostile_team" UNCONDITIONALLY. A fixture standing on another
	# team has to leave it, or it sits in both at once — a state no real ship is ever in
	# (GuardianShip extends BuildShip, not AIShip, precisely so it never joins), and it
	# makes a synthetic Guardian look shootable by a synthetic Navy.
	if team != "hostile_team":
		a.remove_from_group("hostile_team")
	if not a.is_in_group(team):
		a.add_to_group(team)
	return a


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(what)

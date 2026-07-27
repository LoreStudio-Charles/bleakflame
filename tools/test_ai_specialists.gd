extends Node
## RARE AI SPECIALISTS — do they actually do the thing, and stay rare?
##
## A clean boot proves nothing here: a specialist only acts when a pirate, a
## wounded ally and a prey all exist at once, which a headless flight scene will
## not arrange on its own. So this builds those situations directly.
##
## RUN AS A SCENE (autoloads):
##   <godot> --headless --path . res://tools/test_ai_specialists.tscn
## Never writes the save.

var _fails: Array[String] = []
var _checks := 0


func _ready() -> void:
	_case_rarity()
	_case_mender_heals()
	_case_warden_braces()
	_case_binder_snares()
	_case_only_pirates_specialize()
	_case_rescue_standing_must_be_earned()
	_case_ships_keep_their_distance()
	_case_nothing_chases_prey_into_a_gravity_well()
	_case_courage_does_not_depend_on_rate_of_fire()
	_case_fighting_style_is_authored_not_derived()
	_case_a_holed_ship_cannot_run()
	_case_an_ally_is_healed_once_not_twice()
	_case_shadow_escort_trails_and_hangs_back()
	_case_shadow_escort_commits_on_spring()
	_case_miner_ore_sense_is_a_commission_perk()
	_case_moving_shooter_fires_true()
	_case_bolts_inherit_shooter_velocity()
	_case_scan_chip_enables_scanning()
	_case_killshot_range_and_fire()
	_case_collision_damage()
	_case_every_played_sound_exists()
	_case_tutor_watchdog_unjams()

	if _fails.is_empty():
		print("test_ai_specialists: ALL PASS (%d checks)" % _checks)
	else:
		for f in _fails:
			printerr("  FAIL: %s" % f)
		printerr("test_ai_specialists: %d FAILED of %d checks" % [_fails.size(), _checks])
	get_tree().quit(0 if _fails.is_empty() else 1)


## THE POINT IS RARITY. If most pirates cast, the specialist stops being an
## event and becomes a tax. Sampled over many rolls so a bad constant is caught.
func _case_rarity() -> void:
	# Sampled WITHOUT building 400 ships: each AIShip constructs sprites, mounts
	# and particles, and a few hundred of those blew a five-minute budget. The
	# roll is the thing under test, so drive it directly on one reusable hull.
	seed(20260722)
	var specialists := 0
	var total := 300
	var probe := _pirate()
	# SPECIALISTS ARE LEVEL-GATED NOW (SPECIALIST_MIN_LEVEL, user 2026-07-26), so a
	# rim-level probe can never roll one and this case would report 0% forever —
	# passing as "rare" while actually measuring the gate. Age the probe past the
	# floor so what is under test is still the CHANCE.
	probe.spawn_level = AIShip.SPECIALIST_MIN_LEVEL
	for i in total:
		probe.specialty = AIShip.Specialty.NONE
		probe._roll_specialty()
		if probe.specialty != AIShip.Specialty.NONE:
			specialists += 1
	probe.free()
	var rate := float(specialists) / float(total)
	_ok(rate > 0.02, "specialists actually occur (%.0f%%)" % (rate * 100.0))
	_ok(rate < 0.30, "specialists stay RARE — under a third of pirates (%.0f%%)" % (rate * 100.0))


func _case_mender_heals() -> void:
	var medic := _pirate(AIShip.Specialty.MENDER)
	var patient := _pirate()
	patient.global_position = medic.global_position + Vector2(120, 0)
	patient.hull = patient.stats.hull_hp * 0.4
	var before: float = patient.hull
	medic._tick_specialty(0.1, null)
	_ok(patient.hull > before, "a Mender heals a wounded ally")

	# ...and does not burn its cooldown on a wing that is already fine.
	var medic2 := _pirate(AIShip.Specialty.MENDER)
	var healthy := _pirate()
	healthy.global_position = medic2.global_position + Vector2(120, 0)
	medic2._tick_specialty(0.1, null)
	_ok(medic2._spec_cd == 0.0, "a Mender with nobody hurt just flies")


func _case_warden_braces() -> void:
	var warden := _pirate(AIShip.Specialty.WARDEN)
	var friend := _pirate()
	friend.global_position = warden.global_position + Vector2(200, 0)
	friend.hull = friend.stats.hull_hp * 0.3     # someone is in trouble
	warden._tick_specialty(0.1, null)
	_ok(warden._dmg_reduction > 0.0, "a Warden braces itself")
	_ok(friend._dmg_reduction > 0.0, "a Warden braces its wing")

	# The brace must actually reduce damage — the buff is worthless if
	# take_damage ignores it.
	var hp: float = friend.hull
	friend.shield = 0.0
	friend.armor = 0.0
	friend.take_damage(100.0)
	_ok(friend.hull > hp - 100.0, "the brace really cuts incoming damage")


func _case_binder_snares() -> void:
	var binder := _pirate(AIShip.Specialty.BINDER)
	var prey := _pirate()
	prey.global_position = binder.global_position + Vector2(300, 0)
	var before := get_child_count()
	binder._tick_specialty(0.1, prey)
	_ok(get_child_count() > before, "a Binder puts a tangle field on its prey")

	# Out of range it holds its cast rather than firing into nothing.
	var b2 := _pirate(AIShip.Specialty.BINDER)
	var far := _pirate()
	far.global_position = b2.global_position + Vector2(AIShip.BINDER_RANGE + 500.0, 0)
	b2._tick_specialty(0.1, far)
	_ok(b2._spec_cd == 0.0, "a Binder holds its cast when prey is out of range")


## Practice drones and the station guard wing must NEVER roll a specialty. They
## are separate classes today, and this is the assertion that notices if one is
## ever re-parented onto AIShip.
func _case_only_pirates_specialize() -> void:
	# Written as a PROPERTY probe, not a type check: `x is AIShip` on these two is
	# a COMPILE error today ("Expression is of type GuardianShip so it can't be of
	# type AIShip") — the compiler already proves the invariant, but a compile
	# error is not a test. Probing for the `specialty` field compiles now and
	# starts failing the moment either class is re-parented onto AIShip.
	var drone := TargetDrone.new()
	var guard := GuardianShip.new()
	_ok(not ("specialty" in drone), "practice drones never roll a specialty")
	_ok(not ("specialty" in guard), "the guard wing never rolls a pirate specialty")
	drone.free()
	guard.free()


## STANDING IS EARNED. A hauler's rescue bonus may only pay out when the PLAYER
## killed the pirate. The lane kills pirates by itself from t=0 (Guardian
## patrols, Cinderweb), and crediting those put a fresh pilot at INVITE_AT with
## two commission doors already open.
func _case_rescue_standing_must_be_earned() -> void:
	# 1. Someone else's kill pays nothing.
	Standing.points.clear()
	var hauler := _hauler()
	var pirate := _pirate()
	hauler._watch_savior(pirate)
	pirate.died.emit()                      # died with no player attacker
	_ok(Standing.get_points("guardian") == 0,
		"a pirate killed by someone else grants NO Guardian standing")
	_ok(Standing.get_points("trader") == 0,
		"a pirate killed by someone else grants NO Trader standing")

	# 2. ...and the hauler is still rescuable afterwards, so the miss does not
	#    silently consume its one payout.
	var player := TestShip.new()
	add_child(player)
	player.add_to_group("player_ship")
	var pirate2 := _pirate()
	pirate2.take_damage(1.0, player)        # now the player is the last attacker
	hauler._watch_savior(pirate2)
	pirate2.died.emit()
	_ok(Standing.get_points("guardian") > 0 and Standing.get_points("trader") > 0,
		"the player's own kill still pays the rescue")


func _hauler() -> TraderShip:
	var t := TraderShip.new()
	add_child(t)
	t.setup(SampleBuilds.get_build(0))
	return t


## NOT BUMPER CARS. Separation is a NUDGE, not a force field — the ask was fewer
## collisions, not none — so this asserts the push exists and points the right
## way, rather than that ships never touch.
func _case_ships_keep_their_distance() -> void:
	var a := _pirate()
	var b := _pirate()
	var FAR := Vector2(60000, 60000)        # clear of ships parked by earlier cases
	a.global_position = FAR
	b.global_position = FAR + Vector2(30, 0)   # practically inside each other

	var away: Vector2 = a.separation_dir()
	_ok(away != Vector2.ZERO, "a crowded ship feels a push")
	_ok(away.x < 0.0, "...and the push is AWAY from its neighbour, not toward it")

	# Far apart, nothing should tug at all — separation must not warp normal flight.
	b.global_position = FAR + Vector2(4000, 0)
	_ok(a.separation_dir() == Vector2.ZERO, "ships with room are left alone")

	# The PLAYER is never auto-steered, however crowded it gets.
	var player := TestShip.new()
	add_child(player)
	_ok(not player.avoids_obstacles, "the player is never steered by the game")
	_ok(a.avoids_obstacles, "...but AI is")

	# THE WIRING, not just the maths. separation_dir() being correct is worthless
	# if apply_movement ignores it — and a test of the helper alone passes
	# happily with the movement seam disabled (verified by sabotage).
	var steered := _pirate()
	var straight := _pirate()
	steered.global_position = FAR + Vector2(0, 3000)
	straight.global_position = FAR + Vector2(0, 3000)
	steered.avoids_obstacles = true
	straight.avoids_obstacles = false
	var wall := _pirate()                       # something to steer around
	wall.global_position = steered.global_position + Vector2(120, 0)
	wall.avoids_obstacles = false
	var into := Vector2(600, 0)                 # thrust straight at it
	steered.velocity = Vector2.ZERO
	straight.velocity = Vector2.ZERO
	steered.apply_movement(into, 0.2)
	straight.apply_movement(into, 0.2)
	_ok(absf(steered.velocity.angle_to(into)) > absf(straight.velocity.angle_to(into)),
		"apply_movement actually DEFLECTS an avoiding ship around a neighbour")
	_ok(is_equal_approx(straight.velocity.angle_to(into), 0.0),
		"...and leaves a non-avoiding ship flying straight")
	steered.free(); straight.free(); wall.free()

	# THE NOSE MUST TURN. These AI derive thrust from `rotation`, so deflecting
	# the thrust vector alone is undone next frame while the hull keeps pointing
	# at the obstacle — the exact reason guardians still rammed the station after
	# separation was "working".
	var flyer := _pirate()
	flyer.global_position = FAR + Vector2(0, 7000)
	flyer.rotation = 0.0                       # nose +X, straight at the blocker
	flyer.avoids_obstacles = true
	var blocker := _pirate()
	blocker.global_position = flyer.global_position + Vector2(110, 0)
	blocker.avoids_obstacles = false
	var before: float = flyer.rotation
	for i in 10:
		flyer.apply_movement(Vector2.RIGHT.rotated(flyer.rotation) * 600.0, 0.05)
	_ok(absf(angle_difference(flyer.rotation, before)) > 0.05,
		"a ship bearing down on an obstacle TURNS AWAY, not just drifts")
	flyer.free(); blocker.free()

	# Exactly-stacked ships must still separate rather than divide by zero.
	b.global_position = a.global_position
	_ok(a.separation_dir() != Vector2.ZERO, "perfectly stacked hulls still push apart")
	a.free(); b.free(); player.free()


## A BOLT MUST OUTRUN THE SHIP THAT FIRED IT. Without inheriting the shooter's
## velocity a projectile has the same world speed however fast you fly, so at
## speed it crawls a few lengths ahead and dies on its timer — "my guns stop
## working when I go fast". Reach from the SHOOTER's frame must stay exactly
## weapon_range, which is why `life` is unchanged.
func _case_bolts_inherit_shooter_velocity() -> void:
	var gun := WeaponDef.new()
	gun.projectile_speed = 1000.0
	gun.weapon_range = 2000.0
	gun.damage = 10.0

	var still := _pirate()
	still.global_position = Vector2(90000, 0)
	still.velocity = Vector2.ZERO
	var fast := _pirate()
	fast.global_position = Vector2(92000, 0)
	fast.velocity = Vector2(900, 0)          # nearly as fast as the bolt

	var dir := Vector2.RIGHT
	var b1 := Projectile.spawn(self, still.global_position, dir, gun, "hostile_team", 0.0, 1.0, still)
	var b2 := Projectile.spawn(self, fast.global_position, dir, gun, "hostile_team", 0.0, 1.0, fast)

	_ok(is_equal_approx(b1.velocity.x, 1000.0),
		"a standing ship's bolt flies at muzzle speed")
	_ok(b2.velocity.x > 1800.0,
		"a fast ship's bolt carries the ship's velocity too (%.0f)" % b2.velocity.x)
	# The bit that makes it FEEL right: closing speed relative to the shooter is
	# still muzzle speed, so the weapon's reach is unchanged by how fast you fly.
	_ok(is_equal_approx(b2.velocity.x - fast.velocity.x, 1000.0),
		"...so reach from the shooter's own frame is unchanged")
	_ok(is_equal_approx(b1.life, b2.life), "and lifetime is not shortened by speed")
	b1.free(); b2.free(); still.free(); fast.free()


## THE TUTOR CANNOT JAM FOREVER. A lesson that is eligible (safe, right context)
## but stuck on screen doing nothing — the entire failure mode behind this
## session's tutor bugs — must eventually give up so the queue drains. The
## watchdog counts only ELIGIBLE-but-idle time and retires past STALL_LIMIT.
func _case_tutor_watchdog_unjams() -> void:
	Tutor.reset()
	Tutor.safe = true
	Tutor.context = "dock"
	Tutor.venue = "station"
	# A dock lesson whose step just sits there (no player action drives it).
	Tutor.arm("buy_scanner")
	_ok(Tutor.active == "buy_scanner", "a lesson is running")

	# A patient reader is NOT a stall: eligible time under the limit keeps it.
	Tutor.tick(Tutor.STALL_LIMIT * 0.5)
	_ok(Tutor.active == "buy_scanner", "a slow reader is left alone")

	# Past the limit with no progress, it gives up rather than blocking forever.
	Tutor.tick(Tutor.STALL_LIMIT)
	_ok(Tutor.active != "buy_scanner", "a stuck lesson retires so the queue drains")

	# ...and the abandonment is LOGGED for review, aggregated by site.
	_ok(not Tutor.stalls.is_empty(), "an abandoned lesson is recorded in the stall log")
	var before := 0
	for k in Tutor.stalls:
		before += int(Tutor.stalls[k].get("count", 0))
	Tutor.record_stall("buy_scanner", 1, "manual")
	Tutor.record_stall("buy_scanner", 1, "manual")   # same site: increments, no flood
	var sites := Tutor.stalls.size()
	Tutor.record_stall("buy_scanner", 1, "manual")
	_ok(Tutor.stalls.size() == sites, "repeat stalls at one site AGGREGATE, not duplicate")

	# It survives a save round-trip (this is the whole point — review later).
	var dumped := Tutor.stalls_to_list()
	Tutor.stalls.clear()
	Tutor.stalls_from_list(dumped)
	_ok(not Tutor.stalls.is_empty(), "the stall log persists across save/load")

	# Progress resets the clock — advancing a step is not stalling.
	Tutor.reset(); Tutor.safe = true; Tutor.context = "dock"; Tutor.venue = "station"
	Tutor.arm("buy_scanner")
	Tutor.tick(Tutor.STALL_LIMIT * 0.9)
	Tutor.note(str(Tutor.current().get("anchor", "")))    # advance a step
	Tutor.tick(Tutor.STALL_LIMIT * 0.9)
	_ok(Tutor.active == "buy_scanner", "making progress resets the stall timer")


## FITTING THE SCAN CHIP MUST LET YOU SCAN. The scan ability moved to the Survey
## Routine CHIP and the scanner MODULE was deleted, but `scanner_fitted` still
## read has_system_tag("scanner") — so [1] answered "NO SCANNER FITTED" on a ship
## that plainly knew scan. Every use of scanner_fitted means "knows scan".
func _case_scan_chip_enables_scanning() -> void:
	var bare := _pirate()
	_ok(not bare.scanner_fitted, "a ship with no scan chip cannot scan")

	var scanner := TestShip.new()
	add_child(scanner)
	var b := SampleBuilds.get_build(SampleBuilds.current)
	b.chips.append(load("res://data/components/chips/survey_scan_chip.tres"))
	scanner.apply_build(b)
	_ok(scanner._known_abilities.has("scan"), "the Survey Routine chip grants the scan ability")
	_ok(scanner.scanner_fitted,
		"...and scanner_fitted follows the ability, so [1] will fire")
	scanner.free()


## COLLISION DAMAGE — a real impact is a MISTAKE and costs hull; a gentle nudge
## is free. Now that everyone avoids obstacles, contact reads as physics, not a
## tax, so it should hurt when you actually drive into something hard.
func _case_collision_damage() -> void:
	# A hard head-on: full hull, then ram the surface at speed.
	var a := _pirate()
	a.shield = 0.0; a.armor = 0.0
	var full: float = a.hull
	a._apply_collision_damage(700.0)
	_ok(a.hull < full, "a hard impact damages the hull")

	# Gentle contact below the floor is free — creep-docking must never hurt.
	var b := _pirate()
	b.shield = 0.0; b.armor = 0.0
	var bfull: float = b.hull
	b._apply_collision_damage(BuildShip.COLLISION_MIN_SPEED - 10.0)
	_ok(b.hull == bfull, "a gentle nudge does no damage")

	# One hit per impact, not per sliding frame: the cooldown blocks the second.
	var c := _pirate()
	c.shield = 0.0; c.armor = 0.0
	c._apply_collision_damage(700.0)
	var after_one: float = c.hull
	c._apply_collision_damage(700.0)          # same impact, next frame
	_ok(c.hull == after_one, "collision damage is throttled to one hit per impact")

	# Harder ram hurts more than a soft one (above the floor).
	var d := _pirate(); d.shield = 0.0; d.armor = 0.0; var d0 := d.hull
	d._apply_collision_damage(400.0)
	var soft := d0 - d.hull
	var e := _pirate(); e.shield = 0.0; e.armor = 0.0; var e0 := e.hull
	e._apply_collision_damage(850.0)
	var hard := e0 - e.hull
	_ok(hard > soft, "a faster impact hurts more")

	# A dead ship takes no further collision damage.
	var f := _pirate(); f.dead = true; f.shield = 0.0; f.armor = 0.0; var f0 := f.hull
	f._apply_collision_damage(900.0)
	_ok(f.hull == f0, "a dead ship is not hurt by collisions")
	for s2 in [a, b, c, d, e, f]:
		s2.free()


## EVERY SOUND A PROFESSION ABILITY PLAYS MUST EXIST. Killshot and Lance played
## "shot", which was never in the streams dict — _streams[sound] then hard-crashed
## mid-combat. The sounds the new abilities use are checked directly, and play()
## on an unknown name must now no-op rather than throw.
func _case_every_played_sound_exists() -> void:
	for name in ["shot", "pew", "hit", "explosion", "click", "jingle", "scrape",
			"shield_hit", "dread", "static", "pickup", "dock", "slide"]:
		_ok(Sfx._streams.has(name), "the '%s' sound is defined" % name)
	# An unknown name is now survivable, not fatal.
	Sfx.play("definitely_not_a_real_sound")
	Sfx.play_at("also_fake", Vector2.ZERO)
	_ok(true, "playing an unknown sound no-ops instead of crashing")


## KILLSHOT MUST FIRE AT REAL COMBAT RANGE. It was 700-2400 (min too far for a
## dogfight, so it refused constantly and read as "does nothing"); retuned to
## 300-1800. The chip's `extra` is authoritative, so this checks the value the
## FITTED chip actually yields, plus that a mid-range shot lands and a
## point-blank one is still refused.
func _case_killshot_range_and_fire() -> void:
	var me := TestShip.new()
	add_child(me)
	var b := SampleBuilds.get_build(SampleBuilds.current)
	b.chips.append(load("res://data/components/chips/killshot_coilgun.tres"))
	me.apply_build(b)
	_ok(me._killshot_min_range == 300.0, "the fitted chip yields the 300 minimum")
	_ok(me._killshot_max_range == 1800.0, "the fitted chip yields the 1800 maximum")

	me.global_position = Vector2.ZERO; me.rotation = 0.0; me.energy = 999.0
	var foe := _pirate()
	foe.shield = 0.0

	# 500u, on the nose: was refused at the old 700 floor, now a clean hit.
	foe.global_position = Vector2(500, 0)
	me.target = foe
	var before: float = foe.hull
	me._engage_killshot()
	_ok(foe.hull < before, "a mid-range mark (500u) takes the shot")

	# Point-blank is still refused — it is not a brawling weapon.
	var me2 := TestShip.new(); add_child(me2)
	me2.apply_build(b); me2.global_position = Vector2.ZERO; me2.rotation = 0.0; me2.energy = 999.0
	var close := _pirate(); close.shield = 0.0
	close.global_position = Vector2(120, 0)   # inside the 300 floor
	me2.target = close
	var ch: float = close.hull
	me2._engage_killshot()
	_ok(close.hull == ch, "a point-blank mark is still refused")
	me.free(); me2.free()


## SHADOW ESCORT (survive_event beat). The ambush wing is no longer a spawn at the
## spring moment — it launches from home and TRAILS the pilot to the objective,
## hanging back out of sight, then breaks to engage when the beast opens. Verifies
## the two behaviours that make that read right: it cruises toward the objective
## when clear, and it backs OFF the objective heading to keep clear of a pilot.
## FAR from other cases' ships so their strays are never the "nearest player".
func _case_shadow_escort_trails_and_hangs_back() -> void:
	var FAR := Vector2(-60000, -60000)
	var obj := FAR + Vector2(5000, 0)

	# Clear road: cruise toward the objective.
	var g := GuardianShip.spawn_shadow_escort(self, FAR, obj, SampleBuilds.guardian_kestrel())
	for i in 20:
		g._fly_shadow(0.1)
	_ok(g.velocity.x > 0.0, "shadow escort cruises toward the objective when the road is clear")
	g.free()

	# A pilot crowding it from ahead (inside HANG_BACK): back off, don't tailgate.
	var g2 := GuardianShip.spawn_shadow_escort(self, FAR, obj, SampleBuilds.guardian_kestrel())
	var pilot := Node2D.new()
	pilot.add_to_group("player_ship")
	add_child(pilot)
	pilot.global_position = FAR + Vector2(700, 0)     # crowding, inside SHADOW_HANG_BACK
	for i in 90:
		g2._fly_shadow(0.1)
	_ok(g2.velocity.x < 0.0,
		"shadow escort backs off the objective heading to hang back from the pilot")
	g2.free()
	pilot.free()


## And the spring: assigning escort_target (what flight_test._commit_shadow_escort
## does) must OVERRIDE the shadow trail so the wing charges the beast, wherever it
## was drifting — the escort branch runs before the shadow branch.
func _case_shadow_escort_commits_on_spring() -> void:
	var FAR := Vector2(-60000, 60000)
	var obj := FAR + Vector2(-4000, 0)                 # objective to the LEFT
	var g := GuardianShip.spawn_shadow_escort(self, FAR, obj, SampleBuilds.guardian_kestrel())
	var beast := _pirate()                             # a real BuildShip (has dead + velocity)
	beast.global_position = FAR + Vector2(4000, 0)     # the beast to the RIGHT
	g.rotation = PI                                    # currently facing the objective
	g.shadow_escort = false                            # commit, as flight_test does
	g.escort_target = beast
	for i in 30:
		g._physics_process(0.1)
	_ok(g.velocity.x > 0.0, "on spring the wing charges the beast, not the objective it was patrolling")
	g.free()
	beast.free()


## MINER ORE-SENSE is a commission perk: mineable rock paints the radar only for a
## Miner (ore_sense stat > 0), staying off the scope for everyone else. Gates the
## radar loop that draws asteroid blips.
func _case_miner_ore_sense_is_a_commission_perk() -> void:
	var prev := Pilot.profession
	Pilot.profession = ""
	var civ := TestShip.new()
	add_child(civ)
	civ.apply_build(SampleBuilds.get_build(SampleBuilds.current))
	_ok(float(civ.stats.get("ore_sense", 0.0)) == 0.0,
		"a non-miner has no ore-sense — rock stays off the scope")

	Pilot.profession = "miner"
	var miner := TestShip.new()
	add_child(miner)
	miner.apply_build(SampleBuilds.get_build(SampleBuilds.current))
	_ok(float(miner.stats.get("ore_sense", 0.0)) >= Pilot.MINER_ORE_SENSE,
		"the Miner commission grants ore-sense, painting rock on the radar")

	Pilot.profession = prev
	civ.free()
	miner.free()


## AIM COMPENSATES FOR THE SHOOTER'S OWN VELOCITY. Bolts inherit the shooter's
## velocity now (so your guns don't crawl at speed), but the auto-aim wasn't leading
## for that — a strafing pirate fired wide ("bullets aren't accurate", playtest).
## WeaponMount.intercept_point solves the lead in the shooter's frame so a moving
## shooter's bolt flies true.
func _case_moving_shooter_fires_true() -> void:
	var from := Vector2.ZERO
	var target := Vector2(1000, 0)      # dead ahead, stationary
	var strafe := Vector2(0, 200)       # shooter sliding sideways at 200
	var speed := 800.0

	# Aiming STRAIGHT at the target, the inherited sideways velocity flings the bolt
	# wide — that's the bug.
	var naive := Vector2(1, 0) * speed + strafe
	_ok(absf(naive.angle_to(target - from)) > deg_to_rad(10.0),
		"a strafing shooter aiming straight WOULD miss (the regression)")

	# Aiming in the shooter's frame, the bolt's WORLD velocity points at the target.
	var aim := WeaponMount.intercept_point(from, target, Vector2.ZERO, strafe, speed, 1.0)
	var bolt := (aim - from).normalized() * speed + strafe
	_ok(absf(bolt.angle_to(target - from)) < deg_to_rad(1.5),
		"canceling the shooter's own velocity makes the bolt fly true")

	# A stationary shooter is unchanged — aim is still just the target.
	var still := WeaponMount.intercept_point(from, target, Vector2.ZERO, Vector2.ZERO, speed, 1.0)
	_ok(still.is_equal_approx(target), "a stationary shooter still aims dead at the target")


## AN ALLY IS HELPED ONCE, NOT ONCE PER GROUP THEY BELONG TO (2026-07-27).
##
## `player_team` and `friendly_targets` OVERLAP — a Guardian joins both, and so
## does every hauler. Five sites walked the pair by hand; the Science Repair Field
## and Bulwark were the two that forgot to dedupe, so the field mended every
## escort at DOUBLE its authored rate and the "N shielded" readout counted each
## Guardian twice. Invisible in play: an ability that is twice as good as written
## reads as a generous ability.
##
## The exact-rate assertion is the load-bearing one. "Did it heal?" passes just as
## happily at 2x — which is why the bug survived every existing ability test.
func _case_an_ally_is_healed_once_not_twice() -> void:
	var HOME := Vector2(70000, -70000)   # clear of the debris earlier cases leave

	var player := TestShip.new()
	add_child(player)
	player.global_position = HOME
	player.apply_build(SampleBuilds.get_build(SampleBuilds.current))

	var escort := GuardianShip.new()
	add_child(escort)
	escort.setup_guard(SampleBuilds.get_build(0), 600.0)
	escort.global_position = HOME + Vector2(150, 0)

	# WITHOUT THIS THE CASE IS VACUOUS. If a Guardian ever stops joining both
	# groups the dedupe becomes untested and this quietly passes forever.
	_ok(escort.is_in_group("player_team") and escort.is_in_group("friendly_targets"),
		"a Guardian really is in BOTH ally groups (else this case tests nothing)")

	escort.hull = escort.stats.hull_hp * 0.5
	var before: float = escort.hull
	player._run_repair(1.0)              # one second of channel
	var healed: float = escort.hull - before
	_ok(healed > 0.0, "the Repair Field mends an escort in range")
	_ok(absf(healed - player._repair_rate) < 0.01,
		"...at EXACTLY its authored rate, not twice (healed %.1f, rate %.1f)"
			% [healed, player._repair_rate])

	# The count is the player's only readout of the ability's reach, so it has to
	# count SHIPS, not group memberships.
	_ok(player.allies_within(player._repair_radius).size() == 1,
		"one escort in the dome counts as one ally, not two")

	# OUT OF RANGE IS STILL OUT OF RANGE — the dedupe must not have widened reach.
	escort.global_position = HOME + Vector2(player._repair_radius + 200.0, 0)
	var far_before: float = escort.hull
	player._run_repair(1.0)
	_ok(is_equal_approx(escort.hull, far_before), "an escort outside the radius gets nothing")

	# AND THE WANTED-PLAYER RULE, which now rides on the same function. A wanted
	# pilot joins hostile_team, so a pirate asking for "my side" used to be handed
	# the person it is shooting at — a Mender healing its own attacker.
	player.global_position = HOME
	player.add_to_group("hostile_team")
	var medic := _pirate(AIShip.Specialty.MENDER)
	medic.global_position = HOME + Vector2(100, 0)
	player.hull = player.stats.hull_hp * 0.2
	var pilot_hp: float = player.hull
	medic._tick_specialty(0.1, null)
	_ok(is_equal_approx(player.hull, pilot_hp),
		"a pirate Mender never mends the WANTED player it is shooting at")
	player.remove_from_group("hostile_team")

	player.free()
	escort.free()
	medic.free()


# ---- rig ----

func _pirate(force: int = -1) -> AIShip:
	var a := AIShip.new()
	add_child(a)
	a.setup(SampleBuilds.get_build(0))
	if force >= 0:
		a.specialty = force
		a._spec_cd = 0.0
	return a


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(what)


## NOTHING CHASES PREY INTO A GRAVITY WELL (2026-07-26).
##
## Stationing pirates around Epharon made an old weakness lethal: telemetry went
## from ~1 planet-surface crash per boot to ~2, and the crashers were pirates riding
## a pursuit straight into the planet. Widening `avoid_radius` had never fixed it,
## because REACH was not the limit — WEIGHT was. `separation_dir()` returns a
## normalized push and apply_movement blended it at a flat 0.85, so `dir + away*0.85`
## with `away` opposite `dir` STILL POINTS ALONG `dir`: the ship brakes a little and
## ploughs on. Correct for a station, fatal for a planet.
##
## Both halves are asserted, because either alone passes while the bug is live:
## the urgency ramp itself, AND that apply_movement actually reverses a committed
## pursuit. (A correct helper nobody consults is a failure this project has paid
## for before.)
func _case_nothing_chases_prey_into_a_gravity_well() -> void:
	# PARKED FAR OUT, like _case_ships_keep_their_distance. A planet dropped at the
	# origin sits on top of every pirate the earlier cases left lying around, and
	# hoovers them into its own gravity well mid-test.
	var HOME := Vector2(-90000, -90000)
	var planet := Planetoid.new()
	planet.position = HOME
	add_child(planet)

	var hunter := AIShip.new()
	add_child(hunter)
	hunter.setup(SampleBuilds.pirate_raider(), AIShip.Tactic.ORBIT)

	# --- the ramp: 0 out in clear space, 1 inside the well ---
	hunter.global_position = HOME + Vector2(planet.avoid_radius * 2.0, 0.0)
	_ok(hunter.hazard_urgency() == 0.0,
		"clear of the planet the hazard ramp reads 0 (got %.2f)" % hunter.hazard_urgency())

	hunter.global_position = HOME + Vector2(planet.grav_r * 0.8, 0.0)
	_ok(hunter.hazard_urgency() >= 0.999,
		"inside the gravity well the ramp is saturated (got %.2f)" % hunter.hazard_urgency())

	# Between the two it must actually RAMP, not step — an ordinary pass near the
	# planet should still be a nudge, or every hauler would flinch off the lane.
	hunter.global_position = HOME + Vector2(planet.avoid_radius * 0.95, 0.0)
	var mid := hunter.hazard_urgency()
	_ok(mid > 0.0 and mid < 0.5,
		"just inside avoid_radius is a NUDGE, not an override (got %.2f)" % mid)

	# --- the wiring: a committed pursuit INTO the planet must be turned around ---
	# Deep in the well, thrusting straight at the core — the exact frame that used
	# to end in a crash.
	hunter.global_position = HOME + Vector2(planet.grav_r * 0.9, 0.0)
	hunter.velocity = Vector2.ZERO
	var into_planet := Vector2.LEFT * 400.0          # dead at the core
	hunter.apply_movement(into_planet, 0.05)
	_ok(hunter.velocity.x > 0.0,
		"a pursuit aimed into the well still drove the ship inward (velocity %s) — "
		% hunter.velocity + "avoidance must OVERRIDE intent this close, not blend with it")

	planet.queue_free()
	hunter.queue_free()


## BREAKING THE NERVE IS ABOUT DAMAGE, NOT BULLET COUNT (2026-07-26).
##
## The bare-hull break was a 12% roll PER DAMAGE INSTANCE, so a pilot with a
## fast-firing gun made every pirate in the sky braver or more cowardly purely by
## fire rate — two slugthrowers land ~4 hits/sec, which is ~40% per second. Pirates
## turned tail almost on contact, which is a large part of why they read as "running
## in and out" rather than fighting.
##
## The assertion is EQUIVALENCE: the same total damage must produce the same
## outcome whether it arrives in one shell or twenty. That is the property a
## per-hit roll cannot have.
func _case_courage_does_not_depend_on_rate_of_fire() -> void:
	var one := _pirate()
	var many := _pirate()
	one.shield = 0.0
	many.shield = 0.0
	var bite: float = one.stats.hull_hp * AIShip.BREAK_DAMAGE_FRACTION

	# A NIBBLE must not rout anyone, however many pellets it is chopped into.
	for _i in 20:
		many.take_damage(bite * 0.2 / 20.0)
	_ok(many._break_timer <= 0.0,
		"20 tiny hits totalling a fifth of the break threshold did NOT rout it")

	# The same real bite, delivered two ways, must land the same.
	#
	# Deliberately 1.1x the threshold rather than exactly on it: summing 40
	# fractional hits lands a hair under a bare `bite` through pure float
	# accumulation, so an exact-threshold test decides on rounding noise instead of
	# on the rule. (It passed at BREAK_DAMAGE_FRACTION 0.35 and failed at 0.50 for
	# precisely that reason — the tuning did not change the behaviour, only which
	# side of the epsilon the sum fell on.) The EQUIVALENCE is what matters, and
	# giving it headroom is what makes it about the rule.
	one.take_damage(bite * 1.1)
	for _i in 20:
		many.take_damage(bite * 0.9 / 20.0)   # tops the earlier 0.2 up to 1.1x
	_ok(one._break_timer > 0.0, "one heavy shell past the threshold breaks them")
	_ok(many._break_timer > 0.0,
		"the SAME damage as twenty light hits breaks them too — fire rate must not "
		+ "decide how brave a pirate is")

	# An extend must end on DISTANCE, comfortably inside the re-engage band, or a
	# fast ship spends its speed leaving the fight instead of pressing it.
	_ok(AIShip.EXTEND_TURN_AT < 2.2,
		"ships turn back (%.1fx) before the re-engage threshold (2.2x), so they "
		% AIShip.EXTEND_TURN_AT + "finish an extend already inside their fighting band")


## HOW A HULL FIGHTS IS AUTHORED (2026-07-26, user: "I don't mind having the wasp
## strafe if that makes more sense").
##
## This was briefly DERIVED — circle if top speed vs turn rate allowed it, else make
## passes. Then trimming the wasp by 85 units of speed silently converted it from an
## interceptor into a circler, which is the exact failure `WeaponDef.traverse` was
## authored to escape (`mark` quietly deciding what a gun could hit). Tuning a
## physics number must not rewrite a design decision.
##
## So the tactic is stated, and geometry only VETOES: a hull told to ORBIT that
## cannot hold the ring falls back to passes rather than wobbling.
func _case_fighting_style_is_authored_not_derived() -> void:
	var wasp := AIShip.new()
	add_child(wasp)
	wasp.setup(SampleBuilds.pirate_wasp(), AIShip.Tactic.STRAFE)
	wasp.preferred_range = 120.0
	_ok(wasp.tactic == AIShip.Tactic.STRAFE,
		"the wasp is AUTHORED as a strafer — a light interceptor slashes past")

	# THE POINT: it strafes because it was told to, NOT because it is too fast to
	# circle. At 383 it is comfortably slow enough to hold the ring, so if tactic
	# were still inferred from geometry this hull would now be circling.
	_ok(wasp.can_hold_orbit(),
		"...and it strafes even though it COULD circle (%.2f rad/s needed, %.2f "
		% [wasp._max_speed / wasp.preferred_range, wasp._turn_speed]
		+ "available) — speed no longer decides the design")

	# THE WASP MUST STAY SLOW ENOUGH TO MATTER. Its whole problem was outrunning its
	# own usefulness, so guard the speed itself: re-engine it and this fails loudly
	# rather than the wasp quietly going back to being scenery.
	_ok(wasp._max_speed < 460.0,
		"the wasp tops out at %.0f — much past this its passes throw it far enough "
		% wasp._max_speed + "out for the player's shields to fully regenerate between them")

	# ORBIT still means ORBIT for a hull that can hold it.
	var heavy := AIShip.new()
	add_child(heavy)
	heavy.setup(SampleBuilds.pirate_vulture(), AIShip.Tactic.ORBIT)
	_ok(heavy.tactic == AIShip.Tactic.ORBIT, "the Vulture is authored to sit on you")

	wasp.queue_free()
	heavy.queue_free()


## A HOLED SHIP CANNOT RUN (user, 2026-07-26): below 30% hull you lose a quarter of
## your top speed, below 10% you lose half.
##
## The point is that FLEEING BECOMES A TIMING DECISION rather than a free option
## always waiting at the bottom of the health bar — break off at 40% and you get
## away, ride it to 15% and the escape you were counting on is gone.
##
## Asserted through apply_movement, not just the helper, because a correct
## multiplier nobody consults is a failure this project has already paid for (the
## separation-avoidance pass shipped exactly that way and guardians kept ramming
## the station).
func _case_a_holed_ship_cannot_run() -> void:
	var s := _pirate()
	var full: float = s.stats.hull_hp

	s.hull = full
	_ok(is_equal_approx(s.limp_speed_mult(), 1.0), "an intact ship runs at full speed")
	s.hull = full * 0.5
	_ok(is_equal_approx(s.limp_speed_mult(), 1.0),
		"half hull is NOT crippled — the penalty must not creep up on a ship that "
		+ "is merely losing")
	s.hull = full * 0.25
	_ok(is_equal_approx(s.limp_speed_mult(), BuildShip.LIMP_HURT_MULT),
		"under 30%% hull costs a quarter of top speed (got %.2f)" % s.limp_speed_mult())
	s.hull = full * 0.05
	_ok(is_equal_approx(s.limp_speed_mult(), BuildShip.LIMP_CRIPPLED_MULT),
		"under 10%% hull costs half (got %.2f)" % s.limp_speed_mult())

	# THE WIRING. Drive a wreck flat-out and its actual velocity must be capped.
	var wreck := _pirate()
	wreck.global_position = Vector2(70000, 70000)     # clear of everything parked earlier
	wreck.hull = wreck.stats.hull_hp * 0.05
	wreck.velocity = Vector2.ZERO
	for _i in 200:
		wreck.apply_movement(Vector2.RIGHT * 9999.0, 0.05)
	var healthy := _pirate()
	healthy.global_position = Vector2(74000, 74000)
	healthy.velocity = Vector2.ZERO
	for _i in 200:
		healthy.apply_movement(Vector2.RIGHT * 9999.0, 0.05)
	_ok(wreck.velocity.length() < healthy.velocity.length() * 0.75,
		"a crippled hull actually FLIES slower (%.0f vs %.0f) — the multiplier has "
		% [wreck.velocity.length(), healthy.velocity.length()]
		+ "to reach apply_movement, not just exist")

	s.queue_free()
	wreck.queue_free()
	healthy.queue_free()

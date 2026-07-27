extends Node
## SHIP LEVEL SCALING — the curve AND the wiring.
##   godot --headless --path . res://tools/test_levels.tscn
##
## Run as a SCENE, not --script: BuildShip.apply_build reaches autoloads.
##
## THE MODEL (user, 2026-07-25): a hull's authored pools are what that ship FIELDS
## AT ITS OWN LEVEL. The Supercruiser's 1800 is its level-35 hull; the Bellwether's
## 900 is her level-15 hull. Nothing on disk is re-based, and spawning one at a
## different level scales from THAT baseline rather than from level 1 — which is
## what lets one .tres cover a region band (the rim runs 1-5, the Long Lane 6-15).
##
## WHY THIS TESTS THE WIRING TOO: a pure-math check on Progression would pass with
## apply_build never calling it. That exact failure — a correct helper nobody
## invoked — has already cost this project a session (the AI separation pass), so
## every assertion below goes through a REAL BuildShip.

var failures := 0


func _ready() -> void:
	_case_default_is_a_no_op()
	_case_fielding_higher_scales_up()
	_case_fielding_lower_scales_down()
	_case_ratio_is_relative_not_absolute()
	_case_zero_and_missing_levels_are_safe()
	_case_spawners_actually_pass_the_level()
	_case_no_sensors_means_blind()
	_case_hunters_see_only_as_far_as_they_are_equipped()
	_case_evasion_shrinks_the_profile_for_every_weapon()
	_case_interaction_reach_is_a_ship_property()

	if failures == 0:
		print("test_levels: ALL PASS")
		get_tree().quit(0)
	else:
		print("test_levels: %d FAILURE(S)" % failures)
		get_tree().quit(1)


func _fail(msg: String) -> void:
	print("FAIL: " + msg)
	failures += 1


## Builds a real ship at `lvl` (0 = leave it at the hull's authored level).
func _ship(build: ShipBuild, lvl: int) -> BuildShip:
	var s := BuildShip.new()
	s.spawn_level = lvl
	add_child(s)
	s.apply_build(build)
	return s


## THE DEFAULT MUST CHANGE NOTHING. Every ship in the game spawns without a
## spawn_level, so if this drifts, the whole fleet quietly re-tunes itself.
func _case_default_is_a_no_op() -> void:
	var b := SampleBuilds.lane_bellwether()
	var authored: float = b.hull.hull_hp
	var s := _ship(b, 0)
	if not is_equal_approx(s.stats.hull_hp, authored):
		_fail("default spawn changed hull: authored %.1f, got %.1f" % [authored, s.stats.hull_hp])
	if s.level() != b.hull.level:
		_fail("default level should be the hull's %d, got %d" % [b.hull.level, s.level()])
	# Explicitly asking for the hull's OWN level must also be a no-op (ratio = 1).
	var same := _ship(SampleBuilds.lane_bellwether(), b.hull.level)
	if not is_equal_approx(same.stats.hull_hp, authored):
		_fail("spawning at the hull's own level changed hull: %.1f vs %.1f" % [
			same.stats.hull_hp, authored])
	s.queue_free()
	same.queue_free()


func _case_fielding_higher_scales_up() -> void:
	var b := SampleBuilds.escort_harrier()
	var lvl: int = b.hull.level
	var base := _ship(SampleBuilds.escort_harrier(), 0)
	var hot := _ship(b, lvl + 6)
	if hot.stats.hull_hp <= base.stats.hull_hp:
		_fail("a higher-level Harrier is not tougher: %.1f vs %.1f" % [
			hot.stats.hull_hp, base.stats.hull_hp])
	# Armor and shield ride the same curve — a tougher ship is tougher all through,
	# not just in the hull pool.
	if base.stats.shield_hp > 0.0 and hot.stats.shield_hp <= base.stats.shield_hp:
		_fail("shield did not scale with level: %.1f vs %.1f" % [
			hot.stats.shield_hp, base.stats.shield_hp])
	if base.stats.armor_hp > 0.0 and hot.stats.armor_hp <= base.stats.armor_hp:
		_fail("armor did not scale with level: %.1f vs %.1f" % [
			hot.stats.armor_hp, base.stats.armor_hp])
	base.queue_free()
	hot.queue_free()


func _case_fielding_lower_scales_down() -> void:
	var b := SampleBuilds.lane_bellwether()
	var base := _ship(SampleBuilds.lane_bellwether(), 0)
	var cold := _ship(b, maxi(1, b.hull.level - 8))
	if cold.stats.hull_hp >= base.stats.hull_hp:
		_fail("a lower-level Bellwether is not softer: %.1f vs %.1f" % [
			cold.stats.hull_hp, base.stats.hull_hp])
	if cold.stats.hull_hp <= 0.0:
		_fail("scaling down produced a non-positive hull: %.1f" % cold.stats.hull_hp)
	base.queue_free()
	cold.queue_free()


## THE HEART OF THE CHOSEN MODEL: scaling is RELATIVE to the hull's own level, not
## absolute from level 1. Field a level-15 Bellwether at 15 and she is unchanged —
## under an absolute model she would be multiplied ~4.9x instead.
func _case_ratio_is_relative_not_absolute() -> void:
	var b := SampleBuilds.lane_bellwether()
	var lvl: int = b.hull.level
	var absolute := Progression.toughness_mult(lvl)
	if absolute <= 1.5:
		_fail("test is toothless: the L%d absolute multiplier is only %.2f, so an absolute model would be indistinguishable" % [lvl, absolute])
	var s := _ship(b, lvl)
	if not is_equal_approx(s.stats.hull_hp, b.hull.hull_hp):
		_fail("ABSOLUTE scaling leaked in: L%d hull became %.1f from an authored %.1f" % [
			lvl, s.stats.hull_hp, b.hull.hull_hp])
	if not is_equal_approx(Progression.toughness_between(lvl, lvl), 1.0):
		_fail("toughness_between(%d, %d) should be 1.0, got %.4f" % [
			lvl, lvl, Progression.toughness_between(lvl, lvl)])
	s.queue_free()


## THE SPAWNERS MUST ACTUALLY PASS IT THROUGH. A correct level band that no
## spawner hands to a ship is the same failure as a correct helper nobody calls —
## everything computes, nothing changes, and the world quietly stays level 1.
##
## The ORDER is the fragile part: spawn_level has to be set BEFORE the setup call,
## because apply_build is where the pools get scaled. Setting it afterwards
## compiles, reads fine, and does nothing at all.
func _case_spawners_actually_pass_the_level() -> void:
	var route: Array[Vector2] = [Vector2.ZERO, Vector2(500, 0)]

	# GuardianShip.spawn_lane_patrol — the Navy picket's path.
	var base := GuardianShip.spawn_lane_patrol(self, Vector2.ZERO,
		SampleBuilds.guardian_vulture(), route)
	var hot := GuardianShip.spawn_lane_patrol(self, Vector2.ZERO,
		SampleBuilds.guardian_vulture(), route, 30)
	if hot.level() != 30:
		_fail("spawn_lane_patrol(level=30) produced a level-%d ship" % hot.level())
	if hot.stats.hull_hp <= base.stats.hull_hp:
		_fail("a level-30 lane patrol is no tougher than a default one (%.0f vs %.0f) — spawn_level was set after apply_build" % [
			hot.stats.hull_hp, base.stats.hull_hp])
	base.queue_free()
	hot.queue_free()

	# WidowShip — the Gap raiders, spawned through their own path.
	var plain := WidowShip.new()
	add_child(plain)
	plain.setup_widow(SampleBuilds.widow_goshawk())
	var deep := WidowShip.new()
	add_child(deep)
	deep.spawn_level = 15
	deep.setup_widow(SampleBuilds.widow_goshawk())
	if deep.level() != 15:
		_fail("a Widow set to level 15 reports level %d" % deep.level())
	if deep.stats.hull_hp <= plain.stats.hull_hp:
		_fail("a deep-Gap Widows is no tougher than one at the mouth (%.0f vs %.0f)" % [
			deep.stats.hull_hp, plain.stats.hull_hp])
	plain.queue_free()
	deep.queue_free()


## NO SENSORS BLINDS YOU — AND BUYS YOU NOTHING (user, 2026-07-25).
##
## Missing a component costs exactly that component. GOING DARK is taking them ALL
## offline at once, and that total shutdown is what pays for the low signature. An
## earlier pass let a sensorless hull count as "running silent", handing it dark's
## stealth while it kept shields, engines and guns — a large free benefit for
## leaving off the cheapest part on the ship. Both halves are pinned here.
func _case_no_sensors_means_blind() -> void:
	var seeing := _ship(SampleBuilds.escort_goshawk(), 0)
	if seeing.sensor_reach(600.0) <= 0.0:
		_fail("the escort build shipped blind — _make's default sensor did not fit")
	if seeing.runs_silent():
		_fail("an ordinary ship reports as running silent")

	var blind := _ship(_blinded(SampleBuilds.escort_goshawk()), 0)
	if blind.sensor_reach(600.0) != 0.0:
		_fail("a hull with no sensor still perceives %.0fu — the floor is masking blindness" % 			blind.sensor_reach(600.0))
	# THE HALF THAT MATTERS: blind must not be stealthy.
	if blind.runs_silent():
		_fail("a blind ship is treated as running silent — it would get dark's stealth for free")
	seeing.queue_free()
	blind.queue_free()


## A HUNTER SEES ONLY AS FAR AS ITS EQUIPMENT (user, 2026-07-26).
##
## Acquisition used to be a flat AGGRO_RANGE for every AI, so sensors were
## decorative on every enemy in the game and a Tin-Ear was worth nothing to fit —
## the exact "granting what a ship has not equipped" leak the component model
## forbids. Retention is a separate thing and must stay untouched.
func _case_hunters_see_only_as_far_as_they_are_equipped() -> void:
	var cheap := AIShip.new()
	add_child(cheap)
	cheap.setup(SampleBuilds.pirate_brawler())          # Tin-Ear, 700u
	var cheap_reach := cheap.acquire_range()
	if cheap_reach <= 0.0 or cheap_reach >= AIShip.AGGRO_RANGE:
		_fail("a Tin-Ear hunter acquires at %.0fu — it should be its sensor's reach, under the %.0fu flat range" % [
			cheap_reach, AIShip.AGGRO_RANGE])

	# Blind: no eyes, no hunt. It must not fall back on the flat range.
	var blind := AIShip.new()
	add_child(blind)
	blind.setup(_blinded(SampleBuilds.pirate_brawler()))
	if blind.acquire_range() != 0.0:
		_fail("a sensorless hunter still acquires at %.0fu" % blind.acquire_range())

	# A better suite must not silently EXTEND how far pirates engage from — that
	# would be a pacing buff smuggled in as a leak fix.
	var keen := AIShip.new()
	add_child(keen)
	keen.setup(SampleBuilds.widow_goshawk_elite())     # Augur, 2400u
	if keen.acquire_range() > AIShip.AGGRO_RANGE:
		_fail("an Augur hunter acquires at %.0fu, past the %.0fu ceiling" % [
			keen.acquire_range(), AIShip.AGGRO_RANGE])
	if keen.acquire_range() <= cheap_reach:
		_fail("better sensors bought a hunter nothing (%.0f vs %.0f)" % [
			keen.acquire_range(), cheap_reach])

	cheap.queue_free()
	blind.queue_free()
	keen.queue_free()


## EVASION IS A SMALLER TARGET TO EVERY WEAPON (user, 2026-07-26).
##
## It used to be a multiply inlined in the bolt sweep and nowhere else, so Evasion
## — a favoured 5-cap skill for two commissions — did nothing at all against beams,
## proximity fuzes, splash or any ability. All four weapon tests now share
## `hit_profile_of`, while the PHYSICAL `hit_radius` is untouched: an evasive ship
## is harder to shoot, not smaller to bump into.
func _case_evasion_shrinks_the_profile_for_every_weapon() -> void:
	var s := _ship(SampleBuilds.escort_goshawk(), 0)
	var physical := s.hit_radius
	if physical <= 0.0:
		_fail("test is toothless: the hull has no hit_radius to shrink")

	if not is_equal_approx(BuildShip.hit_profile_of(s), physical):
		_fail("a ship with no evasion is already shrunk (%.1f vs %.1f)" % [
			BuildShip.hit_profile_of(s), physical])

	s.evasion = 0.25          # the real ceiling: 5 ranks x 0.05
	var profile := BuildShip.hit_profile_of(s)
	if profile >= physical:
		_fail("evasion did not shrink the hit profile (%.1f vs %.1f)" % [profile, physical])
	if not is_equal_approx(profile, physical * 0.75):
		_fail("expected %.2f at 0.25 evasion, got %.2f" % [physical * 0.75, profile])

	# THE PHYSICAL COLLIDER MUST NOT MOVE. Evasion is about being hard to hit, not
	# about phasing closer to planets or through other hulls.
	if not is_equal_approx(s.hit_radius, physical):
		_fail("evasion changed the PHYSICAL radius (%.1f) — collision and AI spacing would shift" % s.hit_radius)

	# Anything without an `evasion` property keeps its honest full size, and a
	# missing node must not crash the helper.
	if not is_equal_approx(BuildShip.hit_profile_of(null, 12.0), 12.0):
		_fail("hit_profile_of(null) did not fall back cleanly")
	s.queue_free()


## THE THIRD RADIUS — how far a ship can PULL (user, 2026-07-26).
##
## It was a flat constant on the player, so a Bellwether scooped from exactly the
## same distance as a Rooster and NO COMPONENT COULD AFFECT IT — a cargo scoop was
## unbuildable. A component has to provide something or there is no reason to carry
## it. The hull gives the baseline; gear raises it.
func _case_interaction_reach_is_a_ship_property() -> void:
	var small := _ship(SampleBuilds.escort_harrier(), 0)       # LIGHT
	var big := _ship(SampleBuilds.lane_bellwether(), 0)        # HEAVY
	if small.interaction_radius() < BuildShip.BASE_INTERACTION:
		_fail("a bare hull reaches %.0f, under the %.0f baseline" % [
			small.interaction_radius(), BuildShip.BASE_INTERACTION])
	if big.interaction_radius() <= small.interaction_radius():
		_fail("a HEAVY freighter (%.0f) does not out-reach a LIGHT fighter (%.0f)" % [
			big.interaction_radius(), small.interaction_radius()])

	# THE POINT OF THE WHOLE CHANGE: a fitted module must move it.
	var scooped := SampleBuilds.escort_harrier()
	var fitted := false
	for i in scooped.hull.hardpoints.size():
		if scooped.hull.hardpoints[i].slot_type == HardpointDef.SlotType.SYSTEM:
			scooped.slots[i] = load("res://data/components/systems/grapple_scoop.tres")
			fitted = true
			break
	if not fitted:
		_fail("no SYSTEM slot to test a scoop in — this case proved nothing")
	else:
		var s := _ship(scooped, 0)
		if s.interaction_radius() <= small.interaction_radius():
			_fail("fitting a Grapple Scoop changed nothing (%.0f vs %.0f) — the stat never reached the ship" % [
				s.interaction_radius(), small.interaction_radius()])
		s.queue_free()
	small.queue_free()
	big.queue_free()


## Strip the sensor out of a build, whatever socket it landed in.
func _blinded(b: ShipBuild) -> ShipBuild:
	for i in b.hull.hardpoints.size():
		if b.hull.hardpoints[i].slot_type == HardpointDef.SlotType.SENSOR:
			b.slots.erase(i)
	return b


## A hull with an unset (0) level must not blow the ratio up or divide by zero.
func _case_zero_and_missing_levels_are_safe() -> void:
	for pair in [[0, 5], [5, 0], [0, 0], [-3, 9]]:
		var r := Progression.toughness_between(pair[0], pair[1])
		if not is_finite(r) or r <= 0.0:
			_fail("toughness_between(%d, %d) = %s — must stay finite and positive" % [
				pair[0], pair[1], r])

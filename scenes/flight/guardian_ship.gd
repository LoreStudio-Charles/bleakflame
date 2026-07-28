class_name GuardianShip
extends BuildShip
## The station guard wing: blue hulls, one white stripe on the right wing.
## Guardians patrol a BAND around the station — never closer than MIN_R
## (the station's structure lives inside that; hugging it means grinding
## on collision), never past MAX_R (the sanctuary's teeth stay home; the
## leash is the doctrine). They engage hostiles that enter the band's
## reach, which in ambient play is nobody — until an authored assault
## event makes them earn the paint.

const MIN_R := 700.0
const MAX_R := 1500.0
const CRUISE := 0.5
const ENGAGE_RANGE := 240.0

## Military-grade hardware: the station's guns hit far harder and soak far
## more than their hull class suggests — better than a starter ship, better
## than any pirate, and still nowhere near where a veteran player is headed.
const MILITARY_DMG := 3.0
const MILITARY_HULL := 3.0
## Protective escort: the range around the ESCORTED ship inside which a
## guardian will peel off to kill a pirate, and how far it holds formation.
const PROTECT_ENGAGE := 1100.0
const FORMATION_R := 300.0
## Shadow escort (survive_event beat): trails the players out to the objective and
## patrols it from a distance until the ambush springs. HANG_BACK keeps it beyond
## the screen edge (half-screen is 960 at 1:1 zoom) so the pilot feels ALONE until
## the dark opens; PATROL_R is the ring it holds around the objective once there.
const SHADOW_HANG_BACK := 1180.0
const SHADOW_PATROL_R := 440.0

var _ring_r := 600.0
var _phase := 0.0
var _ring_dir := 1.0


func _ready() -> void:
	avoids_obstacles = true   # AI flies around things; the player is trusted to steer
	enemy_group = "hostile_team"
	ally_groups = ["player_team", "friendly_targets"]
	# ELITE (user, 2026-07-27). The 3x pools and 3x damage below land it at exactly
	# 3.00x a same-level normal, which is what ELITE promises -- the one ship in the
	# fleet that already meets its mark.
	rank = Threat.Rank.ELITE
	add_to_group("player_team")
	add_to_group("friendly_targets")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING


func setup_guard(new_build: ShipBuild, ring_r: float) -> void:
	# PRIVATE POLICE AND INVESTIGATORS (user) — licensed, not enlisted.
	faction = "guardian"
	ship_name = ShipNames.registry("guardian")
	enemy_group = "hostile_team"
	ally_groups = ["player_team", "friendly_targets"]
	apply_build(new_build)
	# Military grade: triple hull/armor pool, triple weapon damage.
	stats.hull_hp *= MILITARY_HULL
	stats.armor_hp *= MILITARY_HULL
	hull = stats.hull_hp
	armor = stats.armor_hp
	_ring_r = clampf(ring_r, MIN_R + 60.0, MAX_R - 120.0)
	_phase = randf() * TAU
	_ring_dir = 1.0 if randf() < 0.5 else -1.0
	set_hull_tint(Color(0.55, 0.68, 1.05))
	_add_guard_livery()
	# Damage scales with the ship's LEVEL (Progression) with the military 3x as a
	# floor: a level-1 guardian still does 3x, but a level-35 capital does ~12x and
	# instagibs level-1 pirates — the level gap finally means something.
	# Reads level() rather than the hull's authored level, so a guardian fielded at
	# a region-appropriate spawn_level hits as hard as it is tough.
	var dmg := maxf(MILITARY_DMG, Progression.damage_mult(level()))
	for mount in _mounts:
		mount.lead_factor = 0.6
		mount.damage_mult = dmg


## One white stripe on the RIGHT wing (art noses +X, so the pilot's right
## is +Y). Clipped to the hull silhouette by the sprite stencil.
func _add_guard_livery() -> void:
	if _hull_sprite == null:
		return
	var stripe := Polygon2D.new()
	stripe.polygon = PackedVector2Array([
		Vector2(-2.0, 3.0), Vector2(2.0, 3.0),
		Vector2(2.0, 16.0), Vector2(-2.0, 16.0)])
	stripe.color = Color(0.96, 0.97, 1.0, 0.9)
	_hull_sprite.add_child(stripe)


## Shadow escort (survive_event): launched from HOME when the stage arms. It trails
## the players out to the objective and patrols it OUT OF SIGHT — a normal-looking
## patrol behind the player, coop-ready (it hangs back from the nearest player_ship,
## whichever pilot that is). When the ambush springs, flight_test flips escort_target
## and it breaks to engage, already on-station instead of teleporting in on top of you.
static func spawn_shadow_escort(parent: Node, pos: Vector2, objective: Vector2,
		fit: ShipBuild) -> GuardianShip:
	var g := GuardianShip.new()
	parent.add_child(g)
	g.global_position = pos
	g.setup_guard(fit, MIN_R + 100.0)
	g.shadow_escort = true
	g.escort_objective = objective
	return g


## Protective escort (beat 4+): a wing assigned to a PILOT. It flies loose
## formation, breaks off to gun down any pirate that gets near the pilot,
## then rejoins. Military-grade, so it actually wins — it clears the road
## instead of dying on it. `slot` spreads a wing around the escorted ship.
## `level` 0 = field it at its hull's own level. Anything else must be set BEFORE
## setup_guard, since apply_build is where the pools are scaled.
static func spawn_protector(parent: Node, fit: ShipBuild, protect_ship: Node2D,
		slot: int, wing: int, lvl: int = 0) -> GuardianShip:
	var g := GuardianShip.new()
	parent.add_child(g)
	g.spawn_level = lvl
	g.setup_guard(fit, MIN_R + 100.0)
	g.protect = protect_ship
	g._slot_angle = TAU * float(slot) / float(maxi(wing, 1))
	g.global_position = protect_ship.global_position \
		+ Vector2.RIGHT.rotated(g._slot_angle) * FORMATION_R
	return g


## A single Guardian flying a trade lane end to end, gunning pirates it meets.
## Military-grade like the guard wing but off the station's leash — and exposed,
## so the beast can take it. Respawns from home when lost (flight_test).
static func spawn_lane_patrol(parent: Node, pos: Vector2, fit: ShipBuild,
		route: Array[Vector2], lvl: int = 0) -> GuardianShip:
	var g := GuardianShip.new()
	parent.add_child(g)
	g.spawn_level = lvl
	g.setup_guard(fit, MIN_R + 100.0)
	g.lane_patrol = true
	g.patrol_points = route
	g.global_position = pos
	return g


var escort_target: Node2D
## Shadow escort: pre-spring, trail the players toward escort_objective and patrol
## it from a distance, out of sight. Setting escort_target (the ambush springs)
## overrides this — the wing breaks to engage from wherever it was already flying.
var shadow_escort := false
var escort_objective := Vector2.ZERO
var protect: Node2D
var _slot_angle := 0.0
var _returning := false   # dismissed: fly home and stand down, never just vanish
# Lane patrol: unlike the station BAND, a lane guardian flies a waypoint route (a
# trade lane end to end) and guns down hostiles it meets on the road. Exposed out
# there, so the Cinderweb's hunger can take it too — even the military vanishes.
var lane_patrol := false
var patrol_points: Array[Vector2] = []
var _patrol_index := 0
const LANE_ARRIVE := 220.0


## Stand down the wing: drop the pilot and turn for home. It flies back to the
## station band under its own power and despawns only on ARRIVAL — no popping
## out of existence when a beat ends (that broke immersion).
func dismiss() -> void:
	protect = null
	escort_target = null
	_returning = true


func _physics_process(delta: float) -> void:
	if build == null or dead:
		return
	tick_common(delta)
	if _returning:
		var home := AIShip.station_pos
		if global_position.distance_to(home) <= MIN_R:
			queue_free()   # made it back to the harbor — stand down
			return
		rotation = rotate_toward(rotation, (home - global_position).angle(), _turn_speed * delta)
		apply_movement(Vector2.RIGHT.rotated(rotation) * _accel, delta)
		return
	# Protective escort: hold formation on the pilot, break off for pirates.
	if protect != null and is_instance_valid(protect) and not bool(protect.get("dead")):
		_fly_protect(delta)
		return
	# Escort mode overrides the leash: fly at the target and fire, doomed.
	if escort_target != null and is_instance_valid(escort_target) \
			and not bool(escort_target.get("dead")):
		var to_t := escort_target.global_position - global_position
		rotation = rotate_toward(rotation, to_t.angle(), _turn_speed * delta)
		var th := Vector2.RIGHT.rotated(rotation) * _accel
		if to_t.length() < ENGAGE_RANGE * 1.6:
			th = to_t.normalized().orthogonal() * _accel * 0.7   # strafe it
		update_mounts(escort_target.global_position, delta, escort_target.velocity)
		fire_mounts(to_t.length())
		apply_movement(th, delta)
		return
	# Shadow escort: no target yet — trail the players toward the objective and
	# patrol it, hanging back out of sight until the ambush springs.
	if shadow_escort:
		_fly_shadow(delta)
		return
	# Lane patrol: fly the road, gun what you meet — off the station's band.
	if lane_patrol:
		_fly_lane(delta)
		return
	var station := AIShip.station_pos
	var thrust := Vector2.ZERO
	var threat := _nearest_threat(station)

	var out := global_position.distance_to(station)
	if out > MAX_R:
		# Hard leash: whatever is happening out there, come home.
		rotation = rotate_toward(rotation, (station - global_position).angle(),
			_turn_speed * delta)
		thrust = Vector2.RIGHT.rotated(rotation) * _accel
	elif out < MIN_R:
		# Too close to the structure: climb back out to the band before it
		# becomes a fender-bender with the harbor you're guarding.
		rotation = rotate_toward(rotation, (global_position - station).angle(),
			_turn_speed * delta)
		thrust = Vector2.RIGHT.rotated(rotation) * _accel
	elif threat != null:
		var to_t := threat.global_position - global_position
		rotation = rotate_toward(rotation, to_t.angle(), _turn_speed * delta)
		if to_t.length() > ENGAGE_RANGE:
			thrust = Vector2.RIGHT.rotated(rotation) * _accel
		else:
			thrust = to_t.normalized().orthogonal() * _accel * 0.6
		update_mounts(threat.global_position, delta, threat.velocity)
		fire_mounts(to_t.length())
	else:
		# Ring patrol: chase a point that walks the circle.
		var goal := station + Vector2.RIGHT.rotated(_phase) * _ring_r
		if global_position.distance_to(goal) < 130.0:
			_phase += _ring_dir * 0.55
		rotation = rotate_toward(rotation, (goal - global_position).angle(),
			_turn_speed * delta)
		thrust = Vector2.RIGHT.rotated(rotation) * _accel * CRUISE

	apply_movement(thrust, delta)


## Escort a pilot: gun down any pirate near them, else hold a formation slot
## and drift along with them.
func _fly_protect(delta: float) -> void:
	var foe := _nearest_hostile_near(protect.global_position, PROTECT_ENGAGE)
	if foe != null:
		var to_t := foe.global_position - global_position
		rotation = rotate_toward(rotation, to_t.angle(), _turn_speed * delta)
		var th := Vector2.RIGHT.rotated(rotation) * _accel
		if to_t.length() < ENGAGE_RANGE * 1.5:
			th = to_t.normalized().orthogonal() * _accel * 0.7   # strafe it
		update_mounts(foe.global_position, delta, foe.velocity)
		fire_mounts(to_t.length())
		apply_movement(th, delta)
		return
	# Formation: hold a slot around the pilot, face where they're heading.
	var goal: Vector2 = protect.global_position + Vector2.RIGHT.rotated(_slot_angle) * FORMATION_R
	var to_g := goal - global_position
	var vel = protect.get("velocity")
	var face: Vector2 = vel if vel != null and (vel as Vector2).length() > 20.0 else to_g
	rotation = rotate_toward(rotation, face.angle(), _turn_speed * delta)
	apply_movement(to_g.normalized() * _accel * clampf(to_g.length() / 220.0, 0.0, 1.0), delta)


## Trail the players to the objective and patrol it, HANGING BACK so the wing sits
## off-screen (out of sight) behind the nearest pilot. Slow cruise, not a burn — it
## reads as a normal patrol drifting the same way you're going, right up until the
## dark opens and escort_target flips it to the doomed charge.
func _fly_shadow(delta: float) -> void:
	var to_goal := escort_objective - global_position
	var heading: Vector2
	if to_goal.length() > SHADOW_PATROL_R * 1.3:
		heading = to_goal.normalized()                  # still inbound to the site
	else:
		# Arrived — orbit it on a slow patrol ring.
		var ang := (global_position - escort_objective).angle() + _ring_dir * 0.5
		heading = (escort_objective + Vector2.RIGHT.rotated(ang) * SHADOW_PATROL_R \
			- global_position).normalized()
	# Hang back: never crowd a pilot. Bias away from any player within reach so the
	# wing sits behind them, off-screen, instead of flying up their tailpipe.
	var player := _nearest_player()
	if player != null:
		var to_p := player.global_position - global_position
		if to_p.length() < SHADOW_HANG_BACK:
			heading = (heading - to_p.normalized() * 1.4).normalized()
	if heading == Vector2.ZERO:
		heading = Vector2.RIGHT.rotated(rotation)
	rotation = rotate_toward(rotation, heading.angle(), _turn_speed * delta)
	apply_movement(Vector2.RIGHT.rotated(rotation) * _accel * 0.5, delta)


## The nearest human pilot — group "player_ship" (each coop client's own hull), so
## the wing hangs back from whoever is closest rather than a single hardcoded ship.
func _nearest_player() -> Node2D:
	var best: Node2D = null
	var bd := INF
	for p in get_tree().get_nodes_in_group("player_ship"):
		if not is_instance_valid(p):
			continue
		var d: float = global_position.distance_squared_to((p as Node2D).global_position)
		if d < bd:
			bd = d
			best = p
	return best


## Fly the lane end to end; break off to gun down any hostile within reach, then
## resume the route. Dodges rocks like the pirates/traders do.
func _fly_lane(delta: float) -> void:
	var foe := _nearest_hostile_near(global_position, PROTECT_ENGAGE)
	if foe != null:
		var to_t := foe.global_position - global_position
		rotation = rotate_toward(rotation, to_t.angle(), _turn_speed * delta)
		var th := Vector2.RIGHT.rotated(rotation) * _accel
		if to_t.length() < ENGAGE_RANGE * 1.5:
			th = to_t.normalized().orthogonal() * _accel * 0.7   # strafe it
		update_mounts(foe.global_position, delta, foe.velocity)
		fire_mounts(to_t.length())
		apply_movement(th, delta)
		return
	if patrol_points.is_empty():
		apply_movement(Vector2.ZERO, delta)
		return
	var goal := patrol_points[_patrol_index]
	if global_position.distance_to(goal) < LANE_ARRIVE:
		_patrol_index = (_patrol_index + 1) % patrol_points.size()
		goal = patrol_points[_patrol_index]
	rotation = rotate_toward(rotation, (goal - global_position).angle(), _turn_speed * delta)
	var thrust := Vector2.RIGHT.rotated(rotation) * _accel * CRUISE
	var dodge := avoid_obstacles_dir(thrust)
	if dodge != Vector2.ZERO:
		rotation = rotate_toward(rotation, dodge.angle(), _turn_speed * delta)
		thrust = Vector2.RIGHT.rotated(rotation) * _accel
	apply_movement(thrust, delta)


func _nearest_hostile_near(center: Vector2, reach: float) -> BuildShip:
	var best: BuildShip = null
	var best_d := reach * reach
	# The reach was already the answer's bound; now it bounds the SEARCH too.
	for node in SpaceHash.near(get_tree(), "hostile_team", center, reach):
		# Never fire on the civilians we exist to protect — a trader in
		# hostile_team is the PLAYER's mark, not ours (the outlaw's crime).
		if node is not BuildShip or node.dead or node.is_in_group("traders"):
			continue
		var d: float = center.distance_squared_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best


## Guard the harbor, don't police the Reach: only hostiles inside (or a
## hair beyond) the patrol band count as threats.
func _nearest_threat(station: Vector2) -> BuildShip:
	var best: BuildShip = null
	var best_d := INF
	# Everything this can return sits within MAX_R of the station — the loop body says
	# so on its second line. Searching the whole hostile roster to throw most of it away
	# is the shape that does not scale.
	for node in SpaceHash.near(get_tree(), "hostile_team", station, MAX_R + 120.0):
		if node is not BuildShip or node.dead or node.is_in_group("traders"):
			continue   # protect civilians, never police them
		if node.global_position.distance_to(station) > MAX_R + 120.0:
			continue
		var d := global_position.distance_squared_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best

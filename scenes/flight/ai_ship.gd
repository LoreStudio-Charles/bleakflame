class_name AIShip
extends BuildShip
## Pirate brains, one per archetype:
##   ORBIT     — close to weapon range, then circle-strafe with random jinks.
##               Lateral motion makes them hard to hit and impossible to kite.
##   BOOM_ZOOM — head-on attack run, blow past, extend, turn, come again.
## All combat capability still comes from the ShipBuild — tactics are the only
## hand-authored part of an enemy.

enum Tactic { ORBIT, BOOM_ZOOM }

## ---- RARE SPECIALISTS (2026-07-22) ----
##
## PARITY, EQ-STYLE. The player has a dozen system abilities and the enemy had
## none, which made every ability a one-way advantage. But parity does NOT mean
## everything casts: in EverQuest a caster mob is a MINORITY and that is exactly
## why one is memorable — you learn to read the pull and kill the healer first.
##
## So a small fraction of pirates carry ONE ability on a long cooldown, and the
## rest are guns like always. Each specialty reuses an effect the PLAYER already
## has, through BuildShip's own API (apply_bulwark / repair / TangleField), so
## there is one implementation of each effect rather than a divergent AI copy.
##
## They announce themselves — a callout on use and a tinted flash — because an
## unreadable enemy ability is just damage the player cannot learn from.
enum Specialty { NONE, MENDER, WARDEN, BINDER }

## How many pirates are specialists at all. Deliberately low: the whole point is
## that meeting one is an event, not a mechanic you fight every wave.
const SPECIALIST_CHANCE := 0.13
## Never on the smallest hulls — a specialist should read as someone's veteran,
## not a random wasp, and it keeps early tutorial-adjacent fights clean.
const SPECIALIST_MIN_MASS := 40.0

const MENDER_CD := 9.0
const MENDER_HEAL := 55.0
const MENDER_RANGE := 700.0
const WARDEN_CD := 16.0
const WARDEN_REDUCTION := 0.45
const WARDEN_DUR := 5.0
const WARDEN_RADIUS := 520.0
const BINDER_CD := 14.0
const BINDER_RANGE := 850.0
const BINDER_DUR := 2.6

## Set at spawn; NONE for the overwhelming majority.
var specialty: int = Specialty.NONE
var _spec_cd := 0.0

const AGGRO_RANGE := 950.0
## Once locked on, a hunter HOLDS the mark far past the range it would first
## acquire at — so a fast strafing pass that overshoots doesn't make it "forget"
## the prey and wander back to patrol (the old 10k fly-away). Acquire close, leash far.
const LEASH_RANGE := 1700.0
const PATROL_CRUISE := 0.55    # of combat accel: pirates loiter, prey sprints
const PATROL_ARRIVE := 260.0

## Station sanctuary: the same 1800-unit radius the Cinderweb respects.
## Pirates don't work under the station's guns — a target inside it is
## no target at all, and a pirate who drifts inside leaves. This is what
## makes the tutorial range (drones at 550-950) actually safe. Yes, a
## player can pot-shot from just inside the line: being untouchable under
## the harbor guns is the genre-correct meaning of "safe harbor".
## Authored station-assault events (campaign beat "Closer") flip
## `sanctuary_suppressed` to bring the war to the doorstep.
const SANCTUARY_R := 2600.0   # bigger safe bubble — new pilots learn to fly unmolested
static var station_pos := Vector2.ZERO
static var sanctuary_suppressed := false
## Safe passage: while true, pirates won't engage the PLAYER — set during the
## Krayt PARLEY beat so you can fly into the Shoal and talk without being gunned
## down (they still hunt haulers; only the meeting is protected).
static var parley := false

## Attacker slots: only the closest MAX_ATTACKERS engaged pirates press the
## attack; the rest hold a menacing perimeter and wait for a slot to open.
## Outnumbered should feel scary but LEGIBLE — a duel with an audience, not
## a blender. Heavies (Vulture+) ignore the queue and always push in.
## UNDER TEST (user, 2026-07-25): the queue was written when pirates could pounce the
## moment you undocked, and it was the thing that made that survivable. Since then the
## station sanctuary, the guard wing, lane patrols and the leash have all made
## near-station space genuinely safe — so the queue may be solving a problem that no
## longer exists, and paying for it with dogfights that feel staged. Setting
## `queue_attackers = false` gives an ALL-IN brawl (`/brawl` toggles it in a debug
## build). If unqueued reads as a blender rather than a fight, it comes back — and this
## note is the reason it existed.
static var queue_attackers := true
const MAX_ATTACKERS := 2
const STANDOFF_RANGE := 680.0
const HEAVY_MASS := 100.0

## Break-and-run: losing an exchange makes a pirate turn tail for a few
## seconds — which is what CREATES tail-chases. Getting behind an enemy is
## the reward for winning the exchange, not something orbit geometry allows.
const BREAK_MIN_INTERVAL := 6.0

var tactic := Tactic.ORBIT
var preferred_range := 200.0
## Set TRUE before setup() to keep this ship off the shared random pirate skin
## pool, so a faction with its own colours stays uniform. See VShrikeShip.
var faction_livery := false
## World-anchored waypoint loop flown while not engaged. Pirates live in
## places and travel between them — they are traffic, not a gauntlet.
var patrol_points: Array[Vector2] = []
var _patrol_index := 0
var _orbit_dir := 1.0
var _jink_timer := 0.0
var _extend_timer := 0.0
var _break_timer := 0.0
var _break_cd := 0.0
var _weave_phase := randf() * TAU
## Perimeter ships aren't passive: every so often one peels off the ring for
## a single slashing pass through the fight, then extends back out. Pressure
## from the audience without claiming a dogfight slot — and it's linear and
## telegraphed, so a player watching the ring can dodge or punish it.
var _sweep := false
var _sweep_extend := 0.0
var _raid_timer := randf_range(4.0, 9.0)
var _prey: BuildShip = null   # the mark: player OR a hauler, held stable while valid


func _ready() -> void:
	avoids_obstacles = true   # AI flies around things; the player is trusted to steer
	enemy_group = "player_team"
	add_to_group("hostile_team")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING


## Rolled once the build is known (mass gates it). Called from setup(), not
## _ready, because _ready runs before there is a hull to weigh.
func _roll_specialty() -> void:
	if specialty != Specialty.NONE or build == null:
		return
	if stats.mass < SPECIALIST_MIN_MASS or randf() >= SPECIALIST_CHANCE:
		return
	specialty = [Specialty.MENDER, Specialty.WARDEN, Specialty.BINDER][randi() % 3]
	# A specialist is still identifiable BEFORE it acts — the lesson ("kill the
	# mender first") has to be learnable in advance. It just is NOT advertised by
	# repainting the hull any more (user, 2026-07-25).
	#
	# WHY THE HULL WAS THE WRONG CHANNEL: hull colour also carries FACTION, and
	# the two fought. A rolled specialty overwrote the V-Shrike's black livery,
	# spawning roughly one in eight out of its own colours. One channel cannot
	# answer both "who are they" and "what does this one do".
	#
	# ROLE IS SENSOR DATA NOW — see Ship.classify(). Your targeting computer names
	# it, and only when your sensors actually reach the mark, so a better sensor
	# suite buys something concrete and the Kestrel's "Long Sight" means what it
	# says. Hull colour goes back to meaning faction, exclusively.


## The colour this role reads as on the TARGETING display — the classification
## ring around a scanned mark. These are the shades the hull used to wear, kept
## deliberately: the information is unchanged, only the channel moved.
func specialty_color() -> Color:
	match specialty:
		Specialty.MENDER: return Color(0.55, 0.86, 0.60)
		Specialty.WARDEN: return Color(0.55, 0.70, 0.95)
		Specialty.BINDER: return Color(0.86, 0.72, 0.42)
	return Color.WHITE


func specialty_name() -> String:
	match specialty:
		Specialty.MENDER: return "Mender"
		Specialty.WARDEN: return "Warden"
		Specialty.BINDER: return "Binder"
	return ""


## One ability, one long cooldown, only when it would actually accomplish
## something — a mender with nobody hurt just flies.
func _tick_specialty(delta: float, prey: BuildShip) -> void:
	if specialty == Specialty.NONE:
		return
	_spec_cd = maxf(0.0, _spec_cd - delta)
	if _spec_cd > 0.0:
		return
	match specialty:
		Specialty.MENDER:
			var patient := _worst_wounded_ally()
			if patient != null:
				patient.repair(MENDER_HEAL)
				_spec_cd = MENDER_CD
				_announce("mending")
		Specialty.WARDEN:
			# Braces the wing when someone is actually in trouble, itself included.
			if hull < float(stats.get("hull_hp", 0.0)) * 0.7 or _worst_wounded_ally() != null:
				apply_bulwark(WARDEN_REDUCTION, WARDEN_DUR)
				for a in _allies_within(WARDEN_RADIUS):
					a.apply_bulwark(WARDEN_REDUCTION, WARDEN_DUR)
				_spec_cd = WARDEN_CD
				_announce("bracing")
		Specialty.BINDER:
			if prey != null and is_instance_valid(prey) 					and global_position.distance_to(prey.global_position) <= BINDER_RANGE:
				var tf: TangleField = preload("res://scenes/flight/tangle_field.gd").new()
				tf.target = prey
				tf.life = BINDER_DUR
				tf.global_position = prey.global_position
				get_parent().add_child(tf)
				_spec_cd = BINDER_CD
				_announce("binding")


## Wounded ally in reach, worst first. Excludes the caster for MENDER purposes
## only when it is healthier than someone else — a mender does heal itself.
func _worst_wounded_ally() -> BuildShip:
	var worst: BuildShip = null
	var worst_frac := 0.85     # nobody below this is worth a cast
	for a in _allies_within(MENDER_RANGE):
		var full: float = float(a.stats.get("hull_hp", 0.0))
		if full <= 0.0:
			continue
		var frac: float = a.hull / full
		if frac < worst_frac:
			worst_frac = frac
			worst = a
	return worst


func _allies_within(radius: float) -> Array[BuildShip]:
	var out: Array[BuildShip] = []
	for other in get_tree().get_nodes_in_group("hostile_team"):
		if not is_instance_valid(other) or other == self:
			continue
		var b := other as BuildShip
		if b == null or b.dead:
			continue
		if global_position.distance_to(b.global_position) <= radius:
			out.append(b)
	if specialty == Specialty.MENDER and not dead:
		out.append(self)       # a mender is allowed to save itself
	return out


## Say it out loud. The player cannot counter what they cannot perceive.
func _announce(verb: String) -> void:
	var player := get_tree().get_first_node_in_group("player_team")
	if player != null and is_instance_valid(player) and player.has_method("_flash_note") 			and global_position.distance_to(player.global_position) < 1800.0:
		player._flash_note("%s is %s." % [specialty_name().to_upper(), verb])
	Sfx.play("click", -14.0, 1.4)


func setup(new_build: ShipBuild, p_tactic: Tactic = Tactic.ORBIT,
		tint: Color = Color(0.85, 0.52, 0.46)) -> void:
	enemy_group = "player_team"
	# The shared pirate skin pool is rust-and-orange. A faction that wears its OWN
	# livery (the V-Shrike are black) sets `faction_livery` before calling setup,
	# because a livery only means anything if it is the same every time.
	if not faction_livery:
		use_variant_skin = true
	apply_build(new_build)
	set_hull_tint(tint)
	tactic = p_tactic
	_roll_specialty()
	# Fight at the range of your shortest gun, with a little personality.
	var min_range := 500.0
	for mount in _mounts:
		min_range = minf(min_range, mount.def.weapon_range)
		mount.lead_factor = 0.6   # good fire-control, not prescient
	preferred_range = clampf(min_range * randf_range(0.45, 0.6), 90.0, 260.0)


func _physics_process(delta: float) -> void:
	if build == null or dead:
		return
	tick_common(delta)
	_break_cd = maxf(0.0, _break_cd - delta)

	var thrust := Vector2.ZERO
	# Prey = the nearest EXPOSED target — the player OR a Trader-guild hauler
	# (both ride "player_team"). Held stable so the pirate doesn't flap between
	# marks mid-strafe; ships under the station's guns are never prey.
	if _prey == null or not _prey_valid(_prey, LEASH_RANGE):
		_prey = _pick_prey()
	var prey: BuildShip = _prey
	var engaged := prey != null
	_tick_specialty(delta, prey)

	if engaged and _break_timer > 0.0:
		# Running: straight-ish away with a weave, guns cold. The player's
		# tail-chase window — nose guns feast on a fleeing target.
		_break_timer -= delta
		_weave_phase += delta * 5.0
		var away := (global_position - prey.global_position).normalized()
		var flee := away.rotated(sin(_weave_phase) * 0.45)
		rotation = rotate_toward(rotation, flee.angle(), _turn_speed * delta)
		thrust = Vector2.RIGHT.rotated(rotation) * _accel
	elif engaged and _sweep:
		# Strafing run: dive, one slashing pass, extend out, rejoin the ring.
		var to_prey := prey.global_position - global_position
		var dist := to_prey.length()
		if _sweep_extend > 0.0:
			_sweep_extend -= delta
			thrust = Vector2.RIGHT.rotated(rotation) * _accel
			if _sweep_extend <= 0.0:
				_sweep = false
		else:
			rotation = rotate_toward(rotation, to_prey.angle(), _turn_speed * delta)
			thrust = Vector2.RIGHT.rotated(rotation) * _accel
			if dist < 140.0:
				_sweep_extend = randf_range(1.2, 1.8)
		update_mounts(prey.global_position, delta, prey.velocity)
		fire_mounts(dist)
	elif engaged and not _attack_slot_open(prey):
		# Perimeter: face the prey, circle wide, wait for a slot — and every
		# so often, someone's patience runs out.
		var to_prey := prey.global_position - global_position
		rotation = rotate_toward(rotation, to_prey.angle(), _turn_speed * delta)
		var tangent := to_prey.normalized().orthogonal() * _orbit_dir
		var radial := to_prey.normalized() \
			* clampf((to_prey.length() - STANDOFF_RANGE) / STANDOFF_RANGE, -1.0, 1.0)
		thrust = (tangent * 0.6 + radial).normalized() * _accel * 0.7
		update_mounts(prey.global_position, delta, prey.velocity)   # aim, don't fire
		_raid_timer -= delta
		if _raid_timer <= 0.0:
			_raid_timer = randf_range(6.0, 12.0)
			_sweep = true
	elif engaged:
		var to_prey := prey.global_position - global_position
		var dist := to_prey.length()

		_jink_timer -= delta
		if _jink_timer <= 0.0:
			_jink_timer = randf_range(1.4, 2.6)
			if randf() < 0.4:
				_orbit_dir *= -1.0

		match tactic:
			Tactic.ORBIT:
				# STRAFING PASS, not a nose-glued orbit (user, 2026-07-23 — "strafe
				# past me, turn and strafe back from the other direction"). Circling a
				# slow/stationary mark can't work: at preferred_range the orbit rate
				# (speed/radius) outruns _turn_speed, so the nose never lines up and
				# turning tighter risks a collision. The fix: keep the NOSE ON THE
				# mark and fly THROUGH it — nose on the travel line, gimbal guns tracking
				# the mark as it sweeps the arc — then extend out and come back the other way.
				if dist > preferred_range * 2.2:
					# Too far to strafe: close the gap head-on first.
					rotation = rotate_toward(rotation, to_prey.angle(), _turn_speed * delta)
					thrust = Vector2.RIGHT.rotated(rotation) * _accel
				elif _extend_timer > 0.0:
					# Blew past — keep running out, then turn back the OTHER way.
					_extend_timer -= delta
					thrust = Vector2.RIGHT.rotated(rotation) * _accel
					if _extend_timer <= 0.0:
						_orbit_dir *= -1.0
				else:
					# Run the pass: nose tracks the mark (guns on target), thrust
					# leans off-axis so we slide past its flank, not into it.
					rotation = rotate_toward(rotation, to_prey.angle(), _turn_speed * delta)
					var fwd := Vector2.RIGHT.rotated(rotation)
					thrust = (fwd + fwd.orthogonal() * _orbit_dir * 0.6).normalized() * _accel
					if dist < preferred_range:
						_extend_timer = randf_range(0.5, 0.9)   # abreast — extend past
			Tactic.BOOM_ZOOM:
				if _extend_timer > 0.0:
					# Blow through and keep running before turning back.
					_extend_timer -= delta
					thrust = Vector2.RIGHT.rotated(rotation) * _accel
				else:
					rotation = rotate_toward(rotation, to_prey.angle(), _turn_speed * delta)
					thrust = Vector2.RIGHT.rotated(rotation) * _accel
					if dist < 110.0:
						_extend_timer = randf_range(1.8, 2.6)

		update_mounts(prey.global_position, delta, prey.velocity)
		fire_mounts(dist)
	elif not sanctuary_suppressed \
			and global_position.distance_to(station_pos) < SANCTUARY_R:
		# Strayed under the station's guns: leave, directly and briskly.
		var away := (global_position - station_pos).normalized()
		rotation = rotate_toward(rotation, away.angle(), _turn_speed * delta)
		thrust = Vector2.RIGHT.rotated(rotation) * _accel * PATROL_CRUISE
	elif not patrol_points.is_empty():
		var goal := patrol_points[_patrol_index]
		if global_position.distance_to(goal) < PATROL_ARRIVE:
			_patrol_index = (_patrol_index + 1) % patrol_points.size()
			goal = patrol_points[_patrol_index]
		rotation = rotate_toward(rotation, (goal - global_position).angle(), _turn_speed * delta)
		thrust = Vector2.RIGHT.rotated(rotation) * _accel * PATROL_CRUISE

	# Dodge a rock in the lane: override steering to swing around it (dodge
	# first, fight second), then normal behaviour resumes once the path clears.
	var dodge := avoid_obstacles_dir(thrust)
	if dodge != Vector2.ZERO:
		rotation = rotate_toward(rotation, dodge.angle(), _turn_speed * delta)
		thrust = Vector2.RIGHT.rotated(rotation) * _accel
	apply_movement(thrust, delta)


## A valid mark: alive, exposed (not cloaked, not docked), in aggro range, and
## OUTSIDE the station sanctuary. Traders and the player both qualify — pirates
## prey on whoever's caught in the open on the lanes.
func _prey_valid(node: BuildShip, base_reach := AGGRO_RANGE) -> bool:
	if node.is_in_group("player_ship") and (parley or Standing.shoal_open()):
		return false   # safe passage: the Krayt parley, or you're the Shoal's now
	# Signature drop: a ship running SILENT is seen only up close — distant hunters
	# lose the contact (but anything on top of it still has eyes). Silent covers
	# both the deliberate [K] Going Dark and a hull carrying no sensors at all,
	# which radiates nothing whether it meant to or not.
	var reach := base_reach
	if node.has_method("runs_silent") and node.runs_silent():
		reach *= 0.4
	return node != null and is_instance_valid(node) and not node.dead \
		and not node.is_hidden() and node.get("docked_at") == null \
		and global_position.distance_to(node.global_position) <= reach \
		and (sanctuary_suppressed \
			or node.global_position.distance_to(station_pos) > SANCTUARY_R)


## How far this hunter can ACQUIRE a new mark — ITS OWN SENSORS, never further.
##
## Acquisition used to be a flat AGGRO_RANGE for everyone, which handed every
## pirate 950u of sight regardless of what it carried: sensors were decorative on
## every AI in the game and the Tin-Ear set was worth nothing to fit. A component
## has to DO something or there is no reason to carry its mass and draw.
##
## RETENTION IS DELIBERATELY UNTOUCHED. `_prey_valid(_prey, LEASH_RANGE)` still
## holds a locked mark out to 1700 — acquire close, leash far, which is what stops
## a fast strafing pass "forgetting" its prey and wandering off. Once you have the
## contact you chase it by eye; finding it in the first place is what takes eyes.
##
## Capped at AGGRO_RANGE, so good sensors do not silently extend how far pirates
## engage from — that would be a pacing buff, not a leak fix. Raising the ceiling
## for a superior suite is a separate, deliberate decision.
func acquire_range() -> float:
	return minf(AGGRO_RANGE, sensor_reach(0.0))


func _pick_prey() -> BuildShip:
	var reach := acquire_range()
	if reach <= 0.0:
		return null          # no eyes, no hunt
	var best: BuildShip = null
	var best_d := reach * reach
	for node in get_tree().get_nodes_in_group("player_team"):
		var bs := node as BuildShip
		if bs == null or not _prey_valid(bs, reach):
			continue
		var d := global_position.distance_squared_to(bs.global_position)
		if d < best_d:
			best_d = d
			best = bs
	return best


## True when this ship ranks among the MAX_ATTACKERS closest engaged
## pirates. Heavies (Vulture+) never queue.
func _attack_slot_open(prey: BuildShip) -> bool:
	if not queue_attackers:
		return true      # all-in: everyone who can reach you presses the attack
	if stats.mass >= HEAVY_MASS:
		return true
	var my_d := global_position.distance_squared_to(prey.global_position)
	var closer := 0
	for other in get_tree().get_nodes_in_group("hostile_team"):
		if other == self or other is not AIShip or other.dead:
			continue
		var od: float = other.global_position.distance_squared_to(prey.global_position)
		if od <= AGGRO_RANGE * AGGRO_RANGE and od < my_d:
			closer += 1
			if closer >= MAX_ATTACKERS:
				return false
	return true


func take_damage(amount: float, source: Node = null) -> void:
	var had_shield := shield > 0.0
	super(amount, source)
	if dead or _break_timer > 0.0 or _break_cd > 0.0:
		return
	# Shield cracked — or bare hull chewed — and the nerve goes: turn tail.
	# Winning the exchange hands the player a fleeing target instead of an
	# endless circle; the chase is the reward.
	if (had_shield and shield <= 0.0) or (not had_shield and randf() < 0.12):
		_break_timer = randf_range(2.5, 4.0)
		_break_cd = BREAK_MIN_INTERVAL
		_sweep = false   # a punished sweep becomes a rout
		_sweep_extend = 0.0


const DROP_CHANCE := 0.45
const MAX_DROPS := 3


## Pirates eject what they were actually flying — loot is the victim's build —
## plus, sometimes, a crate of what they stole from the trade route. Salvage is
## the PLAYER's prize: a pirate downed by a guardian leaves nothing to scoop.
func _on_death() -> void:
	if not killed_by_player():
		queue_free()
		return
	var dropped := 0
	for comp in build.slots.values():
		if dropped >= MAX_DROPS:
			break
		if randf() < DROP_CHANCE:
			# Salvage rolls affixes on the way out of the wreck — the shop
			# sells clean; the dead sell interesting.
			LootPickup.spawn(get_parent(), global_position, Affixes.roll_for_drop(comp))
			dropped += 1
	if randf() < 0.35:
		LootPickup.spawn_commodity(get_parent(), global_position, "stolen_goods")
	queue_free()

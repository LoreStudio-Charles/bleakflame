class_name BuildShip
extends CharacterBody2D
## Base for anything that flies as a ShipBuild — the player and AI pirates are
## the same machine with different brains. Owns build consumption (hull visual,
## plumes, weapon mounts), handling derived from ShipStats, and the damage
## flow: shields absorb and regenerate, then armor soaks, then hull dies.

signal died

const ACCEL_SCALE := 66.0
const SPEED_SCALE := 44.0
const SHIELD_REGEN_DELAY := 2.5

## --- ENERGY (docs/energy_system.md) ---------------------------------------
## The spendable pool module abilities draw from. CAPACITY (pool) and RECHARGE
## (rate) are now HARD STATS the REACTOR publishes (ReactorDef, 2026-07-22), so
## they are tuned directly. They used to be derived from LOAD/margin — a lean fit
## recharged fast, a full one crawled — which was realistic but coupled every
## fitting choice to regen and made the pool untunable. LOAD is still a real fit
## budget (modules draw against power_output); it just no longer secretly sets
## your regen.
##
## LEGACY FALLBACK: an OLD reactor with no energy_capacity/energy_recharge (0)
## keeps the pre-change derived values, so saves from before the split still fly.
const ENERGY_PER_OUTPUT := 2.0    # fallback pool = reactor Load x this (old reactors only)
const REGEN_BASE := 0.6           # fallback regen base (old reactors only)
const REGEN_PER_MARGIN := 0.05    # fallback regen per unused LOAD (old reactors only)
const REGEN_FLOOR := 0.3          # fallback backstop

@export var drift_damp := 0.25

var build: ShipBuild
var stats: Dictionary = {}
var enemy_group := ""          # the group this ship's weapons target
var dead := false
## AI ships draw a random skin from assets/ships/variants/<hull>/ so every
## pirate looks individually lived-in; the player keeps the canonical sprite.
var use_variant_skin := false
## Player ships lock narrow-arc mounts to the nose (steering is aiming);
## AI ships leave this off and keep in-arc fire-control tracking.
var lock_narrow_mounts := false

var shield := 0.0
var armor := 0.0
var hull := 0.0
var hit_radius := 12.0

var _accel := 0.0
var _max_speed := 0.0
var _turn_speed := 0.0
var _trail_color := Color(0.55, 0.75, 1.0)
var _hull_visual: Polygon2D
var _hull_sprite: Sprite2D
var _plumes: Array[CPUParticles2D] = []
var _mounts: Array[WeaponMount] = []
var _regen_blocked := 0.0
var energy := 0.0
var energy_max := 0.0
var energy_regen := 0.0
## Multiplier on regen — Going Dark raises it (the "meditate" seam), and the
## player's profession sets a standing rate. AI ships leave it at 1.0.
var energy_regen_mult := 1.0
## Player-only: a smaller hit profile from the Evasion skill (0 for everyone
## else). Projectiles multiply this ship's effective hit radius by (1 - evasion).
var evasion := 0.0
## Cloak/stealth veil: alpha the whole ship draws at (1.0 = solid). Set via
## set_veil() so the hit-flash tween restores THIS, not full opacity. is_hidden()
## gates AI target acquisition — cloaked ships (player now, raiders later) drop
## enemy locks. Lives on the base so both sides can cloak (the parity rule).
var _veil_alpha := 1.0
var _hidden := false
## Bulwark: a Guardian throws a damage-reduction field over self + nearby allies.
## Applied at cast time and held for a duration — on the BASE so ANY ship can be
## a beneficiary (the caster's wing, an escorted NPC, later an enemy anchor).
var _dmg_reduction := 0.0
var _bulwark_t := 0.0


func apply_build(new_build: ShipBuild) -> void:
	add_to_group("ships")   # every hull is an obstacle to every other hull
	build = new_build
	stats = ShipStats.aggregate(build)

	_accel = stats.accel * ACCEL_SCALE
	_max_speed = stats.accel * SPEED_SCALE
	_turn_speed = clampf(220.0 / stats.mass, 1.2, 4.5)

	shield = stats.shield_hp
	armor = stats.armor_hp
	hull = stats.hull_hp

	# Refit tops the pool off — you leave the bay charged, same as repaired.
	# CAPACITY + RECHARGE come straight from the reactor now. A reactor that
	# publishes neither (a pre-2026-07-22 save) falls back to the old LOAD-derived
	# formula so it still flies.
	energy_max = float(stats.get("energy_capacity", 0.0))
	energy_regen = float(stats.get("energy_recharge", 0.0))
	if energy_max <= 0.0:
		energy_max = maxf(0.0, stats.power_output * ENERGY_PER_OUTPUT)
	if energy_regen <= 0.0:
		energy_regen = maxf(REGEN_FLOOR,
			REGEN_BASE + maxf(0.0, stats.power_margin) * REGEN_PER_MARGIN)
	energy = energy_max

	_trail_color = Color(0.55, 0.75, 1.0)
	for comp in build.slots.values():
		if comp is ReactorDef:
			_trail_color = comp.trail_color

	_rebuild_visuals()


func _rebuild_visuals() -> void:
	if _hull_visual != null:
		_hull_visual.queue_free()
	if _hull_sprite != null:
		_hull_sprite.queue_free()
	for p in _plumes:
		p.queue_free()
	_plumes.clear()
	for m in _mounts:
		m.queue_free()
	_mounts.clear()

	# Convention over config, like the audio overrides: a sprite at
	# res://assets/ships/<hullname>.png replaces the placeholder polygon.
	# Player hull art is weaponless — mounted components draw the guns.
	var hull_name := build.hull.display_name.to_snake_case()
	var sprite_path := "res://assets/ships/%s.png" % hull_name
	if use_variant_skin:
		var variant := _random_variant(hull_name)
		if variant != "":
			sprite_path = variant
	if ResourceLoader.exists(sprite_path):
		var sprite := Sprite2D.new()
		sprite.texture = load(sprite_path)
		# Stencil behavior: decal children (stripes, logos, liveries) are
		# clipped to the hull's alpha silhouette.
		sprite.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		_hull_sprite = sprite
		add_child(sprite)
	else:
		_hull_sprite = null
	_hull_visual = Polygon2D.new()
	_hull_visual.polygon = build.hull.silhouette
	_hull_visual.color = Color(0.72, 0.76, 0.82)
	_hull_visual.visible = _hull_sprite == null
	add_child(_hull_visual)

	hit_radius = 8.0
	for point in build.hull.silhouette:
		hit_radius = maxf(hit_radius, point.length() * 0.7)

	var collision := get_node_or_null("Collision") as CollisionShape2D
	if collision == null:
		collision = CollisionShape2D.new()
		collision.name = "Collision"
		collision.shape = CircleShape2D.new()
		add_child(collision)
	(collision.shape as CircleShape2D).radius = hit_radius

	for i in build.hull.hardpoints.size():
		var hp := build.hull.hardpoints[i]
		var comp := build.component_at(i)
		if comp is WeaponDef:
			var mount := WeaponMount.new()
			add_child(mount)
			mount.shooter = self   # a ship never eats its own bolts (WANTED self-hit guard)
			# Wide-arc mounts get the turret housing sprite, scaled by the
			# weapon's Mark so a Mk1 ring gun doesn't dwarf a Light hull.
			if hp.arc_deg > 90.0:
				mount.sprite_scale = (8.0 + 3.0 * comp.mark) / 32.0
				mount.setup(hp, comp, enemy_group, "res://assets/mounts/turret_compact.png")
			else:
				mount.setup(hp, comp, enemy_group)
			mount.nose_locked = lock_narrow_mounts and hp.arc_deg <= WeaponMount.FIXED_ARC_DEG
			# Player bolts (all mounts) carry graze forgiveness; AI's carry none.
			mount.shot_grace = 5.0 if lock_narrow_mounts else 0.0
			# Auto-sort into arrays: guns fire forever, ordnance is finite —
			# they must never share a trigger state.
			mount.group = 2 if comp.magazine > 0 else 1
			_mounts.append(mount)
		elif comp is EngineDef:
			var plume := CPUParticles2D.new()
			plume.position = hp.offset
			plume.emitting = false
			plume.amount = 48
			plume.lifetime = 0.45
			plume.local_coords = false
			plume.direction = Vector2(1, 0)
			plume.spread = comp.trail_spread_deg
			plume.gravity = Vector2.ZERO
			plume.initial_velocity_min = 90.0 * comp.trail_scale
			plume.initial_velocity_max = 160.0 * comp.trail_scale
			plume.damping_min = 60.0
			plume.damping_max = 120.0
			plume.scale_amount_min = 0.8 * comp.trail_scale
			plume.scale_amount_max = 1.8 * comp.trail_scale
			plume.color = _trail_color
			plume.set_meta("trail_scale", comp.trail_scale)
			add_child(plume)
			_plumes.append(plume)


func _random_variant(hull_name: String) -> String:
	var dir_path := "res://assets/ships/variants/%s" % hull_name
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return ""
	var pool: Array[String] = []
	for f in dir.get_files():
		# Exported builds list remapped ".import" entries; trim to the source.
		var file_name := f.trim_suffix(".import")
		if file_name.ends_with(".png"):
			var p := "%s/%s" % [dir_path, file_name]
			if ResourceLoader.exists(p) and not pool.has(p):
				pool.append(p)
	return pool.pick_random() if not pool.is_empty() else ""


## Tints the hull art (sprite modulate or polygon color, whichever is active).
func set_hull_tint(tint: Color) -> void:
	if _hull_sprite != null:
		_hull_sprite.modulate = tint
	else:
		_hull_visual.color = tint


## Shared per-frame upkeep: shield regeneration and energy recharge.
func tick_common(delta: float) -> void:
	_collision_cd = maxf(0.0, _collision_cd - delta)
	if energy < energy_max:
		energy = minf(energy_max, energy + energy_regen * energy_regen_mult * delta)
	_regen_blocked = maxf(0.0, _regen_blocked - delta)
	if _regen_blocked == 0.0 and shield < stats.shield_hp:
		shield = minf(stats.shield_hp, shield + stats.shield_regen * delta)
	if _bulwark_t > 0.0:
		_bulwark_t -= delta
		if _bulwark_t <= 0.0:
			_dmg_reduction = 0.0


## Take a Bulwark buff: cut incoming damage by `reduction` for `duration`. Never
## downgrades an existing stronger/longer field.
func apply_bulwark(reduction: float, duration: float) -> void:
	_dmg_reduction = maxf(_dmg_reduction, reduction)
	_bulwark_t = maxf(_bulwark_t, duration)


## Mend the hull, then spill any remainder into armor (never shields — those
## regen on their own). The Science Repair Field's per-tick heal, and reusable
## for any future repair effect on self or an ally.
func repair(amount: float) -> void:
	if dead or amount <= 0.0:
		return
	var hull_missing: float = stats.hull_hp - hull
	var to_hull := minf(amount, hull_missing)
	hull += to_hull
	amount -= to_hull
	if amount > 0.0:
		armor = minf(stats.armor_hp, armor + amount)


## Restitution when a ship runs into something solid — it rebounds instead of
## clinging. move_and_slide alone just scrubs the into-surface velocity and
## leaves the hull pressed flat (thrust into it forever = Velcro). Mirrors the
## planetoid/dock bounces the rest of the world already had.
const OBSTACLE_BOUNCE := 0.45   # fraction of incoming speed kept after a bounce
const OBSTACLE_KICK := 55.0     # extra shove straight off the surface, no cling

## COLLISION DAMAGE (2026-07-22). Now that everyone avoids obstacles, a real
## impact is a MISTAKE and should cost something — it reads as physics rather
## than as a tax. Damage scales with how fast you drove INTO the surface (the
## normal component only, so a glancing scrape is cheap and a head-on ram is
## not), and everything below a gentle-contact floor is free — creep-docking and
## light bumps never hurt. Tiers through shield -> armor -> hull via take_damage.
const COLLISION_MIN_SPEED := 260.0    # closing speed below this = a harmless nudge
const COLLISION_DMG_PER_SPEED := 0.06 # ~20 dmg at 600, ~38 at a 900 head-on
const COLLISION_DMG_CD := 0.7         # one hit per impact, not per sliding frame
var _collision_cd := 0.0


## Shared movement integration: thrust, drift decay, speed cap, plumes.
func apply_movement(thrust: Vector2, delta: float, speed_mult := 1.0, boosting := false) -> void:
	# AI ships steer around what they are about to hit. Done HERE rather than at
	# each behaviour's call site because a ship has many movement paths (the guard
	# wing alone has eight: formation, ring patrol, lane, escort, regroup...) and
	# only one of them used to avoid anything — so guardians rammed the station
	# and each other while "avoidance" looked implemented. Opt-in: the PLAYER
	# never gets steered by the game.
	if avoids_obstacles and thrust.length_squared() > 1.0:
		var away := separation_dir()
		if away != Vector2.ZERO:
			var dir := thrust.normalized()
			# HEAD-ON NEEDS A TANGENT. A purely radial push cannot turn a ship
			# flying straight at something — RIGHT + LEFT*0.85 still points
			# right, so it only brakes while the hull ploughs on. When the
			# obstacle is nearly dead ahead, steer AROUND it instead of backing
			# off it. Side is picked by instance id so two ships meeting nose to
			# nose choose opposite ways rather than mirroring into each other.
			if away.dot(dir) < -0.55:
				var side := dir.orthogonal()
				if int(get_instance_id()) % 2 == 1:
					side = -side
				away = (away + side * 1.8).normalized()
			var want := (dir + away * SEPARATION_WEIGHT).normalized()
			thrust = want * thrust.length()
			# TURN THE NOSE, not just the thrust vector. These AI steer by
			# rotation — `rotation = rotate_toward(...)` then
			# `thrust = RIGHT.rotated(rotation) * accel` — so deflecting the
			# thrust alone was undone on the very next frame while the hull kept
			# pointing at whatever it was about to hit. That is why guardians
			# still rammed the station after separation "worked": the maths was
			# right and aimed at the wrong variable.
			rotation = rotate_toward(rotation, want.angle(),
				_turn_speed * delta * AVOID_TURN_GAIN)
	velocity += thrust * delta
	velocity *= exp(-drift_damp * delta)
	velocity = velocity.limit_length(_max_speed * speed_mult)
	var pre := velocity
	move_and_slide()
	if get_slide_collision_count() > 0:
		bounce_off_obstacles(pre)
	_update_plumes(thrust, boosting)


## PROXIMITY avoidance: a push away from anything we are too close to, right now.
##
## This is the companion to avoid_obstacles_dir(), which only looks AHEAD along
## the travel lane and only at asteroids. Bumping happens in the cases that miss:
## a structure you are orbiting rather than flying at, and other SHIPS, which
## move. Cheap and always-on, so a ship drifts clear instead of grinding.
##
## Deliberately soft — SEPARATION_WEIGHT keeps it a nudge, not an autopilot, so
## contact still happens occasionally. It should look like flying, not like a
## force field.
func separation_dir() -> Vector2:
	var away := Vector2.ZERO
	var react := velocity.length() * AVOID_REACT_TIME
	# STRUCTURES — station, outposts, dens. Big, static, and the thing guardians
	# were most visibly slamming into.
	# "planetoids" included so AI give the gravity WELL a wide berth — it was the
	# one landmark not in the avoidance, so ships drifted into the pull and
	# crash-looped to death at the planet. The player is never auto-steered, so
	# they can still fly in and land.
	for g in ["structures", "outposts", "pirate_dens", "planetoids"]:
		for st in get_tree().get_nodes_in_group(g):
			if not is_instance_valid(st) or not (st is Node2D):
				continue
			var r: float = float(st.get("avoid_radius") if st.get("avoid_radius") != null
				else STRUCTURE_AVOID_R)
			away += _push_from((st as Node2D).global_position, r + hit_radius + react)
	# OTHER SHIPS, including the player. Anything that flies is a moving obstacle.
	for other in get_tree().get_nodes_in_group("ships"):
		if other == self or not is_instance_valid(other):
			continue
		var b := other as BuildShip
		if b == null or b.dead:
			continue
		away += _push_from(b.global_position,
			hit_radius + b.hit_radius + SHIP_CLEARANCE + react)
	return away.normalized() if away.length_squared() > 0.0001 else Vector2.ZERO


## Outward push that grows as the gap closes, and is nothing at all beyond `reach`.
func _push_from(at: Vector2, reach: float) -> Vector2:
	var to_me := global_position - at
	var d := to_me.length()
	if d >= reach or reach <= 0.0:
		return Vector2.ZERO
	if d < 1.0:
		return Vector2.RIGHT.rotated(float(get_instance_id() % 617))   # exactly stacked
	return (to_me / d) * (1.0 - d / reach)


## Rebound off whatever move_and_slide just hit, rather than sliding along it.
## `pre_vel` is the velocity carried into the collision (slide has since
## flattened its normal component, so we reflect the pre-move velocity).
func bounce_off_obstacles(pre_vel: Vector2) -> void:
	for i in get_slide_collision_count():
		var n := get_slide_collision(i).get_normal()
		var into := -pre_vel.dot(n)                 # closing speed INTO the surface
		if into <= 0.0:
			continue                                # heading away; not a real hit
		velocity = pre_vel.bounce(n) * OBSTACLE_BOUNCE + n * OBSTACLE_KICK
		_apply_collision_damage(into)
		return


## Hurt the ship for driving into something, once per impact. Docking and
## landing have their OWN scrape/crash handling and set `cinematic`, so this is
## suppressed there to avoid double-charging; a docked ship never collides.
func _apply_collision_damage(impact_speed: float) -> void:
	# `cinematic`/`docked_at` live on TestShip, not this base, so duck-type them:
	# AI never docks and has no cinematic, so absent == false is exactly right.
	if dead or _collision_cd > 0.0:
		return
	if get("cinematic") == true or get("docked_at") != null:
		return
	if impact_speed < COLLISION_MIN_SPEED:
		return                                      # gentle contact is free
	_collision_cd = COLLISION_DMG_CD
	var dmg := (impact_speed - COLLISION_MIN_SPEED) * COLLISION_DMG_PER_SPEED
	take_damage(dmg)
	on_collision_impact(dmg, impact_speed)


## Feedback hook. Base ship just thuds, pitched by force; TestShip overrides to
## flash the cockpit note. AI stays silent.
func on_collision_impact(_dmg: float, impact_speed: float) -> void:
	var force: float = clampf(impact_speed / 900.0, 0.2, 1.0)
	Sfx.play("scrape", -10.0 + 6.0 * force, 0.8 + 0.3 * force)


## Look-ahead steering. If a solid rock sits in the travel path within
## AVOID_LOOKAHEAD, return a heading that SKIRTS it — the current heading blended
## with a perpendicular shove away from the obstacle. Vector2.ZERO when the lane
## is clear. AI callers steer toward this to dodge, then resume their behaviour;
## the bounce above is the last-ditch net for when a dodge comes too late.
const AVOID_LOOKAHEAD := 320.0
## How hard proximity avoidance pulls against the ship's own intent. Low on
## purpose: the user asked for fewer collisions, NOT none — "I don't mind it
## happening sometimes". Raise toward 1.0 for pilots who never touch anything.
const SEPARATION_WEIGHT := 0.85
## How hard avoidance may fight the behaviour's own steering for the nose. Above
## 1.0 so a ship about to hit something turns away FASTER than its brain turns it
## back — otherwise the two cancel and it grinds along the obstacle.
const AVOID_TURN_GAIN := 1.6
## Personal space between hulls, on top of both radii. Was 46 — about a hull and
## a half, which meant avoidance only woke up when two ships were already
## touching and there was no room left to turn. A ship needs to see the problem
## while it can still do something about it.
const SHIP_CLEARANCE := 120.0
## ...plus a braking-distance term: how many seconds ahead a ship looks. At
## cruise this adds a few hundred units of warning, so fast traffic starts its
## turn early and slow traffic is not pushed around for no reason.
const AVOID_REACT_TIME := 0.7
const STRUCTURE_AVOID_R := 260.0    # fallback when a structure declares no radius

## Opt-in; the player is never auto-steered.
var avoids_obstacles := false
const AVOID_CLEARANCE := 60.0

func avoid_obstacles_dir(intent: Vector2) -> Vector2:
	var heading := velocity if velocity.length_squared() > 400.0 else intent
	if heading.length_squared() < 1.0:
		return Vector2.ZERO
	var dir := heading.normalized()
	var worst := 0.0
	var steer := Vector2.ZERO
	for rock in get_tree().get_nodes_in_group("asteroids"):
		if not is_instance_valid(rock):
			continue
		var to_o: Vector2 = rock.global_position - global_position
		var ahead := to_o.dot(dir)
		if ahead <= 0.0 or ahead > AVOID_LOOKAHEAD:
			continue                                  # behind us, or too far to matter
		var clear_r: float = float(rock.hit_radius) + hit_radius + AVOID_CLEARANCE
		var perp := to_o - dir * ahead                # offset of the rock from our path line
		var pd := perp.length()
		if pd >= clear_r:
			continue                                  # the lane clears this rock
		# Blocked: nearer + more centred = more urgent. Steer to the side the
		# rock ISN'T on (or pick one if it's dead ahead).
		var urgency := (1.0 - ahead / AVOID_LOOKAHEAD) + (1.0 - pd / clear_r)
		if urgency > worst:
			worst = urgency
			var side := (-perp / pd) if pd > 2.0 else dir.orthogonal()
			steer = (dir + side * 1.35).normalized()
	return steer


func update_mounts(aim: Vector2, delta: float, aim_vel := Vector2.ZERO) -> void:
	for mount in _mounts:
		mount.aim_at(aim, delta, aim_vel)


## Fires every mount whose weapon reaches `target_dist` (0 = fire regardless).
func fire_mounts(target_dist := 0.0) -> void:
	for mount in _mounts:
		if target_dist <= mount.def.weapon_range:
			mount.fire()


## Whoever last dealt us damage — kill credit. XP and loot are the PLAYER's
## reward alone (guardians/pirates killing each other pay nobody), so death
## handlers gate on killed_by_player().
var _last_attacker: Node = null


## True only if the killing blow traces to the player's ship — the gate for
## XP, loot drops, and bounty tallies.
func killed_by_player() -> bool:
	return is_instance_valid(_last_attacker) and _last_attacker.is_in_group("player_ship")


func take_damage(amount: float, source: Node = null) -> void:
	if dead:
		return
	if source != null:
		_last_attacker = source
	_regen_blocked = SHIELD_REGEN_DELAY
	var remaining := amount * (1.0 - _dmg_reduction)
	var shield_absorbed := minf(shield, remaining)
	shield -= shield_absorbed
	remaining -= shield_absorbed
	var armor_absorbed := minf(armor, remaining)
	armor -= armor_absorbed
	remaining -= armor_absorbed
	hull -= remaining
	Sfx.play_at("shield_hit" if shield_absorbed > 0.0 else "hit", global_position, -10.0)
	_flash()
	if hull <= 0.0:
		_die()


func _flash() -> void:
	modulate = Color(1.9, 1.9, 1.9)
	# Restore to the veil, not full opacity — a cloaked ship stays dim after a hit
	# (the flash is a brief tell that something's there).
	create_tween().tween_property(self, "modulate", Color(1, 1, 1, _veil_alpha), 0.12)


## Draw the whole ship at alpha `a` (cloak/stealth). Tint on _hull_sprite is a
## child modulate, so it multiplies through and survives.
func set_veil(a: float) -> void:
	_veil_alpha = a
	modulate = Color(1, 1, 1, a)


func is_hidden() -> bool:
	return _hidden


func _die() -> void:
	dead = true
	_explode()
	died.emit()
	_on_death()


## Devoured by a leviathan: gone TRACELESS — no wreck, no cargo, no rap sheet,
## just an empty patch where a ship used to be. A quiet shadow-swallow instead
## of the loud explosion of a normal death (an explosion is evidence; the beast
## leaves none — the campaign's whole horror). Emits `died` so the world's
## respawn hooks refill the lane, but bypasses _on_death so nothing drops.
func devour() -> void:
	if dead:
		return
	dead = true
	_devour_implosion()
	died.emit()
	queue_free()


## A dark inward collapse where the ship was — particles pulled to the centre
## (radial_accel negative), violet-black. Reads as swallowed, not blown up.
func _devour_implosion() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var p := CPUParticles2D.new()
	p.position = global_position
	p.one_shot = true
	p.emitting = true
	p.amount = 18
	p.lifetime = 0.5
	p.explosiveness = 0.9
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 150.0
	p.radial_accel_min = -300.0   # pull inward — a collapse, not a blast
	p.radial_accel_max = -360.0
	p.scale_amount_max = 2.4
	p.color = Color(0.34, 0.2, 0.5, 0.9)
	parent.add_child(p)
	p.finished.connect(p.queue_free)


## AI ships free themselves; the player overrides this to linger for respawn.
func _on_death() -> void:
	queue_free()


func _explode() -> void:
	Sfx.play_at("explosion", global_position, -3.0,
		clampf(1.4 - stats.mass / 180.0, 0.55, 1.3))
	var burst := CPUParticles2D.new()
	burst.position = global_position
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 36
	burst.lifetime = 0.6
	burst.spread = 180.0
	burst.gravity = Vector2.ZERO
	burst.initial_velocity_min = 80.0
	burst.initial_velocity_max = 220.0
	burst.scale_amount_max = 2.4
	burst.color = Color(1.0, 0.62, 0.28)
	burst.emitting = true
	get_parent().add_child(burst)
	burst.get_tree().create_timer(1.2).timeout.connect(burst.queue_free)


func _update_plumes(thrust: Vector2, boosting: bool) -> void:
	var thrusting := thrust.length_squared() > 1.0
	for plume in _plumes:
		plume.emitting = thrusting
		if thrusting:
			plume.rotation = thrust.angle() - rotation + PI
			var trail_scale: float = plume.get_meta("trail_scale", 1.0)
			plume.scale_amount_max = (2.6 if boosting else 1.8) * trail_scale

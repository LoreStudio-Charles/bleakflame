class_name WeaponMount
extends Node2D
## Runtime weapon at a hardpoint. Aim is clamped to the hardpoint's arc and
## slewed at the weapon's traverse speed — the traverse rule (big guns track
## slowly) lives here, in motion, not just in a stat panel.

## At or under this arc a mount is a gun, not a turret. Player guns hold the
## nose line (steering IS aiming); AI ships keep in-arc gimbal tracking — the
## fiction is machine fire-control, and it preserves strafing pirates' teeth.
const FIXED_ARC_DEG := 60.0

var def: WeaponDef
var hardpoint: HardpointDef
var target_group := ""
var nose_locked := false
## 1.0 = perfect intercept solution. AI ships dial this down — pirate
## fire-control is good, not prescient.
var lead_factor := 1.0
## Pilot-background bonus (Turret Tender): scales slew rate, set by the
## owning ship at apply_build. 1.0 for everyone else.
var traverse_mult := 1.0
## Owner-set damage scalar — military Guardians hit far harder than their
## hull class suggests. 1.0 for everyone else.
var damage_mult := 1.0

## Player-favoring grace (coyote-time philosophy: when the system can't be
## tuned perfectly, nudge in the player's favor — invisibly). AI gets none.
## Shots fired within ASSIST_CONE of the intercept line bend up to
## ASSIST_SNAP degrees onto it: near-solution shots become true.
## (Widened for the ordnance era — slow unguided rockets must be landable.)
const ASSIST_CONE_DEG := 14.0
const ASSIST_SNAP_DEG := 7.0
var assist_active := false
var assist_point := Vector2.ZERO
## Extra effective target radius for this mount's bolts (player only):
## miss-by-a-hair reads as unfair, so a hair counts as a hit.
var shot_grace := 0.0
## Rounds remaining for ordnance (-1 = energy weapon, never runs dry).
## Restocked, for credits, when the ship docks.
var ammo := -1
## Weapon array (1 = guns, 2 = ordnance — auto-assigned by magazine).
## The trigger fires enabled arrays only; offline mounts hold fire and
## grey their effigy pip. AI never toggles arrays.
var group := 1
var offline := false
var shooter: Node = null   # the owning ship — its own bolts never hit it

## Turret sprite scale (1.0 for station emplacements; ships scale by mark).
var sprite_scale := 1.0

var _cooldown := 0.0
var _facing := 0.0     # arc center, radians, ship-local
var _half_arc := 0.0
var _sprite_path := ""
var _flash := 0.0
var _beam_time := 0.0
var _beam_end := Vector2.ZERO   # mount-local


func setup(hp: HardpointDef, weapon: WeaponDef, group: String, sprite_path := "") -> void:
	hardpoint = hp
	def = weapon
	target_group = group
	_sprite_path = sprite_path
	position = hp.offset
	_facing = deg_to_rad(hp.facing_deg)
	_half_arc = deg_to_rad(hp.arc_deg) * 0.5
	rotation = _facing
	ammo = weapon.magazine if weapon.magazine > 0 else -1
	material = Projectile.additive_material()   # flash + beam glow
	_build_visual()


func _build_visual() -> void:
	# A turret sprite (housing pointing right) rotates with the mount itself.
	if _sprite_path != "" and ResourceLoader.exists(_sprite_path):
		var sprite := Sprite2D.new()
		sprite.texture = load(_sprite_path)
		sprite.scale = Vector2.ONE * sprite_scale
		add_child(sprite)
		return
	# Placeholder vectors: turret-y mounts get a base ring, barrel scales
	# with weapon Mark so big guns read as big.
	if hardpoint.arc_deg > 90.0:
		var base := Polygon2D.new()
		var points := PackedVector2Array()
		for i in 10:
			points.append(Vector2.RIGHT.rotated(TAU * i / 10.0) * 3.5)
		base.polygon = points
		base.color = Color(0.45, 0.48, 0.55)
		add_child(base)
	var len := 7.0 + 2.5 * def.mark
	var w := 0.9 + 0.3 * def.mark
	var barrel := Polygon2D.new()
	barrel.polygon = PackedVector2Array([
		Vector2(0, -w), Vector2(len, -w * 0.7), Vector2(len, w * 0.7), Vector2(0, w)])
	barrel.color = Color(0.85, 0.88, 0.95)
	add_child(barrel)


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if _flash > 0.0 or _beam_time > 0.0:
		_flash = maxf(0.0, _flash - delta)
		_beam_time = maxf(0.0, _beam_time - delta)
		queue_redraw()


## Slews the barrel toward a world-space point, respecting arc and traverse.
## Given the target's velocity, aims at the intercept point — where the target
## will be when the bolt arrives, not where it is. Without lead, every gun in
## a fight of circling ships shoots behind its target forever.
func aim_at(world_target: Vector2, delta: float, target_vel := Vector2.ZERO) -> void:
	if nose_locked:
		rotation = rotate_toward(rotation, _facing,
			deg_to_rad(def.traverse_speed() * traverse_mult) * delta)
		return
	var ship := get_parent() as Node2D
	# The bolt now INHERITS the shooter's velocity (Projectile.spawn), so a moving
	# shooter's shots drift unless we cancel it out here — see intercept_point. A
	# strafing pirate was firing wide until this ("bullets aren't accurate", found in
	# playtest after velocity-inheritance landed).
	var sv = ship.get("velocity")
	var shooter_vel: Vector2 = sv if sv is Vector2 else Vector2.ZERO
	var aim_point := intercept_point(global_position, world_target, target_vel,
		shooter_vel, def.projectile_speed, lead_factor)
	var desired := (aim_point - global_position).angle() - ship.global_rotation
	var clamped := _facing + clampf(angle_difference(_facing, desired), -_half_arc, _half_arc)
	rotation = rotate_toward(rotation, clamped,
		deg_to_rad(def.traverse_speed() * traverse_mult) * delta)


## Where to aim so a bolt — which carries the SHOOTER's velocity now — meets the
## target. Solve it in the shooter's own frame: lead the TARGET imperfectly (lead =
## the AI's aim skill) but cancel OUR OWN velocity EXACTLY (physics, not skill), so a
## moving shooter no longer fires wide. Pure + static so it's testable.
static func intercept_point(from: Vector2, world_target: Vector2, target_vel: Vector2,
		shooter_vel: Vector2, projectile_speed: float, lead: float) -> Vector2:
	var lead_vel := target_vel * lead - shooter_vel
	var aim_point := world_target
	if lead_vel != Vector2.ZERO and projectile_speed > 0.0:
		for i in 2:   # two passes converge close enough at these speeds
			var t := from.distance_to(aim_point) / projectile_speed
			aim_point = world_target + lead_vel * t
	return aim_point


## 1.0 = charged and ready; rising fraction = recharge. Drives the HUD rack.
func ready_fraction() -> float:
	if def == null or def.fire_interval <= 0.0:
		return 1.0
	return clampf(1.0 - _cooldown / def.fire_interval, 0.0, 1.0)


func fire() -> void:
	if offline or _cooldown > 0.0:
		return
	# Dry magazine: a hollow click, not silence — the player must HEAR
	# that they're out (visibility rule, audio edition).
	if def.magazine > 0 and ammo <= 0:
		_cooldown = 0.3
		Sfx.play_at("click", global_position, -14.0, 0.55)
		return
	_cooldown = def.fire_interval
	if def.magazine > 0:
		ammo -= 1
	if def.beam:
		_fire_beam()
		return
	var shot_angle := global_rotation
	if assist_active:
		var diff := angle_difference(global_rotation, (assist_point - global_position).angle())
		if absf(diff) <= deg_to_rad(ASSIST_CONE_DEG):
			shot_angle += clampf(diff, -deg_to_rad(ASSIST_SNAP_DEG), deg_to_rad(ASSIST_SNAP_DEG))
	var dir := Vector2.RIGHT.rotated(shot_angle)
	Projectile.spawn(get_tree().current_scene, global_position + dir * 10.0, dir, def,
		target_group, shot_grace + def.hit_bonus, damage_mult, shooter)
	_flash = 0.09
	queue_redraw()
	# Bigger guns bark lower.
	Sfx.play_at("pew", global_position, -12.0, clampf(1.35 - def.mark * 0.18, 0.5, 1.3))


## Instant ray along the barrel: nearest thing on the line eats this tick's
## damage. Held fire reads as a continuous beam (visual persists past the
## fire interval).
func _fire_beam() -> void:
	var origin := global_position
	var dir := Vector2.RIGHT.rotated(global_rotation)
	var best := def.weapon_range
	var hit_obj: Node2D = null
	for group in [target_group, "asteroids"]:
		for node in get_tree().get_nodes_in_group(group):
			if not is_instance_valid(node) or node.get("dead") == true or node == shooter:
				continue
			var r := BuildShip.hit_profile_of(node) + shot_grace
			var to: Vector2 = node.global_position - origin
			var along := to.dot(dir)
			if along < 0.0 or along > best + r:
				continue
			var perp := absf(to.cross(dir))
			if perp <= r:
				var d := maxf(along - sqrt(maxf(r * r - perp * perp, 0.0)), 0.0)
				if d < best:
					best = d
					hit_obj = node
	var hit_pos := origin + dir * best
	if hit_obj != null:
		if hit_obj.is_in_group("asteroids"):
			hit_obj.hit(def.damage * damage_mult, def.mining_power)
		else:
			hit_obj.take_damage(def.damage * damage_mult,
				shooter if is_instance_valid(shooter) else null)
		Projectile.spark(get_tree().current_scene, hit_pos, def.bolt_color, 3)
	_beam_time = 0.11
	_beam_end = to_local(hit_pos)
	queue_redraw()
	Sfx.play_at("pew", origin, -22.0, 1.75)


func _draw() -> void:
	if def == null:
		return
	var tip := Vector2(7.0 + 2.5 * def.mark, 0)
	var c := def.bolt_color
	if _beam_time > 0.0:
		draw_line(tip, _beam_end, Color(c, 0.22), 5.0)
		draw_line(tip, _beam_end, Color(c, 0.6), 2.4)
		draw_line(tip, _beam_end, Color(1, 1, 1, 0.9), 1.0)
		draw_circle(_beam_end, 2.8, Color(1, 1, 1, 0.85))
		draw_circle(tip, 2.2, Color(c, 0.7))
	if _flash > 0.0:
		draw_circle(tip, 2.5 + def.mark, Color(c, 0.55))
		draw_circle(tip, 1.4 + def.mark * 0.5, Color(1, 1, 1, 0.85))

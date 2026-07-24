class_name Projectile
extends Node2D
## Faction-aware bolt: only hits members of its target group. Collision is a
## swept segment test against each target's hit_radius so fast bolts cannot
## tunnel through small targets between frames.
## Rendered additively (shared material) — bolts GLOW against dark space,
## the compatibility renderer's answer to emissive. Color/size come from the
## weapon def, so every gun family is identifiable by its fire.

static var _add_material: CanvasItemMaterial

var velocity := Vector2.ZERO
var damage := 0.0
var life := 1.0
var target_group := ""
var color := Color(1.0, 0.85, 0.5)
var bolt_scale := 1.0
## Pulse-beam tail length (0 = plain bolt). See WeaponDef.beam_tail.
var beam_tail := 0.0
var _travel := 0.0
var _collapsing := false
var _tail_len := 0.0
var _pulse_speed := 0.0
## Extra effective target radius. Player bolts carry a little (grazes count);
## everyone else's carry zero.
var grace := 0.0
## Mining power carried from the weapon def — extraction rate against rock.
var mining := 0.0
## Proximity-fuzed blast radius (0 = plain bolt). Near a target = boom.
var blast := 0.0
## The ship that fired this — never hit your own shooter (matters once a ship can
## share a target group with its own bolts, e.g. a WANTED player in hostile_team).
var shooter: Node = null
## Homing (missiles): turn rate deg/s toward the tracked target (0 = straight).
var homing := 0.0
## Per-size homing override (5 entries = deg/s by target size band; empty = flat
## `homing`). Lets a weapon track small hulls harder or only big ones. See WeaponDef.
var homing_by_band := PackedFloat32Array()
## true = HEAT seeker (re-acquire nearest each frame); false = RADIO (locked target).
var seek_nearest := false
var target_ref: Node = null   # RADIO's locked target (or HEAT's current pick)
## ORDNANCE (a magazine weapon: rockets, missiles) rather than a gun bolt. The
## Miner's Crystalline Array denies this damage TYPE specifically — point
## defense stops warheads, it does not stop bullets.
var ordnance := false


static func spawn(parent: Node, pos: Vector2, dir: Vector2, def: WeaponDef,
		group: String, shot_grace := 0.0, dmg_mult := 1.0, p_shooter: Node = null) -> Projectile:
	var p := Projectile.new()
	p.shooter = p_shooter
	p.global_position = pos
	p.rotation = dir.angle()
	# INHERIT THE SHOOTER'S VELOCITY. Without it a bolt has the same world speed
	# however fast you are flying, so at speed it barely outruns your own nose —
	# it crawls a few lengths ahead and then dies on its timer, which reads as
	# "my guns stopped working when I go fast".
	#
	# `life` stays range/muzzle_speed on purpose: RELATIVE closing speed is still
	# projectile_speed, so a weapon's reach from the shooter's frame is exactly
	# its designed weapon_range. The bolt simply covers more ground in the world.
	p.velocity = dir * def.projectile_speed
	if p_shooter != null and is_instance_valid(p_shooter):
		var sv = p_shooter.get("velocity")
		if sv is Vector2:
			p.velocity += sv
	p.damage = def.damage * dmg_mult
	p.life = def.weapon_range / def.projectile_speed
	p.target_group = group
	p.grace = shot_grace
	p.mining = def.mining_power
	p.color = def.bolt_color
	p.bolt_scale = def.bolt_scale
	p.beam_tail = def.beam_tail
	p.blast = def.blast_radius
	p.homing = def.homing
	p.homing_by_band = def.homing_by_band
	p.seek_nearest = def.seek_nearest
	p.ordnance = def.magazine > 0   # the game's own definition of ordnance
	if def.homing > 0.0 and p_shooter != null:
		p.target_ref = p_shooter.get("target")   # RADIO locks the shooter's selection
	p.material = additive_material()
	parent.add_child(p)
	# RADIO launched with nothing designated: lock the nearest foe at the muzzle.
	if def.homing > 0.0 and not def.seek_nearest \
			and (p.target_ref == null or not is_instance_valid(p.target_ref)):
		p.target_ref = p._nearest_in_group()
	return p


## Shared add-blend material — the one fake-emissive everyone borrows.
static func additive_material() -> CanvasItemMaterial:
	if _add_material == null:
		_add_material = CanvasItemMaterial.new()
		_add_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add_material


## Impact spark burst in the bolt's color, additive like the bolt itself.
static func spark(parent: Node, pos: Vector2, spark_color: Color, count: int) -> void:
	var burst := CPUParticles2D.new()
	burst.position = pos
	burst.one_shot = true
	burst.emitting = true
	burst.amount = count
	burst.lifetime = 0.22
	burst.explosiveness = 1.0
	burst.spread = 180.0
	burst.gravity = Vector2.ZERO
	burst.initial_velocity_min = 60.0
	burst.initial_velocity_max = 160.0
	burst.scale_amount_max = 1.6
	burst.color = spark_color
	burst.material = _add_material
	parent.add_child(burst)
	burst.finished.connect(burst.queue_free)


func _physics_process(delta: float) -> void:
	# A spent pulse: the tail collapses forward into wherever the front died.
	if _collapsing:
		_tail_len -= _pulse_speed * delta
		if _tail_len <= 0.0:
			queue_free()
		queue_redraw()
		return

	var prev := global_position
	# Homing: bend the velocity toward the tracked target, capped by the turn rate.
	if homing > 0.0:
		var tgt := _homing_target()
		if tgt != null:
			var to_t: Vector2 = tgt.global_position - global_position
			if to_t.length() > 1.0:
				# The per-size table is DEG PER 10 UNITS TRAVELLED — speed-independent
				# (a fast bolt and a slow one bend the same amount over the same ground),
				# so it's tunable without re-deriving against projectile speed. A weapon
				# with no table (or a non-ship mark) uses the legacy flat deg/SECOND.
				var band := _band_of(tgt) if homing_by_band.size() >= 5 else -1
				var max_turn: float
				if band >= 0:
					max_turn = deg_to_rad(homing_by_band[band]) * (velocity.length() * delta / 10.0)
				else:
					max_turn = deg_to_rad(homing) * delta
				var cur := velocity.normalized()
				var turn := clampf(cur.angle_to(to_t.normalized()), -max_turn, max_turn)
				velocity = cur.rotated(turn) * velocity.length()
				rotation = velocity.angle()
	position += velocity * delta
	_travel += velocity.length() * delta
	life -= delta
	if life <= 0.0:
		if blast > 0.0:
			_detonate()   # AA shells self-detonate at range's end
		else:
			_end_flight()
		return

	# Proximity fuze: a target inside ~70% of the blast radius means the
	# splash will hurt — that's near enough. Ships only; rocks don't set
	# off fuzes (belt flying would be miserable), direct hits still do.
	if blast > 0.0:
		for target in get_tree().get_nodes_in_group(target_group):
			if not is_instance_valid(target) or target.get("dead") == true or target == shooter:
				continue
			var r: float = target.get("hit_radius") if target.get("hit_radius") != null else 12.0
			var fuze := blast * 0.7 + r
			if global_position.distance_squared_to(target.global_position) <= fuze * fuze:
				_detonate()
				return
	for target in get_tree().get_nodes_in_group(target_group):
		if not is_instance_valid(target) or target.get("dead") == true or target == shooter:
			continue
		# Evasion shrinks the target's effective profile (player-only; 0 for the
		# rest) — a harder target, deterministically, not an RNG miss.
		var base_r: float = target.get("hit_radius") if target.get("hit_radius") != null else 12.0
		var ev: float = target.get("evasion") if target.get("evasion") != null else 0.0
		var radius: float = base_r * (1.0 - ev) + grace
		var closest := Geometry2D.get_closest_point_to_segment(
			target.global_position, prev, global_position)
		if target.global_position.distance_squared_to(closest) <= radius * radius:
			if blast > 0.0:
				_detonate()
			else:
				# The shooter may have died mid-flight — pass null, never a freed
				# object (a typed Node param rejects it and throws).
				target.take_damage(damage, shooter if is_instance_valid(shooter) else null)
				spark(get_parent(), global_position, color, 6)
				_end_flight()
			return
	# Asteroids are terrain: they stop everyone's bolts. Cover for prey and
	# predator alike — and where the mining actually happens.
	for rock in get_tree().get_nodes_in_group("asteroids"):
		if not is_instance_valid(rock):
			continue
		var closest := Geometry2D.get_closest_point_to_segment(
			rock.global_position, prev, global_position)
		if rock.global_position.distance_squared_to(closest) <= rock.hit_radius * rock.hit_radius:
			if blast > 0.0:
				_detonate()
			else:
				rock.hit(damage, mining)
				spark(get_parent(), global_position, Color(0.8, 0.7, 0.55), 4)
				_end_flight()
			return


## The target this missile steers for: HEAT re-picks the nearest foe every frame;
## RADIO holds its locked target until it dies or is freed (then flies dumb).
func _homing_target() -> Node:
	if seek_nearest:
		return _nearest_in_group()
	if is_instance_valid(target_ref) and target_ref.get("dead") != true:
		return target_ref
	return null


## The target's size band [0..4] for the per-size homing table, or -1 if it isn't a
## ship with a hull (a leviathan / anomaly falls back to the flat homing rate).
func _band_of(node: Node) -> int:
	var build = node.get("build")
	if build != null and build.get("hull") != null:
		return int(build.hull.size_band)
	return -1


func _nearest_in_group() -> Node:
	var best: Node = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group(target_group):
		if not is_instance_valid(n) or n.get("dead") == true or n == shooter:
			continue
		var d: float = global_position.distance_squared_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	return best


## The splash is what kills: everything in the blast takes damage, full at
## the center falling to ~45% at the rim. Rocks chip too — a rocket is a
## poor but legal mining tool.
func _detonate() -> void:
	Sfx.play_at("explosion", global_position, -13.0, 1.5)
	spark(get_parent(), global_position, color, 14)
	var flash := BlastFlash.new()
	flash.radius = blast
	flash.color = color
	get_parent().add_child(flash)
	flash.global_position = global_position
	# The shooter may have died mid-flight — pass null, never a freed object.
	var src: Node = shooter if is_instance_valid(shooter) else null
	for target in get_tree().get_nodes_in_group(target_group):
		if not is_instance_valid(target) or target.get("dead") == true or target == shooter:
			continue
		var r: float = target.get("hit_radius") if target.get("hit_radius") != null else 12.0
		var d := maxf(global_position.distance_to(target.global_position) - r, 0.0)
		if d <= blast:
			target.take_damage(damage * lerpf(1.0, 0.45, d / blast), src)
	for rock in get_tree().get_nodes_in_group("asteroids"):
		if not is_instance_valid(rock):
			continue
		var d := maxf(global_position.distance_to(rock.global_position) - rock.hit_radius, 0.0)
		if d <= blast:
			rock.hit(damage * lerpf(1.0, 0.45, d / blast), mining)
	queue_free()


## One-shot expanding shockwave ring, additive like all weapon light.
class BlastFlash:
	extends Node2D
	const LIFE := 0.28
	var radius := 40.0
	var color := Color(1.0, 0.6, 0.3)
	var _age := 0.0

	func _ready() -> void:
		material = Projectile.additive_material()

	func _physics_process(delta: float) -> void:
		_age += delta
		if _age >= LIFE:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var t := _age / LIFE
		var r := radius * sqrt(t)
		draw_circle(Vector2.ZERO, r * 0.5 * (1.0 - t), Color(1, 1, 1, 0.7 * (1.0 - t)))
		draw_circle(Vector2.ZERO, r, Color(color, 0.3 * (1.0 - t)))
		draw_arc(Vector2.ZERO, r, 0, TAU, 28, Color(color, 0.85 * (1.0 - t)), 2.5)


## Plain bolts vanish; pulse beams hold position and collapse their tail.
func _end_flight() -> void:
	if beam_tail <= 0.0:
		queue_free()
		return
	_collapsing = true
	_pulse_speed = velocity.length()
	_tail_len = minf(_travel, beam_tail)
	velocity = Vector2.ZERO


func _draw() -> void:
	var s := bolt_scale
	if beam_tail > 0.0:
		# Pulse laser: light-front with the beam trailing behind it. While
		# flying, the tail grows out of the muzzle (clipped by distance
		# traveled); while collapsing, it shrinks into the impact point.
		var tail := _tail_len if _collapsing else minf(_travel, beam_tail)
		if tail > 0.5:
			draw_line(Vector2(-tail, 0), Vector2.ZERO, Color(color, 0.2), 4.5 * s)
			draw_line(Vector2(-tail, 0), Vector2.ZERO, Color(color, 0.6), 2.2 * s)
			draw_line(Vector2(-tail, 0), Vector2.ZERO, Color(1, 1, 1, 0.9), 1.0 * s)
		if not _collapsing:
			draw_circle(Vector2.ZERO, 3.0 * s, Color(color, 0.4))
			draw_circle(Vector2.ZERO, 1.6 * s, Color(1, 1, 1, 0.95))
		else:
			draw_circle(Vector2.ZERO, 2.2 * s, Color(color, 0.5))   # impact afterglow
		return
	# Plain bolt: layered additive halo -> hot core -> white tip.
	draw_circle(Vector2(1.5 * s, 0), 5.0 * s, Color(color, 0.16))
	draw_circle(Vector2(1.5 * s, 0), 2.6 * s, Color(color, 0.4))
	draw_line(Vector2(-7.0 * s, 0), Vector2(2.5 * s, 0), Color(color, 0.85), 1.8 * s)
	draw_line(Vector2(-3.0 * s, 0), Vector2(2.5 * s, 0), Color(1, 1, 1, 0.9), 0.9 * s)

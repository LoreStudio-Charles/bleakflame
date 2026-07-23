class_name BreathCloud
extends Node2D
## The Cinderweb's exhalation: a slow gout of clinging shadow. Inside it a
## ship is ENSNARED — velocity bleeds away, thrusters gutter (TestShip cuts
## thrust while snared), and the dark chews at the hull in slow pulses. The
## cloud itself is survivable; what kills you is the thing that exhaled it
## closing in while you wallow. Burn out early or never touch it.

const TRAVEL_SPEED := 240.0
const RADIUS := 110.0
const LIFETIME := 3.5
const SNARE_DAMP := 1.6       # extra velocity damping per second inside
const DOT_PULSE := 2.4        # hull chew per pulse
const PULSE_EVERY := 0.35

## Drop-in smoke art: assets/world/breath/*.png (variant pool). Two copies
## counter-rotate for the roil. Flat shadow circles remain the fallback.
const ART_DIR := "res://assets/world/breath"
static var _pool: Array[Texture2D] = []
static var _pool_loaded := false

var _velocity := Vector2.ZERO
var _age := 0.0
var _pulse := 0.0
var _texture: Texture2D
var _texture_b: Texture2D
var _spin := randf_range(0.25, 0.5) * (1.0 if randf() < 0.5 else -1.0)


static func spawn(parent: Node, pos: Vector2, dir: Vector2) -> BreathCloud:
	if not _pool_loaded:
		_pool_loaded = true
		var dir_access := DirAccess.open(ART_DIR)
		if dir_access != null:
			for f in dir_access.get_files():
				var file_name := f.trim_suffix(".import")
				if file_name.ends_with(".png"):
					var p := "%s/%s" % [ART_DIR, file_name]
					if ResourceLoader.exists(p):
						_pool.append(load(p))
	var cloud := BreathCloud.new()
	cloud.global_position = pos
	cloud._velocity = dir * TRAVEL_SPEED
	if not _pool.is_empty():
		cloud._texture = _pool[randi() % _pool.size()]
		cloud._texture_b = _pool[randi() % _pool.size()]
	parent.add_child(cloud)
	return cloud


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	# The gout slows and hangs — breath, not bullet.
	_velocity *= exp(-0.9 * delta)
	position += _velocity * delta
	_pulse = maxf(0.0, _pulse - delta)

	var player := get_tree().get_first_node_in_group("player_ship") as TestShip
	if player != null and not player.dead and player.docked_at == null \
			and global_position.distance_to(player.global_position) <= RADIUS:
		player.snared = 0.3
		player.velocity *= exp(-SNARE_DAMP * delta)
		if _pulse <= 0.0:
			_pulse = PULSE_EVERY
			player.take_damage(DOT_PULSE)
	queue_redraw()


func _draw() -> void:
	# Dark breath: layered shadow, NOT additive — it eats light.
	var fade := clampf(1.0 - _age / LIFETIME, 0.0, 1.0)
	var swell := minf(_age * 2.2, 1.0)   # blooms outward on arrival
	var r := RADIUS * (0.55 + 0.45 * swell)
	if _texture != null:
		# Two counter-rotating smoke sprites roil against each other; the
		# second is bigger, dimmer, and behind. Still normal blend — the
		# Cinderweb's breath eats light, it does not emit it.
		var base_scale := (r * 2.0) / maxf(_texture.get_width(), 1.0)
		draw_set_transform(Vector2.ZERO, -_age * _spin * 0.7, Vector2.ONE * base_scale * 1.25)
		draw_texture(_texture_b, -_texture_b.get_size() * 0.5, Color(0.55, 0.5, 0.7, 0.5 * fade))
		draw_set_transform(Vector2.ZERO, _age * _spin, Vector2.ONE * base_scale)
		draw_texture(_texture, -_texture.get_size() * 0.5, Color(0.9, 0.85, 1.0, 0.85 * fade))
		draw_set_transform_matrix(Transform2D())
		return
	draw_circle(Vector2.ZERO, r, Color(0.09, 0.05, 0.14, 0.34 * fade))
	draw_circle(Vector2.ZERO, r * 0.66, Color(0.13, 0.07, 0.2, 0.4 * fade))
	draw_circle(Vector2.ZERO, r * 0.33, Color(0.2, 0.1, 0.3, 0.42 * fade))
	draw_arc(Vector2.ZERO, r, 0, TAU, 24, Color(0.45, 0.25, 0.6, 0.25 * fade), 1.5)

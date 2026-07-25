class_name TargetDrone
extends Node2D
## Dumb practice target: drifts slowly, flashes on hit, pops on death.

signal destroyed

var hp := 30.0
var hit_radius := 10.0
var _drift := Vector2.ZERO
var _flash := 0.0
var _sprite: Sprite2D = null   # drop-in art: assets/ships/drone.png (else the procedural mark)


func _ready() -> void:
	add_to_group("hostile_team")
	_drift = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(6.0, 22.0)
	# Drop-in art: use assets/ships/drone.png if it exists, else fall back to the diamond.
	var path := "res://assets/ships/drone.png"
	if ResourceLoader.exists(path):
		_sprite = Sprite2D.new()
		_sprite.texture = load(path)
		# Native scale: the ~19px of content inside the 32px canvas matches the procedural
		# diamond (~18px). If a replacement sprite has different margins, retune here.
		_sprite.scale = Vector2.ONE
		add_child(_sprite)


func _physics_process(delta: float) -> void:
	position += _drift * delta
	if _flash > 0.0:
		_flash -= delta
		queue_redraw()
	if _sprite != null:
		_sprite.modulate = Color(1.9, 1.9, 1.9) if _flash > 0.0 else Color.WHITE


func take_damage(amount: float, _source: Node = null) -> void:
	# Practice drones die ONLY to the player. A stray Guardian bolt clearing one advanced
	# the drones step before the pilot had killed all three themselves — telling them
	# "bring her home" while targets still drifted out there. Guardians may shoot; they
	# just can't score it. (The damage source existed; the port to lessons never used it.)
	if _source == null or not _source.is_in_group("player_ship"):
		return
	hp -= amount
	_flash = 0.1
	Sfx.play_at("hit", global_position, -12.0, 1.2)
	queue_redraw()
	if hp <= 0.0:
		_explode()
		destroyed.emit()
		queue_free()


func _explode() -> void:
	Sfx.play_at("explosion", global_position, -9.0, 1.3)
	var burst := CPUParticles2D.new()
	burst.position = global_position
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 24
	burst.lifetime = 0.5
	burst.direction = Vector2.ZERO
	burst.spread = 180.0
	burst.gravity = Vector2.ZERO
	burst.initial_velocity_min = 60.0
	burst.initial_velocity_max = 160.0
	burst.scale_amount_max = 2.0
	burst.color = Color(1.0, 0.6, 0.3)
	burst.emitting = true
	get_parent().add_child(burst)
	burst.get_tree().create_timer(1.0).timeout.connect(burst.queue_free)


func _draw() -> void:
	if _sprite != null:
		return   # the sprite carries the visual; flash is handled via its modulate
	var color := Color(0.75, 0.35, 0.35) if _flash <= 0.0 else Color(1, 1, 1)
	draw_colored_polygon(PackedVector2Array([
		Vector2(9, 0), Vector2(0, -7), Vector2(-9, 0), Vector2(0, 7)]), color)
	draw_circle(Vector2.ZERO, 2.5, Color(0.25, 0.1, 0.1))

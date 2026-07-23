class_name Decoy
extends Node2D
## Trader Decoy Flare: a bright false contact ejected on the gem. It joins
## "player_team" so hostile fire-control retargets IT while the real ship rides
## is_hidden() (ship.gd _decoy_t). Drifts, flickers, self-frees. Duck-types the
## members AI target-selection reads (dead / docked_at / is_hidden / hit_radius
## / velocity), so a pirate treats it exactly like a ship worth shooting.

var life := 4.0
var velocity := Vector2.ZERO
var hit_radius := 16.0
var dead := false
var docked_at: Node = null
var _t := 0.0


func _ready() -> void:
	add_to_group("player_team")   # hostiles acquire + shoot it in the real ship's place


func is_hidden() -> bool:
	return false


func take_damage(_amount: float, _source: Node = null) -> void:
	# A flare, not a hull — fire pours into it and pops sparks, no health to track.
	Projectile.spark(get_parent(), global_position, Color(1.0, 0.82, 0.42), 4)


func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	global_position += velocity * delta
	velocity *= 0.985
	queue_redraw()


func _draw() -> void:
	var a := 1.0 - _t / life
	var flick := 0.6 + 0.4 * sin(_t * 40.0)
	draw_circle(Vector2.ZERO, 11.0, Color(1.0, 0.85, 0.45, 0.22 * a))
	draw_circle(Vector2.ZERO, 5.0 * flick, Color(1.0, 0.95, 0.72, 0.9 * a))

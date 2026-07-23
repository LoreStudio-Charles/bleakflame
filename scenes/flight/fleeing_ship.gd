class_name FleeingShip
extends BuildShip
## A one-off scripted actor for witness set-pieces: a ship that BURNS away on a
## fixed heading, faster than the player can chase, and frees itself once it's
## far enough to have "escaped" (or been taken). No AI, no fighting, and in no
## target group — stray fire can't touch it. It exists to be watched leaving.
## Built for Krayt's run from the falling Rust Shoal; reusable for any ship the
## story needs to streak off the edge of the world.

var flee_vel := Vector2.ZERO
var _origin := Vector2.ZERO
## While holding (not yet launched), turn to face this and fire — Krayt emptying
## his guns into the beast to draw its ire before he runs. Ignored once launched.
var harass: Node2D = null
const DESPAWN_DIST := 4200.0


## Point it and light the engines. Call after apply_build + positioning.
func launch(dir: Vector2, speed: float) -> void:
	flee_vel = dir.normalized() * speed
	_origin = global_position
	rotation = flee_vel.angle()


func _physics_process(delta: float) -> void:
	if build == null:
		return
	tick_common(delta)
	if flee_vel == Vector2.ZERO:
		# Holding station (formed up). If harassing, turn onto the target and
		# empty the guns into it — the beast's ire is the whole point.
		if harass != null and is_instance_valid(harass) and not bool(harass.get("dead")):
			var to_t: Vector2 = harass.global_position - global_position
			rotation = rotate_toward(rotation, to_t.angle(), 3.0 * delta)
			update_mounts(harass.global_position, delta, Vector2.ZERO)
			fire_mounts()
		return   # no drift until launch() lights the engines
	global_position += flee_vel * delta
	rotation = rotate_toward(rotation, flee_vel.angle(), 3.0 * delta)
	if _origin.distance_to(global_position) > DESPAWN_DIST:
		queue_free()

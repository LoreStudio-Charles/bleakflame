class_name TangleField
extends Node2D
## Miner Tangle Shot: a clinging drag on a single target for `life` seconds. It
## damps the target's velocity every frame externally — no cooperation from the
## target needed, so it works on any ship — and draws a green web tether. Frees
## itself when it expires or the target dies. The target still THRUSTS, so this
## caps its speed and holds it rather than freezing it dead.

var target: Node2D
var life := 3.5
var _t := 0.0
const DRAG := 0.82


func _process(delta: float) -> void:
	_t += delta
	if _t >= life or target == null or not is_instance_valid(target) or target.get("dead") == true:
		queue_free()
		return
	global_position = target.global_position
	var v = target.get("velocity")
	if v != null:
		target.velocity = (v as Vector2) * DRAG
	queue_redraw()


func _draw() -> void:
	var a := 1.0 - _t / life
	var r := 16.0
	if is_instance_valid(target) and target.get("hit_radius") != null:
		r = float(target.hit_radius)
	draw_arc(Vector2.ZERO, r + 6.0, 0.0, TAU, 24, Color(0.7, 0.95, 0.6, 0.5 * a), 2.0)
	for i in 6:
		var ang := TAU * i / 6.0 + _t
		draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(ang) * (r + 6.0),
			Color(0.6, 0.9, 0.55, 0.35 * a), 1.5)

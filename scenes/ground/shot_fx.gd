class_name ShotFx
extends Node2D
## The ranged-shot flash — pure juice, one node per shot, dead in ~0.14s:
## a hot muzzle spark, a tracer line to the target, and an impact fleck.
##
## Draws in WORLD coordinates as a top-level node, so it never inherits the
## shooter's flip/scale and never fights the town's y-sort (z above the actors).

const LIFE := 0.14
const TRACER := Color(1.0, 0.92, 0.66)   # hot brass — reads on the dusk grade
const FLASH := Color(1.0, 0.97, 0.85)

var from := Vector2.ZERO
var to := Vector2.ZERO
var _t := 0.0


static func spawn(parent: Node, p_from: Vector2, p_to: Vector2) -> void:
	var fx := ShotFx.new()
	fx.from = p_from
	fx.to = p_to
	fx.top_level = true
	fx.z_index = 40
	parent.add_child(fx)


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var fade := 1.0 - _t / LIFE
	# Tracer: bright core over a soft glow, both dying with the fade.
	draw_line(from, to, Color(TRACER, 0.22 * fade), 3.0)
	draw_line(from, to, Color(TRACER, 0.85 * fade), 1.0)
	# Muzzle flash: only the first beat — a flash that lingers reads as fire.
	if _t < LIFE * 0.45:
		var mf := 1.0 - _t / (LIFE * 0.45)
		draw_circle(from, 5.0 * mf, Color(FLASH, 0.9 * mf))
		draw_circle(from, 9.0 * mf, Color(TRACER, 0.3 * mf))
	# Impact fleck at the target.
	draw_circle(to, 3.5 * fade, Color(FLASH, 0.8 * fade))

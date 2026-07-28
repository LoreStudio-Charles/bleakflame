class_name KillshotBeam
extends Node2D
## The Scout Killshot's tracer — a hairline rail streak from muzzle to mark that
## snaps in and fades. Purely cosmetic: the shot has ALREADY landed by the time
## this draws (the ability cannot miss), so nothing here can affect the outcome.
## Points are baked at spawn in world space, so a dying target or a jinking
## shooter never drags the line around after the fact.

const CORE := Color(0.86, 0.96, 1.0)
const HALO := Color(0.42, 0.78, 1.0)
const LIFE := 0.32

var from_point := Vector2.ZERO
var to_point := Vector2.ZERO

var _t := 0.0


func _ready() -> void:
	z_index = 6


func _process(delta: float) -> void:
	var _t0 := Telemetry.now_us()
	_tick_p(delta)
	Telemetry.phase("p.killshot_beam", _t0)


func _tick_p(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var _t0 := Telemetry.now_us()
	_paint_d()
	Telemetry.phase("d.killshot_beam", _t0)


func _paint_d() -> void:
	var a := 1.0 - _t / LIFE
	var a_local := to_local(from_point)
	var b_local := to_local(to_point)
	draw_line(a_local, b_local, Color(HALO, 0.35 * a), 5.0)
	draw_line(a_local, b_local, Color(CORE, 0.95 * a), 1.5)
	draw_circle(b_local, 7.0 * a, Color(CORE, 0.5 * a))

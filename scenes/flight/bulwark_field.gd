extends Node2D
## The blue protective dome a Bulwark Projector throws up. PURELY COSMETIC — the
## damage reduction is applied to ships at cast time (BuildShip.apply_bulwark);
## this just marks the zone and fades as the protection runs out. Child of the
## caster, so it travels with them. Drop-in art could replace the drawn ring.

var radius := 420.0
var life := 5.0
var _t := 0.0


func _process(delta: float) -> void:
	var _t0 := Telemetry.now_us()
	_tick_p(delta)
	Telemetry.phase("p.bulwark_field", _t0)


func _tick_p(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var _t0 := Telemetry.now_us()
	_paint_d()
	Telemetry.phase("d.bulwark_field", _t0)


func _paint_d() -> void:
	var a := 1.0 - _t / life
	# Soft fill + a brighter rim; both fade together with the buff.
	draw_circle(Vector2.ZERO, radius, Color(0.4, 0.7, 1.0, 0.09 * a))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 72, Color(0.55, 0.82, 1.0, 0.55 * a), 3.0, true)

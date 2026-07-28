class_name RangeRuler
extends Node2D
## DEV MEASURING TAPE (debug only). Concentric rings centred on the player, each
## labelled with its distance in WORLD UNITS. So "the edge of the screen" and "up
## close" stop being guesses when you're tuning an ability's range band — you can
## read the number off the ring.
##
## (Live range to the CURRENT target lives on the target HUD instead — it is
## targeting-computer data, not a dev overlay. This is only the measuring rings.)
##
## Toggled by the ] dev key in flight_test (pairs with [ , the tutorial re-arm).
## World-space, so the rings sit in the world and scale with the camera exactly
## like everything the ranges actually measure against.

## Rings at round distances a range value is likely to land near.
const RINGS := [250.0, 500.0, 750.0, 1000.0, 1250.0, 1500.0, 1800.0, 2000.0, 2500.0]
const RING := Color(0.35, 0.75, 0.95, 0.28)
const RING_LABEL := Color(0.6, 0.86, 1.0, 0.85)

var ship: Node2D


func _init(p_ship: Node2D) -> void:
	ship = p_ship
	z_index = 40
	visible = false


func _process(_delta: float) -> void:
	var _t0 := Telemetry.now_us()
	_tick_p(_delta)
	Telemetry.phase("p.range_ruler", _t0)


func _tick_p(_delta: float) -> void:
	if not visible or ship == null or not is_instance_valid(ship):
		return
	global_position = ship.global_position
	rotation = 0.0                # rings stay axis-aligned regardless of the hull
	queue_redraw()


func _draw() -> void:
	var _t0 := Telemetry.now_us()
	_paint_d()
	Telemetry.phase("d.range_ruler", _t0)


func _paint_d() -> void:
	var f := ThemeDB.fallback_font
	for r in RINGS:
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, RING, 1.5, true)
		# Label at the top of each ring, kept upright.
		var txt := "%d" % int(r)
		var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(f, Vector2(-w * 0.5, -r - 4.0), txt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, RING_LABEL)

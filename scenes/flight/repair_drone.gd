class_name RepairDrone
extends Node2D
## Trader Repair Drone — the guild's HEAL-OVER-TIME. A miniature tender launched
## at an ally: it circles them and pulses a mend every `pulse` seconds for `life`
## seconds, then burns out. Fire-and-forget, so a hauler pilot can keep flying
## while it works — the opposite of Science's channelled Repair Field (big burst,
## everyone in a radius, you stand still).
##
## Lives in the FLIGHT SCENE, not under its patient: ships rotate, and a child
## node would spin with the hull instead of orbiting it. It tracks the target by
## reference and validates every frame — a freed or dead patient just ends the
## drone (see the freed-reference rule: never hand a freed object to a typed
## parameter).

const BODY := Color(0.62, 0.92, 0.72)
const GLOW := Color(0.45, 0.95, 0.60)

var target: Node2D = null
var life := 30.0
var pulse := 3.0
var heal := 14.0
var orbit_radius := 38.0
var orbit_speed := 2.2

var _t := 0.0
var _next_pulse := 0.0
var _flash := 0.0


func _ready() -> void:
	_next_pulse = pulse
	z_index = 4


func _process(delta: float) -> void:
	if not _patient_valid():
		queue_free()
		return

	_t += delta
	if _t >= life:
		queue_free()
		return

	# Orbit the patient wherever they fly.
	var ang := _t * orbit_speed
	global_position = target.global_position \
		+ Vector2(cos(ang), sin(ang) * 0.55) * orbit_radius

	_flash = maxf(0.0, _flash - delta * 3.0)
	if _t >= _next_pulse:
		_next_pulse += pulse
		_mend()
	queue_redraw()


func _patient_valid() -> bool:
	return is_instance_valid(target) and target.get("dead") != true


## One tick of the heal. `repair()` already clamps to missing hull/armor, so an
## untouched ally simply wastes the tick rather than overhealing.
func _mend() -> void:
	if not target.has_method("repair"):
		return
	target.repair(heal)
	_flash = 1.0
	Sfx.play("click", -20.0, 1.6)


func _draw() -> void:
	var fade := 1.0
	var remaining := life - _t
	if remaining < 3.0:
		fade = remaining / 3.0   # the drone dims as it burns out — the telegraph

	# tether back to the patient, so the heal is legible at a glance
	if _patient_valid():
		var to_patient := to_local(target.global_position)
		draw_line(Vector2.ZERO, to_patient, Color(GLOW, 0.22 * fade), 1.0)

	if _flash > 0.0:
		draw_circle(Vector2.ZERO, 14.0 * _flash, Color(GLOW, 0.30 * _flash * fade))
	draw_circle(Vector2.ZERO, 4.5, Color(BODY, 0.95 * fade))
	draw_circle(Vector2.ZERO, 2.0, Color(1.0, 1.0, 1.0, 0.85 * fade))

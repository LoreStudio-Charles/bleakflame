class_name ShieldOverload
extends Node2D
## Science "Overload Pulse" — the EMP that drops a hull's SHIELDS, then hands
## them back exactly as they were. It is a WINDOW, not damage: nothing is
## destroyed, an opening is created, and what the wing does with those seconds
## is the whole ability.
##
## THE RESTORE IS THE DESIGN. Shields blink back at the strength they held when
## they dropped — damage dealt during the window does NOT eat into them. So the
## pulse can never be used to grind a tank down by chaining it; it buys a burst
## window and nothing more. That also makes it clean against the Killshot, which
## is halved by live shields: EMP, then take the shot.
##
## Suppression has to be ACTIVE, not a one-off zeroing: `tick_common` regenerates
## shields every frame, so the node pins them at zero for the duration and holds
## the regen delay down, then releases.

const ARC := Color(0.55, 0.85, 1.0)

var target: Node2D = null
var life := 3.0

var _t := 0.0
var _stored := 0.0
var _held := false


func _ready() -> void:
	z_index = 5


## Take the shields down and remember EXACTLY what was there.
func seize(victim: Node2D) -> void:
	target = victim
	_stored = float(victim.get("shield"))
	victim.shield = 0.0
	_held = true


func _process(delta: float) -> void:
	var _t0 := Telemetry.now_us()
	_tick_p(delta)
	Telemetry.phase("p.shield_overload", _t0)


func _tick_p(delta: float) -> void:
	if not _valid():
		queue_free()
		return

	_t += delta
	# Pin the shield at zero — tick_common would otherwise trickle it back up during
	# the window, and the regen delay must not expire mid-suppression either.
	target.shield = 0.0
	target._regen_blocked = maxf(target._regen_blocked, BuildShip.SHIELD_REGEN_DELAY)

	global_position = target.global_position
	if _t >= life:
		queue_free()
		return
	queue_redraw()


func _valid() -> bool:
	return is_instance_valid(target) and target.get("dead") != true


## Give them back whatever they had — even if the node dies early, so a freed
## caster or a scene change can never strand a ship without shields.
func _exit_tree() -> void:
	if _held and _valid():
		target.shield = _stored
		target._regen_blocked = 0.0
	_held = false


func _draw() -> void:
	var _t0 := Telemetry.now_us()
	_paint_d()
	Telemetry.phase("d.shield_overload", _t0)


func _paint_d() -> void:
	var a := 1.0 - _t / life
	var r: float = 26.0
	if is_instance_valid(target) and target.get("hit_radius") != null:
		r = maxf(20.0, float(target.hit_radius) * 1.6)
	# a broken, guttering ring — the shield envelope failing rather than a field
	for i in 7:
		var base := float(i) / 7.0 * TAU
		var wob := sin(_t * 14.0 + float(i) * 2.3) * 0.12
		draw_arc(Vector2.ZERO, r + sin(_t * 9.0 + i) * 2.0,
			base + wob, base + 0.42 + wob, 8, Color(ARC, 0.75 * a), 2.0)

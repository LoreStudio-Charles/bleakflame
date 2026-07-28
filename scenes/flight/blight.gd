class_name Blight
extends Node2D
## Privateer "Withering Timbers" — a blight of a thousand nanobot privateers that
## take the target apart at the molecular level. It CLINGS to the hull and bites
## every `pulse` seconds for as long as it stays attached: slow, inevitable, and
## impossible to shoot off. The outlaw mirror of the Trader's Tender Drone — same
## 30-second window, opposite sign.
##
## Kill CREDIT matters here: a ship that dies to the blight must count as the
## player's kill (XP, loot, standing), so every bite passes the owner along as the
## damage source. If the owner is gone we deal the damage anonymously rather than
## hand a freed object to a typed parameter — that crash is a known one.

const MOTE := Color(0.72, 0.86, 0.35)
const DEEP := Color(0.45, 0.62, 0.20)
const MOTES := 9

var target: Node2D = null
var owner_ship: Node = null
var life := 30.0
var pulse := 6.0
var damage := 30.0

var _t := 0.0
var _next_pulse := 0.0
var _flash := 0.0


func _ready() -> void:
	_next_pulse = pulse
	z_index = 3


## Re-applying to an already-infected hull REFRESHES the blight instead of
## stacking a second one — spamming the gem must never multiply the damage.
func refresh() -> void:
	_t = 0.0
	_next_pulse = pulse
	_flash = 1.0


func _process(delta: float) -> void:
	var _t0 := Telemetry.now_us()
	_tick_p(delta)
	Telemetry.phase("p.blight", _t0)


func _tick_p(delta: float) -> void:
	if not _host_valid():
		queue_free()
		return

	_t += delta
	if _t >= life:
		queue_free()
		return

	global_position = target.global_position
	_flash = maxf(0.0, _flash - delta * 2.5)
	if _t >= _next_pulse:
		_next_pulse += pulse
		_bite()
	queue_redraw()


func _host_valid() -> bool:
	return is_instance_valid(target) and target.get("dead") != true


func _bite() -> void:
	if not target.has_method("take_damage"):
		return
	if is_instance_valid(owner_ship):
		target.take_damage(damage, owner_ship)
	else:
		target.take_damage(damage)
	_flash = 1.0
	Sfx.play("click", -18.0, 0.55)


func _draw() -> void:
	var _t0 := Telemetry.now_us()
	_paint_d()
	Telemetry.phase("d.blight", _t0)


func _paint_d() -> void:
	var fade := 1.0
	var remaining := life - _t
	if remaining < 4.0:
		fade = remaining / 4.0   # the swarm thins as it dies off

	var spread: float = 15.0
	if is_instance_valid(target):
		spread = maxf(12.0, float(target.get("hit_radius") if target.get("hit_radius") else 15.0))

	if _flash > 0.0:
		draw_circle(Vector2.ZERO, spread * 1.5 * _flash, Color(DEEP, 0.22 * _flash * fade))

	# motes crawling the hull — deterministic orbits, no per-frame randomness
	for i in MOTES:
		var phase := float(i) / float(MOTES) * TAU
		var wob := sin(_t * 1.7 + phase * 3.0) * 0.35
		var r := spread * (0.55 + 0.45 * sin(_t * 0.9 + phase))
		var p := Vector2(cos(phase + _t * 0.6 + wob), sin(phase + _t * 0.45)) * r
		draw_circle(p, 1.8, Color(MOTE, 0.85 * fade))

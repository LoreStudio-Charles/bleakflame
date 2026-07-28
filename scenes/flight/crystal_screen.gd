class_name CrystalScreen
extends Node2D
## Miner "Crystalline Defense Array" — a mining laser refracted through a
## crystal lattice into a point-defense screen. Every hostile WARHEAD that
## enters is cut out of the sky; gunfire passes straight through.
##
## It DENIES a damage type where Guardian's Bulwark SOAKS one — and it is the
## only ability in the game that puts an OBJECT IN THE WORLD: placed at the
## cursor and left there, so a Miner can screen an ALLY, or cover a lane they
## are not standing in. (Cursor = where a SYSTEM goes; the mouse still never
## aims a gun.)
##
## Deliberately NOT total immunity: it eats ordnance only. A screen that stopped
## bullets too would be a 7-second invulnerability bubble.

const LATTICE := Color(0.62, 0.92, 0.86)
const FACET := Color(0.85, 1.0, 0.96)

var radius := 128.0
var life := 7.0
var shield_group := "player_team"   # whose incoming fire this screen cuts

var _t := 0.0
var _kills := 0
var _flash := 0.0


func _ready() -> void:
	z_index = 1
	top_level = true   # it STAYS where it was placed; it does not ride the caster


func _process(delta: float) -> void:
	var _t0 := Telemetry.now_us()
	_tick_p(delta)
	Telemetry.phase("p.crystal_screen", _t0)


func _tick_p(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	_flash = maxf(0.0, _flash - delta * 4.0)
	_intercept()
	queue_redraw()


## Cut every hostile warhead inside the lattice. Projectiles carry the group they
## are hunting, so "incoming" is simply anything aimed at our side — a Miner's
## own rockets fly out through their screen untouched.
func _intercept() -> void:
	for node in get_parent().get_children():
		if node is not Projectile:
			continue
		var shot: Projectile = node
		if not shot.ordnance or shot.target_group != shield_group:
			continue
		if global_position.distance_to(shot.global_position) > radius:
			continue
		Projectile.spark(get_parent(), shot.global_position, FACET, 5)
		shot.queue_free()
		_kills += 1
		_flash = 1.0
		Sfx.play_at("shield_hit", shot.global_position, -14.0)


func _draw() -> void:
	var _t0 := Telemetry.now_us()
	_paint_d()
	Telemetry.phase("d.crystal_screen", _t0)


func _paint_d() -> void:
	var a := 1.0 - _t / life
	if _t < 0.25:
		a *= _t / 0.25          # snaps into being rather than popping

	draw_circle(Vector2.ZERO, radius, Color(LATTICE, 0.07 * a))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(LATTICE, 0.55 * a), 2.0)

	# the lattice itself — a slow-turning crystal mesh, brightening on a kill
	var spin := _t * 0.35
	var bright: float = 0.22 + 0.5 * _flash
	for i in 6:
		var ang := spin + float(i) / 6.0 * PI
		var edge := Vector2(cos(ang), sin(ang)) * radius
		draw_line(-edge, edge, Color(LATTICE, bright * a), 1.0)
	for i in 3:
		var r := radius * (0.35 + 0.22 * i)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(FACET, 0.18 * a), 1.0)

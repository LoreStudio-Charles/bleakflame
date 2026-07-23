class_name Station
extends Node2D

## How much room AI ships give this thing (BuildShip.separation_dir):
## the whole module cluster, not just its collision shape.
var avoid_radius := 760.0
## Sprite-composite station: generated modules (core, docking arm, habs)
## assembled with matched colliders and turret emplacements. Forerunner of the
## data-driven module system — for now the assembly is authored here.

var pad: DockingPad


func _ready() -> void:
	add_to_group("structures")
	# Cyclable with the friendly-target key; future co-op wingmen join too.
	add_to_group("friendly_targets")
	# Integer 2x scale: stays on the pixel grid (1.5x would wobble), doubles
	# docking tolerance for free, and lands the footprint (~1200 world units)
	# inside the codified station spec. Ships finally look small at home.
	scale = Vector2(2, 2)

	# Draw order: arm under core (they overlap at the joint), habs, then
	# turrets and the pad on top.
	_add_sprite("res://assets/station/arm.png", Vector2(215, 0))
	_add_sprite("res://assets/station/core.png", Vector2.ZERO)
	_add_sprite("res://assets/station/hab_a.png", Vector2(-70, -165))
	_add_sprite("res://assets/station/hab_b.png", Vector2(-90, 150))

	pad = DockingPad.new()
	pad.position = Vector2(185, 0)   # deep in the channel — dock INSIDE the arm
	# The Reach's one station is SMALL: it berths up to MEDIUM (the Dowager is
	# the local ceiling). Heavies can't dock here — the fiction for why the Reach
	# is all small ships, and the geography gate that puts heavies a system away.
	pad.max_size_band = HullDef.SizeBand.MEDIUM
	add_child(pad)

	_add_collider(Vector2.ZERO, null, 118.0)                 # core
	_add_collider(Vector2(225, -47), Vector2(210, 18))       # arm rail top
	_add_collider(Vector2(225, 47), Vector2(210, 18))        # arm rail bottom
	_add_collider(Vector2(-70, -165), Vector2(116, 104))     # hab A
	_add_collider(Vector2(-90, 150), Vector2(116, 104))      # hab B

	var battery := "res://data/components/weapons/bastion_heavy_battery.tres"
	var pd := "res://data/components/weapons/skeet_pd_array.tres"
	var emplacements := [
		[Vector2(0, -86), battery, StationTurret.TargetMode.HEAVIEST],
		[Vector2(-86, 0), battery, StationTurret.TargetMode.HEAVIEST],
		[Vector2(-70, -165), pd, StationTurret.TargetMode.NEAREST],
		[Vector2(-90, 150), pd, StationTurret.TargetMode.NEAREST],
		[Vector2(300, -50), pd, StationTurret.TargetMode.NEAREST],
	]
	for e in emplacements:
		var turret := StationTurret.create(e[1], e[2])
		turret.position = e[0]
		add_child(turret)


func _add_sprite(path: String, pos: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = load(path)
	sprite.position = pos
	add_child(sprite)


func _add_collider(pos: Vector2, rect_size, circle_radius := 0.0) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	var shape := CollisionShape2D.new()
	if rect_size == null:
		var circle := CircleShape2D.new()
		circle.radius = circle_radius
		shape.shape = circle
	else:
		var rect := RectangleShape2D.new()
		rect.size = rect_size
		shape.shape = rect
	body.add_child(shape)
	add_child(body)

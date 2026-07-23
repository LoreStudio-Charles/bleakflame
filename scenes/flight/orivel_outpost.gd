class_name OrivelOutpost
extends Node2D
## The capital's orbital drydock ring — core + four LANDING BAYS (cardinals, for
## the small hulls a fringe port already takes) + four DRYDOCK BAYS (corners, for
## the capital-scale hulls a bay physically can't hold). The counterpart to Orivel
## the planet, parked in a safe orbit OUTSIDE the ~6240 gravity well.
##
## Scaled like Station (node scale 2, sprites at scale 1) so the DockingPads —
## also children — line up with the baked composite art at source-pixel offsets.
## Bare berths for now (runs_dock_services = false): they repair + checkpoint like
## any dock but run no capital economy yet (see docs/capital_defenses.md + the
## coming capital services). Turret hardpoints come with the weapon-platform pass.

## Wide berth for AI (BuildShip.separation reads this): the whole ring, not the pad.
var avoid_radius := 1500.0

const SCALE := 2.0

## The eight berths, exposed so flight_test can route their dock screen. Built in
## _ready.
var pads: Array[DockingPad] = []

## Source-px offset (pre-scale) + facing for each berth. local +X points OUT of the
## slot (a correct approach flies in along -X), so facing = the OUTWARD direction.
## Bays sit at the arm tips (cardinals); drydocks in the corner pockets (diagonals).
const BAYS := [
	["Landing Bay · East",  Vector2(205, 0),    0.0],
	["Landing Bay · North", Vector2(0, -205),  -PI / 2],
	["Landing Bay · West",  Vector2(-205, 0),   PI],
	["Landing Bay · South", Vector2(0, 205),    PI / 2],
]
const DRYDOCKS := [
	["Drydock · NE", Vector2(140, -140), -PI / 4],
	["Drydock · SE", Vector2(140, 140),   PI / 4],
	["Drydock · SW", Vector2(-140, 140),  3 * PI / 4],
	["Drydock · NW", Vector2(-140, -140), -3 * PI / 4],
]


func _ready() -> void:
	add_to_group("outposts")
	# Cyclable with the friendly-target key, like the fringe station.
	add_to_group("friendly_targets")
	scale = Vector2(SCALE, SCALE)

	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/station/orivel/outpost.png")
	add_child(sprite)

	# Core collider so ships can't fly through the hub (the arms/cradles are open
	# approaches; a wreck's back-wall raycast just overshoots past them for now).
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 96.0
	shape.shape = circle
	body.add_child(shape)
	add_child(body)

	# LANDING BAYS — up to HEAVY (64px and below); the capital takes bigger than the
	# fringe station's MEDIUM cap, but still not the drydock hulls.
	for b in BAYS:
		_add_pad(b[0], b[1], b[2], HullDef.SizeBand.LIGHT, HullDef.SizeBand.HEAVY)
	# DRYDOCKS — SUPER_HEAVY and up ONLY; a bay-sized craft is refused (min floor).
	for d in DRYDOCKS:
		_add_pad(d[0], d[1], d[2], HullDef.SizeBand.SUPER_HEAVY, HullDef.SizeBand.SUPER_HEAVY_PLUS)


func _add_pad(label: String, pos: Vector2, facing: float, min_band: int, max_band: int) -> void:
	var pad := DockingPad.new()
	pad.position = pos
	pad.rotation = facing
	pad.min_size_band = min_band
	pad.max_size_band = max_band
	pad.runs_dock_services = false   # bare berth: repairs + save, no capital economy yet
	pad.berth_label = label
	add_child(pad)
	pads.append(pad)

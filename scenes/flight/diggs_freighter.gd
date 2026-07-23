class_name DiggsFreighter
extends Node2D

## How much room AI ships give this thing (BuildShip.separation_dir):
## a long hull you fly alongside.
var avoid_radius := 330.0
## THE DIG — Doug Diggs' freighter, parked in the Verge.
##
## An old bulk hauler that stopped hauling: engines dead, holds cut open into
## ore hoppers, a berth welded onto her flank. As big as a small station and
## twice as ugly, and she is the only reason to fly out to the Verge.
##
## She exists because THE VERGE HAD NO REASON. It was a charted rock field with
## nothing in it but rocks — the trip out paid the same as the trip anywhere.
## Doug turns it into a destination: an ore buyer who pays a premium BECAUSE you
## hauled it to him, the Prospector Guild's front door, and a third dockable
## silhouette in a system that had two.
##
## Drop-in art (same convention as ships and the den):
##   assets/world/diggs_freighter.png
## Until it lands she renders as a hull of welded modules, so she is a real
## place immediately rather than an invisible dock.
##
## CHARTED, unlike the Shoal — Doug wants customers. She is a radar landmark
## and sits on the chart from the start.

const ART := "res://assets/world/diggs_freighter.png"
const HULL_R := 150.0

var pad: DockingPad


func _ready() -> void:
	add_to_group("structures")
	add_to_group("outposts")
	_build_hull()

	# The berth is a bay cut into her flank, offset like the station's.
	pad = DockingPad.new()
	pad.position = Vector2(0, 96)   # the bay mouth on her flank, clear of the hull
	pad.rotation = PI * 0.5
	# She is a HAULER: her bay swallowed cargo containers for forty years, so
	# nothing in the Reach is too big for it. No size cap.
	add_child(pad)

	# RECTANGLE, not a circle: she is a long hull, and a circle either leaves her
	# bow and stern flyable-through or throws ships off empty space above her.
	var body := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(330.0, 112.0)
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _build_hull() -> void:
	if ResourceLoader.exists(ART):
		var sprite := Sprite2D.new()
		sprite.texture = load(ART)
		# 117x43 art at 3x reads as ~350 long — a hull you fly ALONGSIDE rather
		# than past, which is the point of her being station-sized.
		sprite.scale = Vector2(3.0, 3.0)
		add_child(sprite)
		return
	_build_placeholder()


## Welded-together modules in rust and hazard orange — reads as a working hull
## that was never meant to sit still, at a glance, with no art at all.
func _build_placeholder() -> void:
	var rust := Color(0.42, 0.30, 0.22)
	var plate := Color(0.34, 0.35, 0.40)
	var hazard := Color(0.78, 0.48, 0.18)
	# Spine.
	_slab(Vector2(0, 0), Vector2(300, 84), plate)
	# Holds cut open into hoppers.
	for i in 3:
		var x := -96.0 + float(i) * 96.0
		_slab(Vector2(x, -66), Vector2(74, 52), rust)
		_slab(Vector2(x, 66), Vector2(74, 52), rust)
	# Dead engine block astern.
	_slab(Vector2(-176, 0), Vector2(60, 100), plate.darkened(0.25))
	# The berth's lit mouth, so the dockable side is obvious.
	_slab(Vector2(0, 132), Vector2(120, 26), hazard)


func _slab(at: Vector2, size: Vector2, col: Color) -> void:
	var r := ColorRect.new()
	r.color = col
	r.size = size
	r.position = at - size * 0.5
	add_child(r)

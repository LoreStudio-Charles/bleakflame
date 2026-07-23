class_name WayGate
extends Node2D
## The ancient ring at the system's rim — dead metal older than the colony,
## the door the Cinderweb came through. Appears only when the finale charts
## it (Krayt's last transmission). Flying into its throat leaves the Cinder
## Reach: the demo's exit. Drawn, not sprited — a slow cold-blue aperture.

const R := 150.0

var _t := 0.0
var _ring: Line2D
var _throat: Polygon2D


static func create(pos: Vector2) -> WayGate:
	var g := WayGate.new()
	g.position = pos
	return g


func _ready() -> void:
	add_to_group("waygate")
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_throat = Polygon2D.new()
	_throat.polygon = _disc(R * 0.82, 40)
	_throat.color = Color(0.18, 0.34, 0.6, 0.4)
	_throat.material = add
	add_child(_throat)
	_ring = Line2D.new()
	_ring.points = _disc(R, 48)
	_ring.closed = true
	_ring.width = 5.0
	_ring.default_color = Color(0.5, 0.75, 1.0, 0.9)
	_ring.material = add
	add_child(_ring)
	# A second, counter-rotating inner ring — old machinery still turning.
	var inner := Line2D.new()
	inner.points = _disc(R * 0.6, 36)
	inner.closed = true
	inner.width = 2.5
	inner.default_color = Color(0.4, 0.6, 0.95, 0.7)
	inner.material = add
	inner.name = "inner"
	add_child(inner)


func _process(delta: float) -> void:
	_t += delta
	_ring.rotation = _t * 0.15
	$inner.rotation = -_t * 0.28
	_throat.scale = Vector2.ONE * (0.94 + 0.06 * sin(_t * 1.3))
	_throat.color.a = 0.3 + 0.15 * sin(_t * 0.9)


func _disc(radius: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * float(i) / segments
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts

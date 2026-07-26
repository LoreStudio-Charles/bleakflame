class_name NavBeacon
extends Node2D
## A LANE MARKER — the thing that makes a trade lane a road instead of a line of
## maths (user, 2026-07-26).
##
## THE PROBLEM IT SOLVES. The Long Lane is ~91,000 units long and a stock sensor
## reaches 1,500, so the corridor a pilot must hold to meet traffic is about SEVEN
## DEGREES wide at the near end and under two at the far end. Flying out and
## meeting nothing was not bad luck; it was the only likely outcome. There was
## nothing in the world to aim at.
##
## Beacons fix that by being CHARTED POIs: `Radar` rim-clamps charted landmarks, so
## a beacon shows as a bearing marker from any distance. "Hold a heading across
## 13km and hope" becomes "fly at the marker".
##
## They also make the lane's THREE BANDS legible, which the spec claimed would
## happen by flying and could not, because nothing marked the boundaries. A pilot
## passes the patrol limit, watches the escorts stop following, and then meets
## nothing at all for a very long way. The Gap becomes something experienced
## rather than something a document asserts.
##
## Drop-in art seam like the anomaly and the WayGate: `assets/world/nav_beacon.png`
## renders under the procedural glow if present; otherwise it is pure procedural
## and looks fine.

const R := 46.0                  # body radius
const PULSE_R := 300.0           # the ring that makes it findable at a glance
const PULSE_PERIOD := 2.6

@export var label_text := ""
## Colour by role: lane markers are pale gold, authority limits take the colour of
## whoever's writ ends there.
@export var tint := Color(0.95, 0.82, 0.45)

var _t := 0.0
var _sprite: Sprite2D = null


func setup(display_name: String, colour: Color) -> void:
	label_text = display_name
	tint = colour


func _ready() -> void:
	z_index = -1                 # a landmark sits behind traffic, never over it
	var art := "res://assets/world/nav_beacon.png"
	if ResourceLoader.exists(art):
		_sprite = Sprite2D.new()
		_sprite.texture = load(art)
		_sprite.self_modulate = tint
		add_child(_sprite)
	var tag := Label.new()
	tag.text = label_text
	tag.add_theme_font_size_override("font_size", 13)
	tag.add_theme_color_override("font_color", tint)
	tag.position = Vector2(-90.0, R + 14.0)
	tag.size = Vector2(180.0, 18.0)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(tag)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var phase := fmod(_t, PULSE_PERIOD) / PULSE_PERIOD
	# The mast: a simple lit spar. Deliberately plain — a beacon is infrastructure,
	# not a set piece, and it must read instantly at any zoom.
	draw_line(Vector2(0.0, -R), Vector2(0.0, R), Color(tint, 0.75), 3.0)
	draw_line(Vector2(-R * 0.5, 0.0), Vector2(R * 0.5, 0.0), Color(tint, 0.55), 2.0)
	draw_circle(Vector2.ZERO, R * 0.30, Color(tint, 0.9))
	draw_arc(Vector2.ZERO, R, 0.0, TAU, 28, Color(tint, 0.5), 2.0)
	# One expanding pulse. Big enough to catch the eye off-centre, faint enough not
	# to clutter — this is the part that says "something is here" at a distance.
	var rr := lerpf(R, PULSE_R, phase)
	draw_arc(Vector2.ZERO, rr, 0.0, TAU, 40, Color(tint, 0.35 * (1.0 - phase)), 2.0)


## Places a beacon and charts it, so it is a permanent radar landmark AND a
## waypoint a pilot can tag from the [G] chart.
static func place(parent: Node, pos: Vector2, id: String, display_name: String,
		colour := Color(0.95, 0.82, 0.45)) -> NavBeacon:
	var b := NavBeacon.new()
	b.setup(display_name, colour)
	parent.add_child(b)
	b.global_position = pos
	PoiMap.register(id, display_name, pos, "beacon", true)
	return b

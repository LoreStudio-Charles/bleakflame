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
## The art spans a little wider than the body, so the mast it replaces sits inside
## it. Scaled BY TEXTURE WIDTH (same as the anomaly and the gate) so the drop-in
## can be re-authored at any canvas size without touching code.
const ART_SPAN := R * 2.2

# --- THE PING (user, 2026-07-26) ---
# A radar sweep: one ray rotating forever, dragging a fading wake behind it and
# dimming out toward the rim. Drawn as a fan of thin triangles with PER-VERTEX
# ALPHA, which buys both fades at once — the shared centre vertex carries the
# wake (each step behind the head is dimmer) and the two rim vertices sit at
# alpha 0, which is the fade over distance.
const SWEEP_PERIOD := 3.4        # seconds per revolution — slow, patient, unhurried
const SWEEP_TRAIL := 0.85        # radians of visible wake behind the leading edge
const SWEEP_STEPS := 18          # triangles in the wake; more = smoother gradient
const SWEEP_ALPHA := 0.40        # brightness at the leading edge
const RINGS := 2                 # expanding rings, staggered so one is always mid-flight

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

	# ADDITIVE, so the ping reads as emitted light against the black instead of a
	# grey film laid over it. This applies to THIS node's _draw only — a CanvasItem
	# does not hand its material down unless a child asks for it — so the sprite and
	# the label keep normal blending and the art is not washed out.
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat

	var art := "res://assets/world/nav_beacon.png"
	if ResourceLoader.exists(art):
		_sprite = Sprite2D.new()
		_sprite.texture = load(art)
		# self_modulate, NOT modulate: modulate cascades to children, and the label
		# is a child. That is the same trap that rendered the V-Shrike hourglass black.
		_sprite.self_modulate = tint
		var tw: float = maxf(1.0, float(_sprite.texture.get_width()))
		_sprite.scale = Vector2.ONE * (ART_SPAN / tw)
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
	# THE BODY RETIRES WHEN THE ART LANDS (the WayGate rule: the drawing carries the
	# object, the procedural layer keeps only the fx). Drawing the mast over the
	# sprite would put a lit spar straight through the middle of it.
	if _sprite == null:
		# The mast: a simple lit spar. Deliberately plain — a beacon is
		# infrastructure, not a set piece, and it must read instantly at any zoom.
		draw_line(Vector2(0.0, -R), Vector2(0.0, R), Color(tint, 0.75), 3.0)
		draw_line(Vector2(-R * 0.5, 0.0), Vector2(R * 0.5, 0.0), Color(tint, 0.55), 2.0)
		draw_circle(Vector2.ZERO, R * 0.30, Color(tint, 0.9))
		draw_arc(Vector2.ZERO, R, 0.0, TAU, 28, Color(tint, 0.5), 2.0)
	_draw_sweep()

	# Expanding rings — kept in BOTH paths. This is not decoration: it is the part
	# that says "something is here" from off-centre, and the whole reason the beacon
	# exists is to be seen from a long way off. Staggered so one is always in flight;
	# a single ring spends most of its cycle invisible and the beacon looks dead.
	for i in RINGS:
		var p := fmod(phase + float(i) / float(RINGS), 1.0)
		var rr := lerpf(R, PULSE_R, p)
		draw_arc(Vector2.ZERO, rr, 0.0, TAU, 40, Color(tint, 0.30 * (1.0 - p)), 2.0)


## The sweeping ray. One fan of triangles, rebuilt each frame — cheap enough at
## this count that a particle system would be more machinery for less control.
##
## WHY NOT GPUParticles2D: particles need a TEXTURE, which is the exact thing there
## was no obvious pixel art for. Drawn geometry needs none, stays crisp at every
## zoom (the camera ranges enormously here), and fades over distance exactly rather
## than approximately. It also matches how the anomaly and the WayGate already layer
## procedural light over drop-in art.
func _draw_sweep() -> void:
	var head := fmod(_t / SWEEP_PERIOD, 1.0) * TAU
	var step := SWEEP_TRAIL / float(SWEEP_STEPS)
	for i in SWEEP_STEPS:
		# 0 at the leading edge, 1 at the tail. Squared so the wake falls off fast
		# and the head stays the thing your eye catches.
		var back := float(i) / float(SWEEP_STEPS)
		var a := SWEEP_ALPHA * (1.0 - back) * (1.0 - back)
		if a <= 0.004:
			continue
		var a0 := head - float(i) * step
		var a1 := a0 - step
		var pts := PackedVector2Array([
			Vector2.ZERO,
			Vector2(cos(a0), sin(a0)) * PULSE_R,
			Vector2(cos(a1), sin(a1)) * PULSE_R,
		])
		# Bright at the mast, nothing at the rim: the fade over distance.
		var cols := PackedColorArray([
			Color(tint, a), Color(tint, 0.0), Color(tint, 0.0),
		])
		draw_polygon(pts, cols)


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

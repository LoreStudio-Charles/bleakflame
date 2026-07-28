class_name Lightning
extends Node2D
## Reusable branching lightning between an ORIGIN and an ENDPOINT (user, 2026-07-24).
## A fractal midpoint-displacement main bolt + random forks, drawn as additive Line2D
## glow (crisp segments, no texture — "pixel-art-guided procedural"). One implementation,
## three ways to use it:
##   ONE-SHOT   Lightning.flash(parent, from, to, opts)  — spawns, holds a beat, fades+frees.
##              (WayGate ring discharge, a hit spark, a chain-lightning hop.)
##   SUSTAINED  var b = Lightning.beam(parent, from, to, opts); then set b.from_point /
##              b.to_point each frame — it RE-ROLLS the jitter on a flicker timer, so a
##              lightning WEAPON just re-points it muzzle->target every physics tick.
##   CHAIN      Lightning.chain(parent, [p0, p1, p2, ...], opts)  — one link per hop.
##
## The path math (fractal_path) is a PURE STATIC func so it's testable with a seeded RNG
## and callable without a node. tools/test_lightning.gd covers it.

@export var from_point := Vector2.ZERO
@export var to_point := Vector2.ZERO
@export var color := Color(1.0, 0.92, 0.62)     # gold-white Warden discharge
@export var core_width := 2.2
@export var glow_width := 6.5
@export var glow_alpha := 0.30
@export var chaos := 0.22        # first-pass perpendicular jitter, as a fraction of the span
@export var generations := 5     # fractal subdivisions -> 2^generations segments
@export var branch_chance := 0.30  # per interior node, chance to throw a fork
@export var branch_scale := 0.55   # fork reach vs. that node's distance to the endpoint
@export var flicker_hz := 32.0     # re-roll rate for a sustained bolt (0 = draw once, static)
@export var texture: Texture2D = null   # optional pixel-art arc strip (tiles on X) laid along
	# the core so the bolt reads as pixel art. See random_arc() for the drop-in cycle.
@export var cycle_texture := false      # swap in a fresh arc strip on each re-roll -> the bolt
	# ANIMATES (arc-1 -> arc-2 -> ... as frames). Pair with flicker_hz for a crackling strike.

var rng := RandomNumberGenerator.new()

# Drop-in arc strips: assets/fx/lightning-arc-1.png .. lightning-arc-8.png. Add files named
# that way and they auto-join the cycle — no code change. Scanned once, then cached.
static var _arcs: Array = []
static var _arcs_scanned := false

var _core: Line2D
var _glow: Line2D
var _branch_root: Node2D
var _add: CanvasItemMaterial
var _flicker_t := 0.0
var _built := false


func _ready() -> void:
	if rng.seed == 0:
		rng.randomize()   # each bolt differs unless a caller/test seeded it first
	_add = CanvasItemMaterial.new()
	_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow = _new_line(glow_width, Color(color.r, color.g, color.b, glow_alpha), false)
	_core = _new_line(core_width, color, true)
	_branch_root = Node2D.new()
	add_child(_branch_root)
	_built = true
	regenerate()


func _process(delta: float) -> void:
	if flicker_hz <= 0.0:
		return
	_flicker_t -= delta
	if _flicker_t <= 0.0:
		_flicker_t = 1.0 / flicker_hz
		regenerate()


## Re-roll the whole bolt (main path + forks) between the current from_point/to_point.
## Call once for a static bolt; the flicker timer calls it for a live beam.
func regenerate() -> void:
	if not _built:
		return
	if cycle_texture:                  # animate: swap in a fresh arc strip on each re-roll
		var nt := random_arc(rng)
		if nt != null:
			texture = nt
			_core.texture = nt
	var pts := fractal_path(from_point, to_point, generations, chaos, rng)
	_core.points = pts
	_glow.points = pts
	for c in _branch_root.get_children():
		c.free()
	_spawn_branches(pts)


func _spawn_branches(main: PackedVector2Array) -> void:
	# Fork off interior nodes toward the endpoint, splayed out and tapering to nothing.
	for i in range(2, main.size() - 1, 2):
		if rng.randf() > branch_chance:
			continue
		var node: Vector2 = main[i]
		var toward := to_point - node
		if toward.length() < 6.0:
			continue
		var dir := toward.normalized().rotated(rng.randf_range(-1.1, 1.1))
		var tip := node + dir * toward.length() * branch_scale * rng.randf_range(0.5, 1.0)
		var bpts := fractal_path(node, tip, maxi(1, generations - 2), chaos * 1.3, rng)
		_branch_root.add_child(_new_branch(bpts))


func _new_line(w: float, c: Color, textured: bool) -> Line2D:
	var l := Line2D.new()
	l.width = w
	l.default_color = c
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.material = _add
	if textured and texture != null:
		l.texture = texture
		l.texture_mode = Line2D.LINE_TEXTURE_TILE   # the strip tiles along the jagged path
	add_child(l)
	return l


func _new_branch(pts: PackedVector2Array) -> Line2D:
	var l := Line2D.new()
	l.points = pts
	l.width = core_width * 0.6
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	l.material = _add
	var grad := Gradient.new()   # bright at the fork, gone at the tip
	grad.set_color(0, Color(color.r, color.g, color.b, 0.8))
	grad.set_color(1, Color(color.r, color.g, color.b, 0.0))
	l.gradient = grad
	return l


## PURE: the jagged path from `a` to `b` via fractal midpoint displacement. path[0] is
## always exactly `a` and path[-1] exactly `b` (endpoints are anchored, so a beam always
## connects); interior points stay within the segment's shrinking displacement envelope.
## `gens` subdivisions yield 2^gens segments. Seed `rng` for a deterministic bolt.
static func fractal_path(a: Vector2, b: Vector2, gens: int, chaos_frac: float,
		gen: RandomNumberGenerator) -> PackedVector2Array:
	var pts := PackedVector2Array([a, b])
	var offset := a.distance_to(b) * chaos_frac
	for _g in gens:
		var next := PackedVector2Array()
		for i in pts.size() - 1:
			var p0: Vector2 = pts[i]
			var p1: Vector2 = pts[i + 1]
			var mid := (p0 + p1) * 0.5
			mid += (p1 - p0).orthogonal().normalized() * gen.randf_range(-offset, offset)
			next.append(p0)
			next.append(mid)
		next.append(pts[pts.size() - 1])
		pts = next
		offset *= 0.5   # halve the displacement each pass -> self-similar detail
	return pts


# --- convenience constructors --------------------------------------------------------

## Spawn a bolt that holds `life` seconds then fades and frees itself. Static by default
## (one rolled path); pass {"flicker_hz": 40} to make even the brief flash writhe.
static func flash(parent: Node, from: Vector2, to: Vector2, opts := {}) -> Node2D:
	var lb := _make(from, to, opts)
	if not opts.has("flicker_hz"):
		lb.flicker_hz = 0.0
	parent.add_child(lb)
	lb._flash_out(float(opts.get("life", 0.22)))
	return lb


## Spawn a PERSISTENT bolt. Caller owns it: update from_point/to_point each frame and it
## re-rolls on flicker_hz; free it when the weapon stops firing.
static func beam(parent: Node, from: Vector2, to: Vector2, opts := {}) -> Node2D:
	var lb := _make(from, to, opts)
	parent.add_child(lb)
	return lb


## Chain lightning: a one-shot link per hop through the point list (origin -> t1 -> t2 ...).
static func chain(parent: Node, points: Array, opts := {}) -> Array:
	var links: Array = []
	for i in points.size() - 1:
		links.append(flash(parent, points[i], points[i + 1], opts))
	return links


## The drop-in arc strips present on disk (assets/fx/lightning-arc-1..8.png), cached.
static func arc_textures() -> Array:
	if not _arcs_scanned:
		_arcs_scanned = true
		for i in range(1, 9):
			var p := "res://assets/fx/lightning-arc-%d.png" % i
			if ResourceLoader.exists(p):
				_arcs.append(load(p))
	return _arcs


## One arc strip for a bolt, cycling the pool, or null if none exist (bolt falls back to
## the solid glow line). Pass an rng for a seeded pick.
static func random_arc(gen: RandomNumberGenerator = null) -> Texture2D:
	var arcs := arc_textures()
	if arcs.is_empty():
		return null
	var i := (gen.randi() if gen != null else randi()) % arcs.size()
	return arcs[i]


static func _make(from: Vector2, to: Vector2, opts: Dictionary) -> Node2D:
	# load() self instead of Lightning.new() so this file has NO reference to its own
	# class_name — it then compiles even in a bare --script load (where the name isn't
	# registered). Returns the same Lightning node; callers treat it duck-typed.
	var lb = load("res://scenes/flight/lightning.gd").new()
	lb.from_point = from
	lb.to_point = to
	for k in ["color", "core_width", "glow_width", "glow_alpha", "chaos", "generations",
			"branch_chance", "branch_scale", "flicker_hz", "texture", "cycle_texture"]:
		if opts.has(k):
			lb.set(k, opts[k])
	return lb


func _flash_out(dur: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(queue_free)

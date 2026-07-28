extends Node2D
## Infinite scrolling starfield: an AUTHORED far layer with procedural point stars
## parallaxing over it. Both are hashed from world-cell coordinates, so the field is
## stable and endless with no bounds — fly out and back and the sky is where you left it.
##
## BUILT UP ADDITIVELY OVER BLACK (user, 2026-07-28). Space is emissive: stars and dust
## are light ADDED to a void, not surfaces that occlude each other. So the tiles ship with
## an opaque black background and the node blends additive — black contributes nothing,
## layers stack in any order, and there is no alpha channel to get wrong. It also means a
## tile can be dropped in without any transparency surgery.

## ---- THE FAR LAYER: authored nebula tiles, drop-in ----
##
## Any `assets/world/starfield_*.png` is picked up automatically and joins the rotation —
## add art, get sky, no code. With none present the field is purely procedural, exactly as
## it was before.
const TILE_DIR := "res://assets/world"
const TILE_PREFIX := "starfield_"

## TWO KINDS OF TILE, SORTED BY THEIR OWN ALPHA (2026-07-28). The first tile authored was
## an opaque nebula; the next two came back 97.8% TRANSPARENT — sparse stars and little
## galaxies meant to sit OVER something. Those are not interchangeable, and drawing them
## from one pool would have put a rich nebula in one cell and near-nothing in the two
## beside it: obvious square patches, which is worse than plain tiling.
##
## So a BACKDROP covers (mostly opaque) and an OVERLAY decorates (mostly clear), each on
## its own layer at its own parallax — which is the "build up with additive layers over
## black" the art was made for.
##
## CLASSIFIED BY MEASURING THE ART, not by a naming rule. Drop a tile in and it lands on
## the right layer because of what it IS; nobody has to remember a suffix, and a tile
## cannot end up on the wrong layer by being misnamed.
const BACKDROP_COVERAGE := 0.5

## INTEGER SCALES, because this is pixel art: a fractional scale resamples across the
## pixel grid and turns crisp stars to mush. Scale is also the repetition control — a
## 256 px tile at 1:1 puts about THIRTY-TWO copies on a 1920x1080 screen, which reads as
## wallpaper however good the art is.
##
## The backdrop goes big (~2 copies on screen) because a nebula's silhouette is what
## gives repetition away. Overlays stay smaller: they are sparse enough that a repeat is
## hard to catch, and more cells means more of the eight orientations in view at once.
const BACKDROP_SCALE := 4
const OVERLAY_SCALE := 2

## The backdrop is the slowest thing in the sky and the overlay drifts a little faster,
## with the procedural point stars faster still. That laddering is most of what sells
## depth at speed, and it is the reason to keep dust and stars on separate tiles rather
## than baking them into one.
const BACKDROP_PARALLAX := 0.06
const OVERLAY_PARALLAX := 0.11

## HOW MUCH EACH LAYER CONTRIBUTES. Additive means these ACCUMULATE rather than replace,
## so at full strength the layers fought: roughly half the nebula tile is dark blue haze,
## every visible copy lifted the black level of space, and where a bright star landed on a
## bright nebula the sum clipped to white (0.74% of the screen, measured).
##
## Starting low and building up is the right way round for an additive stack — you are
## composing light, so it is far easier to add another layer than to unpick an
## over-bright one. Started at 0.3, settled at 0.5 on sight (user, 2026-07-28): the dust
## reads as structure again without the stack clipping anywhere.
##
## Dialled HERE, never by re-authoring the art: the tiles stay full-strength on disk so
## the balance is a live decision and not a destructive one.
const BACKDROP_ALPHA := 0.5
const OVERLAY_ALPHA := 0.5

## The procedural point stars are a layer too, and get the same knob so the whole sky is
## balanced from one place rather than half here and half in the LAYERS table.
const STAR_ALPHA := 0.5

static var _backdrops: Array[Texture2D] = []
static var _overlays: Array[Texture2D] = []
static var _tiles_scanned := false

const LAYERS := [
	{"parallax": 0.15, "cell": 140.0, "per_cell": 3, "size": 1.0, "brightness": 0.45},
	{"parallax": 0.35, "cell": 180.0, "per_cell": 2, "size": 1.6, "brightness": 0.7},
	{"parallax": 0.65, "cell": 260.0, "per_cell": 1, "size": 2.2, "brightness": 1.0},
]

## A CELL'S STARS NEVER CHANGE. They are hashed from the cell's own coordinates, which is
## what makes the field endless and stable — and it also means the whole computation was a
## constant being recomputed every frame. At 1080p that is ~285 cells and ~650 stars per
## frame, each cell allocating its own RandomNumberGenerator: on the order of seventeen
## thousand object allocations a second to arrive at the same answer as last frame.
##
## Allocation churn at that rate is not just slow, it is LUMPY — which matters more here
## than the average, because a stutter is what a player actually feels.
##
## Cached by (layer, cell), so a cell is generated once for the life of the run.
const CACHE_CAP := 8192

static var _cells := {}

@onready var camera: Camera2D = get_viewport().get_camera_2d()


func _ready() -> void:
	# ADDITIVE, so the tiles' black background costs nothing and every layer only ever
	# adds light. NEAREST, because everything here is pixel art and the default bilinear
	# filter would smear a one-pixel star across four.
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_scan_tiles()


## Drop-in: every starfield_*.png in assets/world joins the rotation. Scanned once per
## run and shared, since the set cannot change while the game is up.
static func _scan_tiles() -> void:
	if _tiles_scanned:
		return
	_tiles_scanned = true
	var dir := DirAccess.open(TILE_DIR)
	if dir == null:
		return
	var names: Array[String] = []
	for f in dir.get_files():
		# Godot hands an exported build ".png.import"; strip it so both cases resolve.
		var clean := f.trim_suffix(".import")
		if clean.begins_with(TILE_PREFIX) and clean.ends_with(".png"):
			if not names.has(clean):
				names.append(clean)
	names.sort()   # stable order, so a cell picks the same tile every run
	for n in names:
		var tex := load("%s/%s" % [TILE_DIR, n]) as Texture2D
		if tex == null:
			continue
		if _coverage(tex) >= BACKDROP_COVERAGE:
			_backdrops.append(tex)
		else:
			_overlays.append(tex)


## How much of a tile is actually painted. A tile with no alpha channel at all is opaque
## by definition — starfield_1 ships an opaque black background on purpose, since black
## adds nothing under additive blending — so it counts as full coverage.
##
## Sampled on a stride: this runs once per tile at load and the answer only has to be
## right to about a percent, not exact.
static func _coverage(tex: Texture2D) -> float:
	var img := tex.get_image()
	if img == null:
		return 1.0
	if not img.detect_alpha():
		return 1.0
	var w := img.get_width()
	var h := img.get_height()
	if w <= 0 or h <= 0:
		return 1.0
	var step := maxi(1, int(round(float(maxi(w, h)) / 64.0)))
	var painted := 0
	var total := 0
	for y in range(0, h, step):
		for x in range(0, w, step):
			total += 1
			if img.get_pixel(x, y).a > 0.02:
				painted += 1
	return float(painted) / float(maxi(1, total))


## THE FAR LAYER, CELL-BOMBED. Stamped on an exact grid rather than at random offsets:
## the tile is seamless, so offsets buy nothing and would open gaps in a layer that has
## to cover the screen. What needs breaking up is the SHAPE — a nebula is recognisable in
## a way an anonymous dot is not — so each cell hashes its own tile, quarter-turn and
## mirror, giving eight orientations per tile before any new art is drawn.
##
## Rotating a neighbour breaks continuity across that edge, which is normally the cost of
## this trick. It is cheap HERE specifically because the tile's edges are its quietest
## part: measured, the wrap delta is 0.74x (columns) and 0.37x (rows) of a typical
## interior neighbour delta. There is very little there to mismatch.
func _paint_tiles(set: Array[Texture2D], scale_i: int, parallax: float, alpha: float,
		salt: int, cam_pos: Vector2, view_size: Vector2) -> void:
	if set.is_empty():
		return
	var tex_size := Vector2(set[0].get_size())
	var span := tex_size.x * float(scale_i)
	if span <= 0.0:
		return
	var origin := cam_pos * parallax
	var first := Vector2i(((origin - view_size * 0.5) / span).floor())
	var nx := int(view_size.x / span) + 2
	var ny := int(view_size.y / span) + 2
	var to_world := cam_pos - origin
	var tint := Color(1, 1, 1, alpha)
	for cy in range(first.y, first.y + ny):
		for cx in range(first.x, first.x + nx):
			# SALTED PER LAYER, so the backdrop and the overlay do not turn the same way
			# in the same place. Without it both layers hash the same cell to the same
			# quarter-turn, and their features line up into a visible grid — the one
			# thing this whole scheme exists to avoid.
			var h: int = absi(hash(Vector2i(cx, cy)) ^ salt)
			var tex: Texture2D = set[h % set.size()]
			var quarter: int = (h >> 5) & 3
			var mirror := 1.0 if ((h >> 7) & 1) == 0 else -1.0
			var centre := Vector2(cx + 0.5, cy + 0.5) * span + to_world
			draw_set_transform(centre, float(quarter) * PI * 0.5,
				Vector2(mirror, 1.0) * float(scale_i))
			draw_texture(tex, -tex_size * 0.5, tint)
	# Hand the canvas back unrotated, or everything drawn after this inherits the last
	# cell's quarter-turn and mirror.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The stars of one cell in LAYER SPACE, with their colour already resolved.
static func cell_stars(layer_i: int, cx: int, cy: int, cell: float, parallax: float,
		per_cell: int, brightness: float) -> Array:
	var key := Vector3i(layer_i, cx, cy)
	var got = _cells.get(key)
	if got != null:
		return got
	# Flying far enough to fill this is rare, and regenerating is cheap — a bounded
	# dictionary is worth more than a perfect one that grows for the whole session.
	if _cells.size() > CACHE_CAP:
		_cells.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(cx, cy)) + hash(parallax)
	var out: Array = []
	for _i in per_cell:
		var p := Vector2((cx + rng.randf()) * cell, (cy + rng.randf()) * cell)
		var b := brightness * rng.randf_range(0.5, 1.0)
		out.append([p, Color(b, b, minf(1.0, b * 1.15))])
	_cells[key] = out
	return out


func _process(_delta: float) -> void:
	var _t0 := Telemetry.now_us()
	_tick_p(_delta)
	Telemetry.phase("p.starfield", _t0)


func _tick_p(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var _t0 := Telemetry.now_us()
	_paint_d()
	Telemetry.phase("d.starfield", _t0)


func _paint_d() -> void:
	if camera == null:
		camera = get_viewport().get_camera_2d()
		if camera == null:
			return
	var view_size := get_viewport_rect().size
	var cam_pos := camera.get_screen_center_position()

	# Furthest first: additive blending makes the order irrelevant to the result, but it
	# keeps the code reading the way the sky is built — dust behind, stars in front.
	_paint_tiles(_backdrops, BACKDROP_SCALE, BACKDROP_PARALLAX, BACKDROP_ALPHA,
		0, cam_pos, view_size)
	_paint_tiles(_overlays, OVERLAY_SCALE, OVERLAY_PARALLAX, OVERLAY_ALPHA,
		0x5bf03, cam_pos, view_size)

	for layer_i in LAYERS.size():
		var layer: Dictionary = LAYERS[layer_i]
		var parallax: float = layer["parallax"]
		var cell: float = layer["cell"]
		# The layer scrolls slower than the world; convert the visible rect
		# into layer-space and stamp stars from hashed cells.
		var layer_origin := cam_pos * parallax
		var top_left := layer_origin - view_size * 0.5
		var first_cell := Vector2i((top_left / cell).floor())
		var cells_x := int(view_size.x / cell) + 2
		var cells_y := int(view_size.y / cell) + 2

		# Both conversions back to world space are the SAME constant offset for every
		# star in the layer, so it is computed once here rather than twice per star:
		# screen = layer_pos - layer_origin + view/2, world = cam - view/2 + screen,
		# which collapses to layer_pos + (cam - layer_origin).
		var to_world := cam_pos - layer_origin
		var size: float = layer["size"]
		var per_cell: int = layer["per_cell"]
		var brightness: float = layer["brightness"]
		# SQUARE STARS, NOT CIRCLES. draw_circle tessellates a polygon per call, and at
		# ~650 stars a frame that measured 3.02 ms in the seat -- 17.4% of the frame, to
		# round off a dot one to two pixels across. A rect is two triangles. At this size
		# the shapes are indistinguishable, and square points are if anything the more
		# honest choice in a game drawn from pixel art.
		#
		# If they ever need to be round again, this is the one line to change back --
		# but reach for a batched primitive rather than draw_circle.
		# EQUAL AREA, not equal bounding box. `size` was a RADIUS, so a square of side 2r
		# covers 4r^2 against the disc's 3.14r^2 and reads a quarter bolder -- a visible
		# change dressed up as an optimisation. sqrt(PI) * r keeps the weight identical.
		var side := size * 1.7725
		var half := Vector2(side, side) * 0.5
		var box := Vector2(side, side)
		for cy in range(first_cell.y, first_cell.y + cells_y):
			for cx in range(first_cell.x, first_cell.x + cells_x):
				for star in cell_stars(layer_i, cx, cy, cell, parallax, per_cell,
						brightness):
					# Alpha applied at DRAW, not baked into the cached colour — the cache
					# holds what the star IS, this holds how loud the layer is, and only
					# the second one is meant to be tuned.
					var c: Color = star[1]
					c.a = STAR_ALPHA
					draw_rect(Rect2(star[0] + to_world - half, box), c)

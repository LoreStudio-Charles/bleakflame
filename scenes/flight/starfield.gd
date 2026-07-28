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

## INTEGER, because this is pixel art: a fractional scale resamples across the pixel grid
## and the crisp stars turn to mush. It is also the answer to repetition — a 256 px tile
## at 1:1 shows about THIRTY-TWO copies at once on a 1920x1080 screen, which reads as
## wallpaper however good the art is. At 4x it is nearer two.
const TILE_SCALE := 4

## The slowest thing in the sky. Distant dust should barely move while the near stars
## stream past; that differential is most of what sells depth at speed.
const TILE_PARALLAX := 0.06

## Dialled here rather than by re-authoring the tile. Roughly half of the art is a very
## dark blue haze, and under additive every visible copy lifts the black level of space —
## fine for one layer, compounding once more are stacked over it.
const TILE_ALPHA := 1.0

static var _tiles: Array[Texture2D] = []
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
		if tex != null:
			_tiles.append(tex)


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
func _paint_tiles(cam_pos: Vector2, view_size: Vector2) -> void:
	if _tiles.is_empty():
		return
	var tex_size := Vector2(_tiles[0].get_size())
	var span := tex_size.x * float(TILE_SCALE)
	if span <= 0.0:
		return
	var origin := cam_pos * TILE_PARALLAX
	var first := Vector2i(((origin - view_size * 0.5) / span).floor())
	var nx := int(view_size.x / span) + 2
	var ny := int(view_size.y / span) + 2
	var to_world := cam_pos - origin
	var tint := Color(1, 1, 1, TILE_ALPHA)
	for cy in range(first.y, first.y + ny):
		for cx in range(first.x, first.x + nx):
			var h: int = absi(hash(Vector2i(cx, cy)))
			var tex: Texture2D = _tiles[h % _tiles.size()]
			var quarter: int = (h >> 5) & 3
			var mirror := 1.0 if ((h >> 7) & 1) == 0 else -1.0
			var centre := Vector2(cx + 0.5, cy + 0.5) * span + to_world
			draw_set_transform(centre, float(quarter) * PI * 0.5,
				Vector2(mirror, 1.0) * float(TILE_SCALE))
			draw_texture(tex, -tex_size * 0.5, tint)
	# Hand the canvas back unrotated, or every point star after this inherits the last
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
	_paint_tiles(cam_pos, view_size)

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
					draw_rect(Rect2(star[0] + to_world - half, box), star[1])

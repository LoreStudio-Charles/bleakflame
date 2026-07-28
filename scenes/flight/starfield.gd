extends Node2D
## Infinite scrolling starfield with parallax layers, generated procedurally —
## stars are hashed from world-cell coordinates so the field is stable and
## endless with no textures or bounds.

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

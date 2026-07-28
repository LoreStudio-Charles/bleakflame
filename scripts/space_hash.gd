class_name SpaceHash
## WHAT IS NEAR WHAT, without asking everything about everything.
##
## Built because measurement said the only lever left was ITERATION COUNT (user,
## 2026-07-28: "we need to find a way to scale. 30 ships taking 10% of a frame is
## untenable"). separation_dir compares every ship against every other ship, and
## avoid_obstacles_dir compares every ship against every asteroid — 900 and 1440 pairs
## respectively at thirty ships, EVERY PHYSICS FRAME.
##
## THE THINGS THAT DID NOT HELP, measured and kept here so nobody re-tries them:
## removing the square root from the inner test, and caching the per-frame group arrays
## so `get_nodes_in_group` stopped allocating. Together: 1.563 ms -> 1.599 ms, i.e.
## nothing. At roughly 0.7 microseconds per pair the cost is GDScript's per-iteration
## overhead, not the work inside the iteration, so the body cannot be optimised — only
## the number of times it runs.
##
## SO: bucket by cell once a frame, and let a query look only at the cells its radius
## actually covers. A ship on the Long Lane has a handful of neighbours within 400 units
## and several dozen ships elsewhere in the system; the whole point is that it stops
## paying for the ones elsewhere.
##
## REBUILT LAZILY, PER GROUP, PER FRAME — the same contract as BuildShip.frame_group. A
## group nobody queries this frame is never bucketed at all.
##
## THE RETURNED ARRAY IS FRESH and the caller may do as it likes with it; the BUCKETS
## behind it are shared and must not be mutated.
##
## POSITIONS ARE READ WHEN THE GRID IS BUILT, and that is the one hazard here. Inside a
## physics frame the ships move one at a time, so a ship that has already moved sits in
## the bucket it was in at the start of the frame — bounded by a frame of travel, which
## QUERY_PAD covers. ANYTHING THAT TELEPORTS must call invalidate(): the engine does it
## for free at every frame boundary, but a test that sets global_position and re-queries
## in the same frame is asking about a world that no longer exists. Three avoidance
## assertions caught exactly that, which is the whole reason they walk real ships.

## Cell edge. Sized against the two real query radii — separation reaches roughly
## hull + hull + SHIP_CLEARANCE + a velocity lead (~360), and AVOID_LOOKAHEAD is 320 —
## so a typical query covers a 3x3 block. Much smaller and the block grows faster than
## the bucket shrinks; much larger and every cell is a linear scan again.
const CELL := 384.0

## Slack for a frame of movement, since the grid is built before the ships move within it
## (see the note above). A fast hull covers ~15 units at 900 u/s in a 60Hz step; this is
## comfortably over that and costs nothing but an occasionally wider sweep.
const QUERY_PAD := 48.0

static var _grids := {}          ## group -> { Vector2i: Array }
static var _frame := -1


## Everything in `group` within `radius` of `pos`. Approximate by design: it returns
## everything in the covered CELLS, so a caller still does its own precise distance test
## — which every caller already did anyway. The win is that it tests ten candidates
## instead of nine hundred.
static func near(tree: SceneTree, group: String, pos: Vector2, radius: float) -> Array:
	# NO SMALL-GROUP FAST PATH — TRIED AND REMOVED, recorded so it is not re-tried. The
	# idea was that a short group is cheaper to walk than to bucket, and the four-ship
	# furball (0.25 ms) seemed to want it. It failed twice: it did not help that case,
	# because the cost there is the 48 ROCKS whose rebuild is amortised over only four
	# queries; and it actively HURT the sparse case, taking twelve ships on a real lane
	# from 0.138 to 0.203 ms, because in a spread world even a short group is worth
	# indexing. SPARSITY matters here, not population, and a size threshold cannot see it.
	var grid := _grid_for(tree, group)
	var out: Array = []
	var r := maxf(radius, 0.0) + QUERY_PAD
	var min_c := _cell(pos - Vector2(r, r))
	var max_c := _cell(pos + Vector2(r, r))
	for cx in range(min_c.x, max_c.x + 1):
		for cy in range(min_c.y, max_c.y + 1):
			var bucket = grid.get(Vector2i(cx, cy))
			if bucket != null:
				out.append_array(bucket)
	return out


## How many cells a query of this radius would sweep — for a caller deciding whether the
## index is worth using at all, and for tests to prove the sweep stays small.
static func cells_for(radius: float) -> int:
	var span := int(ceil(maxf(radius, 0.0) * 2.0 / CELL)) + 1
	return span * span


static func _grid_for(tree: SceneTree, group: String) -> Dictionary:
	var frame := Engine.get_physics_frames()
	if frame != _frame:
		_frame = frame
		_grids.clear()
	if _grids.has(group):
		return _grids[group]
	var grid := {}
	for n in tree.get_nodes_in_group(group):
		var n2 := n as Node2D
		if n2 == null or not is_instance_valid(n2):
			continue
		var key := _cell(n2.global_position)
		if grid.has(key):
			(grid[key] as Array).append(n2)
		else:
			grid[key] = [n2]
	_grids[group] = grid
	return grid


static func _cell(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / CELL)), int(floor(p.y / CELL)))


## A NEW FRAME, DECLARED BY HAND. The engine does this by advancing the physics counter;
## a test or a benchmark that spawns or teleports inside one frame has to say so.
##
## IT CLEARS BOTH CACHES, because they share one contract and splitting them is a trap:
## the spatial grid goes stale on a MOVE, and BuildShip.frame_group goes stale on a
## SPAWN — a node created after the group array was cached is simply not in it. Two of
## the avoidance assertions failed on the second of those while the first was already
## fixed, which is precisely the kind of half-solved cache bug that survives a green run.
static func invalidate() -> void:
	_frame = -1
	_grids.clear()
	BuildShip._group_frame = -1
	BuildShip._group_cache.clear()

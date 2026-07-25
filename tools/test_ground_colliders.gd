extends Node
## COLLIDERS MUST MATCH THE ART (user bug, 2026-07-25: "colliders don't match the
## placement of the sprite — they seem offset behind them").
##
## The town spawns building art BASE-ANCHORED and 1.25x the old procedural footprint width,
## while the collider was built from that footprint, centred, at 0.82/0.72 scale. The solid
## was ~66% of the drawn width and sat behind the visible base — you bumped into nothing in
## front of a wall and walked through its edges.
##
## Same idea as tools/test_ground_shadow.tscn: measure the geometry rather than eyeball it.
## The town stores each sprite's drawn base (`_shadow_pairs`), so this compares every
## building's collider against the art it belongs to — no rendering needed.
##   <godot> --headless --path . res://tools/test_ground_colliders.tscn

## The collider's front edge should sit ON the drawn base line, within this slop.
const EDGE_TOL := 2.0

var _fails := 0


func _ready() -> void:
	var town: Node = load("res://scenes/ground/epharon_town.tscn").instantiate()
	add_child(town)
	for _i in 4:
		await get_tree().physics_frame

	var bodies: Array = []
	for c in town.get_children():
		if c is StaticBody2D and c.has_meta("building"):
			bodies.append(c)
	_chk(not bodies.is_empty(), "the town built building colliders (%d)" % bodies.size())

	var pairs: Array = town.get("_shadow_pairs")
	var checked := 0
	for pair in pairs:
		var nm := str(pair.get("name", ""))
		if nm == "" or nm == "prop":
			continue                      # scattered props aren't named buildings
		var body: StaticBody2D = null
		for b in bodies:
			if str(b.get_meta("building")) == nm:
				body = b
		if body == null:
			continue
		checked += 1

		var spr: Sprite2D = pair["spr"]
		var sc: float = float(pair["scale"])
		var base: Vector2 = pair["base"]
		var art_w: float = (float(pair["right"]) - float(pair["left"])) * sc
		# Shape-agnostic: a collider may be the auto-measured RECTANGLE or a HAND-AUTHORED
		# POLYGON (scenes/ground/colliders/<key>.tscn). Both must line up with the art, so
		# compare world-space bounds rather than caring which one it is.
		var rect := _collider_bounds(body)

		# HAND-AUTHORED shapes are allowed to be shapes: a rock's footprint bulges toward
		# the viewer, so demanding a flat front edge on the base line would fail the moment
		# someone used the polygon tool the authoring scenes exist for. Auto-measured
		# colliders keep the exact contract; authored ones only have to sit ON the art.
		if _is_auto_rect(body, base):
			# 1) FRONT EDGE ON THE BASE LINE — the thing that was visibly wrong. The player
			#    must be stopped exactly where the wall is drawn, not short of or inside it.
			_chk(absf(rect.end.y - base.y) <= EDGE_TOL,
				"%s: collider front edge sits on the drawn base (off by %.1f)" % [
					nm, rect.end.y - base.y])
			# 2) WIDTH TRACKS THE ART. Inset a little for forgiving corners, but never a
			#    fraction of the sprite (the old 66% bug) nor wider than it.
			var ratio := rect.size.x / maxf(1.0, art_w)
			_chk(ratio >= 0.85 and ratio <= 1.0,
				"%s: collider width tracks the art (%.0f%% of drawn base)" % [nm, ratio * 100.0])
			# 3) IT STANDS BEHIND THE FRONT EDGE, never in front (that would block open
			#    ground the player can see is empty).
			_chk(rect.position.y < base.y, "%s: footprint stands behind its front edge" % nm)
		else:
			# AUTHORED: still has to be ON the thing. This is what would have caught the
			# original bug (a whole collider shifted off the art) without dictating shape.
			_chk(rect.size.x <= art_w * 1.15 and rect.size.x >= art_w * 0.3,
				"%s: authored collider is sized like the art (%.0f%% of drawn base)" % [
					nm, rect.size.x / maxf(1.0, art_w) * 100.0])
			_chk(absf(rect.get_center().y - base.y) <= art_w,
				"%s: authored collider straddles the drawn base" % nm)

		# 4) Centred on the art, not on the old footprint rect. True either way.
		_chk(absf(rect.get_center().x - spr.position.x) <= maxf(EDGE_TOL, art_w * 0.25),
			"%s: collider is centred on the sprite" % nm)

	_chk(checked >= 4, "checked a real sample of arted buildings (%d)" % checked)

	# 5) SCATTERED PROPS ARE SOLID NOW (they had no colliders at all). Boulders/mesa get a
	#    body; dunes stay passable, so we only assert that SOME prop bodies exist.
	var prop_bodies := 0
	for c in town.get_children():
		if c is StaticBody2D and not c.has_meta("building"):
			prop_bodies += 1
	_chk(prop_bodies > 0, "scattered rock is solid — props have colliders (%d)" % prop_bodies)

	# 6) NO PROP OVERLAPS ANOTHER (user bug: overlapping props stacked TWO projected
	#    shadows into a dark blot). The scatter placed at pure random with no checks; it
	#    now rejects a spot that isn't clear. Assert the field it actually produced.
	var placed: Array = town.get("_placed_props")
	_chk(placed.size() > 20, "the roam is still populated after decluttering (%d props)" % placed.size())
	var worst := 0.0
	var clashes := 0
	for i in placed.size():
		for j in range(i + 1, placed.size()):
			var a: Dictionary = placed[i]
			var b: Dictionary = placed[j]
			var need: float = float(a.r) + float(b.r)
			var gap: float = a.pos.distance_to(b.pos) - need
			if gap < 0.0:
				clashes += 1
				worst = minf(worst, gap)
	_chk(clashes == 0, "no two props overlap (%d clashes, worst %.0fu)" % [clashes, worst])

	# ...and none of them sits on a building.
	var on_building := 0
	for p in placed:
		for b in town.BUILDINGS:
			if p.pos.distance_to(b.pos) < float(p.r) + maxf(b.size.x, b.size.y) * 0.75:
				on_building += 1
	_chk(on_building == 0, "no prop sits on a building (%d)" % on_building)

	# 7) THE AUTHORING SCENES SHARE THE GAME'S ANCHOR. A hand-drawn polygon is authored
	#    against the reference sprite in scenes/ground/colliders/<key>.tscn and PLACED
	#    against the town's measurement of the same art — if those two disagree by even a
	#    row, every authored collider sits visibly offset. (They DID disagree: the tool had
	#    its own copy of the base-row algorithm with a different alpha threshold, search
	#    start, tie-break and an off-by-one. ArtAnchor is now the single implementation;
	#    this is the guard that keeps it that way.)
	for key in ["boulders", "mesa", "starport", "market", "cave"]:
		var scene_path := "res://scenes/ground/colliders/%s.tscn" % key
		var art_path := "res://assets/ground/props/%s.png" % key
		if not FileAccess.file_exists(art_path):
			art_path = "res://assets/ground/buildings/%s.png" % key
		if not ResourceLoader.exists(scene_path) or not FileAccess.file_exists(art_path):
			continue
		var img := Image.new()
		if img.load(art_path) != OK:
			continue
		var want := ArtAnchor.base_offset(ArtAnchor.base_row(img))
		var inst = (load(scene_path) as PackedScene).instantiate()
		var got := Vector2.INF
		for c in inst.get_children():
			if c is Sprite2D:
				got = (c as Sprite2D).offset
		inst.queue_free()
		_chk(got.is_equal_approx(want),
			"%s: authoring scene anchors the art exactly as the game does (%s vs %s)" % [
				key, got, want])

	print("test_ground_colliders: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


## Is this the AUTO-MEASURED footprint (strict contract), or a HAND-AUTHORED polygon
## someone drew with the tool (shape is theirs; it only has to sit on the art)?
## The seed the generator writes is a 4-point axis-aligned rectangle with its front edge
## on the base line — anything else means a human moved the points.
func _is_auto_rect(body: StaticBody2D, _base: Vector2) -> bool:
	var child := body.get_child(0)
	if child is CollisionShape2D:
		return true                       # the measured RectangleShape2D
	var pts: PackedVector2Array = (child as CollisionPolygon2D).polygon
	if pts.size() != 4:
		return false
	# Axis-aligned: two distinct xs and two distinct ys, front edge at local y = 0.
	var xs := {}
	var ys := {}
	for p in pts:
		xs[snappedf(p.x, 0.01)] = true
		ys[snappedf(p.y, 0.01)] = true
	return xs.size() == 2 and ys.size() == 2 and ys.has(0.0)


## World-space bounds of a body's collider, whatever shape it uses.
func _collider_bounds(body: StaticBody2D) -> Rect2:
	var child := body.get_child(0)
	if child is CollisionPolygon2D:
		var pts: PackedVector2Array = (child as CollisionPolygon2D).polygon
		var r := Rect2(body.position + pts[0], Vector2.ZERO)
		for p in pts:
			r = r.expand(body.position + p)
		return r
	var shape: RectangleShape2D = (child as CollisionShape2D).shape
	return Rect2(body.position - shape.size * 0.5, shape.size)


func _chk(cond: bool, msg: String) -> void:
	print(("  ok  " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1

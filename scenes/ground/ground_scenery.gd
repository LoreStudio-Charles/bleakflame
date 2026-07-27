class_name GroundScenery
## THE MACHINERY OF A PLANET SURFACE, with no planet in it.
##
## WHY (user, 2026-07-27): "Let's extract what we can so that as much as possible we can
## reuse things from Epharon on other planets." Two more planets are coming in this system,
## and all of this was welded into epharon_town.gd — a 2,200-line file where the reusable
## machinery and the one colony's contents were the same object.
##
## WHAT LIVES HERE vs WHAT STAYS IN A TOWN: everything here takes its specifics as
## arguments and knows nothing about Epharon. The town keeps its CONTENTS — which buildings
## exist and where, which props scatter, its palette, its NPCs — because that is what makes
## it that place rather than another one. A planet author writes data and calls these.
##
## DELIBERATELY NOT A BASE CLASS. There is exactly one ground scene today, and a base class
## designed against a single implementation reliably bakes that implementation's accidents
## in as if they were rules. These are free functions with explicit parameters; when the
## second planet exists and the genuinely common SHAPE is visible rather than guessed, the
## base class falls out of it.

## THE SUN — one light, shared by every projected shadow on the surface: characters,
## buildings, rocks, the parked ship. A shadow is a dark, transparent copy of the sprite,
## flipped + squashed + skewed so it lies on the ground; SCALE.y is its LENGTH (a low sun
## casts long) and SKEW is its LEAN (the sun's bearing). Change these and the whole world's
## shadows rotate and stretch together — the seam for a real day/night pass.
##
## IT LIVES HERE, WITH THE WORLD. These were consts on GroundCharacter, which made the
## scenery depend on a CHARACTER class to find out what time of day it was — backwards, and
## a coupling that would have had to be unpicked the moment a second planet wanted a
## different light. GroundCharacter now reads them from here; the dependency runs one way,
## from the things standing on a world to the world they stand on.
## IT IS A VALUE, NOT A CONSTANT (user, 2026-07-27: "make sure that any points where there
## data exchanged there is no coupling so that changes later are easy"). Three planets
## around different stars is exactly the case where the light differs, and as consts that
## was a code edit rather than a setting. A scene assigns `GroundScenery.sun` once at
## startup and every shadow in it — character, building, rock, parked hull — follows.
## Same pattern the flight side already uses for per-scene context (AIShip.station_pos).
##
##   tint       the shadow's colour and opacity
##   scale      x = 1.0 so the base width MATCHES (corners line up);
##              y flips + squashes, and its magnitude is the shadow's LENGTH
##   skew       radians of lean = the sun's bearing
##   anchor_pct lift onto the sprite's true base, as a fraction of its visible height
##              (art usually carries a soft margin below the base, so the raw pivot is low)
const DEFAULT_SUN := {
	"tint": Color(0.06, 0.05, 0.10, 0.45),
	"scale": Vector2(1.0, -0.55),
	"skew": 0.5,
	"anchor_pct": 0.22,
}

static var sun: Dictionary = DEFAULT_SUN


## Read one of the sun's properties, falling back to the default for any key a scene did
## not bother to override — so a planet can set ONLY its shadow tint and inherit the rest,
## and a partially-filled dictionary can never produce a zero-length shadow.
static func sun_val(key: String):
	return sun.get(key, DEFAULT_SUN[key])

## How deep a building's ground footprint is, as a fraction of its drawn base width. A 3/4
## sprite cannot tell us how far "back" it goes, so we assume a roughly square footprint
## standing behind its front edge.
const FOOTPRINT_DEPTH := 0.55
## Shave the collider slightly inside the art so corners feel forgiving rather than sticky.
const FOOTPRINT_INSET := 0.94

## HAND-AUTHORED COLLIDER SHAPES (user, 2026-07-25 — "can I adjust the point data of the
## polygon in the Godot UI?"). Drop a scene at `scenes/ground/colliders/<key>.tscn` holding
## a CollisionPolygon2D and its points REPLACE the measured rectangle for that art. Points
## are authored in SOURCE-PIXEL space relative to the art's BASE ANCHOR (origin = the middle
## of the sprite's base line, +y down/toward the viewer), which is exactly what the
## authoring scene shows you, so what you drag is what you get at any prop scale.
##
## Generate the starter scenes with:
##   <godot> --headless --path . --script res://tools/make_collider_scenes.gd
## then open one in the editor and drag the points. Missing file = the automatic rectangle.
const COLLIDER_DIR := "res://scenes/ground/colliders/%s.tscn"

static var _poly_cache := {}


## Load drop-in art. Tries the import pipeline first, then a raw Image.load so freshly
## dropped-in PNGs work with no Godot import step — the same drop-in philosophy as hull
## sprites. Missing art returns null QUIETLY: a planet is allowed to be half-drawn, and the
## procedural fallbacks are what make that survivable.
static func load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var r = load(path)
		if r is Texture2D:
			return r
	if not FileAccess.file_exists(path):
		return null
	var img := Image.new()
	if img.load(path) == OK:
		return ImageTexture.create_from_image(img)
	return null


## Place a base-anchored art prop in a y-sorted world: pivots on its WIDEST base row so it
## sits on the ground, and (if cast_shadow) drops the projected shadow buildings use — which
## then touches at the base corners (see test_ground_shadow). Returns the sprite/shadow pair
## plus the base-corner columns, which the collider and the shadow test both read.
static func spawn_prop(world: Node2D, tex: Texture2D, base_pos: Vector2, target_w: float,
		tint: Color, cast_shadow: bool) -> Dictionary:
	var img := tex.get_image()
	if img != null and img.is_compressed():
		img.decompress()
	var br: Dictionary = ArtAnchor.base_row(img) if img != null else {
		"y": tex.get_height(), "left": 0, "right": tex.get_width(),
		"center": tex.get_width() * 0.5}
	var off := ArtAnchor.base_offset(br)
	var sc: float = target_w / float(tex.get_width())
	var shd: Sprite2D = null
	if cast_shadow:
		shd = Sprite2D.new()
		shd.texture = tex
		shd.centered = false
		shd.offset = off
		shd.position = base_pos
		var sun_scale: Vector2 = sun_val("scale")
		shd.scale = Vector2(sc * sun_scale.x, sc * sun_scale.y)
		shd.skew = sun_val("skew")
		shd.modulate = sun_val("tint")
		world.add_child(shd)   # before the sprite -> drawn behind it
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.scale = Vector2(sc, sc)
	spr.offset = off
	spr.position = base_pos
	spr.modulate = tint
	world.add_child(spr)
	return {"spr": spr, "shd": shd, "y": int(br.y), "left": int(br.left), "right": int(br.right),
		"scale": sc, "base": base_pos}


## Points for a hand-authored collider, in source-pixel space, or [] if none exists.
static func collider_points(key: String) -> PackedVector2Array:
	if _poly_cache.has(key):
		return _poly_cache[key]
	var pts := PackedVector2Array()
	var path := COLLIDER_DIR % key
	if ResourceLoader.exists(path):
		var packed: PackedScene = load(path)
		var inst := packed.instantiate()
		for c in inst.get_children():
			if c is CollisionPolygon2D:
				pts = (c as CollisionPolygon2D).polygon
				break
		inst.queue_free()
	_poly_cache[key] = pts
	return pts


## The solid a piece of art presents to walkers, MEASURED FROM THE SPRITE.
##
## THE BUG THIS ENCODES (user, 2026-07-25): colliders used to be built from an authored
## footprint while the ART was spawned base-anchored and 1.25x as wide, so the solid was
## ~66% of the drawn width and sat behind the visible base — you bumped into nothing in
## front of a wall and walked through its edges. Measuring off the sprite keeps the two in
## agreement whatever art drops in. A hand-authored polygon still wins.
static func add_body(parent: Node, pair: Dictionary, key := "") -> StaticBody2D:
	if pair.is_empty():
		return null
	var sc: float = float(pair["scale"])
	var base: Vector2 = pair["base"]
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var pts := collider_points(key) if key != "" else PackedVector2Array()
	if not pts.is_empty():
		# Authored in source pixels about the base anchor: just scale to this instance.
		body.position = base
		var poly := CollisionPolygon2D.new()
		var scaled := PackedVector2Array()
		for p in pts:
			scaled.append(p * sc)
		poly.polygon = scaled
		body.add_child(poly)
	else:
		var w: float = (float(pair["right"]) - float(pair["left"])) * sc
		var depth: float = w * FOOTPRINT_DEPTH
		body.position = base + Vector2(0.0, -depth * 0.5)
		var shape := RectangleShape2D.new()
		shape.size = Vector2(w * FOOTPRINT_INSET, depth)
		var col := CollisionShape2D.new()
		col.shape = shape
		body.add_child(col)
	parent.add_child(body)
	return body


## A screen-space vignette for noir framing. `strength` is the darkest corner alpha.
static func vignette_tex(strength := 0.6, tint := Color(0.02, 0.01, 0.05)) -> Texture2D:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) * 0.5
	for y in n:
		for x in n:
			var d := Vector2(x - c, y - c).length() / (c * 1.16)
			img.set_pixel(x, y, Color(tint.r, tint.g, tint.b,
				clampf((d - 0.55) / 0.45, 0.0, 1.0) * strength))
	return ImageTexture.create_from_image(img)


## The light of a whole world: a colour cast over everything plus the vignette. `cast` is
## what makes one planet's air different from another's — Epharon's warm golden hour is one
## value, not a fact about ground scenes.
static func apply_light(host: Node, hud: CanvasLayer, cast: Color,
		vignette := 0.6) -> void:
	var cm := CanvasModulate.new()
	cm.color = cast
	host.add_child(cm)
	var vig := TextureRect.new()
	vig.texture = vignette_tex(vignette)
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	hud.add_child(vig)
	hud.move_child(vig, 0)


## Drifting ambient weather (blowing sand here; snow, ash or rain elsewhere on the same
## emitter). SCREEN-SPACE, on the HUD behind the vignette, so it reads wherever the camera
## is. A full storm EVENT can crank amount/velocity/alpha off this same node.
static func build_weather(hud: CanvasLayer, tex: Texture2D, tint: Color,
		amount := 14, speed := Vector2(150.0, 250.0)) -> CPUParticles2D:
	if tex == null:
		return null
	var p := CPUParticles2D.new()
	p.texture = tex
	p.amount = amount
	p.lifetime = 7.0
	p.preprocess = 7.0            # start mid-stream so the screen isn't bare on arrival
	p.local_coords = false
	p.position = Vector2(-160, 540)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(40, 720)
	p.direction = Vector2(1, 0.15)
	p.spread = 12.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = speed.x
	p.initial_velocity_max = speed.y
	p.scale_amount_min = 0.8
	p.scale_amount_max = 2.4
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([
		Color(tint, 0.0), Color(tint, 0.22), Color(tint, 0.0)])
	p.color_ramp = g
	hud.add_child(p)
	hud.move_child(p, 0)   # behind the vignette + labels
	return p


## DECLUTTERED SCATTER. Hand it what the ground is already occupied by, then ask it for
## somewhere a prop of a given size actually FITS.
##
## WHY (user, 2026-07-25): the first scatter placed props at pure random with no checks, so
## art overlapped art — and because each prop casts its own projected shadow, two
## overlapping props stacked TWO darkenings into a blot. It also dropped props on top of
## buildings and inside the landing apron, which read as the pad being derelict rather than
## the colony's live front door.
##
## Every planet needs this and every planet has different things to avoid, which is exactly
## why the blockers are handed in rather than reached for.
class Scatter extends RefCounted:
	## Breathing room between two props on top of their own radii — touching art reads as
	## one clumsy blob even when it is not overlapping.
	const GAP := 26.0
	## How many times to re-roll a position before giving up on a prop entirely.
	const TRIES := 24

	## WHAT I PUT DOWN and WHAT I WAS TOLD TO AVOID ARE TWO DIFFERENT LEDGERS, deliberately.
	## The first version kept one list for both, which reads as harmless — `clear()` wants
	## to test against everything anyway — and quietly corrupted the record: buildings
	## seeded as keep-outs became indistinguishable from placed props, so anything auditing
	## the scatter's output saw nine buildings reported as props sitting on buildings. Ask
	## `placed` what the scatter DID; ask `clear()` where it may go.
	var placed: Array = []        # {pos, r} — spots this scatter actually handed out
	var blockers: Array = []      # {pos, r} — ground already spoken for by someone else
	var rects: Array = []         # Rect2 keep-out zones (a landing apron, a road)

	func block(pos: Vector2, radius: float) -> void:
		blockers.append({"pos": pos, "r": radius})

	func block_rect(r: Rect2) -> void:
		rects.append(r)

	func clear(pos: Vector2, radius: float) -> bool:
		for group in [placed, blockers]:
			for p in group:
				if pos.distance_to(p.pos) < radius + float(p.r) + GAP:
					return false
		for r in rects:
			if (r as Rect2).grow(radius + GAP).has_point(pos):
				return false
		return true

	## Somewhere in the ring between min_d and max_d of `center` that this prop fits.
	## Vector2.INF when the field is too crowded to take it — callers SKIP rather than
	## stack one prop on another.
	func spot(rng: RandomNumberGenerator, min_d: float, max_d: float, radius: float,
			center := Vector2.ZERO) -> Vector2:
		for _try in TRIES:
			var a := rng.randf() * TAU
			var dist := rng.randf_range(min_d, max_d)
			var pos := center + Vector2(cos(a), sin(a)) * dist
			if clear(pos, radius):
				placed.append({"pos": pos, "r": radius})
				return pos
		return Vector2.INF

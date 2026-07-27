extends Node
## THE REUSABLE HALF OF A PLANET SURFACE — the machinery a second and third planet will
## inherit, tested without any planet in it.
##
## RUN AS A SCENE:
##   <godot> --headless --path . res://tools/test_ground_scenery.tscn --quit-after 900

var _fails: Array[String] = []
var _checks := 0


func _ready() -> void:
	_case_the_two_ledgers_are_separate()
	_case_scatter_respects_what_it_was_told()
	_case_a_full_field_refuses_rather_than_stacks()
	_case_the_sun_is_a_setting_not_a_constant()
	_case_a_partial_sun_inherits_the_rest()

	GroundScenery.sun = GroundScenery.DEFAULT_SUN   # never leak a test's light
	if _fails.is_empty():
		print("test_ground_scenery: ALL PASS (%d checks)" % _checks)
	else:
		for f in _fails:
			printerr("  FAIL: %s" % f)
		printerr("test_ground_scenery: %d FAILED of %d checks" % [_fails.size(), _checks])
	get_tree().quit(0 if _fails.is_empty() else 1)


## WHAT I PLACED vs WHAT I MUST AVOID. The first version of Scatter kept one list for both,
## which looks harmless because clear() tests against everything anyway — and corrupted the
## record. Epharon seeds nine buildings as keep-outs, so an audit of the scatter's output
## saw nine "props" sitting exactly on buildings and two buildings "overlapping". A real
## test went red on it; this is that lesson pinned where the class lives.
func _case_the_two_ledgers_are_separate() -> void:
	var s := GroundScenery.Scatter.new()
	s.block(Vector2(5000, 5000), 300.0)
	s.block(Vector2(-5000, 5000), 300.0)
	_ok(s.placed.is_empty(), "blocking ground places nothing (placed=%d)" % s.placed.size())
	_ok(s.blockers.size() == 2, "...it records a blocker instead")

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var got := 0
	for i in 6:
		if not is_inf(s.spot(rng, 400.0, 900.0, 40.0).x):
			got += 1
	_ok(got > 0, "the scatter still places props (%d)" % got)
	_ok(s.placed.size() == got,
		"`placed` counts ONLY what it handed out — %d placed for %d spots" % [s.placed.size(), got])
	_ok(s.blockers.size() == 2, "...and the blocker list did not grow with them")


func _case_scatter_respects_what_it_was_told() -> void:
	var s := GroundScenery.Scatter.new()
	# One blocker sitting over the whole ring we are about to ask for.
	s.block(Vector2.ZERO, 2000.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var pos := s.spot(rng, 100.0, 900.0, 50.0)
	_ok(is_inf(pos.x), "a prop is refused ground a blocker already owns")

	# A KEEP-OUT RECT — Epharon's swept landing apron is one, and every planet will have
	# something like it (a road, a pad, a plaza).
	var s2 := GroundScenery.Scatter.new()
	s2.block_rect(Rect2(Vector2(-4000, -4000), Vector2(8000, 8000)))
	var pos2 := s2.spot(rng, 100.0, 900.0, 50.0)
	_ok(is_inf(pos2.x), "...and ground inside a keep-out rect")

	# The blockers are DATA HANDED IN, not something the scatter reaches for. A fresh one
	# with nothing declared must be free to place anywhere — proving it holds no opinions
	# of its own about the world it is scattering into.
	var s3 := GroundScenery.Scatter.new()
	_ok(not is_inf(s3.spot(rng, 100.0, 900.0, 50.0).x),
		"a scatter told nothing blocks nothing — it has no built-in knowledge of any planet")


func _case_a_full_field_refuses_rather_than_stacks() -> void:
	var s := GroundScenery.Scatter.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	# Ask for huge props in a tiny ring: the field fills, and the rest must be REFUSED.
	# Stacking them would double up their projected shadows into a blot (the original bug).
	var placed := 0
	var refused := 0
	for i in 40:
		if is_inf(s.spot(rng, 200.0, 400.0, 220.0).x):
			refused += 1
		else:
			placed += 1
	_ok(refused > 0, "a crowded field refuses props rather than stacking them (%d refused)" % refused)
	# And nothing it DID place overlaps anything else it placed.
	var clashes := 0
	for i in s.placed.size():
		for j in range(i + 1, s.placed.size()):
			var a: Dictionary = s.placed[i]
			var b: Dictionary = s.placed[j]
			if a.pos.distance_to(b.pos) < float(a.r) + float(b.r):
				clashes += 1
	_ok(clashes == 0, "nothing it placed overlaps anything else it placed (%d clashes)" % clashes)


## THE SUN IS A VALUE A SCENE SETS (user, 2026-07-27: no coupling at the points where data
## is exchanged). Three planets around three stars is exactly where a const would have to
## be unpicked, so this proves a scene can change the light without touching the code that
## draws the shadows.
func _case_the_sun_is_a_setting_not_a_constant() -> void:
	var world := Node2D.new()
	add_child(world)
	var tex := _swatch()
	GroundScenery.sun = {
		"tint": Color(0.4, 0.0, 0.0, 0.5),   # a red star
		"scale": Vector2(1.0, -0.9),          # low and long
		"skew": -0.3,
		"anchor_pct": 0.22,
	}
	var pair := GroundScenery.spawn_prop(world, tex, Vector2.ZERO, 64.0, Color.WHITE, true)
	var shd: Sprite2D = pair["shd"]
	_ok(shd != null, "a shadow is cast")
	_ok(shd.modulate.is_equal_approx(Color(0.4, 0.0, 0.0, 0.5)),
		"the shadow takes the SCENE's sun colour, not a baked constant (got %s)" % shd.modulate)
	_ok(is_equal_approx(shd.skew, -0.3), "...and its bearing")
	_ok(shd.scale.y < 0.0, "...and still flips to lie on the ground")

	# The whole point of one shared light: a CHARACTER standing on the same ground reads the
	# same sun, so a planet cannot end up with its scenery lit differently from its people.
	var c := GroundCharacter.new()
	add_child(c)
	c.setup("res://assets/characters/Colonist")
	var cshd: AnimatedSprite2D = null
	for child in c.get_children():
		if child is AnimatedSprite2D:
			cshd = child
			break      # the shadow is added FIRST, so it is the first one found
	_ok(cshd != null and cshd.modulate.is_equal_approx(Color(0.4, 0.0, 0.0, 0.5)),
		"a character's shadow reads the same sun as the scenery's")

	GroundScenery.sun = GroundScenery.DEFAULT_SUN
	world.queue_free()
	c.queue_free()


## A planet should be able to change ONLY its shadow colour and inherit the rest. Without
## the fallback a half-filled dictionary yields a zero scale — a prop with no shadow at all,
## from an edit that looks entirely reasonable.
func _case_a_partial_sun_inherits_the_rest() -> void:
	GroundScenery.sun = {"tint": Color(0.0, 0.2, 0.4, 0.5)}
	_ok(GroundScenery.sun_val("tint").is_equal_approx(Color(0.0, 0.2, 0.4, 0.5)),
		"an override is honoured")
	_ok(GroundScenery.sun_val("scale") == GroundScenery.DEFAULT_SUN["scale"],
		"...and every key it did NOT set falls back to the default")
	_ok(float(GroundScenery.sun_val("anchor_pct")) > 0.0,
		"...so a partial sun can never produce a degenerate shadow")
	GroundScenery.sun = GroundScenery.DEFAULT_SUN


func _swatch() -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.6, 0.5, 0.4))
	return ImageTexture.create_from_image(img)


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(what)

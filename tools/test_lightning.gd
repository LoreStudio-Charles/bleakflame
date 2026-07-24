extends SceneTree
## Pure-math test for Lightning.fractal_path (no autoloads, no nodes). Asserts the two
## properties a reusable bolt MUST hold: endpoints stay anchored (a beam always connects
## muzzle->target), and interior jitter stays inside the shrinking displacement envelope.

var _fails := 0


func _init() -> void:
	var L := load("res://scenes/flight/lightning.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260724

	var a := Vector2(120.0, 60.0)
	var b := Vector2(760.0, 340.0)
	var gens := 5
	var chaos := 0.22
	var path: PackedVector2Array = L.fractal_path(a, b, gens, chaos, rng)

	# 1) Endpoints anchored EXACTLY (index 0 and last are never displaced).
	_check(path[0] == a, "start anchored: %s == %s" % [path[0], a])
	_check(path[path.size() - 1] == b, "end anchored: %s == %s" % [path[path.size() - 1], b])

	# 2) 2^gens segments -> 2^gens + 1 points.
	var want := int(pow(2, gens)) + 1
	_check(path.size() == want, "point count %d == %d" % [path.size(), want])

	# 3) No point strays past the summed displacement envelope (offset * (1 + 1/2 + ...) < 2x).
	var span := a.distance_to(b)
	var envelope := span * chaos * 2.2
	var dir := (b - a).normalized()
	var worst := 0.0
	for p in path:
		var rel: Vector2 = p - a
		worst = maxf(worst, (rel - dir * rel.dot(dir)).length())
	_check(worst <= envelope, "max deviation %.1f <= envelope %.1f" % [worst, envelope])
	_check(worst > 0.5, "path is actually jagged (dev %.1f > 0)" % worst)

	# 4) chaos = 0 -> a dead-straight line (envelope logic sanity / sabotage guard).
	var straight: PackedVector2Array = L.fractal_path(a, b, gens, 0.0, rng)
	var flat := 0.0
	for p in straight:
		var rel: Vector2 = p - a
		flat = maxf(flat, (rel - dir * rel.dot(dir)).length())
	_check(flat < 0.001, "chaos=0 is straight (dev %.4f ~ 0)" % flat)

	# 5) gens = 0 -> just the two endpoints.
	var raw: PackedVector2Array = L.fractal_path(a, b, 0, chaos, rng)
	_check(raw.size() == 2 and raw[0] == a and raw[1] == b, "gens=0 -> [a, b]")

	print("test_lightning: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	quit(1 if _fails > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	print(("  ok  " if cond else "  FAIL ") + msg)
	if not cond:
		_fails += 1

extends Node
## WRECKS — a killed ship leaves a body; a devoured one does not.
##
## The second half is the load-bearing one. `devour()` has always claimed the Cinderweb
## takes its prey "gone TRACELESS", and the starter campaign turns on that contrast — Voss
## reports NO DEBRIS, which only means something if debris is what normally happens. Until
## wrecks existed the distinction lived entirely in dialogue and nothing could tell the two
## deaths apart on screen.
##
##   <godot> --headless --path . res://tools/test_wrecks.tscn --quit-after 600

var _fails: Array[String] = []
var _checks := 0


func _ready() -> void:
	await _case_a_kill_leaves_a_body()
	await _case_the_beast_leaves_nothing()
	await _case_wrecks_do_not_accumulate_forever()
	_case_a_wreck_is_not_an_obstacle()

	if _fails.is_empty():
		print("test_wrecks: ALL PASS (%d checks)" % _checks)
	else:
		for f in _fails:
			printerr("  FAIL: %s" % f)
		printerr("test_wrecks: %d FAILED of %d checks" % [_fails.size(), _checks])
	get_tree().quit(0 if _fails.is_empty() else 1)


func _case_a_kill_leaves_a_body() -> void:
	_clear()
	var ship := _ship(Vector2(1000, 0))
	ship.take_damage(1e7, null)
	await get_tree().process_frame
	var wrecks := get_tree().get_nodes_in_group("wrecks")
	_ok(wrecks.size() == 1, "a destroyed ship leaves a wreck (%d)" % wrecks.size())
	if wrecks.is_empty():
		return
	var w := wrecks[0] as Wreck
	_ok(w.global_position.distance_to(Vector2(1000, 0)) < 5.0,
		"...where it died, not where the camera is")

	# It must TUMBLE, or it reads as a prop somebody placed rather than something that lost.
	var before := w.rotation
	for _i in 12:
		await get_tree().process_frame
	_ok(not is_equal_approx(w.rotation, before), "...and it tumbles")


## THE CONTRAST THE CAMPAIGN IS BUILT ON.
func _case_the_beast_leaves_nothing() -> void:
	_clear()
	var ship := _ship(Vector2(2000, 0))
	ship.devour()
	await get_tree().process_frame
	_ok(get_tree().get_nodes_in_group("wrecks").is_empty(),
		"a devoured ship leaves NO wreck — traceless, which is the whole horror")


func _case_wrecks_do_not_accumulate_forever() -> void:
	_clear()
	# A long session on a busy lane would otherwise grow without limit.
	for i in Wreck.MAX_WRECKS + 6:
		var s := _ship(Vector2(100 * i, 500))
		s.take_damage(1e7, null)
	await get_tree().process_frame
	var n := get_tree().get_nodes_in_group("wrecks").size()
	_ok(n <= Wreck.MAX_WRECKS,
		"the field is capped at %d wrecks (got %d)" % [Wreck.MAX_WRECKS, n])
	_ok(n >= Wreck.MAX_WRECKS - 2,
		"...and the cap keeps a full field rather than clearing it (%d)" % n)


## Debris you fly through. The avoidance pass (separation_dir, look-ahead) would otherwise
## have to learn a new class of obstacle that accumulates, and a lane strewn with solid
## hulks would make the road worse the more it was used.
func _case_a_wreck_is_not_an_obstacle() -> void:
	_clear()
	var ship := _ship(Vector2(3000, 0))
	ship.take_damage(1e7, null)
	var wrecks := get_tree().get_nodes_in_group("wrecks")
	if wrecks.is_empty():
		_ok(false, "a wreck exists to check")
		return
	var w := wrecks[0] as Wreck
	# "A wreck is not a CollisionObject2D" is not asserted here because it CANNOT BE
	# WRITTEN: Wreck extends Node2D, so the compiler rejects the check as statically
	# impossible. That is a stronger guarantee than a passing test — it is enforced at
	# parse time and would have to be deliberately undone by changing the base class.
	var solid := false
	for c in w.get_children():
		if c is CollisionShape2D or c is CollisionPolygon2D:
			solid = true
	_ok(not solid, "...and no collision shape hidden inside it")
	_ok(not w.is_in_group("structures") and not w.is_in_group("ships"),
		"...and does not join the groups avoidance steers around")


func _clear() -> void:
	for n in get_tree().get_nodes_in_group("wrecks"):
		n.free()


func _ship(at: Vector2) -> AIShip:
	var a := AIShip.new()
	add_child(a)
	a.position = at
	a.setup(SampleBuilds.get_build(0))
	return a


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(what)

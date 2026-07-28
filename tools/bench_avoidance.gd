extends Node
## WHERE THE FRAME GOES when a handful of pirates are on screen (user, 2026-07-28: "the
## game gets a little choppy... playing again just now it was bogging down pretty bad").
##
## MEASURES BEFORE THEORISING. Every ship runs BuildShip.apply_movement every physics
## frame, and that calls two spatial scans:
##
##   separation_dir()      — FIVE get_nodes_in_group walks (structures, outposts,
##                           pirate_dens, planetoids, ships) plus an O(ships) pass
##   avoid_obstacles_dir() — every asteroid in the system, per ship
##
## `get_nodes_in_group` ALLOCATES A NEW ARRAY ON EVERY CALL, so the group count matters
## as much as the element count: at N ships that is 6N arrays a frame before any distance
## maths, and the Reach ships ~48 asteroids across two belts.
##
##   <godot> --headless --path . res://tools/bench_avoidance.tscn --quit-after 600

const SHIPS := [4, 12, 30]
const ROCKS := 48
const FRAMES := 120


func _ready() -> void:
	SaveGame.read_only = true
	print("ships  rocks |  separation   avoidance |  per frame   -> at 60fps")
	print("---------------------------------------------------------------")
	for n in SHIPS:
		_run(n)
	print("")
	print("BOLTS IN THE AIR — every projectile calls _foes() -> engageable() EVERY")
	print("physics frame (twice, for a blast weapon), and each call allocates an Array")
	print("and a Dictionary and walks two groups. Bolts scale with how hard the fight")
	print("is, not with the ship count, which is why this bites at five pirates.")
	print("")
	print("bolts  ships |    distinct  |  per frame   -> at 60fps")
	print("------------------------------------------------------")
	for pair in [[20, 8], [40, 8], [80, 12]]:
		_run_bolts(int(pair[0]), int(pair[1]))
	print("")
	print("Budget for reference: one 60fps frame is 16.67 ms, ALL of it — physics,")
	print("rendering, UI. Anything here is spent before a single pixel is drawn.")
	get_tree().quit()


## A stand-in rock: avoid_obstacles_dir only asks for `hit_radius`, and a real
## MineableAsteroid drags ore tables and art in with it.
class Rock extends Node2D:
	var hit_radius := 40.0


## What the bolts cost. Measured through BuildShip.engageable, which is exactly what
## Projectile._foes() calls — no stand-in, so the number is the real one.
func _run_bolts(bolts: int, ships: int) -> void:
	var host := Node2D.new()
	add_child(host)
	var fleet: Array[BuildShip] = []
	for i in ships:
		var s := BuildShip.new()
		s.hit_radius = 16.0
		s.global_position = Vector2(randf_range(-1200, 1200), randf_range(-1200, 1200))
		host.add_child(s)
		s.add_to_group("ships")
		s.add_to_group("hostile_team")
		fleet.append(s)
	# FAITHFUL TO A REAL FRAME. The cache is keyed on Engine.get_physics_frames(), which
	# never advances inside _ready — so without this every call after the first would be
	# a cache hit and the benchmark would flatter itself by ~50x. Forcing the rebuild
	# each iteration reproduces exactly what the engine does: one scan per distinct
	# shooter per frame, then hits for that shooter's other bolts.
	var shooters: int = mini(ships, 4)     # a firefight: a handful of guns, many bolts
	var t0 := Time.get_ticks_usec()
	for f in FRAMES:
		BuildShip._engage_frame = -1       # a new frame begins
		for b in bolts:
			BuildShip.engageable(get_tree(), fleet[b % shooters], "hostile_team")
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	var per_frame := ms / float(FRAMES)
	print("%5d  %5d | %4d shooters | %7.3f ms   -> %5.1f%% of a frame" % [
		bolts, ships, shooters, per_frame, per_frame / 16.67 * 100.0])
	host.queue_free()


func _run(n: int) -> void:
	var host := Node2D.new()
	add_child(host)
	var rocks: Array[Node2D] = []
	for i in ROCKS:
		var r := Rock.new()
		r.global_position = Vector2(randf_range(-4000, 4000), randf_range(-4000, 4000))
		r.add_to_group("asteroids")
		host.add_child(r)
		rocks.append(r)
	var fleet: Array[BuildShip] = []
	for i in n:
		var s := BuildShip.new()
		s.hit_radius = 16.0
		s.global_position = Vector2(randf_range(-1200, 1200), randf_range(-1200, 1200))
		s.velocity = Vector2(randf_range(-300, 300), randf_range(-300, 300))
		host.add_child(s)
		s.add_to_group("ships")
		fleet.append(s)

	var t0 := Time.get_ticks_usec()
	for f in FRAMES:
		for s in fleet:
			s.separation_dir()
	var sep := float(Time.get_ticks_usec() - t0) / 1000.0

	t0 = Time.get_ticks_usec()
	for f in FRAMES:
		for s in fleet:
			s.avoid_obstacles_dir(s.velocity)
	var avoid := float(Time.get_ticks_usec() - t0) / 1000.0

	var per_frame := (sep + avoid) / float(FRAMES)
	print("%5d  %5d | %8.2f ms %8.2f ms | %7.3f ms   -> %5.1f%% of a frame" % [
		n, ROCKS, sep, avoid, per_frame, per_frame / 16.67 * 100.0])
	host.queue_free()

extends Node
## SPACE TARGETING LIFECYCLE — the two rules the user set for BOTH arenas (2026-07-25):
##   (1) THE KILL STANDS YOU DOWN — weapons go tight when your target DIES. Deselecting,
##       or losing it off sensors, does NOT (only death).
##   (2) RETALIATION TARGETING — whoever hits you becomes your target IF AND ONLY IF you
##       had none. Target only, never engage.
##
## WHY THIS FILE EXISTS: both rules were implemented on the ship as a code MIRROR of the
## ground's, with no harness — and the ground tests obviously can't catch a space
## regression. The first real playtest found exactly that gap (killing practice drones
## left the guns hot), so the mirror gets its own tests.
##
## RUN AS A SCENE (needs autoloads):
##   <godot> --headless --path . res://tools/test_space_targeting.tscn
## Never writes the save.

var _fails: Array[String] = []
var _checks := 0


func _ready() -> void:
	await _case_killing_a_drone_stands_you_down()
	await _case_killing_a_pirate_stands_you_down()
	await _case_stand_down_survives_the_free_race()
	await _case_losing_a_target_does_not_stand_you_down()
	await _case_retaliation_targets_only_when_empty()

	if _fails.is_empty():
		print("test_space_targeting: ALL PASS (%d checks)" % _checks)
	else:
		for f in _fails:
			printerr("  FAIL: %s" % f)
		printerr("test_space_targeting: %d FAILED of %d checks" % [_fails.size(), _checks])
	get_tree().quit(0 if _fails.is_empty() else 1)


## THE PLAYTEST BUG, verbatim: engage a practice drone, kill it, and the guns must go
## tight. A drone is the hard case — it carries no `dead` flag and frees ITSELF on death,
## so the only signal is the reference going invalid.
func _case_killing_a_drone_stands_you_down() -> void:
	var me := _player()
	var drone := TargetDrone.new()
	drone.global_position = Vector2(220, 0)
	add_child(drone)
	await get_tree().physics_frame

	me._select_target_at(drone.global_position)   # RMB on a hostile = target + weapons free
	_ok(me.target == drone, "right-clicking a drone selects it")
	_ok(me.weapons_free, "right-clicking a hostile declares weapons free")

	drone.take_damage(9999.0, me)                 # only the player can score a drone
	for _i in 8:
		await get_tree().physics_frame
	_ok(not me.weapons_free, "KILLING THE DRONE STANDS THE GUNS DOWN")
	_ok(me.target == null, "the dead target clears")
	me.queue_free()


## The same rule against a REAL HULL — a pirate Sparrowhawk, killed the way the game kills
## one (take_damage until the hull gives out, running the actual _die → loot → free path).
##
## THE TESTING LESSON (user, 2026-07-25 — they hit this on a Sparrowhawk after the drone
## fix): the first version of this case SIMULATED death by setting `dead = true` by hand,
## which is a death shape the engine never actually produces (a real hull raises the flag
## AND frees itself in the same call). A simulated death can pass while the real one fails.
## Kill things the way the game kills them.
func _case_killing_a_pirate_stands_you_down() -> void:
	var me := _player()
	var foe := _pirate(Vector2(300, 0))
	await get_tree().physics_frame

	me._select_target_at(foe.global_position)
	_ok(me.weapons_free, "engaging a pirate declares weapons free")
	foe.take_damage(999999.0, me)                 # the real death path, player-attributed
	for _i in 10:
		await get_tree().physics_frame
	_ok(not me.weapons_free, "KILLING A REAL HULL STANDS THE GUNS DOWN")
	_ok(me.target == null, "the killed hull clears from the selection")
	me.queue_free()
	if is_instance_valid(foe):
		foe.queue_free()


## THE RACE THAT MADE THIS INTERMITTENT (user: "not just drones — a pirate Sparrowhawk").
## A dying hull raises `dead` and queue_free()s in the same breath, so whether the wreck
## was still in the object table when the PLAYER's tick ran came down to node order. The
## old guard only handled the "still there, flagged dead" half, so real hulls stood you
## down sometimes and not others. This pins the worst case: the target is GONE before we
## ever look. The stand-down must not care.
func _case_stand_down_survives_the_free_race() -> void:
	var me := _player()
	var foe := _pirate(Vector2(300, 0))
	await get_tree().physics_frame
	me._select_target_at(foe.global_position)
	_ok(me.weapons_free, "engaged the Sparrowhawk")
	# The real death path (which announces), then ripped out of the tree IMMEDIATELY —
	# the worst case for anything that waits until its own tick to look around.
	foe.take_damage(999999.0, me)
	if is_instance_valid(foe):
		foe.free()
	for _i in 6:
		await get_tree().physics_frame
	_ok(not me.weapons_free, "a target freed before our tick STILL stands the guns down")
	me.queue_free()


## The counter-rule: only DEATH stands you down. A target that merely goes away — you
## deselected it, or it flew out of sensor range — leaves the guns exactly as you set them.
func _case_losing_a_target_does_not_stand_you_down() -> void:
	var me := _player()
	var foe := _pirate(Vector2(300, 0))
	await get_tree().physics_frame
	me._select_target_at(foe.global_position)
	_ok(me.weapons_free, "engaged")
	me.target = null                              # deselected, NOT killed
	for _i in 6:
		await get_tree().physics_frame
	_ok(me.weapons_free, "DESELECTING a live target leaves the guns as you set them")
	me.queue_free()
	if is_instance_valid(foe):
		foe.queue_free()


## Retaliation: a hit assigns a target only into an EMPTY slot, and never arms the guns.
func _case_retaliation_targets_only_when_empty() -> void:
	var me := _player()
	var foe := _pirate(Vector2(400, 0))
	var other := _pirate(Vector2(-400, 0))
	await get_tree().physics_frame

	me.target = null
	me.set_weapons_free(false)
	me.take_damage(4.0, foe)
	_ok(me.target == foe, "a hit out of nowhere TARGETS the attacker")
	_ok(not me.weapons_free, "...but never opens fire on its own (target, not engage)")

	me.take_damage(4.0, other)
	_ok(me.target == foe, "a flank hit NEVER re-aims a fight already in progress")
	me.queue_free()
	for f in [foe, other]:
		if is_instance_valid(f):
			f.queue_free()


func _player() -> TestShip:
	var me := TestShip.new()
	add_child(me)
	me.apply_build(SampleBuilds.get_build(SampleBuilds.current))
	me.global_position = Vector2.ZERO
	me.hull = 9999.0        # the test is about STATE, never about surviving
	me.shield = 9999.0
	return me


func _pirate(at: Vector2) -> AIShip:
	var foe := AIShip.new()
	add_child(foe)
	foe.setup(SampleBuilds.pirate_raider())
	foe.global_position = at
	return foe


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(what)

extends Node
## HEADLESS FRAME PROBE — boots the REAL flight scene, lets it settle, and prints the
## same diagnostic /diag prints in the seat.
##
## WHY THIS EXISTS: the phase timers are only useful if they are actually wired, and
## "wired" is exactly the kind of thing that looks fine in a diff and turns out to be a
## function nobody calls. This project has paid for that before. Booting the real scene
## and reading a populated table is the only proof that costs nothing to keep.
##
## IT IS NOT A BENCHMARK. Headless has no renderer, so `hud` and `radar.draw` are
## understated and the frame total means little — what it answers is "does every phase
## report, and roughly where does the GDScript go". The seat is still the measurement.
##
## Run: <godot> --headless --path . res://tools/probe_frame.tscn
## (a SCENE, not --script: the flight scene needs its autoloads)

const SETTLE_FRAMES := 240   # ~4 s of physics: spawners done, ships under way

var _frames := 0
var _scene: Node = null


func _ready() -> void:
	# NEVER WRITE THE PLAYTESTER'S SAVE. The boot docks the pilot, which checkpoints and
	# advances the game day; a probe that ages somebody's pilot is not a probe.
	SaveGame.read_only = true
	_scene = load("res://scenes/flight/flight_test.tscn").instantiate()
	add_child(_scene)
	# Discard the load window: the first frames are shaders, textures and eighty hulls
	# arriving at once, which is the warm-up and not the flying.
	await get_tree().process_frame
	Telemetry.reset_frames()


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames < SETTLE_FRAMES:
		return
	set_physics_process(false)
	# READ THE TABLE BEFORE REPORTING IT. report() clears the window on its way out --
	# deliberately, so the next sample is clean -- so checking afterwards asks an empty
	# dictionary whether it has anything in it and always says no. The first version of
	# this probe did exactly that and cried wolf over instrumentation that was working.
	var seen := Telemetry.phase_us.keys()
	Telemetry.report(get_tree())
	var missing: Array[String] = []
	for want in ["scene", "move", "ai.think", "hud"]:
		if not seen.has(want):
			missing.append(want)
	if missing.is_empty():
		print("probe_frame: every expected phase reported")
		get_tree().quit(0)
	else:
		# A phase that never reports is a timer around dead code. Fail loudly.
		printerr("probe_frame: NO SAMPLES for %s — the timer is not on a live path"
			% ", ".join(missing))
		get_tree().quit(1)

extends Node
## DROP-IN ART IS ACTUALLY VISIBLE — not merely loaded.
##   <godot> --headless --path . res://tools/test_dropin_art.tscn
##
## THE BUG THIS EXISTS FOR (2026-07-26, user: "we created pixelart for the tendril,
## but it's showing the procedural art instead"). The PNG loaded fine. The path was
## right, the file was there, the Sprite2D was created — and it was invisible,
## because Anomaly._ready() dimmed the additive procedural core ONCE and
## Anomaly._process() rewrote that same alpha unconditionally on the first frame.
## A per-frame write always beats a one-time adjustment.
##
## "Does the file load" was never the interesting question, and a test that asked it
## would have passed throughout. So these check what actually reaches the screen:
## the art is present AND the procedural stand-in has genuinely stood down — after
## the process loop has had a chance to undo it.

var _fails: Array[String] = []
var _checks := 0


func _ready() -> void:
	_case_anomaly_art_survives_the_process_loop()
	_case_procedural_body_retires_when_art_exists()

	if _fails.is_empty():
		print("test_dropin_art: ALL PASS (%d checks)" % _checks)
	else:
		for f in _fails:
			printerr("  FAIL: ", f)
		printerr("test_dropin_art: %d FAILED of %d checks" % [_fails.size(), _checks])
	get_tree().quit(0 if _fails.is_empty() else 1)


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(what)


func _anomaly(kind: String) -> Anomaly:
	var a := Anomaly.create(Vector2(50000, 50000), "test_quest", kind)
	add_child(a)
	return a


## The art must still be winning AFTER the animation has run, which is precisely
## where the original bug lived.
func _case_anomaly_art_survives_the_process_loop() -> void:
	for kind in ["tendril", "residue"]:
		var a := _anomaly(kind)
		if not a._has_art():
			print("NOTE: no anomaly_%s.png on disk — nothing to check" % kind)
			a.queue_free()
			continue
		_ok(a._sprite != null and a._sprite.texture != null,
			"anomaly_%s.png loaded into a sprite" % kind)

		# Drive the animation past the point where the old code clobbered the alpha.
		for _i in 12:
			a._process(0.1)

		_ok(a._core.color.a <= 0.35,
			"the additive core stays dimmed over the %s art (alpha %.2f) — a "
			% [kind, a._core.color.a]
			+ "full-strength core washes pixel art out to a violet blob")
		a.queue_free()


## Where art exists it is the BODY; the procedural stand-in for the body retires.
func _case_procedural_body_retires_when_art_exists() -> void:
	var a := _anomaly("tendril")
	if a._has_art():
		_ok(a._tendrils.is_empty(),
			"the %d procedural barbs stand down when a drawn tendril exists — "
			% a._tendrils.size() + "otherwise they are crude spokes laid over the art")
	a.queue_free()

	# ...and with NO art the procedural version must still be complete, or removing
	# a PNG would leave an invisible object rather than falling back.
	var bare := _anomaly("nosuchkind")
	_ok(not bare._has_art(), "an unknown kind has no art (the fallback path)")
	_ok(bare._core != null and bare._ring != null,
		"the procedural anomaly still draws itself with no art present")
	bare._process(0.1)
	_ok(bare._core.color.a > 0.1,
		"...and its core is at FULL strength (alpha %.2f) — it is the body now"
		% bare._core.color.a)
	bare.queue_free()

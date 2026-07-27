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
	_case_chat_bubble_tail_points_at_the_speaker()

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


## THE CHAT BUBBLE'S TAIL POINTS AT THE SPEAKER, and meets the bubble.
##
## The shipped tail is 9x8 of ink adrift in a 32x32 canvas: its centre sits 5.5px
## LEFT of the texture centre, and the arrow is SWEPT, so its point is the
## bottom-RIGHT rather than the bottom-middle. Anything derived from texture SIZE
## rather than from the drawing would hang it off to one side and aim it at nothing
## — and a transparent canvas hides every bit of that, so it would have looked fine
## in a file browser and wrong in game.
##
## The bubble's bottom edge also has to land on the arrow's top. That height is a
## property of the art (8px here), not the constant the code used to assume.
func _case_chat_bubble_tail_points_at_the_speaker() -> void:
	var speaker := Node2D.new()
	speaker.global_position = Vector2(1000, 1000)
	add_child(speaker)
	var b := ChatBubble.say(self, speaker, "Got a moment, pilot?", 9.0)

	_ok(b._body != null, "the bubble built a body")
	if not ResourceLoader.exists(ChatBubble.TAIL_ART):
		print("NOTE: no tail art on disk — geometry check skipped")
		b.queue_free()
		speaker.queue_free()
		return

	_ok(b._tail != null, "the tail art is used when present")
	var tex: Texture2D = load(ChatBubble.TAIL_ART)
	var m := b._tail_metrics(tex)

	# The tip must come from the DRAWING, not the canvas. If someone reverts to
	# texture-width maths this lands on 16.0 and the arrow drifts off the bubble.
	_ok(absf(m.x - tex.get_width() * 0.5) > 0.5,
		"the tip (%.1f) is measured from the ink, not the canvas centre (%.1f)"
		% [m.x, tex.get_width() * 0.5])
	_ok(m.z > 0.0 and m.z < float(tex.get_height()),
		"the arrow's ink height (%.0f) is less than its canvas (%d) — measured, not assumed"
		% [m.z, tex.get_height()])

	# NO SEAM: the body's bottom edge sits exactly on the arrow's top.
	var body_bottom: float = b._body.position.y + b._body.size.y
	var tail_ink_top: float = b._tail.position.y + (m.y - m.z)
	# NEVER A GAP; a small overlap is fine and is deliberate (TAIL_OVERLAP) — an
	# exact join can split across a pixel boundary at a fractional camera zoom.
	var seam := tail_ink_top - body_bottom
	_ok(seam <= 0.51,
		"bubble bottom (%.1f) sits ABOVE tail top (%.1f) — that %.1fpx gap reads as a broken sprite"
		% [body_bottom, tail_ink_top, seam])
	_ok(seam >= -(ChatBubble.TAIL_OVERLAP + 0.51),
		"the tail is buried %.1fpx under the bubble — more than the intended overlap"
		% -seam)

	# And the point lands where the speaker is, horizontally under the bubble.
	_ok(absf(b._tail.position.y + m.y + ChatBubble.LIFT + ChatBubble.TAIL_OVERLAP) < 0.51,
		"the tip sits LIFT above the speaker's origin")

	# THE OVERLAP MUST BE REAL. Shifting body and tail by the same amount moves the
	# assembly and leaves the join exact -- which is what the first version did, and
	# this assertion is what would have caught it.
	_ok(seam < -0.5,
		"the tail rides UP INTO the bubble (seam %.1f) — it draws on top, and its "
		% seam + "fill has to cover the bubble's 1px bottom border or a line runs "
		+ "across the tail's mouth")
	_ok(b._tail.get_index() > b._body.get_index(),
		"the tail is added after the body, so it draws OVER it")

	b.queue_free()
	speaker.queue_free()

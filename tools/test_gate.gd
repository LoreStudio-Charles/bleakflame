extends Node
## THE WAYGATE FINALE (user, 2026-07-23): the pilot ENTERS the waking sequence,
## then the ring opens. Tests the two logic-bearing halves — the console accepts
## only the right sequence, and begin_opening runs the choreography through to a
## traversable gate. (The shudder/fog/ship-shrink are visual; not asserted here.)
##
## RUN AS A SCENE (autoloads — GateConsole plays Sfx):
##   <godot> --headless --path . res://tools/test_gate.tscn

var _fails: Array[String] = []
var _entered_fired := false


func _ready() -> void:
	await _run()
	if _fails.is_empty():
		print("test_gate: ALL PASS")
	else:
		for f in _fails:
			printerr("  FAIL: " + f)
		printerr("test_gate: %d FAILED" % _fails.size())
	get_tree().quit(0 if _fails.is_empty() else 1)


func _run() -> void:
	# --- Every rune must be a DISTINCT glyph ---
	# A duplicate glyph puts the same symbol on the keypad twice — one correct, one
	# a wrong decoy — which no player can tell apart by sight (rune 1 and rune 5 were
	# both a "+" until 2026-07-23). Compare the RENDERED geometry, not the segment
	# lists: rune 1's "1-7" and rune 5's "1-4"+"4-7" draw the identical line, so
	# rasterize each rune to a fine point set and compare those.
	var seen := {}
	for i in GateConsole.RUNES.size():
		var pts := {}
		for s in GateConsole.RUNES[i]:
			var a := GateConsole.grid_point(int(s[0]))
			var b := GateConsole.grid_point(int(s[1]))
			# Sample densely (spacing well under one cell) so the SAME line drawn as
			# one long segment vs two half-segments fills identical cells — otherwise
			# "1-7" (even cells only) reads as different from "1-4"+"4-7".
			for k in 201:
				var p := a.lerp(b, float(k) / 200.0)
				pts[Vector2i(roundi(p.x * 64.0), roundi(p.y * 64.0))] = true
		var keys := pts.keys()
		keys.sort()
		var key := str(keys)
		_ok(not seen.has(key), "rune %d is a distinct glyph (collides with rune %s)" % [i, str(seen.get(key, -1))])
		seen[key] = i

	# --- The console accepts only Krayt's sequence ---
	var con := GateConsole.new()
	add_child(con)
	con.entered.connect(func() -> void: _entered_fired = true)
	await get_tree().process_frame

	con._on_key(GateConsole.CODE[0])
	_ok(con._entered.size() == 1, "a correct key advances the entry")
	var wrong: int = (GateConsole.CODE[0] + 1) % GateConsole.RUNES.size()
	con._on_key(wrong)
	_ok(con._entered.is_empty(), "a wrong key clears the entry (you cannot fail, only restart)")

	for i in GateConsole.CODE.size():
		con._on_key(GateConsole.CODE[i])
	await get_tree().create_timer(0.6).timeout
	_ok(_entered_fired, "entering the full waking sequence emits `entered`")

	# --- The gate opens from closed, through the choreography, to traversable ---
	var gate := WayGate.create(Vector2.ZERO)
	add_child(gate)
	await get_tree().process_frame
	_ok(not gate.is_open() and gate.phase == WayGate.Phase.CLOSED, "a fresh gate is CLOSED")
	gate.begin_opening()
	_ok(gate.phase == WayGate.Phase.OPENING, "begin_opening moves to OPENING")
	gate.begin_opening()
	_ok(gate.phase == WayGate.Phase.OPENING, "a second begin_opening is a no-op")

	var waited := 0.0
	while not gate.is_open() and waited < 12.0:
		await get_tree().create_timer(0.3).timeout
		waited += 0.3
	_ok(gate.is_open(), "the opening choreography completes to a traversable gate")


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails.append(what)

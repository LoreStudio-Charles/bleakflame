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

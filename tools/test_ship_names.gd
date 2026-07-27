extends Node
## SHIP REGISTRIES — and the pointed absence of one.
##
##   <godot> --headless --path . res://tools/test_ship_names.tscn --quit-after 300

var _fails: Array[String] = []
var _checks := 0


func _ready() -> void:
	_case_the_authored_prefixes()
	_case_a_code_is_readable_back()
	_case_pirates_carry_no_registry()
	_case_a_callsign_beats_a_number()
	_case_names_are_not_all_the_same()

	if _fails.is_empty():
		print("test_ship_names: ALL PASS (%d checks)" % _checks)
	else:
		for f in _fails:
			printerr("  FAIL: %s" % f)
		printerr("test_ship_names: %d FAILED of %d checks" % [_fails.size(), _checks])
	get_tree().quit(0 if _fails.is_empty() else 1)


## The user's table, verbatim.
func _case_the_authored_prefixes() -> void:
	for pair in [["hauler", "GCT"], ["liner", "GVIT"], ["navy", "GCN"], ["guardian", "GEU"]]:
		var got := ShipNames.registry(str(pair[0]))
		_ok(got.begins_with(str(pair[1])),
			"a %s registers as %s… (got %s)" % [pair[0], pair[1], got])
		_ok(got.length() == str(pair[1]).length() + ShipNames.CODE_LEN,
			"...with a %d-character code (got %s)" % [ShipNames.CODE_LEN, got])
		_ok(ShipNames.is_registered(got), "...and reads as registered")


## A registry you cannot read back to somebody over a comm is not a registry. The
## ambiguous glyphs are omitted for the same reason real tail numbers omit them.
func _case_a_code_is_readable_back() -> void:
	var bad := ""
	for _i in 200:
		var code := ShipNames.registry("hauler").substr(3)
		for ch in code:
			if ch in "IO01":
				bad = code
	_ok(bad == "", "no registry code contains I, O, 0 or 1 (found '%s')" % bad)


## THE ABSENCE IS THE CHARACTER. A licensed ship has an authority behind it; a pirate has
## noise. You can tell what you are looking at before the hull resolves.
func _case_pirates_carry_no_registry() -> void:
	# NOT a claim about LENGTH. A scramble runs 6-8 characters and GCT+5 is also 8, so a
	# length rule fails about one time in three — and it was never the real signal anyway.
	# What says "unlicensed" is the missing PREFIX: no authority behind it, nothing to file
	# a complaint against. That is the claim, so that is what is asserted.
	for _i in 60:
		var n := ShipNames.scrambled()
		_ok_quiet(not ShipNames.is_registered(n),
			"a pirate carries no registry prefix (got %s)" % n)
		_ok_quiet(n.length() >= 6, "...and is still long enough to read as a mark (%s)" % n)
	_ok(true, "60 scrambled names carry no registry prefix")


## "Or for daring elites+ their callsign" (user). A name is EARNED — and this is the
## Nemesis premise in the naming layer: you die to something with a name, and a smear of
## characters is precisely what you forget.
func _case_a_callsign_beats_a_number() -> void:
	_ok(ShipNames.for_role("pirate", "The Recluse") == "The Recluse",
		"an elite raider goes by its callsign, not a scramble")
	_ok(ShipNames.for_role("hauler", "Raptor") == "Raptor",
		"...and a callsign outranks even a registry")
	_ok(ShipNames.for_role("pirate", "") != "", "a nameless raider still gets something")
	_ok(not ShipNames.is_registered(ShipNames.for_role("pirate", "")),
		"...and it is not a registry")


## A fleet of identically-named ships would be worse than no names: the whole point of
## the loneliness beat is passing STRANGERS, plural.
func _case_names_are_not_all_the_same() -> void:
	var seen := {}
	for _i in 200:
		seen[ShipNames.registry("hauler")] = true
	_ok(seen.size() > 190, "200 haulers produce ~200 distinct marks (got %d)" % seen.size())

	# Seeded generators repeat, which is what lets a lane be stable across a reload.
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 4242
	b.seed = 4242
	_ok(ShipNames.registry("hauler", a) == ShipNames.registry("hauler", b),
		"the same seed names the same ship — a fleet can be stable across a reload")


func _ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(what)


## For loops that would otherwise report 120 identical passes.
func _ok_quiet(cond: bool, what: String) -> void:
	if not cond:
		_checks += 1
		_fails.append(what)

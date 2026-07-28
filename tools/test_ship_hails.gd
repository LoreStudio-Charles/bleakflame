extends SceneTree
## THE ROAD HAS PEOPLE ON IT (docs/cinder_reach_campaign.md, beat 4 — the loneliness).
##
## The beat's instrument is the friendlies roster, and the doc names what it needs:
## "one-line hails that answer politely and fly on — without that, 'together but alone'
## reads as 'some ships went past.'"
##
##   <godot> --headless --path . --script res://tools/test_ship_hails.gd

var _f := 0
var _n := 0


func _init() -> void:
	# ROLE COMES OFF THE REGISTRY MARK, so nothing has to be stored or kept in step.
	for role in ShipNames.PREFIX:
		var mark: String = str(ShipNames.PREFIX[role]) + "4K7B2"
		_ok(ShipHails.role_of(mark) == str(role),
			"%s reads as a %s" % [mark, role])
	_ok(ShipHails.role_of("X9QZ4M") == "",
		"an unregistered hull belongs to no set — nobody stamped it")

	# A MARK IS NATION + ROLE (user, 2026-07-28: G Galean, CT Cargo Transport, VIT
	# Vitality Insured Transport, CN Confederate Navy, EU Enforcement Unit). The shorthand
	# table and the rule must not drift, because the next nation is authored by adding a
	# NATION entry and would silently disagree with a hand-written prefix.
	for role in ShipNames.ROLE_CODE:
		_ok(ShipNames.PREFIX.get(role, "") == ShipNames.prefix(str(role)),
			"%s's mark is its nation + its role code (%s)" % [role, ShipNames.prefix(str(role))])
	_ok(ShipNames.PREFIX.size() == ShipNames.ROLE_CODE.size(),
		"every role in the table has a code and vice versa")

	# EVERY REGISTERED ROLE HAS A VOICE. A licensed hull that falls through to the
	# unregistered set answers a polite hail with "Wrong frequency, friend" — which is
	# exactly what a GVIT liner did until this caught it.
	for role in ShipNames.PREFIX:
		_ok(ShipHails.LINES.has(str(role)),
			"a %s can answer as a %s, not as unregistered noise" % [role, role])

	# A WRITTEN VOICE WAITING FOR ITS CALLSIGN. The lower-rate passenger class exists in
	# the fiction and has no prefix yet (user), so its lines live in LINES with nothing
	# routing to them. Asserted BOTH ways: the writing must not be tidied away as dead
	# data, and it must not be wired up before the user has named the class — an
	# invented prefix reads as canon the moment it ships.
	_ok(not (ShipHails.LINES.get("budget_liner", []) as Array).is_empty(),
		"the cheap crossing's voice is kept, waiting for a callsign")
	_ok(not ShipNames.ROLE_CODE.has("budget_liner"),
		"...and nothing routes to it yet, because the class is still unnamed")

	# THE SAME SHIP ALWAYS SAYS THE SAME THING. A stranger who answers differently every
	# time you raise them is a slot machine, not somebody you passed.
	for mark in ["GCT4K7B2", "GEU91XQ4", "GCNZZ123", "X9QZ4M"]:
		var first := ShipHails.line(mark)
		for i in 20:
			if ShipHails.line(mark) != first:
				_ok(false, "%s changed its answer between hails" % mark)
				break
		_ok(true, "%s keeps its voice across 20 hails" % mark)

	# ...AND DIFFERENT SHIPS DO NOT ALL SOUND THE SAME, or the road is one person.
	var heard := {}
	for i in 40:
		heard[ShipHails.line("GCT%05d" % i)] = true
	_ok(heard.size() > 1, "haulers do not share one voice (%d distinct)" % heard.size())

	# EVERY LINE ANSWERS AND CLOSES. Nothing may end in a question, because an invitation
	# to keep talking makes the long road sociable, which is the opposite of the beat.
	for role in ShipHails.LINES:
		for line in ShipHails.LINES[role]:
			_ok(not str(line).strip_edges().ends_with("?"),
				"a %s line answers rather than asking: %s" % [
					role if role != "" else "unregistered", str(line).substr(0, 40)])

	# THE ADDRESS IS HONEST: an unregistered mark is NAMED as unregistered rather than
	# having its noise printed at the player as though it were a callsign.
	_ok("unregistered" in ShipHails.reply("X9QZ4M"),
		"an unlicensed hull is named as one")
	_ok("unregistered" not in ShipHails.reply("GCT4K7B2"),
		"...and a licensed one is not")
	_ok(ShipHails.reply("", "Kestrel").begins_with("Kestrel"),
		"a nameless contact falls back to its hull rather than an empty address")

	if _f == 0:
		print("test_ship_hails: ALL PASS (%d checks)" % _n)
	else:
		printerr("test_ship_hails: %d FAILED of %d" % [_f, _n])
	quit(0 if _f == 0 else 1)


func _ok(cond: bool, what: String) -> void:
	_n += 1
	if not cond:
		_f += 1
		printerr("  FAIL: %s" % what)

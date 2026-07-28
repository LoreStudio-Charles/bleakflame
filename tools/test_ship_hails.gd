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

	# NO PREFIX MAY BE A PREFIX OF ANOTHER. role_of() matches with begins_with, so an
	# ambiguous pair would misroute silently to whichever key the dictionary yields
	# first — and the marks are getting denser: GCVT joined GCT this session, and the
	# user has said other nations and races bring their own. GCVT is safe (G-C-V vs
	# G-C-T) but "safe by inspection" is exactly what stops being true at the fifth
	# nation, so it is checked rather than eyeballed.
	for a in ShipNames.PREFIX.values():
		for b in ShipNames.PREFIX.values():
			if str(a) == str(b):
				continue
			_ok(not str(a).begins_with(str(b)),
				"%s is not swallowed by %s — role_of matches on begins_with" % [a, b])

	# THE CHEAP CROSSING IS WIRED. GCVT — Common Vital Transport (user, 2026-07-28) —
	# and the pairing with GVIT is the point: the same cargo, carried cheap.
	_ok(ShipNames.PREFIX.get("common_liner", "") == "GCVT",
		"the cheap crossing has its callsign")
	_ok(ShipHails.role_of("GCVT4K7B2") == "common_liner",
		"...a GCVT reads as one, not as a GCT hauler")
	_ok(ShipHails.role_of("GCT4K7B2") == "hauler",
		"...and a GCT still reads as a hauler, not as a GCVT")
	_ok(not (ShipHails.LINES.get("common_liner", []) as Array).is_empty(),
		"...and the voice written for it survived the wait")

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

extends SceneTree
## Headless smoke test for pilot identity/backgrounds:
##   godot --headless --path . --script res://tools/test_pilot.gd

func _init() -> void:
	var failures := 0
	Pilot.reset()

	# Neutral defaults: no background, no bonuses.
	if Pilot.repair_mult() != 1.0 or Pilot.scan_mult() != 1.0 \
			or Pilot.kill_xp_mult() != 1.0 or Pilot.sell_mult() != 1.0 \
			or Pilot.turn_mult() != 1.0 or Pilot.traverse_mult() != 1.0 \
			or Pilot.starting_credits() != 0:
		print("FAIL: fresh pilot should have neutral traits")
		failures += 1

	# Every background exists, is unique, and moves exactly one dial.
	var seen := {}
	for b in Pilot.BACKGROUNDS:
		if seen.has(b.id):
			print("FAIL: duplicate background id ", b.id)
			failures += 1
		seen[b.id] = true
		Pilot.background = b.id
		var moved := 0
		for v in [Pilot.repair_mult(), Pilot.scan_mult(), Pilot.kill_xp_mult(),
				Pilot.sell_mult(), Pilot.turn_mult(), Pilot.traverse_mult()]:
			if absf(v - 1.0) > 0.0001:
				moved += 1
		if Pilot.starting_credits() > 0:
			moved += 1
		if moved != 1:
			print("FAIL: background %s moves %d dials (want exactly 1)" % [b.id, moved])
			failures += 1

	# Sanitizers: names never empty, bios never over the cap.
	# Family name is free text, may be blank; only trims + caps length.
	if Pilot.sanitize_name("  Vex  ") != "Vex" or Pilot.sanitize_name("   ") != "":
		print("FAIL: name sanitizer")
		failures += 1
	var long_bio := ""
	for i in 40:
		long_bio += "0123456789"
	if Pilot.sanitize_bio(long_bio).length() != Pilot.BIO_MAX:
		print("FAIL: bio cap: ", Pilot.sanitize_bio(long_bio).length())
		failures += 1

	# Callsign is pooled: a bad handle snaps to the pool head, a good one holds.
	if Pilot.sanitize_callsign("NotAHandle") != Pilot.CALLSIGNS[0] \
			or Pilot.sanitize_callsign("Ghost") != "Ghost":
		print("FAIL: callsign sanitizer")
		failures += 1

	# Round trip, then corrupt entries rejected.
	Pilot.created = true
	Pilot.callsign = "Ghost"
	Pilot.family_name = "Vex"
	Pilot.background = "courier"
	Pilot.bio = "Flew packets. Owes Odessa."
	if Pilot.handle() != "Ghost" or Pilot.full_name() != "‘Ghost’ Vex":
		print("FAIL: name composition: ", Pilot.full_name())
		failures += 1
	var snap := Pilot.to_dict()
	Pilot.reset()
	Pilot.from_dict(snap)
	if not Pilot.created or Pilot.callsign != "Ghost" or Pilot.family_name != "Vex" \
			or Pilot.background != "courier" or Pilot.turn_mult() != 1.03:
		print("FAIL: pilot round trip")
		failures += 1
	# Pre-callsign save: single "name" migrates to family, callsign defaults.
	Pilot.from_dict({"created": true, "name": "Old Vet", "background": "bogus"})
	if Pilot.family_name != "Old Vet" or Pilot.callsign != Pilot.CALLSIGNS[0] \
			or Pilot.background != "":
		print("FAIL: legacy-save migration")
		failures += 1

	Pilot.reset()
	if failures == 0:
		print("test_pilot: ALL PASS")
	else:
		print("test_pilot: %d FAILURES" % failures)
	quit(failures)

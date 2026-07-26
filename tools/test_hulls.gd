extends SceneTree
## EVERY HULL ON DISK IS FLYABLE — checked against the .tres files themselves.
##   godot --headless --path . --script res://tools/test_hulls.gd
##
## THE BUG THIS EXISTS FOR (2026-07-25): the Universal Coupling — the rack every
## ability chip rides in — lived ONLY as a hand-edit inside the hull .tres files.
## generate_sample_data.gd never authored it, so the moment anyone re-seeded the
## data (which the docs actively tell you to do) the chip rack silently vanished
## from all nine hulls in the game. Nothing caught it: the model tests don't read
## .tres, and the dock UI just draws however many slots it finds.
##
## That is the shape of the whole class — the generated artifact drifting from
## the generator — so this walks the SHIPPED FILES rather than the code that
## writes them. If a regen breaks a hull, this goes red before a playtest does.
##
## Model layer only (no autoloads), so it runs under --script.

const HULL_DIR := "res://data/hulls"


func _init() -> void:
	var failures := 0
	var checked := 0

	for path in _hull_paths():
		var h: HullDef = load(path)
		if h == null:
			print("FAIL: %s did not load as a HullDef" % path)
			failures += 1
			continue
		checked += 1
		var name: String = h.display_name if h.display_name != "" else path.get_file()

		# --- THE COUPLING: one, and LAST ---
		# Last matters as much as present: hardpoint indices are serialized into
		# save files and SampleBuilds fit-maps, so a coupling inserted mid-list
		# would silently re-type every slot after it.
		var couplings := 0
		var last_is_coupling := false
		for i in h.hardpoints.size():
			if h.hardpoints[i].slot_type == HardpointDef.SlotType.COUPLING:
				couplings += 1
				last_is_coupling = (i == h.hardpoints.size() - 1)
		if couplings != 1:
			print("FAIL: %s has %d Universal Couplings (want exactly 1) — a hull with no coupling can hold no ability chips" % [name, couplings])
			failures += 1
		elif not last_is_coupling:
			print("FAIL: %s has its coupling mid-list; it must be APPENDED LAST or every slot index after it shifts" % name)
			failures += 1

		# --- ART BUDGET: the silhouette must fit the size band's canvas ---
		if not h.fits_art_budget():
			print("FAIL: %s overflows the %.0fu canvas for its size band" % [
				name, HullDef.world_budget(h.size_band)])
			failures += 1

		# --- FLYABILITY: a hull with no drive or no power is not a ship ---
		var kinds := {}
		for hp in h.hardpoints:
			kinds[hp.slot_type] = int(kinds.get(hp.slot_type, 0)) + 1
		for need in [HardpointDef.SlotType.ENGINE, HardpointDef.SlotType.REACTOR]:
			if not kinds.has(need):
				print("FAIL: %s has no %s hardpoint" % [name, HardpointDef.SlotType.keys()[need]])
				failures += 1

		if h.hull_hp <= 0.0:
			print("FAIL: %s has hull_hp %.1f" % [name, h.hull_hp])
			failures += 1
		if h.silhouette.is_empty():
			print("FAIL: %s has an empty silhouette — it would render as nothing" % name)
			failures += 1

		# --- TURRET SANITY ---
		# traverse is 360/mark deg/s (WeaponDef.traverse_speed), so mark is what
		# decides whether a mount can follow a fighter. A 360-degree ARC on a
		# high-mark mount is a capital battery that sweeps slowly on purpose;
		# that's legal. What is NOT legal is a mark outside I-V.
		for hp in h.hardpoints:
			if hp.mark < 1 or hp.mark > 5:
				print("FAIL: %s hardpoint '%s' is Mark %d (Mark I-V only)" % [name, hp.display_name, hp.mark])
				failures += 1

	# ---- EVERY AUTHORED BUILD IS LEGAL ----
	# NPC fits never pass through the dock's _fit_error, so an over-budget or
	# wrong-mark loadout on a pirate or a hauler reaches the sky unchallenged and
	# just quietly misbehaves. ShipStats.validate is the same rule set the refit
	# screen enforces on the player; hold the AI to it too.
	var builds := SampleBuilds.lane_builds()
	builds["trader_mule"] = SampleBuilds.trader_mule()
	builds["pirate_raider"] = SampleBuilds.pirate_raider()
	builds["pirate_brawler"] = SampleBuilds.pirate_brawler()
	builds["pirate_wasp"] = SampleBuilds.pirate_wasp()
	builds["pirate_vulture"] = SampleBuilds.pirate_vulture()
	builds["guardian_kestrel"] = SampleBuilds.guardian_kestrel()
	builds["guardian_sparrowhawk"] = SampleBuilds.guardian_sparrowhawk()
	builds["guardian_vulture"] = SampleBuilds.guardian_vulture()
	builds["galean_supercruiser"] = SampleBuilds.galean_supercruiser()
	builds["galean_supercruiser_elite"] = SampleBuilds.galean_supercruiser_elite()
	for i in SampleBuilds.count():
		builds["player_build_%d" % i] = SampleBuilds.get_build(i)

	var builds_checked := 0
	for label in builds:
		var b: ShipBuild = builds[label]
		if b == null:
			print("FAIL: build '%s' is null" % label)
			failures += 1
			continue
		builds_checked += 1
		for err in ShipStats.validate(b):
			print("FAIL: build '%s' — %s" % [label, err])
			failures += 1

	print("hulls checked: %d   builds checked: %d" % [checked, builds_checked])
	if checked == 0 or builds_checked == 0:
		print("FAIL: nothing was loaded — this suite is VACUOUS and proves nothing")
		failures += 1
	if failures == 0:
		print("test_hulls: ALL PASS")
		quit(0)
	else:
		print("test_hulls: %d FAILURE(S)" % failures)
		quit(1)


func _hull_paths() -> Array:
	var out: Array = []
	var dir := DirAccess.open(HULL_DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		# Exported builds rename .tres -> .remap; load() wants the original path.
		var name := f.trim_suffix(".remap")
		if name.ends_with(".tres"):
			out.append("%s/%s" % [HULL_DIR, name])
	out.sort()
	return out

extends SceneTree
## Headless smoke test for the affix system:
##   godot --headless --path . --script res://tools/test_affixes.gd
## Verifies forge determinism (the save format depends on it), value/name
## behavior, and the roll table's grade gates.

func _init() -> void:
	var failures := 0

	var vk2: WeaponDef = load("res://data/components/weapons/vk2_autocannon.tres")
	var forged := Affixes.forge(vk2, ["sharpened", "featherlight"])
	var rebuilt := Affixes.rebuild("res://data/components/weapons/vk2_autocannon.tres",
		["sharpened", "featherlight"])
	if absf(forged.damage - vk2.damage * 1.18) > 0.001:
		print("FAIL: sharpened damage: ", forged.damage)
		failures += 1
	if absf(forged.mass - vk2.mass * 0.72) > 0.001:
		print("FAIL: featherlight mass: ", forged.mass)
		failures += 1
	if forged.display_name != "Sharpened VK-2 Autocannon":
		print("FAIL: name: ", forged.display_name)
		failures += 1
	if absf(forged.damage - rebuilt.damage) > 0.0001 or forged.display_name != rebuilt.display_name \
			or forged.value() != rebuilt.value():
		print("FAIL: rebuild not deterministic")
		failures += 1
	if forged.value() <= vk2.value():
		print("FAIL: affixed value should exceed base: ", forged.value(), " vs ", vk2.value())
		failures += 1
	if forged.base_path != "res://data/components/weapons/vk2_autocannon.tres":
		print("FAIL: base_path: ", forged.base_path)
		failures += 1
	# The original must be untouched (duplicate, not mutation).
	if absf(vk2.damage - 5.0) > 0.001 or not vk2.affix_ids.is_empty():
		print("FAIL: base resource was mutated!")
		failures += 1

	# Ordnance-only affix must not roll on energy weapons.
	if "deeprack" in Affixes.eligible(vk2):
		print("FAIL: deeprack eligible on energy weapon")
		failures += 1
	var rockets: WeaponDef = load("res://data/components/weapons/bombard_rocket_pod.tres")
	if "deeprack" not in Affixes.eligible(rockets):
		print("FAIL: deeprack missing on ordnance")
		failures += 1

	# Flotsam always carries a drawback; Experimental rolls 2-3 positives.
	var scrap: ReactorDef = load("res://data/components/reactors/scrap_cell_pile.tres")
	for i in 20:
		var rolled := Affixes.roll_for_drop(scrap)
		var has_drawback := false
		for id in rolled.affix_ids:
			if Affixes.is_drawback(id):
				has_drawback = true
		if scrap.grade == Grades.Grade.FLOTSAM and not has_drawback:
			print("FAIL: Flotsam rolled without drawback")
			failures += 1
			break
	var twinlance: WeaponDef = load("res://data/components/weapons/twinlance_pulse.tres")
	var aegis: DefenseDef = load("res://data/components/defense/aegis_composite.tres")
	for i in 20:
		var rolled := Affixes.roll_for_drop(aegis)   # Experimental
		var positives := 0
		for id in rolled.affix_ids:
			if not Affixes.is_drawback(id):
				positives += 1
		if positives < 2:
			print("FAIL: Experimental rolled only %d positives" % positives)
			failures += 1
			break

	# Save round-trip: the entry format is {base, affixes} -> rebuild.
	# (SaveGame itself can't compile under --script mode — no autoloads —
	# so this mirrors its logic; the real functions are one call each.)
	var entry := {"base": forged.base_path, "affixes": Array(forged.affix_ids)}
	var back := Affixes.rebuild(str(entry["base"]), entry["affixes"])
	if back == null or back.display_name != forged.display_name \
			or absf(back.damage - forged.damage) > 0.0001 or back.value() != forged.value():
		print("FAIL: save entry round-trip")
		failures += 1
	if not twinlance.affix_ids.is_empty() or twinlance.resource_path == "":
		print("FAIL: clean gear should carry a resource_path and no affixes")
		failures += 1

	if failures == 0:
		print("AFFIX TESTS: all passed")
	else:
		print("AFFIX TESTS: %d FAILURES" % failures)
	quit(1 if failures > 0 else 0)

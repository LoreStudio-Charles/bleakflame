extends SceneTree
## Headless test for the GROUND GEAR schema (docs/ground_combat.md):
##   godot --headless --path . --script res://tools/test_ground_gear.gd
## Model layer only (no autoloads in --script mode): the paperdoll rules on Pilot,
## the derived stat block, the starter kit, affix rolls, and the goblin drop pool.

func _init() -> void:
	var failures := 0

	# ---- catalog exists and parses ----
	var pistol: GroundGearDef = load("res://data/ground/scrap_pistol.tres")
	var rifle: GroundGearDef = load("res://data/ground/dune_rifle.tres")
	var vest: GroundGearDef = load("res://data/ground/scrapweave_vest.tres")
	var buckler: GroundGearDef = load("res://data/ground/scrap_buckler.tres")
	var belt: GroundGearDef = load("res://data/ground/surveyor_belt.tres")
	if pistol == null or rifle == null or vest == null or buckler == null or belt == null:
		print("FAIL: ground gear catalog missing (run tools/generate_ground_gear.gd)")
		quit(1)
		return
	if not rifle.two_handed or rifle.slot_name() != "Main" or vest.slot_name() != "Chest":
		print("FAIL: catalog basics (rifle two-handed Main, vest Chest)")
		failures += 1

	# ---- bare character: the UNARMED floor ----
	# NOTE health/damage ride Pilot.hull_mult()/damage_mult() — the SAME per-level
	# combat-growth seam ships use (a level-1 pilot is already x1.01), so every
	# expectation here is multiplier-scaled, never raw.
	Pilot.reset()
	var bare := GroundStats.derive(Pilot.ground_gear_items())
	if absf(float(bare.max_health) - GroundStats.BASE_HEALTH * Pilot.hull_mult()) > 0.01 \
			or float(bare.mitigation) != 0.0 or bare.weapon != null \
			or not bool((bare.attack as Dictionary).melee):
		print("FAIL: bare character should be base health x growth, no mitigation, fists")
		failures += 1

	# ---- starter kit: once, and it arms + armors ----
	Pilot.ground_kit_granted = false
	Pilot.ensure_ground_kit()
	if Pilot.ground_item("Main") == null or Pilot.ground_item("Chest") == null:
		print("FAIL: starter kit should equip a Main weapon and a Chest piece")
		failures += 1
	var kitted := GroundStats.derive(Pilot.ground_gear_items())
	if float(kitted.mitigation) <= 0.0 or kitted.weapon == null \
			or bool((kitted.attack as Dictionary).melee):
		print("FAIL: kitted character should mitigate and carry a ranged weapon")
		failures += 1
	var main_before: GroundGearDef = Pilot.ground_item("Main")
	Pilot.ensure_ground_kit()   # second call must be a no-op
	if Pilot.ground_item("Main") != main_before:
		print("FAIL: ensure_ground_kit re-granted (must be once, ever)")
		failures += 1

	# ---- the two-hand rule, both ways ----
	var r1: Dictionary = Pilot.equip_ground(buckler)
	if not bool(r1.ok):
		print("FAIL: buckler should equip beside a one-handed pistol")
		failures += 1
	var r2: Dictionary = Pilot.equip_ground(rifle)
	if not bool(r2.ok) or not Pilot.offhand_locked():
		print("FAIL: rifle should equip and lock the off hand")
		failures += 1
	# The displaced pistol AND the shoved-out buckler both come back — nothing is lost.
	var out_names := []
	for it in r2.out:
		out_names.append((it as GroundGearDef).display_name)
	if r2.out.size() != 2 or not out_names.has(buckler.display_name):
		print("FAIL: two-hander must displace BOTH the old Main and the Offhand (got %s)" % [out_names])
		failures += 1
	var r3: Dictionary = Pilot.equip_ground(buckler)
	if bool(r3.ok) or str(r3.msg) == "":
		print("FAIL: equipping an Offhand under a two-hander must refuse, with a reason")
		failures += 1
	if Pilot.unequip_ground("Offhand") != null or not Pilot.offhand_locked():
		print("FAIL: unequipping the LOCK must not free the hand under a wielded two-hander")
		failures += 1
	var dropped := Pilot.unequip_ground("Main")
	if dropped == null or Pilot.offhand_locked():
		print("FAIL: dropping the two-hander should clear the off-hand lock with it")
		failures += 1

	# ---- derive reads the weapon + worn pieces ----
	Pilot.equip_ground(rifle)
	Pilot.equip_ground(belt)
	var armed := GroundStats.derive(Pilot.ground_gear_items())
	if absf(float((armed.attack as Dictionary).damage) - rifle.damage * Pilot.damage_mult()) > 0.01 \
			or float(armed.barrier) < belt.barrier - 0.01:
		print("FAIL: derived attack/barrier should read the equipped rifle + belt")
		failures += 1

	# ---- mitigation cap holds ----
	var stack := {}
	for slot in ["Head", "Chest", "Feet", "Pants", "Hands", "Waist"]:
		var g := GroundGearDef.new()
		g.ground_slot = GroundGearDef.SLOT_NAMES.find(slot)
		g.mitigation = 0.5
		stack[slot] = g
	var tank := GroundStats.derive(stack)
	if float(tank.mitigation) > GroundStats.MITIGATION_CAP + 0.001:
		print("FAIL: worn mitigation must clamp at the cap")
		failures += 1

	# ---- persistence: gear survives a save round-trip, rebuilt by the forge ----
	Pilot.equip_ground(vest)
	var snap := Pilot.to_dict()
	Pilot.reset()
	if Pilot.ground_item("Chest") != null:
		print("FAIL: reset should clear ground gear")
		failures += 1
	Pilot.from_dict(snap)
	var back: GroundGearDef = Pilot.ground_item("Chest")
	if back == null or absf(back.mitigation - vest.mitigation) > 0.001:
		print("FAIL: ground gear should survive a save round-trip")
		failures += 1

	# ---- weapon views: the art discovery is the def's own ----
	if pistol.weapon_views().is_empty() and ResourceLoader.exists("res://assets/ground/weapons/pistol.png"):
		print("FAIL: pistol art exists but weapon_views() found nothing")
		failures += 1
	var shiv: GroundGearDef = load("res://data/ground/scrap_shiv.tres")
	if shiv != null and not shiv.weapon_views().is_empty():
		print("FAIL: a shiv with no art_key should draw nothing")
		failures += 1

	# ---- ground affixes roll and rebuild deterministically ----
	var rolled_one := false
	for i in 40:
		var rolled := Affixes.roll_for_drop(vest)
		if not rolled.affix_ids.is_empty():
			rolled_one = true
			var again := Affixes.rebuild(rolled.base_path, rolled.affix_ids)
			if again is not GroundGearDef or absf((again as GroundGearDef).mitigation - (rolled as GroundGearDef).mitigation) > 0.0001:
				print("FAIL: affixed ground gear must rebuild identically from {base, affixes}")
				failures += 1
			break
	if not rolled_one:
		print("FAIL: 40 Flotsam rolls produced no affixes (Flotsam always draws a drawback)")
		failures += 1

	# ---- goblin drop pool paths are real ----
	# Mirrored from DustGoblin.DROP_POOL by hand: naming the class here would pull in
	# GroundCharacter, which touches autoloads — and --script mode has none.
	# test_ground_combat (scene mode) asserts the constant agrees with this list.
	for path in ["res://data/ground/scrap_shiv.tres", "res://data/ground/rag_hood.tres",
			"res://data/ground/work_gloves.tres"]:
		if not ResourceLoader.exists(path):
			print("FAIL: goblin drop pool names a missing resource: ", path)
			failures += 1

	Pilot.reset()
	if failures == 0:
		print("GROUND GEAR TESTS: all passed")
		quit(0)
	else:
		print("GROUND GEAR TESTS: %d FAILURE(S)" % failures)
		quit(1)

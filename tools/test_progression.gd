extends SceneTree
## Pilot progression math: levels from Wallet.xp, skill points (1 per 4 levels),
## profession-gated caps, combat growth, trader perk, save/load.
## Run: <godot> --headless --path . --script res://tools/test_progression.gd

func _init() -> void:
	var f := 0

	Pilot.reset()
	Wallet.xp = 0
	if Pilot.level() != 1:
		f += 1; print("FAIL: level at 0 xp = ", Pilot.level())
	if Pilot.xp_for_level(1) != 0:
		f += 1; print("FAIL: level 1 should be free, got ", Pilot.xp_for_level(1))
	if Pilot.xp_for_level(3) <= Pilot.xp_for_level(2):
		f += 1; print("FAIL: curve not increasing")

	Wallet.xp = Pilot.xp_for_level(2)
	if Pilot.level() != 2:
		f += 1; print("FAIL: level at xp_for_level(2) = ", Pilot.level())

	Wallet.xp = 999_999_999
	if Pilot.level() != Pilot.MAX_LEVEL:
		f += 1; print("FAIL: max level = ", Pilot.level())
	if Pilot.skill_points_total() != 15:
		f += 1; print("FAIL: points at cap should be 15, got ", Pilot.skill_points_total())

	# Base cap = 2 without a profession.
	Pilot.skills = {}
	if not (Pilot.raise_skill("gunnery") and Pilot.raise_skill("gunnery")):
		f += 1; print("FAIL: could not rank gunnery to base cap")
	if Pilot.raise_skill("gunnery"):
		f += 1; print("FAIL: raised gunnery past base cap without a profession")
	if Pilot.skill_rank("gunnery") != 2:
		f += 1; print("FAIL: gunnery rank = ", Pilot.skill_rank("gunnery"))

	# Guardian raises gunnery cap to 5.
	Pilot.join_profession("guardian")
	if Pilot.skill_cap("gunnery") != 5:
		f += 1; print("FAIL: guardian gunnery cap = ", Pilot.skill_cap("gunnery"))
	if not Pilot.raise_skill("gunnery"):
		f += 1; print("FAIL: could not rank past base cap under guardian")
	if Pilot.skill_rank("gunnery") != 3:
		f += 1; print("FAIL: gunnery rank after guardian = ", Pilot.skill_rank("gunnery"))

	# Combat growth: guardian tier 0.02 at level 60 -> hull mult 2.2.
	if absf(Pilot.hull_mult() - (1.0 + 60 * 0.02)) > 0.001:
		f += 1; print("FAIL: guardian hull_mult = ", Pilot.hull_mult())

	# Evasion from skill rank (0.05/rank).
	Pilot.skills = {"evasion": 3}
	if absf(Pilot.evasion() - 0.15) > 0.001:
		f += 1; print("FAIL: evasion = ", Pilot.evasion())

	# Trader perk: 0.5%/level -> 30% at 60.
	Pilot.join_profession("trader")
	if absf(Pilot.trade_buy_mult() - 0.70) > 0.001 or absf(Pilot.trade_sell_mult() - 1.30) > 0.001:
		f += 1; print("FAIL: trader mults ", Pilot.trade_buy_mult(), " ", Pilot.trade_sell_mult())
	# A combat profession has no trade perk.
	Pilot.join_profession("guardian")
	if absf(Pilot.trade_buy_mult() - 1.0) > 0.001:
		f += 1; print("FAIL: guardian should have no trade perk, got ", Pilot.trade_buy_mult())

	# Save / load round-trip.
	Pilot.skills = {"gunnery": 3, "evasion": 2}
	Pilot.profession = "guardian"
	var d := Pilot.to_dict()
	Pilot.reset()
	Pilot.from_dict(d)
	if Pilot.profession != "guardian" or Pilot.skill_rank("gunnery") != 3 or Pilot.skill_rank("evasion") != 2:
		f += 1; print("FAIL: save/load ", Pilot.profession, " ", Pilot.skills)
	if Pilot.skill_points_spent() != 5:
		f += 1; print("FAIL: spent points after load = ", Pilot.skill_points_spent())

	# ---- Ability gems (memorize into the [1]-[5] bar) ----
	Pilot.reset()
	# A fresh pilot's bar starts EMPTY now (autowire fills [1] only when a fit
	# actually grants an ability — no more phantom "scan" over a ship that can't).
	if Pilot.gem_at(0) != "":
		f += 1; print("FAIL: a new pilot's gem 0 should be empty, got ", Pilot.gem_at(0))
	# One-gem-per-ability: put scan in 0, then move it to 2 -> 0 must vacate.
	Pilot.set_gem(0, "scan")
	Pilot.set_gem(2, "cloak")
	if Pilot.gem_at(2) != "cloak":
		f += 1; print("FAIL: cloak not slotted, got ", Pilot.gem_at(2))
	Pilot.set_gem(2, "scan")
	if Pilot.gem_at(2) != "scan" or Pilot.gem_at(0) != "":
		f += 1; print("FAIL: one-gem-per-ability rule ", Pilot.gems)
	# Clear + first-empty.
	Pilot.clear_gem(2)
	if Pilot.gem_at(2) != "" or Pilot.first_empty_gem() != 0:
		f += 1; print("FAIL: clear/first_empty ", Pilot.gems)
	# Out-of-range and unknown-id are safe (unknown ids drop on load).
	Pilot.set_gem(9, "scan")   # no-op, must not crash
	Pilot.set_gem(1, "cloak")
	var gd := Pilot.to_dict()
	gd["gems"] = ["scan", "bogus_ability", "cloak", "", ""]
	Pilot.reset()
	Pilot.from_dict(gd)
	if Pilot.gem_at(0) != "scan" or Pilot.gem_at(1) != "" or Pilot.gem_at(2) != "cloak":
		f += 1; print("FAIL: gem load/sanitize ", Pilot.gems)

	print("test_progression: %s" % ("ALL PASS" if f == 0 else "%d FAILURES" % f))
	quit()

extends SceneTree
## Headless smoke test for the Research Lab:
##   godot --headless --path . --script res://tools/test_research.gd
## Verifies the docking calendar + artifact trickle, discovery-chain stage
## triggers and gating, tech tree rules, passives, and the save round-trip.
## No autoloads in --script mode — Research/PoiMap are statics, so this
## stays legal.


## Stands in for TestShip: on_dock only touches commodities.
class DummyShip:
	var commodities := {}

	func remove_commodity(key: String, qty: int) -> void:
		commodities[key] = commodities.get(key, 0) - qty
		if commodities[key] <= 0:
			commodities.erase(key)


func _init() -> void:
	var failures := 0
	Research.reset()
	var ship := DummyShip.new()

	# Dock 1 advances the day but fires NO rumor — rumors are overheard at
	# the bar (hear_rumor), never delivered by the dock itself.
	Research.on_dock(true, ship)
	if Research.day != 1:
		print("FAIL: day should advance on dock: ", Research.day)
		failures += 1
	if Research.chain_stage.get("wayfinder_core", 0) != 0:
		print("FAIL: docking alone must not fire rumors")
		failures += 1
	if not Research.rumor_ready():
		print("FAIL: a rumor should be waiting at the bar")
		failures += 1
	# One bar visit overhears the Wayfinder rumor; the Cinderheart rumor
	# must NOT be hearable yet (it requires the Wayfinder recovered).
	if Research.hear_rumor() == "":
		print("FAIL: bar visit should overhear the wayfinder rumor")
		failures += 1
	if Research.chain_stage.get("wayfinder_core", 0) != 1:
		print("FAIL: overheard rumor should advance the chain")
		failures += 1
	if Research.hear_rumor() != "" or Research.rumor_ready():
		print("FAIL: cinderheart rumor hearable before its prerequisite")
		failures += 1
	# The bar consumed its pending note (it displays the text itself).
	if not Research.pending_notes.is_empty():
		print("FAIL: overheard rumor left a duplicate pending note")
		failures += 1
	if Research.active_leads() != ["wayfinder_core"]:
		print("FAIL: leads list: ", Research.active_leads())
		failures += 1

	# Triangulation: three first-time surveys open the dig site.
	for i in 3:
		Research.note_rock_survey()
	if not Research.dig_site_open("wayfinder_core"):
		print("FAIL: dig site should open after 3 surveys")
		failures += 1
	if not PoiMap.is_discovered("silent_beacon"):
		print("FAIL: dig site POI should be charted when the haul stage opens")
		failures += 1

	# Haul home: artifact consumed, recovered, trickle starts (1/day).
	ship.commodities["wayfinder_core"] = 1
	Research.on_dock(true, ship)
	if not Research.recovered.has("wayfinder_core") or ship.commodities.has("wayfinder_core"):
		print("FAIL: haul turn-in did not install the artifact")
		failures += 1
	var base := Research.insight
	Research.on_dock(true, ship)
	if absf(Research.insight - base - 1.0) > 0.001:
		print("FAIL: wayfinder trickle should pay 1/day: ", Research.insight - base)
		failures += 1
	# With the Wayfinder home, the bar can now surface the Cinderheart rumor.
	if Research.hear_rumor() == "" or Research.chain_stage.get("cinderheart", 0) != 1:
		print("FAIL: cinderheart rumor should be hearable once wayfinder is home")
		failures += 1

	# Fragment hunt is live only during its stage; 3 fragments advance it.
	if not Research.fragment_hunt_active("cinder_fragment"):
		print("FAIL: fragment hunt should be active")
		failures += 1
	ship.commodities["cinder_fragment"] = 3
	Research.on_dock(true, ship)
	if ship.commodities.has("cinder_fragment") or Research.fragment_hunt_active("cinder_fragment"):
		print("FAIL: fragments should be consumed and the hunt closed")
		failures += 1

	# Landing on the planet advances land_planet; the chain then goes cold.
	Research.on_dock(false, ship)
	if Research.stage("cinderheart").get("kind", "") != "cold":
		print("FAIL: cinderheart should be cold after the landing: ",
			Research.stage("cinderheart"))
		failures += 1
	Research.on_dock(false, ship)
	if Research.stage("cinderheart").get("kind", "") != "cold":
		print("FAIL: cold stage must be terminal")
		failures += 1

	# Tech gating: prerequisite/cost rejections, then clean unlocks.
	Research.insight = 0.0
	if Research.unlock("ship_2") == "" or Research.unlock("nonsense") == "" \
			or Research.unlock("ship_1") == "":
		print("FAIL: gating let something through with 0 Insight")
		failures += 1
	Research.insight = 60.0
	if Research.unlock("ship_1") != "" or Research.unlock("ship_1") == "":
		print("FAIL: ship_1 unlock / double-unlock")
		failures += 1
	if absf(Research.repair_cost_mult() - 0.75) > 0.001:
		print("FAIL: repair discount after ship_1")
		failures += 1
	if Research.unlock("ship_2") != "" or absf(Research.scan_time_mult() - 0.7) > 0.001:
		print("FAIL: ship_2 unlock or scan multiplier")
		failures += 1

	# Recipes follow their gating node.
	if not Research.unlocked_recipes().is_empty():
		print("FAIL: recipes unlocked without fab nodes")
		failures += 1
	Research.insight += 100.0
	Research.unlock("fab_1")
	if Research.unlocked_recipes().size() != 1:
		print("FAIL: fab_1 should unlock exactly the Bulwark recipe")
		failures += 1

	# The journal recorded every completed stage, day-stamped.
	if Research.journal.size() < 5 or int(Research.journal[0].day) != 1:
		print("FAIL: journal entries: ", Research.journal.size())
		failures += 1

	# Save round-trip: everything survives to_dict -> from_dict.
	var snapshot := Research.to_dict()
	var before_insight := Research.insight
	var before_day := Research.day
	Research.reset()
	Research.from_dict(snapshot)
	if absf(Research.insight - before_insight) > 0.001 or Research.day != before_day \
			or not Research.recovered.has("wayfinder_core") \
			or Research.stage("cinderheart").get("kind", "") != "cold" \
			or not Research.is_unlocked("fab_1") or Research.is_unlocked("fab_2") \
			or Research.journal.size() != int(snapshot.journal.size()):
		print("FAIL: save round-trip lost state")
		failures += 1
	# Corrupt entries must not crash or load.
	Research.from_dict({"recovered": ["bogus"], "chain_stage": {"fake": 9},
		"unlocked": ["fake"]})
	if not Research.recovered.is_empty() or not Research.chain_stage.is_empty() \
			or not Research.unlocked.is_empty():
		print("FAIL: corrupt save entries accepted")
		failures += 1

	# ---- RUMORS ARE NEVER SERVED TWICE (playtest, 2026-07-25) ----
	# The report: "her pip flashes and she offers 'What's the word?' again, but he had
	# already gotten that one." Two ways that could be a real bug — the same rumor text
	# coming back, or the ask re-opening after the chain moved on — plus the sneaky one:
	# a SAVE ROUND-TRIP losing chain_stage would re-arm the very first rumor.
	Research.reset()
	var heard: Array = []
	if not Research.rumor_ready():
		print("FAIL: the first rumor should be waiting at a fresh start")
		failures += 1
	heard.append(Research.hear_rumor())
	if Research.rumor_ready():
		print("FAIL: the bar still offers a rumor immediately after giving one")
		failures += 1
	# Round-trip RIGHT HERE — docking saves, and a lost chain_stage would re-arm rumor #1.
	Research.from_dict(Research.to_dict())
	if Research.rumor_ready():
		print("FAIL: a save round-trip re-armed a rumor that was already heard")
		failures += 1
	# The SECOND rumor unlocks only once the Wayfinder Core is actually recovered — and
	# when it does, it must be DIFFERENT text. (This re-arming is correct behaviour and is
	# most likely what was seen: a new lead, not a repeat.)
	Research.recovered.append("wayfinder_core")
	if not Research.rumor_ready():
		print("FAIL: recovering the core should open the next rumor")
		failures += 1
	heard.append(Research.hear_rumor())
	if heard[0] == heard[1] or str(heard[1]) == "":
		print("FAIL: the second rumor repeated the first (%s)" % [heard])
		failures += 1
	if Research.rumor_ready():
		print("FAIL: the bar offers a third rumor that does not exist")
		failures += 1
	# And every authored rumor is distinct, so no chain can ever echo another.
	var seen_flash := {}
	for cid in Research.CHAINS:
		for st in Research.CHAINS[cid].stages:
			if str(st.get("kind", "")) == "rumor":
				var f := str(st.get("flash", ""))
				if f == "" or seen_flash.has(f):
					print("FAIL: rumor text missing or duplicated in chain %s" % cid)
					failures += 1
				seen_flash[f] = true

	Research.reset()
	if failures == 0:
		print("test_research: ALL PASS")
	else:
		print("test_research: %d FAILURES" % failures)
	quit(failures)

extends SceneTree
## Headless smoke test for the venue-aware contract board:
##   godot --headless --path . --script res://tools/test_missions.gd
## Verifies the reciprocal trade fiction (circuits DOWN, food/water UP),
## per-venue offers, and per-contract turn-in venues.


class DummyShip:
	var commodities := {}

	func remove_commodity(key: String, qty: int) -> void:
		commodities[key] = commodities.get(key, 0) - qty
		if commodities[key] <= 0:
			commodities.erase(key)


func _init() -> void:
	var failures := 0
	MissionLog.offers = []
	MissionLog.active = []
	MissionLog.total_kills = 0
	MissionLog._next_template = 0
	MissionLog.ensure_offers()
	var ship := DummyShip.new()

	# Both boards fill; station gets 3, colony gets 3.
	var st := MissionLog.offers_for(true)
	var pl := MissionLog.offers_for(false)
	if st.size() < 3 or pl.size() < 3:
		print("FAIL: venue offer counts: station %d planet %d" % [st.size(), pl.size()])
		failures += 1

	# Trade fiction: no delivery ships FOOD down to the food planet; the
	# station->planet delivery carries CIRCUITS; planet->station carries
	# food/water. And the colony survey office wants Scan Data.
	var station_deliveries := []
	var planet_goods := {}
	for e in st:
		if e.m.type == "delivery":
			station_deliveries.append(e.m.good)
			if e.m.turn_in != "planet":
				print("FAIL: station delivery should turn in at the planet")
				failures += 1
	for e in pl:
		if e.m.type == "delivery":
			planet_goods[e.m.good] = true
	if station_deliveries.has("food"):
		print("FAIL: still shipping food TO the food planet")
		failures += 1
	if not station_deliveries.has("circuits"):
		print("FAIL: station should offer a circuits delivery to the colony")
		failures += 1

	# venue_ok routes each contract to its own turn-in dock.
	var circuits := {"type": "delivery", "good": "circuits", "n": 4, "turn_in": "planet"}
	var food := {"type": "delivery", "good": "food", "n": 4, "turn_in": "station"}
	var bounty := {"type": "bounty", "n": 2, "turn_in": "station"}
	if MissionLog.venue_ok(circuits, true) or not MissionLog.venue_ok(circuits, false):
		print("FAIL: circuits delivery should turn in at the planet only")
		failures += 1
	if not MissionLog.venue_ok(food, true) or MissionLog.venue_ok(food, false):
		print("FAIL: food delivery should turn in at the station only")
		failures += 1
	if not MissionLog.venue_ok(bounty, true):
		print("FAIL: bounty should turn in at the station")
		failures += 1
	# Legacy save (no turn_in) keeps the old rule: deliveries at the planet.
	if MissionLog.venue_ok({"type": "delivery", "good": "food", "n": 1}, true):
		print("FAIL: legacy delivery should default to planet turn-in")
		failures += 1

	# EITHER-desk turn-in: survey work files wherever the Scout reaches first.
	var either := {"type": "delivery", "good": "scan_data", "n": 3, "turn_in": "either"}
	if not MissionLog.venue_ok(either, true) or not MissionLog.venue_ok(either, false):
		print("FAIL: 'either' survey work should file at BOTH desks")
		failures += 1

	# Sella posts her survey work on the EXPLORER'S UNION board, not the colony's
	# public one — walking into her room is the point of the room.
	var union := MissionLog.offers_for(false, "Explorer's Union")
	var survey: Dictionary = {}
	for e in union:
		if e.m.get("good", "") == "scan_data":
			survey = e.m
	for e in pl:
		if e.m.get("giver", "") == "sella":
			print("FAIL: Sella's work leaked onto the public colony board")
			failures += 1
	if survey.is_empty():
		print("FAIL: colony should offer a scan-data survey contract")
		failures += 1
	else:
		ship.commodities["scan_data"] = int(survey.n)
		if not MissionLog.is_complete(survey, ship):
			print("FAIL: survey should complete when scan data is aboard")
			failures += 1

	MissionLog.offers = []
	MissionLog.active = []
	MissionLog._next_template = 0
	if failures == 0:
		print("test_missions: ALL PASS")
	else:
		print("test_missions: %d FAILURES" % failures)
	quit(failures)

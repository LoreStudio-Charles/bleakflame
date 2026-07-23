extends SceneTree
## THE OBJECTIVE TRACKER — model behaviour (user, 2026-07-23).
## Unifies campaign / contracts / leads, curated order + hidden, top drives the
## waypoint. --script safe: only static classes, and a stub ship for progress().
##   <godot> --headless --path . --script res://tools/test_mission_tracker.gd

var fails: Array[String] = []


class StubShip:
	var commodities := {}


func _init() -> void:
	var ship := StubShip.new()
	_reset_all()

	# --- Trackables gather from all live systems, in a stable order ---
	Quests.active["overdue"] = {"stage": 0, "count": 0}
	MissionLog.ensure_offers()
	_ok(MissionLog.accept(0), "accept a contract")
	_ok(MissionLog.accept(0), "accept a second contract")
	var items: Array = MissionTracker.trackables(ship)
	_ok(items.size() >= 3, "tracker gathers the campaign quest + both contracts (got %d)" % items.size())
	var keys := items.map(func(t): return str(t.key))
	_ok(keys.has("q:overdue"), "the active campaign quest is a trackable")
	var contract_keys := keys.filter(func(k): return str(k).begins_with("m:"))
	_ok(contract_keys.size() == 2, "both accepted contracts are trackables with stable uids")

	# --- Contract uid is stable across a reference re-fetch (save-round-trip proxy) ---
	var first_uid_key: String = contract_keys[0]
	MissionTracker.trackables(ship)                      # regather
	_ok(MissionTracker.trackables(ship).map(func(t): return str(t.key)).has(first_uid_key),
		"a contract keeps the same key across regathers (stable uid)")

	# --- Hidden toggles off the HUD but stays in the full list ---
	MissionTracker.toggle("q:overdue")
	_ok(MissionTracker.is_hidden("q:overdue"), "toggling a key hides it")
	var visible := MissionTracker.visible_tracked(ship).map(func(t): return str(t.key))
	_ok(not visible.has("q:overdue"), "a hidden objective drops off the HUD list")
	_ok(MissionTracker.trackables(ship).map(func(t): return str(t.key)).has("q:overdue"),
		"...but a hidden objective still lives in the full tracker list")
	MissionTracker.toggle("q:overdue")   # unhide for the ordering test
	_ok(not MissionTracker.is_hidden("q:overdue"), "toggling again un-hides it")

	# --- Reorder: move the campaign quest to the bottom, a contract becomes top ---
	MissionTracker.trackables(ship)   # canonicalise order
	var top_before: String = str(MissionTracker.trackables(ship)[0].key)
	MissionTracker.move(top_before, 99)   # shove it to the end
	var top_after: String = str(MissionTracker.trackables(ship)[0].key)
	_ok(top_after != top_before, "moving the top objective down promotes another to current")
	_ok(str(MissionTracker.trackables(ship)[-1].key) == top_before, "...and the moved one lands last")

	# --- HUD cap ---
	_ok(MissionTracker.visible_tracked(ship).size() <= MissionTracker.HUD_CAP,
		"the HUD list never exceeds HUD_CAP")

	# --- Waypoint: auto follows current; manual overrides ---
	PoiMap.register("station", "Station", Vector2.ZERO, "station", true)
	PoiMap.register("planetoid", "Colony", Vector2(1000, 0), "planet", true)
	# Make a station-turn-in contract the current objective.
	_make_only_current_a_station_contract(ship)
	PoiMap.waypoint_manual = false
	MissionTracker.sync_waypoint(ship)
	_ok(PoiMap.waypoint_id == "station",
		"auto waypoint points at the current objective's POI (got '%s')" % PoiMap.waypoint_id)
	PoiMap.set_waypoint("planetoid", true)
	MissionTracker.sync_waypoint(ship)
	_ok(PoiMap.waypoint_id == "planetoid", "a MANUAL waypoint is never overridden by the tracker")

	# --- Save round-trip preserves order + hidden ---
	MissionTracker.toggle(first_uid_key)
	var saved := MissionTracker.to_dict()
	var saved_order: Array = (MissionTracker.order as Array).duplicate()
	MissionTracker.reset()
	_ok(MissionTracker.order.is_empty(), "reset clears the tracker")
	MissionTracker.from_dict(saved)
	_ok(MissionTracker.order == saved_order, "order survives a save round-trip")
	_ok(MissionTracker.is_hidden(first_uid_key), "hidden set survives a save round-trip")

	if fails.is_empty():
		print("test_mission_tracker: ALL PASS")
	else:
		for f in fails:
			printerr("  FAIL: " + f)
		printerr("test_mission_tracker: %d FAILURES" % fails.size())
	quit(0 if fails.is_empty() else 1)


## Strip everything but one station-turn-in contract so `current` is deterministic.
func _make_only_current_a_station_contract(ship) -> void:
	MissionTracker.reset()
	Quests.active.clear()
	MissionLog.active.clear()
	# A bounty turns in at the station by default.
	MissionLog.active.append({"type": "bounty", "n": 1, "reward": 10, "start_kills": 0,
		"turn_in": "station", "desc": "Test bounty", "uid": 999})
	MissionTracker.trackables(ship)


func _reset_all() -> void:
	MissionTracker.reset()
	Quests.reset()
	MissionLog.offers = []
	MissionLog.active = []
	MissionLog.total_kills = 0
	MissionLog.next_uid = 1
	PoiMap.reset()


func _ok(cond: bool, what: String) -> void:
	if not cond:
		fails.append(what)

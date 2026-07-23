class_name SaveGame
## Dock-checkpoint persistence: the game saves whenever you dock or land, and
## loads once per app launch. Components serialize as their resource path
## (clean factory gear) OR as {base, affixes} (rolled items — Affixes.forge
## is deterministic, so base + ids rebuilds the identical item). Old saves
## with bare paths load unchanged. Dying mid-flight costs everything since
## your last dock; that is the design, not a bug.

const PATH := "user://bleakflame_save.json"

static var tutorial_done := false
## Berthing lessons: once a pilot lands a CLEAN approach the guided cinematic
## never plays again — only the earned hazard/crash outcomes do.
static var docking_taught := false
static var landing_taught := false
## Separate from the scrape lessons above: the FIRST wreck gets a modal from the
## harbourmaster/elder framing what just happened, then the crash beat plays.
## After that the beat plays alone — you already know why you're bouncing.
static var crash_taught := false
static var crater_taught := false
## Ids of the AUTHORED distress calls already heard, so each lands exactly once.
static var distress_heard: Array[String] = []
static var _loaded := false
static var _pending_cargo: Array[ComponentDef] = []
static var _pending_commodities := {}


static func save_game(ship: TestShip) -> void:
	var builds := {}
	for index in SampleBuilds._player_builds:
		builds[str(index)] = _build_to_dict(SampleBuilds._player_builds[index])
	var data := {
		"credits": Wallet.credits,
		"xp": Wallet.xp,
		"tutorial_done": tutorial_done,
		"docking_taught": docking_taught,
		"landing_taught": landing_taught,
		"crash_taught": crash_taught,
		"crater_taught": crater_taught,
		"distress_heard": distress_heard,
		"tutor_seen": Tutor.seen,
		"tutor_stalls": Tutor.stalls_to_list(),
		"current_ship": SampleBuilds.current,
		"owned_ships": SampleBuilds.owned,
		"builds": builds,
		"stash": _comp_paths(Stash.items),
		"stash_materials": Stash.commodities.duplicate(),
		"cargo": _comp_paths(ship.cargo),
		"commodities": ship.commodities,
		"missions_offers": MissionLog.offers,
		"missions_active": MissionLog.active,
		"missions_next_uid": MissionLog.next_uid,
		"total_kills": MissionLog.total_kills,
		"pois_discovered": PoiMap.discovered_ids(),
		"waypoint": PoiMap.waypoint_id,
		"waypoint_manual": PoiMap.waypoint_manual,
		"tracker": MissionTracker.to_dict(),
		"research": Research.to_dict(),
		"quests": Quests.to_dict(),
		"pilot": Pilot.to_dict(),
		"comms": Comms.to_dict(),
		"standing": Standing.to_dict(),
	}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "\t"))


## Loads file state into the statics. Runs once per app launch — in-session
## deaths keep in-session state (credits banked, kill counts) by design.
static func load_game() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if data == null:
		return

	Wallet.credits = int(data.get("credits", 0))
	Wallet.xp = int(data.get("xp", 0))
	tutorial_done = bool(data.get("tutorial_done", false))
	docking_taught = bool(data.get("docking_taught", false))
	landing_taught = bool(data.get("landing_taught", false))
	crash_taught = bool(data.get("crash_taught", false))
	crater_taught = bool(data.get("crater_taught", false))
	distress_heard.clear()
	for d in data.get("distress_heard", []):
		distress_heard.append(str(d))
	Tutor.seen.clear()
	for t in data.get("tutor_seen", []):
		Tutor.seen.append(str(t))
	Tutor.stalls_from_list(data.get("tutor_stalls", []))
	SampleBuilds.current = int(data.get("current_ship", 3))
	# Migration: older saves have no ownership — grandfather the active ship.
	SampleBuilds.owned.clear()
	for v in data.get("owned_ships", [SampleBuilds.current]):
		SampleBuilds.owned.append(int(v))
	if not SampleBuilds.owned.has(SampleBuilds.current):
		SampleBuilds.owned.append(SampleBuilds.current)
	for key in data.get("builds", {}):
		SampleBuilds._player_builds[int(key)] = _dict_to_build(data["builds"][key])
	Stash.items.assign(_load_comps(data.get("stash", [])))
	Stash.commodities.clear()
	for mkey in data.get("stash_materials", {}):
		Stash.commodities[str(mkey)] = int(data["stash_materials"][mkey])
	# The Vector Decoupling Computer was removed from the game entirely
	# (2026-07-19): its resource no longer exists, so old saves that carried
	# one simply lose it on load (the null-component path). Do NOT strip the
	# flight_decoupler tag here — Disconnected flight returns later on
	# exotic thrusters/hulls that carry the same tag.
	_pending_cargo.assign(_load_comps(data.get("cargo", [])))
	_pending_commodities = {}
	for key in data.get("commodities", {}):
		# Skip goods that no longer exist (e.g. the short-lived artifact
		# drops) — an unknown key would crash every display_name lookup.
		if TradeGoods.GOODS.has(key):
			_pending_commodities[key] = int(data["commodities"][key])
	MissionLog.offers = _sanitize_missions(data.get("missions_offers", []))
	MissionLog.active = _sanitize_missions(data.get("missions_active", []))
	MissionLog.total_kills = int(data.get("total_kills", 0))
	MissionLog.next_uid = int(data.get("missions_next_uid", 1))
	for id in data.get("pois_discovered", []):
		PoiMap.discover(str(id))
	PoiMap.waypoint_id = str(data.get("waypoint", ""))
	PoiMap.waypoint_manual = bool(data.get("waypoint_manual", false))
	MissionTracker.from_dict(data.get("tracker", {}))
	Research.from_dict(data.get("research", {}))
	Quests.from_dict(data.get("quests", {}))
	# Pre-pilot saves: mark created with defaults, or veterans would be
	# marched through registration they never signed up for.
	if data.has("pilot"):
		Pilot.from_dict(data.pilot)
	else:
		Pilot.created = true
		Pilot.callsign = Pilot.CALLSIGNS[0]
		Pilot.family_name = ""
	Comms.from_dict(data.get("comms", {}))
	Standing.from_dict(data.get("standing", {}))
	Standing.seed_from_xp()   # veterans dock into some Guardian respect


## Cargo/commodities live on the ship instance; apply after the ship exists.
static func restore_ship(ship: TestShip) -> void:
	if not _pending_cargo.is_empty():
		ship.cargo.assign(_pending_cargo)
		_pending_cargo.clear()
	if not _pending_commodities.is_empty():
		ship.commodities = _pending_commodities.duplicate()
		_pending_commodities = {}


static func _comp_entry(comp: ComponentDef) -> Variant:
	if not comp.affix_ids.is_empty() and comp.base_path != "":
		return {"base": comp.base_path, "affixes": Array(comp.affix_ids)}
	if comp.resource_path != "":
		return comp.resource_path
	return null


static func _entry_to_comp(entry) -> ComponentDef:
	if entry is String:
		return load(entry) if ResourceLoader.exists(entry) else null
	if entry is Dictionary:
		return Affixes.rebuild(str(entry.get("base", "")), entry.get("affixes", []))
	return null


static func _comp_paths(comps: Array) -> Array:
	var out := []
	for comp in comps:
		var entry = _comp_entry(comp)
		if entry != null:
			out.append(entry)
	return out


static func _load_comps(entries: Array) -> Array:
	var out := []
	for entry in entries:
		var comp := _entry_to_comp(entry)
		if comp != null:
			out.append(comp)
	return out


static func _build_to_dict(build: ShipBuild) -> Dictionary:
	var slots := {}
	for index in build.slots:
		var entry = _comp_entry(build.slots[index])
		if entry != null:
			slots[str(index)] = entry
	# Chips ride in the build, not on the Coupling component (shared-Resource
	# trap), so they serialise as their own list.
	var chip_paths := []
	for chip in build.chips:
		var e = _comp_entry(chip)
		if e != null:
			chip_paths.append(e)
	return {"hull": build.hull.resource_path, "slots": slots, "chips": chip_paths}


static func _dict_to_build(data: Dictionary) -> ShipBuild:
	var build := ShipBuild.new()
	build.hull = load(data["hull"])
	for key in data.get("slots", {}):
		var comp := _entry_to_comp(data["slots"][key])
		if comp != null:
			build.slots[int(key)] = comp
	for entry in data.get("chips", []):
		var chip := _entry_to_comp(entry)
		if chip is AbilityChipDef:
			build.chips.append(chip)
	return build


## Wipe everything: save file and all session statics. Caller reloads the
## scene. Exists so the tutorial can be demoed to family without file surgery.
static func reset_all_progress() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	tutorial_done = false
	docking_taught = false
	landing_taught = false
	crash_taught = false
	crater_taught = false
	distress_heard.clear()
	Tutor.reset()
	_pending_cargo.clear()
	_pending_commodities = {}
	Wallet.credits = 0
	Wallet.xp = 0
	Stash.items.clear()
	Stash.commodities.clear()
	SampleBuilds._player_builds.clear()
	SampleBuilds.owned.clear()
	SampleBuilds.owned.append(3)
	SampleBuilds.current = 3
	MissionLog.offers = []
	MissionLog.active = []
	MissionLog.total_kills = 0
	MissionLog.next_uid = 1
	MissionLog.ensure_offers()
	PoiMap.reset()
	MissionTracker.reset()
	Research.reset()
	Quests.reset()
	Pilot.reset()
	Comms.reset()
	Standing.reset()


## JSON turns ints into floats; mission math needs them back.
static func _sanitize_missions(raw: Array) -> Array:
	for m in raw:
		m["n"] = int(m.get("n", 1))
		m["reward"] = int(m.get("reward", 0))
		if m.has("start_kills"):
			m["start_kills"] = int(m["start_kills"])
		if m.has("uid"):
			m["uid"] = int(m["uid"])   # JSON floats back to ints for stable keys
	return raw

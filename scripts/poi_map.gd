class_name PoiMap
## Points of interest, fog-of-discovery, and the active waypoint.
## The rules (user design):
##   - POIs appear on the SYSTEM CHART only once discovered (fly near them).
##   - The radar/minimap NEVER shows chart POIs — except the one tagged as
##     the WAYPOINT, which shows as a rim-clamped bearing marker.
## Host-world state: migrates into the WorldState object when the net layer
## lands. Discovery persists via SaveGame.

static var pois: Array[Dictionary] = []
static var waypoint_id := ""
## MANUAL vs AUTO waypoint. The mission tracker auto-points the waypoint at the
## top tracked objective; a manual click-tag on the chart overrides that until
## the player clears it. `waypoint_manual` records which of the two owns the mark.
static var waypoint_manual := false
static var _discovered := {}   # id -> true; survives scene reloads


## Tag the waypoint. `manual` = the player picked it on the chart (locks out the
## auto tracker); auto callers (the tracker) pass false. Clearing (id "") always
## drops back to auto.
static func set_waypoint(id: String, manual: bool) -> void:
	waypoint_id = id
	waypoint_manual = manual and id != ""


## Scene setup: positions can differ per scene, discovery never resets.
static func clear_scene() -> void:
	pois.clear()


## `ephemeral` = a quest-ONLY marker (a scanned anomaly, an intercept point): there
## is nothing there except while a quest places it. These NEVER proximity-chart
## (flying past must not pin a permanent, irrelevant marker) and are shown/hidden
## explicitly by the quest system (Quests.refresh_pois) — visible only while their
## moment is live, gone the instant it ends (user rule, 2026-07-23).
static func register(id: String, display_name: String, pos: Vector2,
		kind: String, charted := false, ephemeral := false) -> void:
	if charted:
		_discovered[id] = true
	for p in pois:
		if p.id == id:
			p.pos = pos
			p["ephemeral"] = ephemeral
			return
	# charted = civilized infrastructure: always on the radar as a landmark.
	# Everything else is a SECRET — chart-only after discovery, radar-never
	# unless tagged as the waypoint (user rule).
	pois.append({"id": id, "name": display_name, "pos": pos, "kind": kind,
		"charted": charted, "ephemeral": ephemeral})


static func is_discovered(id: String) -> bool:
	return _discovered.has(id)


## Is a POI with this id registered in the current scene?
static func exists(id: String) -> bool:
	for p in pois:
		if p.id == id:
			return true
	return false


static func discover(id: String) -> void:
	_discovered[id] = true


static func discovered_ids() -> Array:
	return _discovered.keys()


## One new discovery per call (so each gets its own announcement). EPHEMERAL POIs
## are skipped entirely — a quest-only marker must never be revealed by flying past.
static func tick_discovery(player_pos: Vector2, radius: float) -> String:
	for p in pois:
		if p.get("ephemeral", false):
			continue
		if not _discovered.has(p.id) and player_pos.distance_to(p.pos) <= radius:
			_discovered[p.id] = true
			return p.name
	return ""


## Hide a POI again (the ephemeral rule: a quest marker vanishes when its moment
## ends). Drops the waypoint if it was pointing here so the radar doesn't keep a
## diamond on a place that no longer matters.
static func undiscover(id: String) -> void:
	_discovered.erase(id)
	if waypoint_id == id:
		waypoint_id = ""
		waypoint_manual = false


## Ids of every ephemeral (quest-only) POI — the set Quests.refresh_pois reconciles
## against the live quest stages each time quest state changes.
static func ephemeral_ids() -> Array:
	var out: Array = []
	for p in pois:
		if p.get("ephemeral", false):
			out.append(p.id)
	return out


static func waypoint_pos() -> Variant:
	for p in pois:
		if p.id == waypoint_id and _discovered.has(p.id):
			return p.pos
	return null


static func reset() -> void:
	_discovered.clear()
	waypoint_id = ""
	waypoint_manual = false

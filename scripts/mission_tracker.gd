class_name MissionTracker
## THE OBJECTIVE TRACKER (user, 2026-07-23). One curated, ordered list over all
## three objective systems — campaign quests, side contracts, and expedition
## leads — so the pilot picks what to chase, in what order.
##
##   - TOP OF THE LIST IS CURRENT: it drives the amber waypoint marker (reusing
##     PoiMap's one waypoint; a manual chart-tag still overrides — see sync_waypoint).
##   - HUD shows up to HUD_CAP visible objectives, each looking distinct by KIND.
##   - Toggle any objective off the HUD (still lives in the log); reorder with the
##     up/down arrows in the tracker panel.
##
## Only the player's ORDER (a list of keys) and the HIDDEN set are stored. The live
## objectives are resolved from the systems every call, so a completed one drops
## out and a freshly accepted one appends at the end. Keys:
##   q:<quest_id>   campaign      m:<uid>   contract      r:<lead_id>   expedition
## Persisted via SaveGame under "tracker". No autoloads referenced — --script safe.

const HUD_CAP := 4        # how many tracked objectives the HUD shows at once

static var order: Array = []      # trackable keys, player-defined order
static var hidden := {}            # key -> true (toggled off the HUD, still logged)


static func reset() -> void:
	order = []
	hidden = {}


# ---- key helpers ----
static func campaign_key(id: String) -> String: return "q:" + id
static func contract_key(m: Dictionary) -> String: return "m:%d" % MissionLog.uid_of(m)
static func lead_key(id: String) -> String: return "r:" + id


## Every LIVE objective, resolved to a uniform shape, in the player's order (with
## any not-yet-ordered ones appended at the end). Each entry:
##   {key, kind:"campaign"|"contract"|"lead", label, detail, poi, hidden}
## Reconciles `order`/`hidden` to the live key set as a side effect (stale keys of
## finished objectives fall away; this is the one place that housekeeping happens).
static func trackables(ship) -> Array:
	var found := {}
	var live_order: Array = []      # discovery order, for stable append of new keys

	# 1) Campaign quests — the story spine.
	for id in Quests.active.keys():
		var qd: Dictionary = Quests.quest_def(id)
		if qd.is_empty():
			continue
		var st: Dictionary = Quests.stage_def(id)
		var key := campaign_key(id)
		found[key] = {"key": key, "kind": "campaign",
			"label": str(qd.get("title", id)),
			"detail": str(st.get("step", "")),
			"poi": _stage_poi(st)}
		live_order.append(key)

	# 2) Side contracts — bounty / recovery / delivery.
	for m in MissionLog.active:
		var key := contract_key(m)
		found[key] = {"key": key, "kind": "contract",
			"label": str(m.get("desc", str(m.get("type", "contract")).capitalize())),
			"detail": "%s  %d/%d" % [str(m.get("type", "")).to_upper(),
				MissionLog.progress(m, ship), int(m.get("n", 1))],
			# `count` is the BARE progress, separate from the sentence in `detail`, so a
			# compact surface (the HUD corner) can show "2/3" without printing the prose.
			"count": Vector2i(MissionLog.progress(m, ship), int(m.get("n", 1))),
			"poi": _contract_poi(m)}
		live_order.append(key)

	# 3) Expedition leads — artifact discovery chains in progress.
	for id in Research.active_leads():
		if not Research.CHAINS.has(id):
			continue
		var key := lead_key(id)
		found[key] = {"key": key, "kind": "lead",
			"label": str(Research.CHAINS[id].get("title", id)),
			"detail": Research.journal_line(id, ship),
			"count": Research.stage_progress(id, ship),
			"poi": str(Research.stage(id).get("poi", ""))}
		live_order.append(key)

	# Emit in the player's order, then any live key not yet ordered (append).
	var out: Array = []
	var seen := {}
	for k in order:
		if found.has(k) and not seen.has(k):
			out.append(found[k]); seen[k] = true
	for k in live_order:
		if not seen.has(k):
			out.append(found[k]); seen[k] = true

	# Housekeeping: canonicalise order to the live set, prune stale hidden keys.
	order = []
	for t in out:
		t["hidden"] = hidden.has(t.key)
		order.append(t.key)
	for k in hidden.keys():
		if not found.has(k):
			hidden.erase(k)
	return out


## The ordered objectives the HUD shows: not hidden, capped at HUD_CAP.
static func visible_tracked(ship) -> Array:
	var out: Array = []
	for t in trackables(ship):
		if t.hidden:
			continue
		out.append(t)
		if out.size() >= HUD_CAP:
			break
	return out


## The CURRENT objective — top of the visible list, or {} if nothing is tracked.
static func current(ship) -> Dictionary:
	var vis := visible_tracked(ship)
	return vis[0] if not vis.is_empty() else {}


## Point the waypoint at the current objective, UNLESS the player has manually
## tagged one on the chart. Called each frame from the HUD. Reusing the single
## amber waypoint (the user's choice) keeps the radar to one "go here" mark.
static func sync_waypoint(ship) -> void:
	if PoiMap.waypoint_manual:
		return
	var cur := current(ship)
	var poi := str(cur.get("poi", "")) if not cur.is_empty() else ""
	if poi != "" and PoiMap.exists(poi):
		PoiMap.waypoint_id = poi
	elif PoiMap.waypoint_id != "" and not PoiMap.exists(PoiMap.waypoint_id):
		PoiMap.waypoint_id = ""   # auto mark pointed at something no longer here


# ---- curation (called from the tracker panel) ----
static func toggle(key: String) -> void:
	if hidden.has(key):
		hidden.erase(key)
	else:
		hidden[key] = true


static func is_hidden(key: String) -> bool:
	return hidden.has(key)


## Move a key up (-1) or down (+1) in the player order.
static func move(key: String, delta: int) -> void:
	var i := order.find(key)
	if i < 0:
		return
	var j: int = clampi(i + delta, 0, order.size() - 1)
	if j == i:
		return
	order.remove_at(i)
	order.insert(j, key)


# ---- save / load ----
static func to_dict() -> Dictionary:
	return {"order": order.duplicate(), "hidden": hidden.keys()}


static func from_dict(d: Dictionary) -> void:
	order = (d.get("order", []) as Array).duplicate()
	hidden = {}
	for k in d.get("hidden", []):
		hidden[str(k)] = true


# ---- poi resolution ----
static func _stage_poi(st: Dictionary) -> String:
	var poi := str(st.get("poi", ""))
	if poi != "":
		return poi
	match str(st.get("venue", "")):
		"planet": return "planetoid"
		"station": return "station"
		"verge": return "verge"
	return ""


## Where a contract completes — its turn-in venue as a POI. "either" has no single
## place, so it carries no auto-marker (the pilot can tag one by hand).
static func _contract_poi(m: Dictionary) -> String:
	match str(m.get("turn_in", "planet" if m.get("type") == "delivery" else "station")):
		"station": return "station"
		"planet": return "planetoid"
		"verge": return "verge"
	return ""

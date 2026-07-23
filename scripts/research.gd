class_name Research
## The station Research Lab (user design 2026-07-19, revised same day):
##   - INSIGHT is the research currency. Scan Data trades in flat; ARTIFACTS
##     are unique one-off relics that, once recovered, yield Insight FOREVER —
##     1 per `rate_days` game days. Slow but forever.
##   - The CALENDAR advances one game day per docking (no real-world timers:
##     inactive play must never out-earn flying).
##   - Artifacts are NEVER drops. Each is found through a DISCOVERY CHAIN:
##     a rumor overheard at the station bar, then exploration — surveying,
##     mining fragments, landing on worlds — stage by stage until the relic
##     is unearthed and physically hauled home (die with it aboard and it
##     waits at its site; the trip must be made).
##   - TECH TREES spend Insight. Researched gear is CRAFTED at the
##     Engineering Bay fabricator from mined ore, never sold as shop stock.
## Static like Wallet — survives scene reloads; persists via SaveGame.

const SCAN_DATA_INSIGHT := 2

## The unique artifacts. `rate_days` = game days per point of Insight.
const ARTIFACTS := {
	"wayfinder_core": {"name": "Wayfinder Core", "rate_days": 1,
		"desc": "The still-warm heart of a pre-collapse navigation beacon. It never stopped listening."},
	"cinderheart": {"name": "Cinderheart", "rate_days": 30,
		"desc": "The thing the fragments are fragments of. It remembers a world."},
}

## Discovery chains: ordered stages, index = the CURRENT objective.
## `flash` fires when that stage COMPLETES; `journal` is what the lab's
## LEADS list shows while it is current. Stage kinds:
##   rumor        — overheard on a station dock (one rumor per dock, and only
##                  when `requires_artifact` is already in the collection)
##   survey_rocks — survey `n` distinct asteroids with the scanner
##   fragments    — dock at the station holding `n` of commodity `key`
##   haul         — dock at the station with the artifact commodity aboard;
##                  entering this stage charts the dig-site POI
##   land_planet  — land on the planetoid
##   cold         — terminal for now; the finale content isn't built yet
const CHAINS := {
	"wayfinder_core": {
		"title": "Expedition: The Old Beacon",
		"giver": "Research Lab",
		"body": "Dockhands swear a pre-collapse Wayfinder beacon still whispers out in the Drift Belt. Nobody ever triangulated it, because nobody sober believed it. The lab believes it.",
		"rewards": "Wayfinder Core — +1 Insight per day, forever",
		"stages": [
			{"kind": "rumor",
				"flash": "RUMOR OVERHEARD: a pre-collapse beacon still whispers somewhere in the Drift Belt.",
				"vo": "odessa_rumor_beacon",   # Odessa speaks this in the bar (audio/vo/)
				"journal": ""},
			{"kind": "survey_rocks", "n": 3,
				"flash": "TRIANGULATED — the Silent Beacon dig site is on your chart.",
				"journal": "Triangulate the beacon's last signal: survey belt rocks (%d/%d)."},
			{"kind": "haul", "key": "wayfinder_core", "poi": "silent_beacon",
				"flash": "THE WAYFINDER CORE IS INSTALLED — the lab hums with old sky-charts.",
				"journal": "The Silent Beacon dig site is charted. Cut the core free and haul it to the station lab."},
		]},
	"cinderheart": {
		"title": "Expedition: A Cinder That Beats",
		"giver": "Research Lab",
		"body": "The Wayfinder's recovered logs mention — once, in a dead navigator's shorthand — 'a cinder that beats'. Whatever it meant, the aurite seams remember it.",
		"rewards": "Unknown",
		"stages": [
			{"kind": "rumor", "requires_artifact": "wayfinder_core",
				"flash": "RUMOR OVERHEARD: the Wayfinder's logs mention 'a cinder that beats'. Aurite rock holds fused fragments.",
				"journal": ""},
			{"kind": "fragments", "key": "cinder_fragment", "n": 3,
				"flash": "The fragments fuse in the lab clamp — and pull toward the planetoid.",
				"journal": "Mine Cinder Fragments out of aurite-bearing rock (%d/%d aboard)."},
			{"kind": "land_planet",
				"flash": "On the surface the fused shard points at empty sky — at a world on no chart.",
				"journal": "Land on the planetoid; the fused shard wants ground under it."},
			{"kind": "cold",
				"journal": "The shard strains toward a world beyond the charts. The trail is cold — for now."},
		]},
}

## Ordered tree -> node definitions. `requires` is a node id in the same tree.
const TREES := [
	{"name": "Fabrication", "nodes": [
		{"id": "fab_1", "name": "Fabricator Commission", "cost": 15, "requires": "",
			"desc": "Commission the Engineering Bay fabricator. Unlocks crafting: Bulwark Plating."},
		{"id": "fab_2", "name": "Alloy Formularies", "cost": 35, "requires": "fab_1",
			"desc": "Advanced casting formulae. Unlocks crafting: Hearth Fusion, Aegis Composite."},
	]},
	{"name": "Shipcraft", "nodes": [
		{"id": "ship_1", "name": "Nanite Repair Protocols", "cost": 20, "requires": "",
			"desc": "Self-directing repair nanites cut dock repair bills by 25%."},
		{"id": "ship_2", "name": "Signal Codex", "cost": 30, "requires": "ship_1",
			"desc": "Refined return filtering: survey scans complete 30% faster."},
	]},
	{"name": "Xenology", "nodes": [
		{"id": "xeno_1", "name": "Correlated Charting", "cost": 25, "requires": "",
			"desc": "Cross-reference archived sensor logs: every secret location in the system is charted."},
		{"id": "xeno_2", "name": "Umbral Attunement", "cost": 50, "requires": "xeno_1",
			"desc": "Read the dark between the returns: every completed scan yields +1 Scan Data."},
	]},
]

## Fabricator recipes, gated by Fabrication nodes. Output is an existing
## component resource; materials are commodities consumed from the hold.
const RECIPES := [
	{"id": "bulwark", "node": "fab_1", "name": "Bulwark Plating",
		"output": "res://data/components/defense/bulwark_plating.tres",
		"materials": {"ferrite_ore": 8, "cobalt_ore": 2}},
	{"id": "hearth", "node": "fab_2", "name": "Hearth Fusion",
		"output": "res://data/components/reactors/hearth_fusion.tres",
		"materials": {"cobalt_ore": 8, "aurite_ore": 2}},
	{"id": "aegis", "node": "fab_2", "name": "Aegis Composite",
		"output": "res://data/components/defense/aegis_composite.tres",
		"materials": {"ferrite_ore": 6, "aurite_ore": 4}},
]

static var insight := 0.0
static var day := 0
static var recovered: Array[String] = []
static var chain_stage := {}       # artifact id -> current stage index
static var survey_progress := 0    # counter for the active survey_rocks stage
static var unlocked := {}          # tech node id -> true
## Chain events that happened while docking; the dock screen shows and
## consumes them (every advancement must be VISIBLE).
static var pending_notes: Array[String] = []
## The story so far: every completed chain stage, stamped with the game day
## it happened. Shown as the Captain's Log on the Missions tab; StoryLog
## campaign missions will write here too. Persisted.
static var journal: Array[Dictionary] = []   # {day, text}


## Is any live lead asking the pilot to SCAN something? Drives the tutor that
## makes sure they own the means before they fly out to the belt and find they
## cannot do the job.
static func needs_scanner() -> bool:
	for id in CHAINS:
		if str(stage(id).get("kind", "")) == "survey_rocks":
			return true
	return false


static func stage(id: String) -> Dictionary:
	var stages: Array = CHAINS[id].stages
	var s: int = chain_stage.get(id, 0)
	return stages[s] if s < stages.size() else {}


static func _complete_stage(id: String) -> void:
	var st := stage(id)
	if st.has("flash"):
		pending_notes.append(st.flash)
		journal.append({"day": day, "text": st.flash})
	chain_stage[id] = chain_stage.get(id, 0) + 1
	# Entering a haul stage is when the dig site hits the chart.
	var next := stage(id)
	if next.has("poi"):
		PoiMap.discover(next.poi)


## One game day per docking. Recovered artifacts pay their trickle here.
static func advance_day() -> void:
	day += 1
	for id in recovered:
		insight += 1.0 / float(ARTIFACTS[id].rate_days)


## Called from ship.dock() BEFORE the checkpoint save, so consumed items and
## chain advances persist. Processes every dock-triggered stage kind.
static func on_dock(is_station: bool, ship) -> void:
	advance_day()
	for id in CHAINS:
		var st := stage(id)
		match st.get("kind", ""):
			"fragments":
				if is_station and ship.commodities.get(st.key, 0) >= int(st.n):
					ship.remove_commodity(st.key, int(st.n))
					_complete_stage(id)
			"haul":
				if is_station and ship.commodities.get(st.key, 0) > 0:
					ship.remove_commodity(st.key, 1)
					recovered.append(id)
					_complete_stage(id)
			"land_planet":
				if not is_station:
					_complete_stage(id)


## Rumors are OVERHEARD, not delivered: they fire only when the player
## visits Ember Row (the station bar tab), one per visit. The bar displays
## the returned text itself, so the matching pending-note is consumed here
## rather than double-flashing on the next refresh.
## VO key of the last rumor Odessa delivered ("" = none) — so her line can be
## SPOKEN in her voice, not just printed. The bar reads it right after hear_rumor.
static var last_rumor_vo := ""


static func hear_rumor() -> String:
	last_rumor_vo = ""
	for id in CHAINS:
		var st := stage(id)
		if st.get("kind", "") == "rumor" and _rumor_ok(st):
			var text: String = st.flash
			last_rumor_vo = str(st.get("vo", ""))
			_complete_stage(id)
			pending_notes.erase(text)
			return text
	return ""


## True when a visit to the bar would overhear something new — the
## overview uses this to nudge the player toward the lounge.
static func rumor_ready() -> bool:
	for id in CHAINS:
		var st := stage(id)
		if st.get("kind", "") == "rumor" and _rumor_ok(st):
			return true
	return false


static func _rumor_ok(st: Dictionary) -> bool:
	var needed: String = st.get("requires_artifact", "")
	return needed == "" or recovered.has(needed)


## Called when the player surveys a not-yet-surveyed asteroid. Returns true
## if a triangulation chain counted it (the HUD echoes the progress).
static func note_rock_survey() -> bool:
	for id in CHAINS:
		var st := stage(id)
		if st.get("kind", "") == "survey_rocks":
			survey_progress += 1
			if survey_progress >= int(st.n):
				survey_progress = 0
				_complete_stage(id)
			return true
	return false


static func survey_hunt_active() -> bool:
	for id in CHAINS:
		if stage(id).get("kind", "") == "survey_rocks":
			return true
	return false


static func survey_progress_text() -> String:
	for id in CHAINS:
		var st := stage(id)
		if st.get("kind", "") == "survey_rocks":
			return "%d/%d" % [survey_progress, int(st.n)]
	return ""


## True while some chain wants this fragment commodity mined free.
static func fragment_hunt_active(key: String) -> bool:
	for id in CHAINS:
		var st := stage(id)
		if st.get("kind", "") == "fragments" and st.key == key:
			return true
	return false


## True while the artifact's dig site should exist in the world.
static func dig_site_open(id: String) -> bool:
	return stage(id).get("kind", "") == "haul"


## Chains the player has heard about but not finished — the LEADS list.
static func active_leads() -> Array:
	var out := []
	for id in CHAINS:
		if chain_stage.get(id, 0) > 0 and not recovered.has(id) \
				and not stage(id).is_empty():
			out.append(id)
	return out


static func journal_line(id: String, ship) -> String:
	var st := stage(id)
	match st.get("kind", ""):
		"survey_rocks":
			return st.journal % [survey_progress, int(st.n)]
		"fragments":
			return st.journal % [ship.commodities.get(st.key, 0), int(st.n)]
		_:
			return str(st.get("journal", ""))


static func take_notes() -> Array:
	var out := pending_notes.duplicate()
	pending_notes.clear()
	return out


## Unified quest-log entries (same shape Quests.log_entries produces), so
## expeditions and story quests render through one QuestLogView.
static func log_entries(ship) -> Array:
	var out := []
	for id in CHAINS:
		var s: int = chain_stage.get(id, 0)
		if s <= 0 or recovered.has(id) or stage(id).is_empty():
			continue
		out.append(_entry(id, s, false, ship))
	return out


static func completed_entries() -> Array:
	var out := []
	for id in recovered:
		out.append(_entry(id, (CHAINS[id].stages as Array).size(), true, null))
	return out


static func _entry(id: String, upto: int, done_quest: bool, ship) -> Dictionary:
	var chain: Dictionary = CHAINS[id]
	var done: Array[String] = []
	for j in mini(upto, (chain.stages as Array).size()):
		var st: Dictionary = chain.stages[j]
		if st.has("flash"):
			done.append(st.flash)
	return {"id": id, "title": chain.title, "giver": chain.giver,
		"body": chain.body, "done": done,
		"current": "" if done_quest else journal_line(id, ship),
		"rewards": chain.rewards, "done_quest": done_quest}


## Total passive income, in Insight per game day.
static func income_per_day() -> float:
	var total := 0.0
	for id in recovered:
		total += 1.0 / float(ARTIFACTS[id].rate_days)
	return total


static func find_node(id: String) -> Dictionary:
	for tree in TREES:
		for node in tree.nodes:
			if node.id == id:
				return node
	return {}


static func is_unlocked(id: String) -> bool:
	return unlocked.has(id)


## Returns "" on success, else the reason shown to the player (every
## rejection must be VISIBLE).
static func unlock(id: String) -> String:
	var node := find_node(id)
	if node.is_empty():
		return "Unknown project."
	if unlocked.has(id):
		return "Already researched."
	if node.requires != "" and not unlocked.has(node.requires):
		return "Requires %s first." % find_node(node.requires).name
	if insight < node.cost:
		return "Not enough Insight (%d needed)." % node.cost
	insight -= node.cost
	unlocked[id] = true
	_apply_effect(id)
	return ""


## One-shot effects fire at unlock; passive effects are read via the
## multiplier helpers below wherever the affected code runs.
static func _apply_effect(id: String) -> void:
	if id == "xeno_1":
		for p in PoiMap.pois:
			PoiMap.discover(p.id)


static func repair_cost_mult() -> float:
	return 0.75 if unlocked.has("ship_1") else 1.0


static func scan_time_mult() -> float:
	return 0.7 if unlocked.has("ship_2") else 1.0


static func scan_bonus() -> int:
	return 1 if unlocked.has("xeno_2") else 0


static func unlocked_recipes() -> Array:
	var out := []
	for r in RECIPES:
		if unlocked.has(r.node):
			out.append(r)
	return out


static func to_dict() -> Dictionary:
	return {"insight": insight, "day": day, "recovered": recovered.duplicate(),
		"chain_stage": chain_stage.duplicate(), "survey_progress": survey_progress,
		"unlocked": unlocked.keys(), "journal": journal.duplicate(true)}


static func from_dict(data: Dictionary) -> void:
	insight = float(data.get("insight", 0.0))
	day = int(data.get("day", 0))
	recovered.clear()
	for id in data.get("recovered", []):
		if ARTIFACTS.has(str(id)):
			recovered.append(str(id))
	chain_stage.clear()
	for id in data.get("chain_stage", {}):
		if CHAINS.has(str(id)):
			chain_stage[str(id)] = int(data.chain_stage[id])
	survey_progress = int(data.get("survey_progress", 0))
	journal.clear()
	for e in data.get("journal", []):
		journal.append({"day": int(e.get("day", 0)), "text": str(e.get("text", ""))})
	unlocked.clear()
	for id in data.get("unlocked", []):
		if not find_node(str(id)).is_empty():
			unlocked[str(id)] = true


static func reset() -> void:
	insight = 0.0
	day = 0
	recovered.clear()
	chain_stage.clear()
	survey_progress = 0
	unlocked.clear()
	pending_notes.clear()
	journal.clear()

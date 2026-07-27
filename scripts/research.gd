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

static var insight: float:
	get:
		return PlayerState.local.research_insight
	set(value):
		PlayerState.local.research_insight = value


## THE CALENDAR MOVED OUT (user, 2026-07-27): "no system should have a hard coupling
## with it so that whether it changes to any other system, we just get date from it and
## it advances as needed." It is GameClock now, and it is WORLD state -- the lab does not
## own what day it is any more than the market does.
static var recovered: Array:
	get:
		return PlayerState.local.research_recovered
	set(value):
		PlayerState.local.research_recovered = value


## artifact id -> current stage index
static var chain_stage: Dictionary:
	get:
		return PlayerState.local.research_chain_stage
	set(value):
		PlayerState.local.research_chain_stage = value


## counter for the active survey_rocks stage
static var survey_progress: int:
	get:
		return PlayerState.local.research_survey_progress
	set(value):
		PlayerState.local.research_survey_progress = value


## THE CATALOGUE — every subject this pilot has put on file, keyed by DATA KEY (a
## hull's resource_path, never its display name: player-facing strings rename, keys
## never).
##
## SCAN DATA IS KNOWLEDGE (user, 2026-07-27), so a subject pays ONCE. There was no
## per-target check of any kind before this: park inside the station sanctuary, hold
## a Guardian in the reticle and press [1] every 3.2s, and you minted Insight and
## credits forever without moving. The rock branch had already written the argument
## down — "re-scanning the same rock is not exploration" — and applied it to the
## triangulation counter but not to the payout.
## subject key -> true
static var catalogued: Dictionary:
	get:
		return PlayerState.local.research_catalogued
	set(value):
		PlayerState.local.research_catalogued = value


## tech node id -> true
static var unlocked: Dictionary:
	get:
		return PlayerState.local.research_unlocked
	set(value):
		PlayerState.local.research_unlocked = value


## Chain events that happened while docking; the dock screen shows and
## consumes them (every advancement must be VISIBLE).
static var pending_notes: Array:
	get:
		return PlayerState.local.research_pending_notes
	set(value):
		PlayerState.local.research_pending_notes = value


## The story so far: every completed chain stage, stamped with the game day
## it happened. Shown as the Captain's Log on the Missions tab; StoryLog
## campaign missions will write here too. Persisted.
## {day, text}
static var journal: Array:
	get:
		return PlayerState.local.research_journal
	set(value):
		PlayerState.local.research_journal = value


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
		# A COMPLETION READS AS A COMPLETION (playtest, 2026-07-25: "quest completion should
		# be more obvious"). These lines used to arrive in the same amber prose as every
		# other dockside notice, so finishing a stage looked identical to being told the
		# weather. The tick marks it; a rumor is the one kind that OPENS rather than closes
		# something, so it keeps the plain voice.
		var text: String = st.flash
		if str(st.get("kind", "")) != "rumor":
			text = "✔  " + text
		pending_notes.append(text)
		journal.append({"day": GameClock.now(), "text": text})
	chain_stage[id] = chain_stage.get(id, 0) + 1
	# Entering a haul stage is when the dig site hits the chart.
	var next := stage(id)
	if next.has("poi"):
		PoiMap.discover(next.poi)


## One game day per docking. Recovered artifacts pay their trickle here.
## ARTIFACTS PAY OUT OVER TIME, so this SUBSCRIBES to the clock rather than being called
## from inside it. GameClock knows nothing about artifacts or Insight, which is what lets
## it be replaced wholesale; installed collections accrue for however much time passed,
## so a clock that jumps (a realtime one resuming after a week) pays correctly instead of
## paying once.
static func _on_time_passed(units: int) -> void:
	var elapsed_days := float(units) / float(GameClock.DAY)
	for id in recovered:
		insight += elapsed_days / float(ARTIFACTS[id].rate_days)


## Wire the payout to the clock exactly once, whoever gets here first.
static var _clocked := false

static func ensure_clocked() -> void:
	if _clocked:
		return
	_clocked = true
	GameClock.on_tick(_on_time_passed)


## Called from ship.dock() BEFORE the checkpoint save, so consumed items and
## chain advances persist. Processes every dock-triggered stage kind.
static func on_dock(is_station: bool, ship) -> void:
	ensure_clocked()
	GameClock.advance()
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
static var last_rumor_vo: String:
	get:
		return PlayerState.local.research_last_rumor_vo
	set(value):
		PlayerState.local.research_last_rumor_vo = value


## Which expedition the last rumor opened — so the bar can NAME it. Every rumor is
## worded differently, but the ASK is always "What's the word?", and a player who has
## heard one before reasonably reads a second offer as the game repeating itself
## (playtest, 2026-07-25). Naming the expedition it opens settles that instantly.
static var last_rumor_chain: String:
	get:
		return PlayerState.local.research_last_rumor_chain
	set(value):
		PlayerState.local.research_last_rumor_chain = value


static func hear_rumor() -> String:
	last_rumor_vo = ""
	last_rumor_chain = ""
	for id in CHAINS:
		var st := stage(id)
		if st.get("kind", "") == "rumor" and _rumor_ok(st):
			var text: String = st.flash
			last_rumor_vo = str(st.get("vo", ""))
			last_rumor_chain = str(CHAINS[id].get("title", ""))
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


## HAVE / NEED for a chain's current stage, or (-1, -1) when this stage isn't a count.
## Split out of journal_line (which buries the numbers inside a sentence) so the HUD can
## show a bare "2/3" on the tracker and a pickup can flash the same figure — playtest,
## 2026-07-25: "show a #/# when taking a new item, and the count on the tracker."
static func stage_progress(id: String, ship) -> Vector2i:
	var st := stage(id)
	match st.get("kind", ""):
		"survey_rocks":
			return Vector2i(survey_progress, int(st.n))
		"fragments":
			if ship == null:
				return Vector2i(-1, -1)
			return Vector2i(int(ship.commodities.get(st.key, 0)), int(st.n))
	return Vector2i(-1, -1)


## Which live chain (if any) is collecting `commodity_key` right now, plus the count it
## would read AFTER `gained` more. Returns {} when nothing wants it — so a pickup only
## announces progress when there is progress to announce.
static func collection_for(commodity_key: String, ship, gained := 0) -> Dictionary:
	for id in CHAINS:
		var st := stage(id)
		if str(st.get("kind", "")) == "fragments" and str(st.get("key", "")) == commodity_key:
			var need := int(st.n)
			var have: int = int(ship.commodities.get(commodity_key, 0)) + gained if ship != null else gained
			return {"id": id, "title": str(CHAINS[id].get("title", id)),
				"have": mini(have, need), "need": need}
	return {}


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
			# EPHEMERAL MARKERS ARE NOT DISCOVERIES. The "signal" sites exist only
			# while their beat is live and are shown/hidden by Quests.refresh_pois;
			# charting them here pinned four permanent markers to empty space, and
			# they persisted into the save. PoiMap.tick_discovery already honours
			# this flag -- this was the one path that did not.
			if bool(p.get("ephemeral", false)):
				continue
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


## File a subject. True the FIRST time it is entered — that return IS the discovery,
## so the caller pays out on it and nothing else needs to remember what was new.
static func catalogue(subject: String) -> bool:
	if subject == "" or catalogued.has(subject):
		return false
	catalogued[subject] = true
	return true


static func is_catalogued(subject: String) -> bool:
	return subject != "" and catalogued.has(subject)


static func to_dict() -> Dictionary:
	return {"insight": insight, "recovered": recovered.duplicate(),
		"chain_stage": chain_stage.duplicate(), "survey_progress": survey_progress,
		"unlocked": unlocked.keys(), "journal": journal.duplicate(true),
		"catalogued": catalogued.keys()}


static func from_dict(data: Dictionary) -> void:
	insight = float(data.get("insight", 0.0))
	recovered.clear()
	for id in data.get("recovered", []):
		if ARTIFACTS.has(str(id)):
			recovered.append(str(id))
	chain_stage.clear()
	for id in data.get("chain_stage", {}):
		if CHAINS.has(str(id)):
			chain_stage[str(id)] = int(data.chain_stage[id])
	survey_progress = int(data.get("survey_progress", 0))
	# Absent in saves from before the catalogue existed — an old pilot simply starts
	# with an empty one and re-earns the entries, which is the harmless direction.
	catalogued.clear()
	for key in data.get("catalogued", []):
		catalogued[str(key)] = true
	journal.clear()
	for e in data.get("journal", []):
		journal.append({"day": int(e.get("day", 0)), "text": str(e.get("text", ""))})
	unlocked.clear()
	for id in data.get("unlocked", []):
		if not find_node(str(id)).is_empty():
			unlocked[str(id)] = true


static func reset() -> void:
	insight = 0.0
	recovered.clear()
	chain_stage.clear()
	survey_progress = 0
	unlocked.clear()
	pending_notes.clear()
	journal.clear()
	catalogued.clear()   # a new pilot has seen nothing; the codex is theirs to fill

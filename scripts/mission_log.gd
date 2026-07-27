class_name MissionLog
## Session-persistent mission state (statics survive scene reloads, like the
## wallet). Three archetypes seed the loop: bounties (fight), recovery of
## stolen goods (fight+salvage), delivery (trade). All fiction points at the
## same pirates raiding the same route.

const MAX_ACTIVE := 2

static var offers: Array = []
static var active: Array:
	get:
		return PlayerState.local.mission_active
	set(value):
		PlayerState.local.mission_active = value
static var total_kills: int:
	get:
		return PlayerState.local.mission_total_kills
	set(value):
		PlayerState.local.mission_total_kills = value
## A monotonic id stamped on each accepted contract, so the mission tracker can
## reference a specific one across a save round-trip (two identical bounties are
## still distinct). Persisted; assigned lazily to legacy saves via uid_of().
static var next_uid: int:
	get:
		return PlayerState.local.mission_next_uid
	set(value):
		PlayerState.local.mission_next_uid = value

## Every contract has a face AND a place: it is OFFERED at `venue` and TURNED
## IN at `turn_in`. The trade route is reciprocal and physical — the station
## manufactures (circuits go DOWN to the colony), the colony grows (food/water
## come UP to the station). Same three mechanics (bounty/recovery/delivery),
## two boards, and freight that actually flows the right direction.
static var _templates := [
	# --- Station board (Harbormaster Ruel / Underwriter Voss) ---
	{"type": "bounty", "n": 3, "reward": 150, "giver": "ruel",
		"venue": "station", "turn_in": "station",
		"desc": "Suppression contract: destroy 3 pirates"},
	{"type": "recovery", "n": 2, "reward": 140, "giver": "voss",
		"venue": "station", "turn_in": "station",
		"desc": "Recover 2 crates of Stolen Goods from pirate wrecks"},
	{"type": "delivery", "n": 4, "good": "circuits", "reward": 120, "giver": "ruel",
		"venue": "station", "turn_in": "planet",
		"desc": "Deliver 4 Circuits down to the planet colony"},
	{"type": "bounty", "n": 2, "reward": 120, "giver": "voss",
		"venue": "station", "turn_in": "station",
		"desc": "Claims enforcement: destroy 2 raiders working the lane"},
	{"type": "recovery", "n": 3, "reward": 210, "giver": "ruel",
		"venue": "station", "turn_in": "station",
		"desc": "Repossess 3 crates of Stolen Goods — the board wants its cut back"},
	# --- Colony board (Elder Imari's freight + Cartographer Sella's surveys),
	# interleaved so the opening rotation shows variety: freight, survey,
	# combat. Sella buys Scan Data for CREDITS (the lab buys it for Insight —
	# the pilot chooses); she seeds the Scout / Explorer guild.
	{"type": "delivery", "n": 4, "good": "food", "reward": 120, "giver": "imari",
		"venue": "planet", "turn_in": "station",
		"desc": "Run 4 Food up to the station markets"},
	{"type": "delivery", "n": 3, "good": "scan_data", "reward": 95, "giver": "sella",
		"venue": "planet", "turn_in": "either", "board": "Explorer's Union",
		"desc": "Log 3 Scan Data — file at either desk"},
	{"type": "bounty", "n": 2, "reward": 130, "giver": "imari",
		"venue": "planet", "turn_in": "planet",
		"desc": "Clear 2 pirates off the colony's approach lanes"},
	{"type": "delivery", "n": 3, "good": "water", "reward": 100, "giver": "imari",
		"venue": "planet", "turn_in": "station",
		"desc": "Haul 3 Water up to the station cisterns"},
	{"type": "delivery", "n": 5, "good": "scan_data", "reward": 175, "giver": "sella",
		"venue": "planet", "turn_in": "either", "board": "Explorer's Union",
		"desc": "Chart the far dark — 5 Scan Data, file at either desk"},
	# --- The Dig (Doug Diggs, the Verge). ALL mining work, turned in to him.
	{"type": "delivery", "n": 6, "good": "ferrite_ore", "reward": 110, "giver": "doug",
		"venue": "verge", "turn_in": "verge", "board": "The Dig",
		"desc": "Cut and haul 6 Ferrite Ore to The Dig"},
	{"type": "delivery", "n": 4, "good": "cobalt_ore", "reward": 190, "giver": "doug",
		"venue": "verge", "turn_in": "verge", "board": "The Dig",
		"desc": "Bring Doug 4 Cobalt Ore — he has a buyer waiting"},
	{"type": "delivery", "n": 3, "good": "aurite_ore", "reward": 340, "giver": "doug",
		"venue": "verge", "turn_in": "verge", "board": "The Dig",
		"desc": "3 Aurite Ore. Doug pays hard for the good seam"},
	{"type": "bounty", "n": 2, "reward": 160, "giver": "doug",
		"venue": "verge", "turn_in": "verge", "board": "The Dig",
		"desc": "Clear 2 pirates off the Verge — nobody cuts rock under guns"},
	{"type": "delivery", "n": 2, "good": "scan_data", "reward": 70, "giver": "sella",
		"venue": "planet", "turn_in": "either", "board": "Explorer's Union",
		"desc": "Sella's standing order: 2 Scan Data, any system, any time"},
	# --- The Speak's Easy (Vyper, the Rust Shoal). THE ONLY LADDER FROM VYPER'S BANNER
	# TO THE PRIVATEER COMMISSION. Standing credits through faction_for -> led_by("vyper")
	# -> "privateer", which is the same ledger Krayt's truce and Vyper's banner move: the
	# commission is earned by doing Shoal work, and there was previously no way to do any.
	# The fence sits ABOVE this (Friendly, 100) and the quartermaster above that
	# (commissioned) — a stranger at the bar could look at both and reach neither.
	#
	# Pay is better than the lawful boards and the work is worse, which is the whole
	# pitch. Descriptions stay mechanically honest: `bounty` counts ANY kill (progress()
	# reads total_kills), so Vyper asks for kills and pointedly does not ask whose.
	{"type": "recovery", "n": 3, "reward": 260, "giver": "vyper",
		"venue": "shoal", "turn_in": "shoal", "board": "The Speak's Easy",
		"desc": "Bring back 3 crates of Stolen Goods — off a wreck, off a hold, not our business"},
	{"type": "bounty", "n": 3, "reward": 240, "giver": "vyper",
		"venue": "shoal", "turn_in": "shoal", "board": "The Speak's Easy",
		"desc": "Thin the competition: 3 kills. The Shoal doesn't ask whose"},
	{"type": "delivery", "n": 4, "good": "circuits", "reward": 200, "giver": "vyper",
		"venue": "shoal", "turn_in": "shoal", "board": "The Speak's Easy",
		"desc": "4 Circuits, no manifest, no questions — the Shoal patches its own"},
	{"type": "recovery", "n": 2, "reward": 180, "giver": "vyper",
		"venue": "shoal", "turn_in": "shoal", "board": "The Speak's Easy",
		"desc": "2 crates of Stolen Goods. Somebody else already did the stealing"},
]
static var _next_template := 0


## Which guild a contract's turn-in credits: the GIVER's faction. Professions
## maps its leaders (ruel=guardian, imari=trader, sella=scout, doug=miner,
## lab=science, vyper=privateer even while the profession is hidden); Voss's
## underwriter work is the law's, so Guardian. Giver-less procedural contracts
## fall back to the old work-type flavour so nothing regresses.
static func faction_for(m: Dictionary) -> String:
	var giver := str(m.get("giver", ""))
	var led := Professions.led_by(giver)
	if led != "":
		return led
	if giver == "voss":
		return "guardian"
	return {"delivery": "trader", "bounty": "guardian",
		"recovery": "guardian"}.get(str(m.get("type", "")), "")


static func ensure_offers() -> void:
	_ensure_venue("station", 3)
	_ensure_venue("planet", 3)   # steward freight + approach bounties
	# Sella's desk fills SEPARATELY. Counting her postings against the colony's
	# public board would quietly starve it — moving survey work into her room
	# must not cost the colony its own contracts.
	_ensure_venue("planet", 2, "Explorer's Union")
	_ensure_venue("verge", 3, "The Dig")   # Doug's board, out at the freighter
	# Vyper's board at the Shoal. Stocked unconditionally like every other venue —
	# WHO MAY READ IT is the Speak's Easy's business (her banner gates the display), not
	# a reason to leave the shelf empty. Gating stock here instead would mean the board
	# is bare on the first dock after the banner and fills on the second.
	_ensure_venue("shoal", 3, "The Speak's Easy")


static func _ensure_venue(venue: String, target: int, board := "") -> void:
	var have := 0
	for o in offers:
		if str(o.get("venue", "station")) == venue 				and str(o.get("board", "")) == board:
			have += 1
	var guard := 0
	while have < target and guard < 60:
		guard += 1
		var t: Dictionary = _templates[_next_template % _templates.size()]
		_next_template += 1
		if str(t.get("venue", "station")) == venue 				and str(t.get("board", "")) == board:
			offers.append(t.duplicate())
			have += 1


## Offers for a venue, as [{m, index}] where index is the global offers index
## (the dock UI stores it so accept() targets the right one after filtering).
## Offers posted at this venue. `board` selects WHOSE board: "" is the public
## contract board (and excludes anything posted to a private one), or name a
## board to get only its listings. The Explorer's Union is Sella's own desk —
## survey work belongs there, not mixed into the colony's general postings.
static func offers_for(at_station: bool, board := "") -> Array:
	return offers_at("station" if at_station else "planet", board)


## Offers posted at a NAMED venue — the freighter's board asks by name.
static func offers_at(venue: String, board := "") -> Array:
	var out := []
	for i in offers.size():
		if str(offers[i].get("venue", "station")) != venue:
			continue
		if str(offers[i].get("board", "")) != board:
			continue
		out.append({"m": offers[i], "index": i})
	return out


static func accept(index: int) -> bool:
	if active.size() >= MAX_ACTIVE or index >= offers.size():
		return false
	var m: Dictionary = offers[index]
	offers.remove_at(index)
	if m.type == "bounty":
		m["start_kills"] = total_kills
	m["uid"] = next_uid
	next_uid += 1
	active.append(m)
	return true


## Stable per-contract id, assigned on the fly to any contract that predates the
## uid field (older saves) so the tracker never keys off a missing value.
static func uid_of(m: Dictionary) -> int:
	if not m.has("uid"):
		m["uid"] = next_uid
		next_uid += 1
	return int(m["uid"])


static func note_kill() -> void:
	total_kills += 1


static func progress(m: Dictionary, ship) -> int:
	match m.type:
		"bounty":
			return mini(total_kills - m.start_kills, m.n)
		"recovery":
			return mini(ship.commodities.get("stolen_goods", 0), m.n)
		"delivery":
			return mini(ship.commodities.get(m.good, 0), m.n)
	return 0


static func is_complete(m: Dictionary, ship) -> bool:
	return progress(m, ship) >= m.n


## Each contract turns in at its own venue. Old saves lack `turn_in` — fall
## back to the previous rule (deliveries at the planet, everything else at the
## station) so in-flight contracts still complete.
static func venue_ok(m: Dictionary, at_station: bool) -> bool:
	return venue_ok_at(m, "station" if at_station else "planet")


## Venue as a NAME, so places that aren't the station or the colony (The Dig,
## and any future outpost) can take a turn-in.
static func venue_ok_at(m: Dictionary, here: String) -> bool:
	var want := str(m.get("turn_in", "planet" if m.type == "delivery" else "station"))
	# "either" — SCAN work files at whichever desk you reach first. A Scout is by
	# definition somewhere else, and making them fly home to hand in readings
	# they took in deep space punished the exact playstyle the contract rewards.
	# It is also the standing FORK made physical: the same Scan Data is credits
	# from Sella at the colony or Insight from Dex at the station.
	return want == "either" or want == here


static func turn_in(index: int, ship) -> bool:
	var m: Dictionary = active[index]
	if not is_complete(m, ship):
		return false
	match m.type:
		"recovery":
			ship.remove_commodity("stolen_goods", m.n)
		"delivery":
			ship.remove_commodity(m.good, m.n)
	Wallet.credits += m.reward
	active.remove_at(index)
	Quests.note_contract()
	ensure_offers()
	return true


## ---- THE SHARED BOARD ACTIONS ----
##
## `accept`/`turn_in` above are the raw moves; these two are the WHOLE action a board
## performs, side effects included — taking work, and closing it out with the standing
## credit and the campaign hand-off that must follow it. They exist because the station's
## tabbed board and the ground's colony board would otherwise each re-implement the
## trailing effects, and the one that forgot a step would drift (the Scan-Data standing
## bug was exactly that shape).
##
## UI-FREE, like the rest of this file: they return {"ok": bool, "msg": String} and the
## caller decides how to show it. `here` is a venue NAME ("station"/"planet"/"verge") so
## outposts work; `tutorial_done` is PASSED IN rather than read, keeping this module
## SaveGame-free and loadable under `--script` (the same rule quests.gd follows).

## Take the offer at a GLOBAL offers index (the venue-filtered lists carry it as metadata).
static func take(index: int) -> Dictionary:
	if index < 0 or index >= offers.size():
		return {"ok": false, "msg": "That contract is no longer posted."}
	if not accept(index):
		return {"ok": false, "msg": "Mission log full (max %d active)." % MAX_ACTIVE}
	ensure_offers()
	return {"ok": true, "msg": "Contract accepted."}


## Close out the active contract at `index`, with everything that must follow it:
## payment (turn_in), the GIVER'S GUILD standing, and the campaign check that lets the
## next quest's giver greet you right here instead of after a re-dock.
static func complete(index: int, ship, here: String, tutorial_done: bool) -> Dictionary:
	if index < 0 or index >= active.size():
		return {"ok": false, "msg": "No such contract."}
	# Read the contract BEFORE turn_in consumes it, so it can still feed standing.
	var m: Dictionary = active[index]
	if not is_complete(m, ship):
		return {"ok": false, "msg": "%s isn't finished yet." % label(m)}
	if not venue_ok_at(m, here):
		return {"ok": false, "msg": "%s turns in elsewhere." % label(m)}
	if not turn_in(index, ship):
		return {"ok": false, "msg": "That contract can't be closed here."}
	# Standing follows the GIVER, not the work type: Sella's Scan Data runs are
	# `delivery` contracts, so a type-only map fed her survey work to the Traders.
	var fac := faction_for(m)
	if fac != "":
		Standing.add(fac, 2)
	Quests.check_new_work(here == "station", tutorial_done)
	return {"ok": true, "msg": "Contract complete. Payment received.", "faction": fac}


## "Suppression contract — Harbormaster Ruel". Old saves may lack a giver.
static func label(m: Dictionary) -> String:
	var giver: String = str(m.get("giver", ""))
	if giver == "":
		return m.desc
	return "%s — %s" % [m.desc, Npcs.display_name(giver)]

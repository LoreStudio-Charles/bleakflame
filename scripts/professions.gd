class_name Professions
## Commissions earned from faction leaders (docs/progression_professions.md).
## A profession does NOT grant skill points (those come from pilot levels); it
## (1) sets the per-level COMBAT growth tier (hull/armor/shield/damage),
## (2) raises the CAPS on its favoured skills so you can specialise,
## (3) gives non-combat roles an exclusive per-level PERK, and
## (4) unlocks major ABILITIES (maneuvers/cloak/gear — mostly seams for now).
## Leaders map to the built cast: Guardian=Ruel, Science=Dex(lab), Scout=Sella,
## Trader=Imari, Miner=Doug, Privateer=Vyper (Krayt's successor — Krayt dies at
## the system-1 finale). Each leader is the QUARTERMASTER for their profession's
## signature modules (`wares`): you buy cloak from Vyper, the Crystalline Array
## from Doug, etc. — never the open Armory. VENDOR RULE, docs/progression_professions.md.

const BASE_COMBAT_TIER := 0.01   # per-level hull/armor/shield/damage with NO profession
const PERK_PER_LEVEL := 0.005    # non-combat exclusive perk: 0.5%/level (30% at 60)

## IS THE CHOICE PERMANENT? Derived from the build, so it ships correct with no
## flag to remember: PERMANENT in a release export, SWAPPABLE in a debug build so
## a playtest can iterate on any profession without a fresh pilot. Same
## convention as the dev cheats (debug-only, auto-absent from release).
##
## The warning copy and the two-press confirm show EITHER way — only the lock
## changes — so the moment reads identically in testing and in the shipped game.
## A function, not a const: OS.is_debug_build() is not a compile-time constant.
static func commission_final() -> bool:
	return not OS.is_debug_build()

## SHOW WORK-IN-PROGRESS TREE NODES? False for the DEMO (2026-07-22, user):
## "polish things we plan to show rather than demo things that add questions."
## A node labelled "not yet built" is the tree advertising its own gaps — every
## viewer stops reading the design and starts asking about the roadmap.
##
## The nodes stay in TREES as the design record and reappear on their own the
## moment `built` flips true, so nothing has to be remembered or restored. Set
## this true to see the full designed tree while working on it.
const SHOW_UNBUILT := false

## WITHHELD ABILITIES — ONE SWITCH PER ABILITY, BOTH ENDS DERIVED.
##
## Naming an ability here removes it EVERYWHERE at once: its node vanishes from
## the office tree AND its chip comes off that commission's shelf. There is no
## way to withhold one half and leave the other exposed, which is the whole
## point — two independent flags is precisely how half a feature ships.
##
## The link is the ABILITY ID: tree nodes carry `id`, chips carry a `tag` that
## Abilities.id_for_tag resolves to the same id. Delete an entry to restore both
## halves together.
const WITHHELD := ["blackout"]


static func withheld(ability_id: String) -> bool:
	return ability_id != "" and WITHHELD.has(ability_id)


## Ability ids a component grants, via its tags. Empty for ordinary gear.
static func abilities_of(path: String) -> Array:
	var out := []
	if not ResourceLoader.exists(path):
		return out
	var comp: Resource = load(path)
	var tags = comp.get("tags")
	if tags == null:
		return out
	for t in tags:
		var aid := Abilities.id_for_tag(str(t))
		if aid != "":
			out.append(aid)
	return out


## Is this component withheld because an ability it grants is?
static func ware_withheld(path: String) -> bool:
	for aid in abilities_of(path):
		if withheld(str(aid)):
			return true
	return false

## Dev convenience: every office door unlocked regardless of standing, for
## inspecting a commission without grinding to it.
##
## DEFAULTS TO FALSE — it used to default to OS.is_debug_build(), which meant
## every playtest ran with all six doors open and a brand-new pilot at standing 0
## was greeted by "A door has opened" on their first landing. A dev aid that
## changes what a playtester sees is not an aid, it is a second, wrong build.
## The tests set it false explicitly, so they were asserting the shipping rule
## while the game ran the opposite — the gap that let this survive.
##
## Flip it here (or from a debug console) when you actually want to browse.
static var dev_unlock_offices := false

## Each leader's ROOM — the door behind their counter. `desc` sets the place,
## `pitch` is what they say to a visitor (before) and to a member (after);
## it is their voice, not the UI's.
const OFFICES := {
	"guardian": {
		"office": "The Harbormaster's Office",
		"desc": "A cramped room off the Landing Bay, every wall a berth schedule. "
			+ "The chair on your side of the desk has been sat in by a lot of pilots.",
		"visit": "Sit. I've watched how you fly, and I don't hand these out for being brave.",
		"member": "You're on the roster. Try to fly like it."},
	"privateer": {
		"office": "The Back Room",
		"desc": "Behind the Speak's Easy, past a door that does not look like one. "
			+ "Ledgers nobody will ever audit, and a chair facing the exit.",
		"visit": "You've got the look. Not the honest one — the other one.",
		"member": "Our kind of trouble. Keep the receipts, burn the manifest."},
	"miner": {
		"office": "The Assay Office",
		"desc": "A converted hopper-control booth aboard The Dig, knee-deep in core "
			+ "samples, every surface gritty with rock dust.",
		"visit": "You've hauled enough rock past me that I ought to make it official.",
		"member": "Guild's guild. Bring me the deep stuff."},
	"scout": {
		"office": "The Chart Room",
		"desc": "The back of the Explorer's Union, where the charts with holes in them "
			+ "are kept — the ones nobody has filled in yet.",
		"visit": "You keep coming back with places on your charts that weren't there.",
		"member": "The blank parts are yours now. Go argue with them."},
	"trader": {
		"office": "The Steward's Room",
		"desc": "A low room off the colony's landing pad, smelling of stored grain, "
			+ "manifests pinned in careful rows.",
		"visit": "You've kept your word on every crate. That is rarer than a fast ship.",
		"member": "The colony trusts you. Do not spend that."},
	"science": {
		"office": "The Back Lab",
		"desc": "Past the Research Lab's public bench, where the instruments that "
			+ "actually matter are kept behind glass.",
		"visit": "Your scan data is clean. Do you know how unusual clean data is?",
		"member": "Your bench is the second one. Do not touch the third."},
}

## THE ABILITY TREES — two BRANCHES per commission, the two ways to specialise.
## Kept out of LIST so the trees stay readable while they are being authored.
##
## `built: true` means the ability EXISTS and fires today; false means designed
## but not implemented, and the office draws it dimmed and says so out loud. A
## tree that silently lists vapour teaches players to distrust the whole page.
const TREES := {
	"guardian": [
		{"name": "Bulwark", "role": "Defense", "nodes": [
			{"tier": 1, "name": "Bulwark Brace", "id": "bulwark", "built": true,
				"desc": "Hardened stance: heavy damage reduction while braced."},
			{"tier": 2, "name": "Point-defense", "built": false,
				"desc": "Auto-engages incoming ordnance near the hull."},
			{"tier": 3, "name": "Taunt Beacon", "built": false,
				"desc": "Pulls hostile attention off your wing and onto you."}]},
		{"name": "Lance", "role": "Damage", "nodes": [
			{"tier": 1, "name": "Hyper-Conductive Lance", "id": "lance", "built": true,
				"desc": "Charged javelin of energy that tracks slightly. Hits hard."},
			{"tier": 2, "name": "Hyperslide+", "built": false,
				"desc": "Tighter drift, longer window, guns still live."}]},
	],
	"privateer": [
		{"name": "Blight", "role": "Damage over time", "nodes": [
			{"tier": 1, "name": "Withering Timbers", "id": "blight", "built": true,
				"desc": "Nanobot blight: damage every 6s for 30s. Drains minor energy."},
			{"tier": 2, "name": "Ambush Burst", "built": false,
				"desc": "First strike from concealment lands amplified."},
			{"tier": 3, "name": "Cloak Field", "id": "cloak", "built": true,
				"desc": "Go unseen. Breaks on fire."}]},
		{"name": "JINX", "role": "Defense", "nodes": [
			{"tier": 1, "name": "JINX Evasion Protocol", "id": "jinx", "built": true,
				"desc": "Doubles the evasion of allies in range."}]},
	],
	"miner": [
		{"name": "Tangle", "role": "Control", "nodes": [
			{"tier": 1, "name": "Tangle Shot", "id": "tangle_shot", "built": true,
				"desc": "Snares a target in cable and slag; slows and holds."},
			{"tier": 2, "name": "Blast Mining", "built": false,
				"desc": "Shaped charges crack a rock open in one pass."}]},
		{"name": "Array", "role": "Defense", "nodes": [
			{"tier": 1, "name": "Crystalline Array", "id": "crystal", "built": true,
				"desc": "On cooldown: destroys incoming missiles and ordnance."}]},
	],
	"scout": [
		{"name": "Warp", "role": "Control / mobility", "nodes": [
			{"tier": 1, "name": "Micro-Warp", "id": "warp_jump", "built": true,
				"desc": "Short instant jump toward the cursor."},
			{"tier": 2, "name": "Deep Sensor Sweep", "built": false,
				"desc": "Wide one-shot sweep; charts everything it touches."}]},
		{"name": "Killshot", "role": "Damage", "nodes": [
			{"tier": 1, "name": "Killshot", "id": "killshot", "built": true,
				"desc": "Cannot miss inside a 30° front cone. Heavy damage, half "
					+ "against shields. Extreme range; useless up close."},
			{"tier": 2, "name": "Disruptor Ping", "built": false,
				"desc": "Blinds a target's fire control briefly."}]},
	],
	"trader": [
		{"name": "Tender", "role": "Healing", "nodes": [
			{"tier": 1, "name": "Tender Drone", "id": "repair_drone", "built": true,
				"desc": "Launches a drone that circles an ally, healing every 3s for 30s."},
			# HIDDEN UNTIL AFTER DEMO LOCK (2026-07-22, user). The Trader's second
			# healing node is undesigned, and a tree that shows a player a
			# parenthetical placeholder looks unfinished rather than forthcoming.
			# Kept in source so the slot in the design is not forgotten; drop
			# `hidden` when it is designed.
			{"tier": 2, "name": "(second heal)", "built": false,
				"desc": "Undesigned — the direct, expensive one."},
			# HIDDEN FOR THE DEMO (2026-07-22, user). Blackout is built and works,
			# but it is a TIER-3 payoff for a healing tree whose middle is not
			# designed yet — shown alone above Tender Drone it reads as a jump
			# from nothing to a panic button and invites the roadmap question.
			# Its CHIP is pulled from the quartermaster to match (below): showing
			# an ability you cannot buy, or selling one the office never lists,
			# is the same inconsistency from either end.
			{"tier": 3, "name": "Blackout", "id": "blackout", "built": true,
				"desc": "Aggro dump: you vanish from threat tables. The healer's "
					+ "panic button once the healing itself starts pulling fire."}]},
		{"name": "Decoy", "role": "Control", "nodes": [
			{"tier": 1, "name": "Decoy Flare", "id": "decoy_flare", "built": true,
				"desc": "Throws a false contact; hostiles chase it instead of you."},
			{"tier": 2, "name": "Bribe Jettison", "built": false,
				"desc": "Buy your way out with cargo. Pirates are businessmen."}]},
	],
	"science": [
		{"name": "Repair Field", "role": "Healing", "nodes": [
			{"tier": 1, "name": "Repair Field", "id": "repair_field", "built": true,
				"desc": "Sustained field mends hull and armor for everyone inside it."},
			{"tier": 2, "name": "Weak-point Analyzer", "built": false,
				"desc": "Marks a target; your wing hits the seam."}]},
		{"name": "Overload", "role": "Control", "nodes": [
			{"tier": 1, "name": "Overload Pulse", "id": "overload", "built": true,
				"desc": "Burst that overloads nearby systems and drops shields."},
			{"tier": 2, "name": "Stasis Tractor", "built": false,
				"desc": "Pins a single target in place at range."}]},
	],
}

const LIST := [
	{"id": "guardian", "name": "Guardian", "leader": "ruel", "combat_tier": 0.02, "energy_regen": 1.00,
		"verb": "lane & bounty kills, defense contracts", "perk": "",
		"caps": {"gunnery": 5, "piloting": 5, "shield_tuning": 4, "evasion": 4},
		"abilities": ["Bulwark brace (Defense)", "Hyper-Conductive Lance (Damage)",
			"Point-defense", "Taunt beacon", "Hyperslide+ (tighter drift)"],
		"wares": ["res://data/components/chips/bulwark_projector.tres",
			"res://data/components/chips/conductive_lance.tres"]},
	# SECRET FOR THE DEMO (2026-07-22, user): the Privateer commission is fully
	# built but must not appear anywhere in the UI — no standing meter, no
	# invitation, no door. You cannot be offered it, and ideally you do not know
	# it exists until the Shoal's story hands it to you. `hidden` is honoured by
	# visible()/office_open(); everything downstream (caps, tier, wares, the
	# tree) keeps working the moment it is un-hidden or granted by script.
	{"id": "privateer", "hidden": true,
		"name": "Privateer", "leader": "vyper", "combat_tier": 0.02, "energy_regen": 1.00,
		"verb": "recoveries, salvage, grey work", "perk": "",
		"caps": {"gunnery": 5, "evasion": 5, "salvage": 5},
		"abilities": ["JINX Evasion Protocol (Defense)", "Withering Timbers (DoT)",
			"Cloak field (system 2)", "Ambush burst"],
		"wares": ["res://data/components/chips/jinx_protocol.tres",
			"res://data/components/chips/withering_timbers.tres",
			"res://data/components/chips/umbral_cloak_field.tres"]},
	{"id": "miner", "name": "Miner", "leader": "doug", "combat_tier": 0.015, "energy_regen": 1.15,
		"verb": "ore sold, rocks surveyed", "perk": "mining",
		"caps": {"prospecting": 5, "hull_discipline": 5, "salvage": 4},
		"abilities": ["Tangle Shot (Control/DoT)", "Crystalline Array (Defense)",
			"Blast mining"],
		"wares": ["res://data/components/chips/tangle_projector.tres",
			"res://data/components/chips/crystalline_array.tres"]},
	{"id": "scout", "name": "Scout", "leader": "sella", "combat_tier": 0.015, "energy_regen": 1.15,
		"verb": "POIs discovered, distance flown dark", "perk": "scan_value",
		"caps": {"piloting": 5, "evasion": 5, "prospecting": 4},
		"abilities": ["Micro-Warp (Control)", "Killshot (Damage)",
			"Disruptor ping", "Deep sensor sweep"],
		"wares": ["res://data/components/chips/warp_drive.tres",
			"res://data/components/chips/killshot_coilgun.tres"]},
	{"id": "trader", "name": "Trader", "leader": "imari", "combat_tier": 0.01, "energy_regen": 1.35,
		"verb": "deliveries, trade profit, route runs", "perk": "trade",
		"caps": {"hull_discipline": 5, "piloting": 4, "evasion": 4},
		"abilities": ["Tender Drone (Healing)", "Decoy Flare (Control)",
			"second healing module", "Blackout (T3)", "Bribe jettison"],
		# Tender Drone is the Mk-I signature (the HEALING role). Blackout's chip
		# STAYS LISTED HERE even while withheld: `wares()` filters it out through
		# Professions.WITHHELD. Deleting the path instead would mean removing the
		# ability from WITHHELD restored the tree node but NOT the chip — the same
		# half-exposed state the single switch exists to prevent, just inverted.
		"wares": ["res://data/components/chips/repair_drone.tres",
			"res://data/components/chips/decoy_flare.tres",
			"res://data/components/chips/blackout_transponder.tres"]},
	{"id": "science", "name": "Science Officer", "leader": "lab", "combat_tier": 0.01, "energy_regen": 1.35,
		"verb": "scan data, artifacts, surveys", "perk": "insight",
		"caps": {"prospecting": 5, "shield_tuning": 4, "piloting": 4},
		"abilities": ["Repair Field (Healing)", "Overload Pulse (Control)",
			"Weak-point analyzer", "Stasis tractor"],
		"wares": ["res://data/components/chips/repair_field.tres",
			"res://data/components/chips/overload_pulse.tres"]},
]


## Is this commission kept out of sight? Hidden professions are real in every
## mechanical sense — they are simply never ADVERTISED: absent from the standing
## meters, the faction screen and the invitation tutor, and their office door
## never opens on standing alone. Reveal = delete the flag, or grant it by script.
static func hidden(id: String) -> bool:
	return bool(def(id).get("hidden", false))


## Every commission the player is allowed to KNOW ABOUT. UI must iterate this,
## never LIST — LIST is the mechanical truth and includes the secrets.
static func visible() -> Array:
	var out := []
	for p in LIST:
		if not bool(p.get("hidden", false)):
			out.append(p)
	return out


static func def(id: String) -> Dictionary:
	for p in LIST:
		if p.id == id:
			return p
	return {}


static func display_name(id: String) -> String:
	return str(def(id).get("name", id))


static func leader(id: String) -> String:
	return str(def(id).get("leader", ""))


static func combat_tier(id: String) -> float:
	return float(def(id).get("combat_tier", BASE_COMBAT_TIER))


## ENERGY REGEN multiplier — the combat tier inverted. The support professions
## (Science, Trader) recharge fastest to offset their weak hull/armor/shield
## growth: they cannot take a hit, so they get to keep ACTING. Explicit per
## profession rather than derived from combat_tier, so the two can diverge.
static func energy_regen(id: String) -> float:
	return float(def(id).get("energy_regen", 1.0))


## Skill cap under this profession — its favoured skills go deeper; the rest
## stay at the base cap everyone gets.
static func cap_for(id: String, skill: String) -> int:
	return int(def(id).get("caps", {}).get(skill, Skills.BASE_CAP))


## The exclusive per-level perk name ("trade"/"scan_value"/"mining"/"insight"),
## or "" for combat professions (which spend their tier on raw combat instead).
static func perk(id: String) -> String:
	return str(def(id).get("perk", ""))


## Component paths this profession's leader sells as QUARTERMASTER — the only
## way to acquire signature modules (never the open Armory). Empty until the
## module's .tres + effect exist.
static func wares(id: String) -> Array:
	var out := []
	for path in def(id).get("wares", []):
		if not ware_withheld(str(path)):
			out.append(str(path))
	return out


## ---- The office behind the counter ----

static func office_name(id: String) -> String:
	return str(OFFICES.get(id, {}).get("office", "%s Commission" % display_name(id)))


static func office_desc(id: String) -> String:
	return str(OFFICES.get(id, {}).get("desc", ""))


## What the leader says to you in the room — different before and after.
static func pitch(id: String, member: bool) -> String:
	return str(OFFICES.get(id, {}).get("member" if member else "visit", ""))


## Branches with WITHHELD NODES stripped. The office must never render a node
## marked `hidden` — that is the difference between "designed, coming" and
## "we left a TODO on screen". UI calls this; TREES stays the design record.
static func branches(id: String) -> Array:
	var out := []
	for b in TREES.get(id, []):
		var nodes := []
		for n in b.get("nodes", []):
			if withheld(str(n.get("id", ""))):
				continue
			if not SHOW_UNBUILT and not bool(n.get("built", false)):
				continue
			nodes.append(n)
		if nodes.is_empty():
			continue
		var copy: Dictionary = (b as Dictionary).duplicate()
		copy["nodes"] = nodes
		out.append(copy)
	return out


## Which commission does this NPC lead, if any? Drives the office door: it is
## the leader who owns the room, so the lookup runs from the person outward.
static func led_by(npc: String) -> String:
	for p in LIST:
		if str(p.leader) == npc:
			return str(p.id)
	return ""


## Can this pilot see the door at all? Before an invitation is earned there is
## no office — the leader is just a person at their counter, and the commission
## is something you have not been offered yet. Members always keep their key.
static func office_open(id: String) -> bool:
	if Pilot.profession == id:
		return true          # it is yours; the secret is already out
	if hidden(id):
		return dev_unlock_offices
	return Standing.eligible(id) or dev_unlock_offices


## May this pilot still change commission? False in a shipped build (see
## commission_final) — you get a warning and you live with the choice.
static func can_switch() -> bool:
	return not commission_final()

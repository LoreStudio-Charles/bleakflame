class_name Pilot
## The player character: identity chosen at CREATION — name, portrait,
## background (a basic past with one minor trait), optional bio. This is
## deliberately light: professions/skills are EARNED in play via faction
## trust (docs/progression_professions.md); creation decides who you WERE.
## Portraits are drop-in art: assets/portraits/pilot/*.png (PixelLab).
## Statics persist via SaveGame ("pilot"); New Pilot wipes back to creation.

const BIO_MAX := 255
const NAME_MAX := 24

## The callsign is a HANDLE chosen from a fixed pool, distinct from the
## free-text family name. Fixed on purpose: a finite set means each handle
## can carry a pre-generated voice clip (audio/vo/callsign/<handle>.ogg),
## so NPCs and comms can SPEAK your callsign — impossible with free text.
## Silent until the clips are dropped; the handle still shows in text.
const CALLSIGNS := [
	"Ghost", "Cinder", "Reaper", "Wren", "Vesper", "Ash", "Vector", "Halo",
	"Nomad", "Drift", "Corvid", "Rook", "Sable", "Quill", "Onyx", "Harrow",
	"Pike", "Talon", "Ember", "Kestrel", "Mira", "Slag", "Tally", "Vex",
]

## Minor traits only — a nudge, never a build. Each hooks one existing
## site (repair bill, scan channel, kill XP, sell price, starting wallet).
const BACKGROUNDS := [
	{"id": "dockhand", "name": "Dockhand",
		"desc": "Raised in the Landing Bay rigging, patching hulls before you could spell them.",
		"trait": "Yard rates: dock repairs cost 10% less."},
	{"id": "prospector", "name": "Prospector's Kid",
		"desc": "Childhood on a survey rig, lullabies in scanner static.",
		"trait": "Practiced ear: surveys complete 10% faster."},
	{"id": "merchant", "name": "Merchant Family",
		"desc": "Ledger blood. Your family ran the lane back when it was safe.",
		"trait": "Seed money: +300 starting credits."},
	{"id": "militia", "name": "Militia Brat",
		"desc": "Grew up on a gun deck; recoil is a kind of quiet to you.",
		"trait": "Drilled instincts: +15% XP from kills."},
	{"id": "scrapper", "name": "Breaker's Child",
		"desc": "Born in a breaker yard — you can price a wreck by the sound it makes.",
		"trait": "Appraiser's eye: components sell for 10% more."},
	{"id": "courier", "name": "Courier Stock",
		"desc": "Raised flying packet runs through the belt with the engine note for a heartbeat.",
		"trait": "Light hands: +3% ship turn rate."},
	{"id": "gunner", "name": "Turret Tender",
		"desc": "A childhood spent greasing traverse rings on a defense emplacement.",
		"trait": "Smooth rings: turrets slew 5% faster."},
]

static var created := false
static var callsign := ""       # a handle from CALLSIGNS
static var family_name := ""    # free text
static var portrait_path := ""
static var background := ""
static var bio := ""

## Progression: LEVELS derive from banked Wallet.xp (retroactive — veterans dock
## already levelled), granting a skill point every POINTS_PER_LEVELS levels. A
## PROFESSION (Professions) sets per-level combat growth and raises skill caps.
## Persisted: profession + skills (level/points recompute from Wallet.xp).
const MAX_LEVEL := 60
const POINTS_PER_LEVELS := 4     # 1 skill point per 4 levels -> 15 at the cap

static var profession := ""      # "" = no commission yet
static var skills := {}          # skill id -> ranks bought
## Krayt's invitation (from the hermit) is your first key to the Rust Shoal — the
## campaign grants access to the outlaw haven, before any standing is earned.
static var shoal_invited := false

## The ABILITY GEMS: the [1]-[5] active bar. Each slot holds an ability id (from
## Abilities) or "" (empty). You MEMORIZE abilities into gems at dock; only a
## gemmed AND currently-fitted ability fires in flight. EverQuest spellbook/gems,
## five slots to start.
##
## START EMPTY (2026-07-22, user). Scan used to be pre-slotted "so the bar works
## out of the box", but the starter Rooster carries Wayfarer SENSORS (tag
## "sensor") and Survey Scan needs a SCANNER (tag "scanner") — so a new pilot's
## first sight of the game was gem 1 crossed out in red for an ability they had
## never heard of and could not fix. An empty slot says "nothing here yet",
## which is true; a red ✕ says "something is broken", which was not.
## The bar fills itself from what the ship actually knows — see
## ship.apply_build's auto-memorize.
const GEM_SLOTS := 5

## Everyone you have actually SPOKEN to. Introductions only fire for strangers —
## being told "you haven't met the cartographer" about someone you chatted with
## an hour ago reads as the game not paying attention.
static var met: Array[String] = []


static var gems := ["", "", "", "", ""]


## Radio handle — what NPCs and comms call you. The audio-capable name.
static func handle() -> String:
	return callsign if callsign != "" else "Pilot"


## Formal display: "‘Ghost’ Vex", or whichever half exists.
static func full_name() -> String:
	if callsign != "" and family_name != "":
		return "‘%s’ %s" % [callsign, family_name]
	if family_name != "":
		return family_name
	return handle()


## VO stem for Sfx.play_vo(): plays audio/vo/callsign/<handle>.ogg if present.
static func callsign_vo() -> String:
	return "callsign/" + callsign.to_lower() if callsign != "" else ""


static func background_def(id: String) -> Dictionary:
	for b in BACKGROUNDS:
		if b.id == id:
			return b
	return {}


static func portrait() -> Texture2D:
	return load(portrait_path) if portrait_path != "" \
		and ResourceLoader.exists(portrait_path) else null


static func sanitize_name(raw: String) -> String:
	return raw.strip_edges().left(NAME_MAX)


static func sanitize_callsign(raw: String) -> String:
	return raw if CALLSIGNS.has(raw) else CALLSIGNS[0]


static func sanitize_bio(raw: String) -> String:
	return raw.strip_edges().left(BIO_MAX)


## ---- Progression: levels, skill points, skills, profession ----

## Cumulative XP to REACH level `lv` (lv 1 is free at 0). Tunable curve.
static func xp_for_level(lv: int) -> int:
	return int(50.0 * pow(float(maxi(0, lv - 1)), 1.6))


static func level() -> int:
	var lv := 1
	while lv < MAX_LEVEL and Wallet.xp >= xp_for_level(lv + 1):
		lv += 1
	return lv


static func xp_into_level() -> int:
	return maxi(0, Wallet.xp - xp_for_level(level()))


static func xp_span_to_next() -> int:
	var lv := level()
	return 0 if lv >= MAX_LEVEL else xp_for_level(lv + 1) - xp_for_level(lv)


static func skill_points_total() -> int:
	return level() / POINTS_PER_LEVELS


static func skill_points_spent() -> int:
	var n := 0
	for id in skills:
		n += int(skills[id])
	return n


static func skill_points_available() -> int:
	return skill_points_total() - skill_points_spent()


static func skill_rank(id: String) -> int:
	return int(skills.get(id, 0))


## A skill's cap: the profession's if it favours it, else the base cap everyone
## gets. Raising a cap never invalidates ranks already bought.
static func skill_cap(id: String) -> int:
	return Professions.cap_for(profession, id) if profession != "" else Skills.BASE_CAP


static func can_raise_skill(id: String) -> bool:
	return not Skills.def(id).is_empty() and skill_points_available() > 0 \
		and skill_rank(id) < skill_cap(id)


static func raise_skill(id: String) -> bool:
	if not can_raise_skill(id):
		return false
	skills[id] = skill_rank(id) + 1
	return true


## Mark someone as SPOKEN TO. Called wherever a conversation actually opens, so
## an introduction is never offered for a face you already know.
static func meet(npc: String) -> void:
	if npc != "" and not met.has(npc):
		met.append(npc)


static func has_met(npc: String) -> bool:
	return met.has(npc)


## Accept a commission. One active at a time; passives persist across switches.
static func join_profession(id: String) -> void:
	if not Professions.def(id).is_empty():
		profession = id


## Per-level raw combat growth (hull/armor/shield/damage). Tier = the
## profession's combat status; 1% baseline before any commission.
static func combat_tier() -> float:
	return Professions.combat_tier(profession) if profession != "" else Professions.BASE_COMBAT_TIER


static func combat_growth() -> float:
	return level() * combat_tier()


static func hull_mult() -> float:
	return 1.0 + combat_growth()


static func armor_mult() -> float:
	return 1.0 + combat_growth()


static func shield_hp_mult() -> float:
	return 1.0 + combat_growth()


static func damage_mult() -> float:
	return 1.0 + combat_growth()


static func cargo_mult() -> float:
	return 1.0 + skill_rank("hull_discipline") * Skills.per_rank("hull_discipline")


static func shield_regen_mult() -> float:
	return 1.0 + skill_rank("shield_tuning") * Skills.per_rank("shield_tuning")


## Evasion = a SMALLER hit profile (deterministic, not RNG): incoming fire
## multiplies the ship's effective hit radius by (1 - evasion).
static func evasion() -> float:
	return minf(0.6, skill_rank("evasion") * Skills.per_rank("evasion"))


## Standing energy-regen rate from the commission (player-only, like the combat
## mults). 1.35x Science/Trader, 1.15x Miner/Scout, 1.0x combat + uncommissioned.
static func energy_regen_mult() -> float:
	return Professions.energy_regen(profession) if profession != "" else 1.0


static func salvage_luck() -> float:
	return skill_rank("salvage") * Skills.per_rank("salvage")


static func mining_yield_mult() -> float:
	return 1.0 + skill_rank("prospecting") * Skills.per_rank("prospecting") + _perk_bonus("mining")


static func scan_value_mult() -> float:
	return 1.0 + _perk_bonus("scan_value")


static func insight_mult() -> float:
	return 1.0 + _perk_bonus("insight")


## A non-combat profession's exclusive per-level perk (fraction), for the
## matching perk name only, else 0.
static func _perk_bonus(perk_name: String) -> float:
	return level() * Professions.PERK_PER_LEVEL \
		if profession != "" and Professions.perk(profession) == perk_name else 0.0


## ---- Ability gems (the [1]-[5] active bar; EverQuest-style memorize) ----

static func gem_at(i: int) -> String:
	return str(gems[i]) if i >= 0 and i < gems.size() else ""


## Memorize `ability_id` into slot `i` (""=clear). An ability lives in ONE gem:
## slotting it elsewhere vacates any prior slot so keys never double up.
static func set_gem(i: int, ability_id: String) -> void:
	if i < 0 or i >= GEM_SLOTS:
		return
	_ensure_gems()
	if ability_id != "":
		for j in gems.size():
			if j != i and str(gems[j]) == ability_id:
				gems[j] = ""
	gems[i] = ability_id


static func clear_gem(i: int) -> void:
	set_gem(i, "")


static func first_empty_gem() -> int:
	_ensure_gems()
	for i in GEM_SLOTS:
		if str(gems[i]) == "":
			return i
	return -1


static func _ensure_gems() -> void:
	while gems.size() < GEM_SLOTS:
		gems.append("")
	if gems.size() > GEM_SLOTS:
		gems.resize(GEM_SLOTS)


## ---- Trait hooks (neutral defaults when no background applies) ----

static func repair_mult() -> float:
	return 0.9 if background == "dockhand" else 1.0


static func scan_mult() -> float:
	return 0.9 if background == "prospector" else 1.0


static func kill_xp_mult() -> float:
	return 1.15 if background == "militia" else 1.0


static func sell_mult() -> float:
	return 1.1 if background == "scrapper" else 1.0


static func turn_mult() -> float:
	var m := 1.03 if background == "courier" else 1.0
	return m + skill_rank("piloting") * Skills.per_rank("piloting")


static func traverse_mult() -> float:
	var m := 1.05 if background == "gunner" else 1.0
	return m + skill_rank("gunnery") * Skills.per_rank("gunnery")


## One-time, applied at creation confirm — never on load.
static func starting_credits() -> int:
	return 300 if background == "merchant" else 0


## Trade-rate seams for the eventual Trader profession / skills: a discount on
## what you BUY and a bump on what you SELL, "to a small degree." 1.0 = no
## effect (today). Applied at the market so professions just fill these in.
static func trade_buy_mult() -> float:
	return 1.0 - _perk_bonus("trade")     # Trader commission: cheaper buys (to -30%)


static func trade_sell_mult() -> float:
	return 1.0 + _perk_bonus("trade")     # Trader commission: better sells (to +30%)


static func to_dict() -> Dictionary:
	return {"created": created, "callsign": callsign, "family": family_name,
		"portrait": portrait_path, "background": background, "bio": bio,
		"profession": profession, "skills": skills.duplicate(),
		"gems": gems.duplicate(), "shoal_invited": shoal_invited,
		"met": met.duplicate()}


static func from_dict(data: Dictionary) -> void:
	created = bool(data.get("created", false))
	# Migration: pre-callsign saves stored one "name" — becomes the family
	# name, and the callsign defaults to the head of the pool.
	callsign = sanitize_callsign(str(data.get("callsign", ""))) if created else ""
	family_name = sanitize_name(str(data.get("family", data.get("name", ""))))
	portrait_path = str(data.get("portrait", ""))
	background = str(data.get("background", ""))
	if background_def(background).is_empty():
		background = ""
	bio = sanitize_bio(str(data.get("bio", "")))
	profession = str(data.get("profession", ""))
	if profession != "" and Professions.def(profession).is_empty():
		profession = ""
	shoal_invited = bool(data.get("shoal_invited", false))
	met.clear()
	for who in data.get("met", []):
		met.append(str(who))
	skills = {}
	for k in data.get("skills", {}):
		if not Skills.def(str(k)).is_empty():
			skills[str(k)] = maxi(0, int(data["skills"][k]))
	# Gems: keep only ids that still name a real ability; pre-gems saves default
	# to scan on [1]. Empty strings pass through as blank slots.
	if data.has("gems"):
		gems = ["", "", "", "", ""]
		var raw: Array = data["gems"]
		for i in mini(GEM_SLOTS, raw.size()):
			var gid := str(raw[i])
			gems[i] = gid if gid == "" or not Abilities.def(gid).is_empty() else ""
	else:
		gems = ["scan", "", "", "", ""]


## Put the ship's first known ability on [1] — but ONLY when the bar is
## completely empty. This is what "the bar works out of the box" was meant to
## do: it fires when a fit actually GRANTS something, instead of pre-wiring an
## ability the hull cannot use and rendering it crossed out.
static func autowire(known: Array) -> void:
	if known.is_empty():
		return
	for g in gems:
		if str(g) != "":
			return
	set_gem(0, str(known[0]))


static func reset() -> void:
	created = false
	callsign = ""
	family_name = ""
	portrait_path = ""
	background = ""
	bio = ""
	profession = ""
	skills = {}
	gems = ["", "", "", "", ""]   # empty until a fit grants something
	shoal_invited = false

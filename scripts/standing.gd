class_name Standing
## Faction standing — the BONES of the reputation + piracy system. A SIGNED
## scale per faction, clamped to [MIN, MAX]. The bands are deliberately wide:
## a commission is offered early (INVITE_AT = 10 — "trusted enough to fly for
## them"), but winning their HEARTS (ALLIED) takes far more, and sinking to KOS
## ("utterly destroyed, forever") takes real crimes. Losing standing is fast;
## MENDING it is slow (enforced at the sites + the hermit), so you can never be
## fully allied with two opposed factions at once — the fork holds.
## Persisted; the faction's VERB feeds it; a one-time retroactive seed from
## Wallet.xp means veterans dock into some Guardian respect rather than zero.

const MIN := -1000
const MAX := 1000

const INVITE_AT := 10       # trusted enough to be offered a commission
const FRIENDLY_AT := 100    # they like you — better prices/aid later
const ALLIED_AT := 500      # hearts won — full alliance
const HOSTILE_AT := -100    # at war — their ships will fight you
const KOS_AT := -500        # kill on sight; docking denied; peace toggle locked

static var points: Dictionary:
	get:
		return PlayerState.local.standing_points
	set(value):
		PlayerState.local.standing_points = value
static var peace: Dictionary:
	get:
		return PlayerState.local.standing_peace
	set(value):
		PlayerState.local.standing_peace = value
static var mend_day: Dictionary:
	get:
		return PlayerState.local.standing_mend_day
	set(value):
		PlayerState.local.standing_mend_day = value
static var _seeded: bool:
	get:
		return PlayerState.local.standing__seeded
	set(value):
		PlayerState.local.standing__seeded = value


## ---- PEACE TOGGLE (player choice; the piracy declaration) ----
## A faction you're at peace with is friendly + untargetable; declare war and its
## ships become fair game. Two fragile transitions are guarded automatically:
##  • A HOSTILE faction is at war with YOU no matter your toggle — you can defend
##    without stopping to flip a switch (no cargo lost to a surprise turn).
##  • The instant a faction climbs OUT of hostile, war auto-reverts to PEACE
##    (see add()), so a stray shot can't undo hard-won mending — you must
##    deliberately re-declare war. Faction-wide: piracy is a lifestyle.

static func at_peace(faction: String) -> bool:
	if is_hostile(faction):
		return false   # they've started the fight — you can't opt out of it
	return bool(peace.get(faction, true))


static func at_war(faction: String) -> bool:
	return not at_peace(faction)


## Can the player flip peace ON right now? Only if they're not actively hostile
## (mend standing above the hostile line first; then the toggle reopens).
static func can_make_peace(faction: String) -> bool:
	return not is_hostile(faction)


## Returns true if the toggle took. Declaring war always works; suing for peace
## is refused while they're hostile to you.
static func set_peace(faction: String, on: bool) -> bool:
	if on and is_hostile(faction):
		return false
	peace[faction] = on
	return true


static func add(faction: String, n: int) -> void:
	var was_hostile := is_hostile(faction)
	points[faction] = clampi(int(points.get(faction, 0)) + n, MIN, MAX)
	# Guard the fragile mend: the instant a faction climbs out of hostile, revert
	# to PEACE so a stray shot can't undo the work. War is re-declared by hand.
	if was_hostile and not is_hostile(faction):
		peace[faction] = true


static func get_points(faction: String) -> int:
	return int(points.get(faction, 0))


## The faction's STATE, derived from standing: kos / hostile / neutral /
## friendly / allied. Drives peace-toggle availability, aggression, docking.
static func state(faction: String) -> String:
	var p := get_points(faction)
	if p <= KOS_AT:
		return "kos"
	if p <= HOSTILE_AT:
		return "hostile"
	if p >= ALLIED_AT:
		return "allied"
	if p >= FRIENDLY_AT:
		return "friendly"
	return "neutral"


static func is_kos(faction: String) -> bool:
	return get_points(faction) <= KOS_AT


## At war: their ships will engage you (KoS or merely hostile). Distinct from a
## player-chosen peace-off, which is tracked separately (the peace toggle).
static func is_hostile(faction: String) -> bool:
	return get_points(faction) <= HOSTILE_AT


static func eligible(faction: String) -> bool:
	return get_points(faction) >= INVITE_AT


## ---- Rust Shoal haven access (two-tier) ----
## ACCESS — can dock + safe passage (pirates + den guns hold fire): first via
## KRAYT'S INVITATION from the hermit (the campaign grants the door), OR once
## you've proven yourself to the Shoal (Privateer-friendly). (Post-Krayt Vyper
## truce folds in here later.)
static func shoal_open() -> bool:
	return Pilot.shoal_invited or get_points("privateer") >= FRIENDLY_AT


## TRUSTED — the Speak's Easy's real business (the fence, contraband, Vyper's
## gear) opens only with Privateer standing, never a mere invitation.
static func shoal_trusted() -> bool:
	return get_points("privateer") >= FRIENDLY_AT


## ---- REDEMPTION (the hermit mediates; slow by design) ----
## Only mends the RED — raises a burned faction toward NEUTRAL (caps at 0), never
## into favour (that takes the faction's own verb). Once per faction per game-day
## (the calendar advances per docking), so digging out of KoS is a long grind —
## losing standing is fast, mending is slow, and the fork holds.
const MEND_STEP := 20      # standing recovered per session
const MEND_COST := 250     # credits the Counter's word costs

static func can_mend(faction: String) -> bool:
	return get_points(faction) < 0 and int(mend_day.get(faction, -1)) < Research.day


static func mend(faction: String) -> int:
	if not can_mend(faction):
		return 0
	var before := get_points(faction)
	points[faction] = mini(0, before + MEND_STEP)
	mend_day[faction] = Research.day
	return points[faction] - before


## One-time: veterans with banked XP begin with some Guardian standing so the
## system is felt from the first dock. Other factions build forward from their
## own verbs as those hooks land.
static func seed_from_xp() -> void:
	if _seeded:
		return
	_seeded = true
	if get_points("guardian") == 0 and Wallet.xp > 0:
		points["guardian"] = clampi(Wallet.xp / 40, 0, INVITE_AT)


static func to_dict() -> Dictionary:
	return {"points": points.duplicate(), "peace": peace.duplicate(),
		"mend_day": mend_day.duplicate(), "seeded": _seeded}


static func from_dict(data: Dictionary) -> void:
	points = {}
	for k in data.get("points", {}):
		points[str(k)] = clampi(int(data["points"][k]), MIN, MAX)
	peace = {}
	for k in data.get("peace", {}):
		peace[str(k)] = bool(data["peace"][k])
	mend_day = {}
	for k in data.get("mend_day", {}):
		mend_day[str(k)] = int(data["mend_day"][k])
	_seeded = bool(data.get("seeded", false))


static func reset() -> void:
	points = {}
	peace = {}
	mend_day = {}
	_seeded = false

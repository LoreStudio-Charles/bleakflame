class_name Threat
## WHAT IS THIS ENCOUNTER BUILT FOR — one answer, used by the flight HUD and the
## ground nameplates alike.
##
## WHY (user, 2026-07-27): "targets both in space and on the ground have no
## indication of power. We indicate level, but never Power. Navy ships and Guardian
## patrols don't have a bespoke plate that warns you, this is a tough fight for its
## level."
##
## THE PROBLEM IS REAL AND THE NUMBERS PROVE IT. A Guardian carries MILITARY_HULL 3x
## pools AND MILITARY_DMG 3x damage (guardian_ship.setup_guard), so a level-5
## Guardian is roughly NINE TIMES the fight of a level-5 pirate — and the two were
## indistinguishable on screen, because level was the only thing the HUD said.
##
## THE RANKS ARE ABSOLUTE, NOT RELATIVE TO YOU (user's model, and it is the right
## one). An earlier draft banded target power against the VIEWER's — a con system.
## That answers "can I win" and hides the thing actually worth saying: a Guardian is
## built for a GROUP whether you are level 5 or level 50. Rank is a property of the
## encounter; whether you should try it anyway is the player's call, which is a much
## better game than being told.
##
##   NORMAL     — solo. A rim pirate, a scrit.
##   ELITE      — small group. Above its weight for its level.
##   MILITARY   — full group. Guardian patrols, the Navy.
##   SPEC OPS   — raid. The apex of its region.
##
## RANK IS AUTHORED; POWER IS MEASURED AGAINST IT. An earlier draft derived rank
## purely from stats, and MEASURING THE SHIPPED FLEET DISPROVED IT: a pirate Vulture
## is 1.34x a rim pirate and the Recluse 1.11x a lane normal, so a stats-only rule
## calls both NORMAL forever, no matter what they are meant to be. A Vulture is not
## a multiplied ship, it is a BIG one -- and "big for its level" is exactly what
## level scaling already accounts for. Role cannot be recovered from pools.
##
## So the rank is a design statement (user, 2026-07-27: "Let's make the Vulture
## Elite and The Recluse Military. Guardians are Elite. Navy is Military") and the
## multipliers below are what BALANCE SHOULD THEN HIT:
##
##   NORMAL    1x    solo
##   ELITE     ~3x   small group
##   MILITARY  ~6x   group
##   SPEC OPS  ~24x  raid
##
## The measured power is therefore not the source of the rank — it is the AUDIT of
## it. test_threat prints every ranked ship against its target so an unmet intent is
## a visible number rather than a surprise in play. Today only the Guardian meets
## its mark (exactly 3.00x, the sqrt of its 3x pools times its 3x damage); the rest
## are tuning work this makes measurable for the first time.

enum Rank {NORMAL, ELITE, MILITARY, SPEC_OPS}

const LABELS := ["NORMAL", "ELITE", "MILITARY", "SPEC OPS"]
const GROUPS := ["solo", "small group", "group", "raid"]
## White → green → amber → red. Amber is where a solo pilot should start being
## careful; red is reserved for "bring friends", so it still means something.
const COLORS := [
	Color(0.82, 0.86, 0.95),
	Color(0.42, 0.86, 0.46),
	Color(0.95, 0.72, 0.35),
	Color(0.95, 0.34, 0.32),
]
## What each rank SHOULD field, as a multiple of a normal target of the same level
## (user, 2026-07-27). These are tuning targets, not classifiers — see the header.
const RANK_MULT := [1.0, 3.0, 6.0, 24.0]
## Power of a baseline solo hull at level 1 — the unit everything is measured in, so
## a normalised score of 1.0 IS "an ordinary enemy for its level". MEASURED from the
## shipped build, then pinned; test_threat re-measures and fails if it drifts.
##
## IT IS THE LEVEL-1 VALUE, NOT A MEASUREMENT OF ANY PARTICULAR SHIP. A first pass
## pinned it to a level-3 rim pirate's raw 118 and so counted that ship's level
## growth twice, which made a Guardian audit at 0.63 of a target it actually hits
## exactly. The rim pirate measures 118 at level 3 and level-3 growth is ~1.59, so
## the level-1 unit is ~74 — and a stock pirate then normalises to 1.00, which is
## what "an ordinary enemy for its level" has to mean for any of this to work.
const BASE_POWER := 74.0


## What a ship can soak times what it can deal. sqrt keeps a 3x/3x Guardian at 3x
## rather than 9x — without it every military hull saturates the top rank and the
## scale stops distinguishing exactly where it matters most.
static func ship_power(ship) -> float:
	if ship == null or not is_instance_valid(ship):
		return 0.0
	var st = ship.get("stats")
	if st == null or typeof(st) != TYPE_DICTIONARY:
		return 0.0
	var pool: float = float(st.get("hull_hp", 0.0)) + float(st.get("armor_hp", 0.0)) \
		+ float(st.get("shield_hp", 0.0))
	var dps := 0.0
	var mounts = ship.get("_mounts")
	if mounts != null:
		for m in mounts:
			if m == null or m.def == null:
				continue
			dps += (m.def.damage * float(m.damage_mult)) / maxf(m.def.fire_interval, 0.05)
	# A hauler with no guns is not a fight, but it is not nothing either — the floor
	# keeps it from scoring zero and reading as harmless when it can still take a beating.
	return sqrt(maxf(pool, 1.0) * maxf(dps, 1.0))


## The ground mirror. Same shape — soak times output — with mitigation folded in as
## the multiplier it actually is (ground armour MITIGATES, it does not ablate).
static func ground_power(who) -> float:
	if who == null or not is_instance_valid(who):
		return 0.0
	var pool: float = float(who.get("max_health")) + float(who.get("max_barrier"))
	var mit: float = clampf(float(who.get("mitigation")), 0.0, 0.85)
	pool /= maxf(1.0 - mit, 0.15)
	var dps := 1.0
	var spec = who.get("attack_spec")
	if spec != null and typeof(spec) == TYPE_DICTIONARY and not spec.is_empty():
		dps = float(spec.get("damage", 0.0)) / maxf(float(spec.get("cooldown", 1.0)), 0.1)
	return sqrt(maxf(pool, 1.0) * maxf(dps, 1.0))


## Strip out the growth every ship gets for free at its level, so what remains is
## what somebody deliberately added. This is the whole reason the rank can honestly
## say "for its level".
static func normalised(power: float, level: int) -> float:
	var lv := maxi(1, level)
	var growth := sqrt(Progression.toughness_mult(lv) * Progression.damage_mult(lv))
	return power / maxf(BASE_POWER * growth, 0.001)


## The AUTHORED rank of a ship OR a walker — both carry `rank`, and an encounter's
## intent means the same thing in either mode, which is the whole reason this class is
## shared. (Named rank_of_ship at first; the ground nameplate calling it was the tell.)
## Everything answers NORMAL unless its spawner says otherwise, so the common case needs
## no thought and no upkeep.
static func rank_of(who) -> Rank:
	if who == null or not is_instance_valid(who):
		return Rank.NORMAL
	var r = who.get("rank")
	if r == null:
		return Rank.NORMAL
	return clampi(int(r), 0, Rank.SPEC_OPS) as Rank


## How far a ship actually is from what its rank promises: 1.0 means it hits the
## target, 0.5 means it is half the fight its plate claims. The audit, not the rule.
static func target_ratio(ship) -> float:
	var r := rank_of(ship)
	var want: float = RANK_MULT[clampi(int(r), 0, RANK_MULT.size() - 1)]
	var lv := 1
	if ship != null and ship.has_method("level"):
		lv = int(ship.level())
	return normalised(ship_power(ship), lv) / maxf(want, 0.001)


static func label(r: Rank) -> String:
	return LABELS[clampi(int(r), 0, LABELS.size() - 1)]


## "built for a small group" — the plain-language half, for a tooltip or a target
## readout with room to say it.
static func group_text(r: Rank) -> String:
	return GROUPS[clampi(int(r), 0, GROUPS.size() - 1)]


static func color(r: Rank) -> Color:
	return COLORS[clampi(int(r), 0, COLORS.size() - 1)]


## The compact readout. Pips as well as colour because colour alone is not
## colourblind-safe — the same pairing rule the Grade ladder follows (grades.gd).
## NORMAL draws nothing at all: the common case must stay silent, or the marks
## become wallpaper and stop being a warning.
static func pips(r: Rank) -> String:
	match r:
		Rank.ELITE: return "◆"
		Rank.MILITARY: return "◆◆"
		Rank.SPEC_OPS: return "◆◆◆"
		_: return ""

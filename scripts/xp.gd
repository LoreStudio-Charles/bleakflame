class_name XP
## THE ONE PLACE EXPERIENCE IS TUNED — both halves of it.
##
## Levelling has two halves that only make sense together: how much XP a level
## COSTS, and how much every activity PAYS. They used to live apart — the curve in
## Pilot, kill values in flight_test, quest values inlined across a dozen quest
## definitions, the scrit bounty in epharon_town, the licence reward in tutorial —
## so tuning the feel of progression meant hunting ~17 magic numbers through five
## files and hoping none were missed. That is why refining it felt hard rather than
## because any single number was wrong (user, 2026-07-26).
##
## Everything is static and this file depends on NOTHING — no autoloads, no Wallet,
## no Research — so it loads under `--script` and can be reasoned about (and
## tested) as pure arithmetic.
##
## RELATED BUT SEPARATE: `Progression` maps a level to POWER (toughness, damage).
## This maps a level to EFFORT. Keeping them apart is deliberate — how long a level
## takes and how strong it makes you are different questions and want different
## curves.

# ============================================================ THE CURVE ========
#
# xp_to_reach(L) = BASE * (L-1)^EXP * LATE_STEEPEN^(L - KNEE)
#
# The first two terms are the original curve and are UNCHANGED. The third does
# nothing at all below KNEE and compounds gently above it, which is precisely the
# ask: "slow more toward the end", without touching a low-level pace that has been
# played and confirmed to feel right.
#
# WHY NOT JUST RAISE THE EXPONENT: it steepens everywhere. Going 1.6 -> 2.2 pushes
# level 3 from 151 XP to 229 and level 4 from 289 to 560, so the early game the
# user validated would have been rebalanced as a side effect of tuning the late
# game. A knee keeps the two ends independent, which is the property that makes
# this refinable one end at a time.

## Scales the whole curve. Cosmetic on its own: multiply this and every reward
## below by the same factor and nothing about pacing changes, only the digits.
const BASE := 50.0
## Shape of the early curve. Superlinear already, so levels lengthen from the start.
const EXP := 1.6
## Below this level the curve is EXACTLY the original power curve. Raise it to
## extend the fast early game; lower it to start the long grind sooner.
const KNEE := 5
## Compounding applied per level ABOVE the knee. THE LATE-GAME DIAL.
##   1.00 = no late steepening (the old curve)
##   1.06 = level 60 costs ~25x the old curve      <- current
##   1.10 = level 60 costs ~140x
const LATE_STEEPEN := 1.06


## Total XP required to BE level `lv`. Level 1 is free.
static func xp_to_reach(lv: int) -> int:
	var n := maxi(0, lv - 1)
	if n == 0:
		return 0
	return int(BASE * pow(float(n), EXP) * pow(LATE_STEEPEN, float(maxi(0, lv - KNEE))))


## What the NEXT level costs from here — the number worth showing a player, and the
## one to look at when judging whether a band drags.
static func xp_for_next(lv: int) -> int:
	return maxi(0, xp_to_reach(lv + 1) - xp_to_reach(lv))


# =========================================================== THE REWARDS =======
#
# Authored values stay expressive — a campaign beat SHOULD pay more than a wasp —
# but every one of them passes through this file, so there is a single dial that
# reaches all of them.

## ONE KNOB FOR ALL EARNED XP. Levelling too fast? Drop it to 0.8. Too slow? 1.25.
## Nothing else has to move, and no authored value has to be re-judged.
const REWARD_SCALE := 1.0

## Kills, by archetype. The seed the whole economy of danger is judged against.
const KILL := {
	"wasp": 8,
	"raider": 10,
	"brawler": 14,
	"vulture": 40,
}

## Non-combat and one-off payouts, so they are visible next to the combat ones
## rather than buried at their call sites.
const ACTIVITY := {
	"scrit": 6,          # ground vermin on Epharon — one spine, same currency
	"licence": 50,       # finishing flight training
}


static func kill(kind: String) -> int:
	return _scaled(float(KILL.get(kind, KILL.get("raider", 10))))


## Quests carry their own authored value (a Campaign beat is not a bounty), routed
## through here so the global dial applies to them too.
static func quest(authored: int) -> int:
	return _scaled(float(authored))


static func activity(key: String) -> int:
	return _scaled(float(ACTIVITY.get(key, 0)))


## Rounded, and never rounded down to nothing: a reward that silently pays 0
## because a scale was tuned low reads as a broken drop, not as balance.
static func _scaled(amount: float) -> int:
	if amount <= 0.0:
		return 0
	return maxi(1, int(round(amount * REWARD_SCALE)))

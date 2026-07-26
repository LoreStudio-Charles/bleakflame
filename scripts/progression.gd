class_name Progression
extends RefCounted
## The LEVEL curve — the single source of truth for how a ship's level scales its
## combat power. These are PLACEHOLDER FORMULAS; the plan (user, 2026-07-24) is a
## real PROGRESSION TABLE that tracks expected hull / armour / damage per level
## BAND, so content is authored against known values and balance stays legible.
## See docs/progression_table.md. When the table lands, these functions read from
## it (or are replaced by it) — callers stay the same.

## Outgoing DAMAGE multiplier for a shooter of the given level. Level 1 = 1.0 and it
## climbs, so a level-35 capital annihilates level-1 pirates (a 34-level chasm).
## First cut — tune the slope here; L35 ≈ 11.9x.
static func damage_mult(level: int) -> float:
	return 1.0 + maxf(0.0, float(level - 1)) * 0.32


## HULL/ARMOUR pool multiplier for a hull of the given level. Defined so the table
## has both halves from the start, but NOT YET APPLIED anywhere — the capital's HP
## is still authored directly (1800) + the guardian military bonus. Wiring this in
## needs a decision on whether authored hull_hp is the RAW or the level-scaled
## value; that's a table question, deferred.
static func toughness_mult(level: int) -> float:
	return 1.0 + maxf(0.0, float(level - 1)) * 0.28


## RELATIVE scaling — the model the user chose 2026-07-25.
##
## A hull's authored pools are what that ship FIELDS AT ITS OWN LEVEL: the
## Supercruiser's 1800 is its level-35 hull, the Bellwether's 900 is her level-15
## hull. So nothing on disk needs re-basing, a .tres still shows what the ship
## actually has, and spawning one at a DIFFERENT level scales from that baseline
## rather than from level 1.
##
## That is what lets ONE hull cover a region's whole range — the rim runs 1-5 and
## the Long Lane 6-15 without authoring a separate .tres per level.
##
## Guard the divide: an unset/0 level would otherwise blow the ratio up.
static func toughness_between(from_level: int, to_level: int) -> float:
	return _ratio(toughness_mult(from_level), toughness_mult(to_level))


## Same idea for outgoing damage. NOTE this is NOT how weapons are scaled today:
## weapon `damage` is authored raw and multiplied by the SHOOTER's absolute
## damage_mult(level), because a gun's damage was never authored "at" a level the
## way a hull's HP was. Use this only when scaling something whose damage IS
## authored at a known level.
static func damage_between(from_level: int, to_level: int) -> float:
	return _ratio(damage_mult(from_level), damage_mult(to_level))


static func _ratio(from_mult: float, to_mult: float) -> float:
	if from_mult <= 0.0:
		return 1.0
	return to_mult / from_mult

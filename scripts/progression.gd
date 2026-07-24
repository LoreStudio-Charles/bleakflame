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

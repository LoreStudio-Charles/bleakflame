# Progression Table — level → expected combat stats

**Status: PLANNED (user, 2026-07-24).** The goal: one table that says, for each
LEVEL BAND, the *expected* hull / armour / shield / damage a ship of that level
fields. Content (hulls, weapons, encounters) is then authored against known
numbers, and balance stays legible ("a level-20 cruiser should have ~X hull and
~Y dps") instead of guessed per-item.

## Why

`level` has been a display seam on HullDef/components since it was added. The
Supercruiser (L35) vs pirates (L1) exposed the gap: a 34-level chasm did nothing
until we made **damage** scale with level. The table generalises that so every
level difference reads correctly and we stop hand-tuning each hull.

## What exists now (first cut)

`scripts/progression.gd` (`class_name Progression`):
- **`damage_mult(level)`** — APPLIED. Outgoing damage multiplier, `1 + (L-1)*0.32`
  (L1 = 1x, L35 ≈ 11.9x). Wired in `GuardianShip.setup_guard` with the military 3x
  as a floor, so the capital instagibs L1 pirates. Tune the slope there.
- **`toughness_mult(level)`** — DEFINED, not applied. The HP half.

## The table (to build)

Replace the formulas with a real table keyed by level band (e.g. 1–5, 6–10, …,
31–35, 36–40…), each row the expected:

| band | hull | armour | shield | dps (single main) | notes |
|------|------|--------|--------|-------------------|-------|
| 1–5  | 55–120 | … | … | … | fringe pirates / starter hulls |
| …    | … | … | … | … | |
| 31–35 | (capital) | … | … | … | Galean Navy Supercruiser tier |

Author real rows from the hulls we have (wasp 55 / kestrel 80 / sparrowhawk 120
at L1; Supercruiser 1800 at L35) + the weapons (Aegis Lance 80 dps base).

## The open decision (blocks the HP half)

Is a hull's **authored `hull_hp` the RAW (L1) value that gets scaled by
`toughness_mult(level)`, or the FINAL level-scaled value?**
- The Supercruiser's 1800 was authored as its *final* L35 HP, so applying
  `toughness_mult(35)` on top would double-count (→ ~18,900).
- Cleanest is probably: **authored hull_hp is the RAW value at the hull's `level`,
  and the table normalises**, i.e. store base-at-L1 and let the curve produce the
  rest. That means re-basing existing hulls when the table lands.
Decide this first, then wire `toughness_mult` (and shield/armour) the same way
`damage_mult` is wired now.

## Ties

- The player already has per-level growth via `Pilot.hull_mult/damage_mult`
  (player-only, in ship.gd apply_build). The table should reconcile with those so
  player and NPC scaling share one curve.
- Weapons/components carry `level` + `grade` too (HullDef/component seams) — the
  table eventually covers component power, not just hulls.

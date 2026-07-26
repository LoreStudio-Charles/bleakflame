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

## The open decision — RESOLVED 2026-07-25 (user), and WIRED

**A hull's authored pools are what that ship FIELDS AT ITS OWN LEVEL.** The
Supercruiser's 1800 is its level-35 hull; the Bellwether's 900 is her level-15
hull. Nothing on disk is re-based and a `.tres` still shows what the ship
actually has.

Scaling is therefore **relative, not absolute**:

    fielded = authored * toughness_mult(spawn_level) / toughness_mult(hull.level)

`Progression.toughness_between(from, to)` is that ratio (guarded against a 0 or
negative level, so an unset level can never blow it up).

**Why this one.** The rejected alternative — authored HP is a raw level-1 value
always multiplied by the curve — is a cleaner formula but forces a re-basing pass
over every hull, and the Supercruiser's 1800 becomes ~183 in the file, which reads
as nonsense to anyone who opens it. More importantly, the relative model is what
lets ONE hull cover a whole region band. The user's spec is a RANGE per region
(rim 1–5, the Long Lane 6–15, the Navy 35–40), and ranges need the same hull
fielded at several levels rather than a separate `.tres` per level.

### How it is wired

- `BuildShip.spawn_level` (0 = "the hull's authored level", the default) —
  set it BEFORE `apply_build`.
- `BuildShip.level()` resolves spawn_level → hull.level → 1.
- `apply_build` scales `hull_hp`, `armor_hp` and `shield_hp` by the ratio. It is a
  **no-op for every existing spawn**, since nothing sets `spawn_level` yet.
- `GuardianShip` now reads `level()` rather than `build.hull.level`, so a guardian
  fielded at a region level hits as hard as it is tough.

Test: `tools/test_levels.tscn` — goes through a REAL `BuildShip` rather than
checking the formula in isolation, because a correct helper nobody calls is the
exact failure this project has already paid for once. Sabotage-verified against
both dead wiring and an absolute-scaling model.

### Still open

- **Damage** stays ABSOLUTE (`damage_mult(level)`, applied in GuardianShip only).
  A weapon's `damage` was never authored "at" a level the way a hull's HP was, so
  the ratio does not apply to it. `damage_between` exists for when something IS
  authored at a known level.
- Nothing yet SETS `spawn_level` — the region bands are still just authored hull
  levels. The Long Lane spawner is the first natural caller.
- Components carry `level`/`grade` seams that nothing scales off.

## Ties

- The player already has per-level growth via `Pilot.hull_mult/damage_mult`
  (player-only, in ship.gd apply_build). The table should reconcile with those so
  player and NPC scaling share one curve.
- Weapons/components carry `level` + `grade` too (HullDef/component seams) — the
  table eventually covers component power, not just hulls.

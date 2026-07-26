# Ground regions — making the second one cheap

**Written 2026-07-25, before building Orivel's Megacity.** Epharon is the only region
that exists, and `scenes/ground/epharon_town.gd` is **2101 lines** carrying both the
ENGINE (how a walkable place works) and the CONTENT (what Epharon specifically is).
Districts are 1–4 per world across at least two worlds (docs/planet_districts.md), so
the second region is the moment that bill comes due.

## The survey (measured, not guessed)

| | count | what it means |
|---|---|---|
| Generic systems (movement, combat polling, props, interiors, camera, tutor, techniques, gear, drawing) | **28 functions** | the ENGINE — every region wants all of it |
| Epharon content constants (BUILDINGS, INTERIORS, WARREN, AMBUSH_*, PAD_*, CENTER, HEAT_LIMIT…) | **15** | the CONTENT — none of it is true of a megacity |
| References to named Epharon people/places (Imari, Sella, Bram, Tam, Conall, STARPORT, AQUAPONICS, MARKET…) | **78** | the entanglement |

**Verdict: it generalises, but not by copying.** The engine is genuinely reusable and
already region-agnostic in shape — `_drive_player`, `_poll_combat`, `_spawn_prop`,
`_enter_interior`, `_tick_tutor`, `apply_gear` and the rest do not care what planet they
are on. What is NOT reusable is the 78 places the file says "Imari" out loud.

**Do NOT duplicate the file.** A copied 2101-line town means every future fix to
movement, combat, tutor or gear has to be made twice, and the second copy will silently
drift — that is exactly the mirroring that produced the target-death bug.

## The shape to build

Extract `GroundRegion` (base class, `scenes/ground/ground_region.gd`) holding the 28
engine functions, and leave each region as a small SUBCLASS that supplies only data:

```
GroundRegion  (engine: movement, combat, props, interiors, camera, tutor, gear, draw)
  ├── EpharonTown    (BUILDINGS, INTERIORS, cast, warren, ambush, apron, heat limit)
  └── OrivelMegacity (its own everything)
```

Regions declare content through overridable hooks rather than constants baked into the
engine — `region_buildings()`, `region_interiors()`, `region_cast()`, `region_hazard()`
(Epharon's heat limit is NOT universal; a megacity's boundary is a wall, or nothing).

### Do it in this order — extract UNDER a passing suite

1. **Rename-in-place first:** `EpharonTown` keeps working exactly as-is. Every ground
   test stays green through the whole refactor; that suite is the safety net that makes
   this safe at all (ground_saga, ground_interiors, ground_tutor, ground_combat,
   ground_colliders, ground_landing, ground_notice, ground_shop).
2. **Lift the engine functions** into `GroundRegion`, leaving Epharon's data behind.
   After each lift, run the suite. Nothing should change behaviourally — if a test
   fails, the function was not as generic as it looked, and that is the finding.
3. **Convert Epharon's constants into hook overrides.** Still green.
4. **Only then** write `OrivelMegacity` as a subclass with new data.

Step 4 is the fun part and step 2 is the value: the Megacity is worth building mostly
because it forces the engine/content seam to be real.

## What the Megacity is (content, for step 4)

Orivel SE: the domed capital, the Galean seat — the INSTITUTIONAL district, and the
tonal opposite of Epharon. Epharon is dust, four buildings and people who know your
name. The Megacity should feel like a place that does not care that you arrived.
- Vertical, lit, crowded. Props are structure, not scenery.
- No heat boundary; the edge is architecture.
- Almost certainly home to the **Marine** commission (docs/professions.md) and the
  Galean Navy's institutional face — which is why this district first.
- Its own cast, none of whom are Imari.

## Open

- Do regions share one save key or one per region (visited state, per-region flags)?
- Does the ground tutor need region-awareness, or is `where:"ground"` enough? Today
  every ground lesson assumes Epharon's cast by name.
- Interiors are currently a dict on the region; a megacity may want dozens. Worth a
  per-interior scene file at that point rather than a dict entry.

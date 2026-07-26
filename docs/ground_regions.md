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
engine — `region_buildings()`, `region_interiors()`, `region_cast()`, and crucially
`region_boundary()`.

**The boundary hook is the one that earns the refactor** (user, 2026-07-25 — this
supersedes the `region_hazard()` sketch above it, which assumed every edge turns you
back). An edge has a KIND:

| kind | behaviour | example |
|---|---|---|
| `wall` | turns you back, with a telegraph | Epharon's heat limit |
| `door` | HANDS YOU OFF to a neighbouring district | Telon → Tundra / Desert / Swamp |
| `open` | no edge at all | small interior-ish regions |

So the engine gains a neighbour hand-off (leave region, enter neighbour at the matching
edge — the same shape `_enter_interior` already uses), and a region declares its
neighbours as data. Epharon keeps a wall and never notices; Telon has three doors.

This is exactly why the extraction comes FIRST: had the Megacity been built by copying
the town, the heat-limit boundary would have been copied with it and then special-cased,
and "the edge is a door" would have become an if-statement in two files instead of a
kind in one.

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

## TELON — the look (user, 2026-07-25)

**It is the CAPITAL, so it should feel GLORIOUS.** Tall, beautiful white spires that
match the might of the navy above it. **White, glass, and blue lights.**

This supersedes the earlier "institutional and indifferent" sketch. The register is AWE,
not alienation — a city that is genuinely magnificent, and whose indifference to you (if
any) is the ordinary indifference of somewhere vast, not coldness authored at the player.

**It is a total palette inversion of Epharon, which is the point.** Epharon is dusk,
dust, low mud-brick, warm orange, long shadows, four buildings and everyone knows your
name. Telon is height, white stone and glass, cool blue light. A player who lands on both
should never need a caption to know which world they are on.

- **Vertical.** Spires, not sheds. The camera composition problem is the opposite of
  Epharon's: there, buildings squatted; here, things go UP out of frame, and the art has
  to sell height on a top-down view (long cast shadows, tapering silhouettes, lit
  windows climbing away).
- **Blue lights echo the NAVY.** The Galean Navy livery is already blue
  (`Color(0.23, 0.44, 0.85)`, flight_test's fleet chevron). Telon's lighting should read
  as the same blue — the city and the fleet above it are one civilization's colours,
  which does a lot of storytelling for free while the fleet is literally overhead.
- **Glass matters as a material.** Reflection and transparency are what separate "white
  buildings" from "a capital". Even faked cheaply, glass is the difference.

### DO NOT let it drift into WARDEN

The WayGate's look is "sung from crystal" — pale ivory ceramic with GOLD light-veins
glowing within. Telon is white spires with BLUE light. These are close enough to blur if
nobody is watching, and they must not: the Wardens are elder, alien and grown; Telon is
Galean, built, and proud of it. Keep the split at **gold-veined and organic (Warden) vs
blue-lit and geometric (Galean)**, and never give Telon a glowing vein.

### Art plan

Generate two or three test spires BEFORE committing to a layout — the art will dictate
the scale of the district far more than the code will, and Epharon's layout was tuned
around building art that already existed.

## The ground tutor is REGION-GATED (user, 2026-07-25)

Ground lessons name Epharon's cast and buildings by string (`met_imari`, targets
`"MARKET"`), so they would arm at Telon and point at things that are not there. Lessons
gain a `region` alongside the existing `venue`, and Telon gets **little or no onboarding**
— the hope being there is nothing much left to teach by the time a player reaches the
capital. A megacity that does not stop to explain itself is also correct characterisation.

## Open

- Do regions share one save key or one per region (visited state, per-region flags)?
- Does the ground tutor need region-awareness, or is `where:"ground"` enough? Today
  every ground lesson assumes Epharon's cast by name.
- Interiors are currently a dict on the region; a megacity may want dozens. Worth a
  per-interior scene file at that point rather than a dict entry.

# WIP Handoff — branch `the-legend` (2026-07-23)

Where we left off so we can swap back to the other branch without losing the
thread. This session was the **Cinder Reach capital build + dev tooling**. Playtest
feedback from the last drop is folded in below.

## What shipped this session (all boot- + test-clean)

### 1. Dev codes → chat commands (release-safe)
The old dev KEYS are gone; dev cheats now live in the COMM TERMINAL (Enter, then
type). The dev gate is the **hook registration**: flight_test sets
`Chat.dev_command`/`Chat.dev_help` only inside `if OS.is_debug_build()`, so a
release export never registers them and they fall through to "unknown command".
- `/cash [n]` · `/insight [n]` · `/xp [n]` · `/gate` · `/ruler` · `/heartbeat` · `/rearm`
- **`/warp <x> <y>`** (or `<x>,<y>`, or `/warp <poi>` by id/name, e.g. `/warp orivel`).
  Uses `flight_test._safe_arrival` → stands the ship OFF a gravity well / body
  (grav_r+900 / avoid_radius+500) and faces it, so you never warp into the crush.
- Test: `tools/test_chat.gd` (asserts NO hook ⇒ `/cash` is unknown = release-safe).

### 2. Orivel — the capital planet
- Art: `assets/world/orivel.png` (user-picked PixelLab ocean-world w/ domed
  megacity; beat the "always draws Earth" problem).
- Now a **real `Planetoid`** at `radius_mult 3`, `landable = false`: gravity well +
  surface collider (you feel the pull, can't fly through), but NO berth yet (`[E]`
  and the HUD both say so; the landing band doesn't draw).
- `Planetoid` was **generalized**: `radius_mult` scales every radius (instance
  `surface_r`/`band_r`/`grav_r`, which physics + _draw now read); `landable` gates
  the minigame + band. Epharon = mult 1, landable (tutorial unchanged). External
  code touching a scaled body must use instance radii (flight_hud landing prompt
  updated to `planet.grav_r`/`planet.landable`).

### 3. Orivel Orbital Outpost — functional berths
- `scenes/flight/orivel_outpost.gd`: core + 4 landing bays (cardinals) + 4 drydocks
  (corners), baked composite `assets/station/orivel/outpost.png` (from scratchpad
  `compose_orivel.py`; modules staged in `assets/station/orivel/`). Parked ~9k out,
  clear of the ~6240 well. Secret POI `orivel_orbital`.
- **8 DockingPads, size-gated by the 64px band boundary** (user rule):
  - Bays: `max_size_band = HEAVY` (LIGHT..HEAVY, "64px and below").
  - Drydocks: `min_size_band = SUPER_HEAVY` (**new `DockingPad.min_size_band` floor**)
    — refuses anything a bay could take ("TOO SMALL FOR A DRYDOCK").
- Bare berths: `runs_dock_services = false` → repairs + tops bus + **checkpoints**,
  but no station economy (ship.dock() skips Research/Quests, like ShoalPad).
- Bespoke minimal dock screen `scenes/ui/orivel_dock.gd` (berth + repair receipt +
  "services coming"); routed in flight_test via `_outpost.pads`.
- Drydock art fixed: NE/SW mouths were 180° off; all four now open OUTWARD.

### 4. Capital defenses — PLAN only
`docs/capital_defenses.md`: laser / radar-guided missile / proton torpedo for the
Orbital + defense-platform satellites. Key finding: **weapons are DATA-ONLY**
(WeaponDef+Projectile already implement beam/homing/blast/magazine); the build is
the **firing hosts** (a friendly turret host + a DefenseSatellite node).

## Playtest feedback captured
- "Bullets aren't accurate / pirates couldn't hit me" → FIXED earlier this session
  (WeaponMount.intercept_point leads in the shooter's frame). User: change was good,
  felt a touch too easy after.
- Drydock orientation (NE/SW faced inward) → FIXED.
- Drydock size rule → IMPLEMENTED (this handoff).

## Next up (in rough priority)
1. **The fleet** — IN PROGRESS.
   - ✅ **Supercruiser** built (2026-07-24) — the first SUPER_HEAVY hull, Galean
     Navy line-of-battle ship (`data/hulls/supercruiser.tres` + seed-gen +
     `SampleBuilds.galean_supercruiser`). 1800 hp, mass 780, marks capped at 3
     (user), mixed-mark batteries: Mk3 mains + Mk2 secondary + Mk1 point-defense
     (traverse 360/mark = 360°/s, so it swats fighters — lethal solo, better
     escorted). `level = 35` (display seam). Silhouette until art. The drydock
     ACCEPT path is now validated: `DockingPad.size_permitted()` extracted (pure,
     save-free) + `tools/test_capital_berth.tscn` (37 checks — accept/refuse/every
     band has a home; sabotage this by widening a bay's max_size_band).
   - ⬜ **Carrier** (SUPER_HEAVY_PLUS, drone/fighter host) + modernized escorts.
   - ⬜ **Fleet at Orivel** — spawn Galean Navy ships near the capital so it feels
     defended, + capital-appropriate AI (the slow, escort-screened cruiser
     shouldn't fly fighter tactics). A dev spawn/board command would let us fly a
     super-heavy INTO a drydock and see the accept path in-engine (test covers the
     logic; nothing exercises it live yet).
   - **DESIGN DEBT surfaced here:** (a) **Level as a real stat** — give `level`
     (already on HullDef/components, display-only) mechanical weight so it scales
     hull_hp / component power; capital ships sit ~L35. This is a cross-cutting
     BALANCE feature for **main**, not the-legend. (b) **Galean Confederacy** — a
     new FACTION to align the fleet with (Standing entry + colours + AI team);
     "when the time comes" (user).
2. **Capital weapon platforms** — build per `docs/capital_defenses.md` (turret host
   + satellites + the 3 weapon `.tres`).
3. **Capital services** — flesh out `orivel_dock.gd` (shipyard for super-heavies,
   quartermaster, commissions) when the fiction's ready.
4. **Percival** — art `assets/world/percival.png` fits the style; DECISION PENDING:
   place it as a distant landmark beyond Orivel, or keep pure lore for now.
5. **Tuning** — eyeball the 8 pad offsets in-engine (bay 205 / drydock 140 source-px
   are estimates); add arm/cradle colliders if desired.

## Known gaps / risks
- Pad offsets are estimates; verify berths line up with the art in-engine.
- Only the outpost CORE has a collider (arms/cradles open; wreck raycast overshoots).
- No automated docking test (size-gate REFUSAL is scene-testable without touching
  the save — dock() calls SaveGame.save_game, so only the refusal path is test-safe).
- Orivel dock reuses no fringe NPCs by design (canon: capital has no services yet).

## How to test
- Boot: `<godot> --headless --path . res://scenes/flight/flight_test.tscn --quit-after 60`
- Import new art/classes: `<godot> --headless --path . --import`
- In-engine: fly, Enter → `/warp orivel` (see the planet + well), `/warp orivel_orbital`
  (the ring); fly a starter ship into a landing bay (docks) and into a drydock
  (refused, "too small"). `/gate`, `/ruler`, `/heartbeat` still there.
- Tests: `test_chat.gd`, `test_dock_ui.tscn` (557), `test_ai_specialists.tscn` (65).

## Files touched (this session, capital + devtools)
- scripts/chat.gd, scenes/flight/flight_test.gd, scenes/flight/flight_hud.gd
- scenes/flight/planetoid.gd, scenes/flight/orivel_outpost.gd (new)
- scenes/flight/docking_pad.gd, scenes/flight/ship.gd
- scenes/ui/orivel_dock.gd (new)
- assets/world/orivel.png, assets/world/percival.png, assets/station/orivel/* (new)
- docs/capital_defenses.md (new), CLAUDE.md, tools/test_chat.gd (new)
- scratchpad/compose_orivel.py (the outpost compositor — regenerates outpost.png)

# Handoff — 2026-07-27 (second session)

Branch `the-legend`. **21 commits** since `81e17f1`, working tree clean, everything green.
Supersedes `handoff_2026_07_27.md` (that session's §4 bugs are all fixed).

Godot exe:
`C:\Users\charl\Downloads\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe`

**Read first:** `docs/engineering_principles.md` — decided this session, and it is the
source of truth for *how* we build. Then `docs/multiplayer_readiness.md` (migration
complete) and `docs/cinder_reach_campaign.md` (beats 4–7 written).

---

## THE THREE THINGS THAT WILL BITE YOU IF YOU DO NOT READ THEM

### 1. `-- --no-save` on every headless run of a real scene
The flight scene starts the pilot DOCKED, so it checkpoints, and that advances the game
day. Every "did it still compile" run was ageing the playtester's save. Tests set
`SaveGame.read_only` themselves; the smoke boot has no script to set it in:

```
<godot> --headless --path . res://scenes/flight/flight_test.tscn --quit-after 60 -- --no-save
```

**Checksum the save around any suite you add.** Four tests were quietly writing it before
this session, including one written that same afternoon.

### 2. Two known gaps, both marked in code, neither pretended away
- ~~**Krayt's −50 is UNWIRED.**~~ **FIXED** (`4d5235d`). All four rungs are in, each where
  its beat lives: −100 in `Standing.OPENING`, Krayt's −50 as `rewards.standing_floor` on
  the `rust_shoal` quest, Vyper's 0 and the truce-break −100 in `flight_test`. It is a
  FLOOR, not a set — the beat can never cost a pilot standing they arrived with.
- **The corpse-run's player hook is UNVERIFIED.** `test_wrecks` calls `Wreck.hold_cargo()`
  directly, so it proves the helper and not the call in `TestShip._on_death`. Sabotaging
  that call goes undetected. Closing it needs a real `TestShip` driven through death, which
  wants the flight scene. The comment in the test says so.

### 3. Factions are built and INERT
Stage 1 (matrix) and stage 2 (parity net) are done. **Not one line of targeting is
switched.** See "Next moves" below — the net is what makes stage 3 safe, and it is green.

---

## What landed

**Ground.** Nameplates + unit frames (`nameplate.gd`, `ground_hud.gd`), and three
extractions toward the two coming planets: `GroundScenery` (props, colliders, weather, the
sun as an injected value), `GroundCombat` (target queries, input, technique refusal
ladder), `GroundSpots` (what `[E]` means). `epharon_town.gd` 2,218 → ~1,820. **The
interiors were deliberately NOT extracted** — `_enter_interior` interleaves Epharon's story
wiring with generic room mechanics, and abstracting against one implementation bakes its
accidents in as rules. Wait for planet 2.

**Architecture.** `PlayerState` migration COMPLETE — 10 modules, 61 fields, zero call-site
churn. `GameClock` replaced `Research.day`: opaque stamps, `elapsed()`/`days()`, built to be
gutted for a realtime system. `SaveGame.read_only`. `docs/engineering_principles.md`.

**World.** Power ranks reach the world (Vulture→ELITE, Recluse/Navy→MILITARY) and show on
the HUD. The Long Lane got 16 travellers, a Shoal-raider ramp and a Widow peak — measured
`[0,1,3,0]` hostiles before, `[0,8,6,0]` after, with traffic in every quarter. Wrecks:
burnt tumbling hulls for ~7 minutes, and **your hold stays on yours** (corpse run).

**Fiction.** V-Shrike → **Widows** (160 occurrences, nothing persisted, verified first).
New faction rows: Ooshu (a people, empty row), Ghosts (contractors, neutral — "the Web" was
dropped because Cinderweb already owns that word in shipped text), Galean Marine Corps.
`NavyShip` — the Navy is private-police-adjacent no longer. Ship registries
(GCT/GVIT/GCN/GEU + 5 chars; pirates get noise). **Raptor** at the Vulture haunt.

---

## Next moves, in the order I would take them

1. **Wire Krayt's −50** at the `rust_shoal` beat. One hook; unblocks a real playthrough.
2. **Faction targeting, stage 3.** Switch `Projectile`'s four group loops, `WeaponMount`,
   target cycling, `AIShip` prey selection and the HUD's hostile colour to ask
   `Factions.hostile(a.faction, b.faction)`. **Keep the broad group iteration for the
   physics broad-phase and filter by faction** — do not try to iterate a faction. **Re-run
   `test_faction_parity` after each file**; it shows a new unexpected row the moment a
   conversion is wrong. Expected end state: only `widow↔shoal` differs from the old groups.
3. **Close the corpse-run verification gap** (see above).
4. **Traffic names and hails** — beat 4's material. NOTE: the 24 voiced callsigns are the
   PLAYER'S own choices, not an NPC pool; lane traffic needs its own name source. Registries
   exist now, so a hauler can answer with `GCT#####`. The friendlies roster already shows
   names and `hail_friendly` is already the canned-comm seam.
5. **Beat 4 "The Loneliness"** — the relay chain from beat 3 as its spine.
6. Deferred by decision: multiplayer coop-vs-MMO (design talk first), the component
   refactor, `PatrolShip` (so Guardians and Navy stop inheriting from each other).

---

## Process rules, earned the hard way

- **Sabotage-verify every assertion, and assert the anchor matches exactly once.** Three
  sabotages went *undetected* this session and each one taught something: a length claim
  that was never the real rule; a `days()` scaling invisible because the unit was 1; a
  helper tested directly instead of through its caller.
- **Measure before you derive.** The lane, the threat ranks and the transit time were all
  settled by measurement, and each contradicted an assumption.
- **A test can encode the wrong claim.** The first lane test asserted "hostiles in most
  quarters", which contradicted the design — two quarters are *meant* to be clear. It would
  have driven a fix that broke the sanctuary pillar.
- **Look at it.** Twenty passing checks said the nameplates were fine; the screenshot showed
  four overlapping plates rendering "Scritt" and a foot ring that read as a spiral.
- Bash heredocs eat backslashes — write `.py` to the scratchpad. (Bit me three times.)
- `--quit-after N` always; a new `class_name` needs `--headless --path . --import` first.

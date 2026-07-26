# Ground Combat — design (source of truth)

**Designed with the user 2026-07-25. Read before building any ground-combat feature.**
Status: DESIGN LOCKED on the pillars below; v1 build scope at the end. The death
penalty is deliberately OPEN (build to accommodate, do not finalize).

---

## Philosophy (user, verbatim intent)

> **"Characters progress. Ships just get upgraded and improved by the character."**

The CHARACTER is the RPG entity. One spine: one XP pool (`Wallet.xp`), one level
(`Pilot.level()`), one set of skill points, one profession, one standing sheet — spent
in two arenas. A ship is a thing the character owns and improves, like a sword; the
suit on their back is another. Nothing on the ground forks the progression spine.

The ground is the **MOBA-RPG counterpoint** to space twitch (see ground-mode north
star): click-to-move, target-and-engage, no aiming. "Tired of space combat? Land and
click around, still make progress."

## The grammar (one vocabulary, two bodies)

| Ship | Character | |
|---|---|---|
| HullDef — slot set + trait | **SuitDef** — slot set + trait | flight suit → armored rig → exo-frame is the "hull ladder" |
| Hull / Armor / Shield | **Health / Armor / Barrier** | see damage model — armor differs BY DESIGN |
| Reactor capacity/recharge | **Power cell** capacity/recharge | abilities spend energy |
| Components, Grades, Marks, affixes | **identical — same ComponentDef system** | new slot types; the forge, tiles, shops, salvage, stash all reused |
| Abilities = CHIPS (hardware you fit) | Abilities = **TECHNIQUES (training you learned)** | the deliberate asymmetry — see Abilities |
| Ship bus [1]-[5] (Pilot.gems) | **Character bus [1]-[5]** (own save key) | distinct sets per mode (input scheme) |
| Going Dark [K] | **Meditate [K]** | dump cell into recharge + re-prepare techniques; defenseless while down |

## Stats (NO attribute block)

There is no STR/AGI sheet — ships don't have one and neither do characters. Stats
DERIVE, exactly like a ship's: **suit + fitted gear + skills + profession tier ×
level**. The character sheet shows the derived result.

Derived v1 stats:
- **Health** — the pool. Per-level growth via the existing profession combat tier
  (Pilot.hull_mult seam, player-only, same as ships).
- **Barrier** — energy shield from a fitted emitter; soaks FIRST, regenerates out of
  combat. Zero if no emitter fitted (early game is flesh and nerve).
- **Mitigation** — from PLATING. See damage model.
- **Energy** — from the CELL (capacity + recharge). Techniques spend it.
- **Speed / sprint** — base + suit; SHIFT sprints (drains nothing v1 — keep it fun).
- **Damage / attack speed** — from the WEAPON, scaled by profession tier.

## Damage model — the one deliberate divergence (user)

- ~~**Ship armor ABLATES**: a pool that soaks and depletes.~~ **NO LONGER TRUE
  (2026-07-26).** Ship armor became DR-only too, so this is not a divergence any more —
  armor mitigates in both systems. See `docs/armor_and_penetration.md`. **Nothing on the
  ground changes**; the ship side moved to meet it. The one asymmetry left is that a ship
  may fit **ablative plate** (+10% DR that exhausts as it works); characters have no
  equivalent, and should only get one if it earns its place on its own.
- **Character armor MITIGATES**: worn plating REDUCES incoming damage and does not
  deplete. `taken = max(1, raw * (1 - mitigation))`, mitigation capped (~60%?) so
  nothing is unkillable. Barrier soaks before health; mitigation applies to what
  reaches HEALTH (a barrier is energy — plating doesn't help it).
- Order: raw → Barrier (soak) → remaining × (1 − mitigation) → Health.
- [SPACE] kneel/cover: temporary mitigation bonus (+flat %, stacking multiplicatively
  with plating) while held; you move nowhere. The tactical button.

## Equipment

Same `ComponentDef` machinery — grades, marks, affixes, `Affixes.forge`, ItemTile,
shops, salvage, stash — with new SLOT TYPES on a **SuitDef** frame:

**THE SLOT SET (user, 2026-07-25 — canon, MMO paperdoll):**
**Head · Chest · Feet · Pants · Hands · Waist · Main · Offhand · Grenade** (9 slots).
- The six WORN slots (Head/Chest/Feet/Pants/Hands/Waist) contribute MITIGATION (and
  stat lines); Waist is also the natural home for the cell / barrier-emitter seam.
- **Main / Offhand** — weapons + shields. A TWO-HANDED weapon occupies Main and locks
  Offhand (the classic rule).
- **Grenade** — the thrown slot [R]; consumable stacks, restocked at Bram's.

**VISIBILITY (user):** worn equipment is NOT drawn on the sprite — stat-only.
**WEAPONS ARE DRAWN**, at fixed grip positions per animation frame (one-hand pose vs
two-hand pose) so they animate correctly. See "Weapon display" below.

Suits ladder like hulls (slot counts/trait vary; grades apply). Ground drops roll
affixes exactly like ship drops — a scrit can drop a "Sharpened Scrap Shiv."
Personal gear lives in the pilot's **BAGS [B]** (the reserved key), distinct from the
ship hold; bank at the stash like anything else.

## Weapon display — the HAND-ANCHOR standard (how 2D games do this without skeletons)

Pixel games that show weapons without paperdoll sprite-sheets use **per-frame anchor
tables**: for each (animation, direction, frame) store the HAND pixel + flip + a
draw-order flag; the weapon is its OWN small sprite with its GRIP at origin
(our "nose +X" convention, but for grips), placed at that anchor every frame.

Why this is cheap for us — THE TEMPLATE INSIGHT: every humanoid we generate shares
the SAME PixelLab mannequin skeleton and the SAME walking-4-frames template, so the
hand lands on the same pixel for every character. **ONE anchor table per animation
template serves the entire cast** — authored once (4 dirs × 4 frames = 16 entries),
reused by Imari, Tam, scrit, everyone. New animation template = one more table.
- Two grip poses per the user's spec: ONE-HAND (hip-side grip) and TWO-HAND
  (cross-body carry) — separate anchor columns in the same table.
- Draw order by direction: south/east/west = weapon over body; north = behind.
- Weapon art convention: grip at origin, blade/barrel pointing +X, drop-in PNGs.
- Godot: a WeaponSprite child of GroundCharacter; on frame_changed, look up
  (anim, dir, frame) → position/flip/z. No skeletons, no IK, ~30 lines.

(The alternative — LPC-style full overlay sheets per item — costs a whole animated
sheet PER WEAPON and is exactly why we're NOT drawing worn armor.)

**PROVEN 2026-07-25 (pistol + rifle PoC on PilotM's walk, all 4 dirs × 4 frames).**
Findings that are now RULES:
1. **One-handers: naive hand-tracking just works.** Anchor to the weapon-hand pixel
   per frame; rotate by facing (south = barrel down at the side, profile = forward,
   north = behind the body). The pistol read correctly on the first table.
2. **Two-handers need CARRY POSES, not hand-tracking** (the user predicted this
   failure point; confirmed). A two-hander is constrained by BOTH hands, so it rides
   the BODY with a small bob: south = horizontal across the waist (over), north =
   DIAGONAL 45° back-sling (behind), profiles = fore-grip at the leading hand,
   stock trailing. Naive tracking made it chase one arm and teleport.
3. **Weapon art must be GENRE-SCALED (~60% of character height, ~29px on our 48px
   cast), not realistic.** A realistic 20px rifle is smaller than the torso
   silhouette, so any back-sling is fully hidden — oversizing is what makes it
   readable, which is why every classic pixel RPG does it.
4. Table shape (becomes the GD data): per grip type, `dir -> 4 anchor px` + a pose
   `{rot, flip, behind, center}` per direction. One table per animation template
   serves every mannequin character.

### Combat STANCES (user, 2026-07-25) — poses, not shoot animations

The body doesn't animate a shot; it holds a STANCE and the weapon layer does the
firing (rotation toward target within the facing, recoil kick, muzzle flash,
projectile). Two stances, generated as PixelLab character STATES (4 rotations each,
EMPTY extended hands so the drawn weapon doesn't fight a baked one):
- **Aiming** — standing two-handed brace, arms extended. Entered on engage.
- **Kneeling** — down on one knee, braced. [SPACE], carries the accuracy/cover bonus.

Mechanically each stance is just an ANIMATION GROUP in the character's bank
(`animations/Aiming/<dir>/frame_000.png` — single-frame pose) + its own weapon-anchor
scene (the extended hands hold the gun elsewhere than a walk does). GroundCharacter:
`set_pose("aiming"|"kneeling"|"")` — pose overrides walk/idle; a character WITHOUT
that group gracefully keeps walk/idle frames (the weapon still aims). PixelLab has no
shoot/aim TEMPLATE — states are the way. Body-recoil frames are optional later polish;
recoil reads fine on the weapon sprite alone.

Enemy/melee/death DO use body animation (templates: cross-punch, falling-back-death,
taking-punch, throw-object for the grenade).

## Abilities — profession TECHNIQUES (user: "equipped like spells in fantasy MMORPGs")

- NOT chips. A character's ability book = what their PROFESSION has trained into them
  — learned at the leader's office (the ability TREE is the syllabus), possibly rank
  by rank with standing/level gates.
- **PREPARE 5** onto the character bus ([1]-[5], own save key, auto-wire rules mirror
  Pilot.autowire). Re-preparing in the field = **Meditate [K]** (the Going-Dark
  mirror: cell dumps into recharge, you're defenseless, cold circuits = safe to
  re-prepare).
- Pre-commission characters get a small UNIVERSAL set (basic strike, patch-up) so the
  first scrit fight works before joining anyone — the tutorial-safe floor.
- The six profession identities ARE the ground kits (already locked in
  docs/professions.md): Guardian paladin (brace, taunt, self-mend), Privateer shadow
  knight (drains, terror), Miner (tangle), Scout (blink), Science (mend-field),
  Trader (blackout). Ship chips and ground techniques SHARE the identity, not the
  implementation.

## Combat verbs (already reserved in scripts/keys.gd)

- **LMB** select (never attacks) · **RMB** target + ENGAGE a hostile (auto-attack on)
- **Q** toggle auto-attack (weapons-free mirror) · **TAB** cycle foes
- **R** grenade — the ordnance mirror: consumable, finite, restocked at Bram's
- **SPACE** kneel/cover · **SHIFT** sprint · **1-5** techniques · **F1-F4** frames
- Auto-attack resolves by weapon (melee closes to reach; ranged fires in range) — no
  aiming ever.

## Enemies — v1: the SCRITS (user: "akin to jawa")

Art banked: `assets/characters/Scrit` + `assets/portraits/scrit.png`.
- Pack scavengers of the open roam: cowardly alone, brave in threes.
- Live in authored PLACES (a warren past the heat-shimmer, spawned like the Rust
  Shoal pattern — never on-player). **The town is sanctuary** (mirror of the station
  sanctuary rule): scrit never cross the colony's light.
- Behavior v1: skulk → pack up → rush → melee swipe → break-and-run at low HP
  (they're scavengers, not soldiers). They steal dropped loot if left alone (flavor
  hook, later).
- Loot: trinkets (sellable), occasional rolled ground gear, the odd stolen commodity.
- Kills feed `Wallet.xp` (KILL_XP pattern) — one spine.

## Death — v1 behavior + OPEN final design (user: do NOT finalize)

v1 (buildable now): go down → **held BAG inventory drops** in a satchel at the spot
(recoverable), **equipment stays on you**, wake at the Starport. Ship/stash untouched.

**OPEN — build the seam, not the policy** (user leans EverQuest-light): future
penalty may add XP loss (possibly de-level) + a recoverable corpse. So: route all
consequences through one `GroundDeath.apply()` (or equivalent) with the drop-bag as
its only v1 effect, and keep XP mutation / corpse registry as explicit TODO seams.
Nothing else may hardcode death consequences.

## v1 build scope (in order)

1. Schema — **BUILT 2026-07-25**: `GroundGearDef` (extends ComponentDef; 9-slot enum,
   worn mitigation/health/barrier + weapon damage/range/cooldown/two_handed/melee +
   drop-in `art_key`/grip, `weapon_views()` = THE art discovery), catalog in
   `data/ground/*.tres` (seed: `tools/generate_ground_gear.gd` — regen OVERWRITES),
   ground affixes (keen/quickdraw/farshot/hardened/warding), `Pilot.ground_gear`
   {slot:{base,affixes}} persisted + `ensure_ground_kit()` once on first landfall
   (pistol/vest/pants/boots). `Pilot.equip_ground` returns `{ok,msg,out}` — `out` =
   EVERYTHING displaced (two-hander shoves the Offhand out too, never overwrites it);
   unequipping the Offhand LOCK is refused (drop the Main instead).
   `GroundStats.derive` = the ONE stat source; town `apply_gear(fresh)` maps it onto
   the walker + dresses the Main weapon (`fresh=false` keeps the health fraction — a
   vest swap is never a free heal). Dossier [P] gained an EQUIPMENT tab (9 rows,
   right-click unequip→hold, derived block alongside) and the Inventory tab's ONE
   verb: right-click equips ground gear. Scrit clutch drops (22%,
   `Scrit.DROP_POOL`, affix-rolled → ship hold). Tests: `tools/test_ground_gear.gd`
   (--script; two-hand rules sabotage-verified) + drop checks in test_ground_combat.
2. GroundActor combat: health/barrier/mitigation, auto-attack, target/engage verbs — BUILT.
3. Scrit AI (pack skulk/rush/flee) + warren spawner + town sanctuary — BUILT.
4. Techniques — **BUILT 2026-07-25**: `scripts/ground/techniques.gd` (Techniques.LIST,
   `source` = "universal" or a profession id; `known()` = the floor + your commission's
   syllabus; drop-in art `assets/icons/techniques/<id>.png`; `tooltip_body` returns a
   STRING so the file stays UI-free and parses under --script). v1 set: Field Patch /
   Kick Sand / Second Wind (universal) + Brace (guardian, the profession seam).
   `Pilot.techniques` = the CHARACTER's own 5-slot bus, its own save key, never
   `Pilot.gems` — `set_technique` (one technique, one key) + `autoprepare()` (mirrors
   autowire: drop unknown, fill open, leave placed keys alone), called on landfall.
   THE CELL: `GroundGearDef.energy`/`energy_recharge` + `GroundStats.BASE_ENERGY 60` /
   `BASE_RECHARGE 1.4` so the floor set works in rags; `spend_energy` refuses without
   spending (the ship's invariant). EFFECTS LIVE ON GroundCharacter (`mend`,
   `apply_stun`, `apply_haste`, `apply_brace`) so a future scrit shaman or ally uses
   the identical call — the AI-specialist rule. Reeling and meditating root you in the
   ONE motion path, so no controller can walk out of it. `set_meditating` = [K], the
   Going-Dark mirror (MEDITATE_REGEN 9/s, stands you down, kneeling pose). Town owns
   the dispatch (`_use_technique`) and every refusal is LOUD and specific, always
   BEFORE the spend. Readout: `scenes/ground/technique_bar.gd` (bottom-centre bus +
   cell gauge, cooldown curtain, ✕ when the cell is short) — a readout only, it never
   decides. Prepare UI = dossier [P] → TECHNIQUES tab (select-slot-then-pick, the ship
   bus's gesture). Test: `tools/test_techniques.tscn` (37 checks).
5. Bags [B] + drop-satchel death + Starport wake (v1 seam BUILT as GroundDeath.apply).
6. Grenades [R] later (needs consumables); cover [SPACE] — BUILT (kneel mitigation).

## Open questions (parked)

- Final death penalty (EQ-light XP/corpse — user decides later).
- Do ground skills reuse the 7 ship skills' seams or get ground-facing meanings?
- Barrier emitter as ACCESSORY vs its own slot; mitigation cap value.
- Scrit standing/faction (are they a Standing entry or vermin?).
- PvE only for now; coop targeting frames (F1-F4) when party exists.

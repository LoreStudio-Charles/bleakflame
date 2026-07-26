# Space Combat — Reference

**Derived from the code 2026-07-26, not from memory.** Every number here was read out of
source. Status tags are load-bearing:

- **BUILT** — wired; something reads it at runtime.
- **QUEUED** — specced, agreed, not implemented.
- **DEAD** — exists on a schema but *nothing reads it*. Do not balance around these.

For ground combat see `docs/combat_ground.md`. The two are deliberately separate systems
and should not be reasoned about together — most notably, **ship armor ABLATES and
character armor MITIGATES**.

---

## 1. The damage pipeline

`BuildShip.take_damage(amount, source)` — `scenes/flight/build_ship.gd:721`. This is the
only path into a ship's health. In exact order:

```
1.  dead?                        → return
2.  source given                 → _last_attacker = source     (kill credit)
3.  _regen_blocked = 2.5s        (SHIELD_REGEN_DELAY — see the trap below)
4.  remaining = amount × (1 − _dmg_reduction)     ← the ONLY mitigation in the game
5.  shield absorbs  min(shield, remaining)
6.  armor  absorbs  min(armor,  remaining)
7.  hull   takes    whatever is left
8.  sfx + flash
9.  hull ≤ 0                     → _die()
```

**There are no damage types, no per-layer resistances, and no armor penetration.**
Overflow cascades in full. A point of shield, armor and hull are worth exactly the same.
(That is what `docs/armor_and_penetration.md` is queued to change.)

`_dmg_reduction` has exactly one source: **Bulwark** (`apply_bulwark`, build_ship.gd:442)
— the Guardian ability and the AI **Warden** specialist. It never downgrades
(`maxf`), and on expiry it is zeroed outright.

**Two traps worth knowing:**

- **Shield regen stalls on any hit at all** — `_regen_blocked` is set at step 3, *before*
  mitigation, so a fully-bulwarked or zero-damage call still costs you 2.5s of regen.
- **A second, weaker Bulwark during a stronger one** raises only the timer; when it
  expires the reduction drops to 0 rather than stepping down.

### Overrides

| Class | Behaviour | Where |
|---|---|---|
| `Ship` (player) | **Docked = invulnerable** (returns immediately). Auto-retaliates: an unheld target becomes the attacker. | ship.gd:531 |
| `AIShip` | Break-and-run: if shields just broke, or a flat 12% roll otherwise, flees 2.5–4.0s with guns cold (min 6s between breaks). | ai_ship.gd:467 |

### Collision damage — BUILT

Same pipeline, no `source` (so ramming never sets kill credit).

| Const | Value |
|---|---|
| `COLLISION_MIN_SPEED` | 260 — below this, free |
| `COLLISION_DMG_PER_SPEED` | 0.06 per unit above the floor |
| `COLLISION_DMG_CD` | 0.7s between impacts |
| `OBSTACLE_BOUNCE` / `OBSTACLE_KICK` | 0.45 / 55 |

≈20 damage at 600 speed, ≈38 at 900. Skipped while `cinematic` or docked. Only the
*normal* component counts, so a glancing scrape is cheap and a head-on ram is not.

---

## 2. Defensive layers

| Layer | Source | Regenerates? | Notes |
|---|---|---|---|
| **Shield** | `DefenseDef.shield_hp`, summed | **Yes** — `shield_regen` hp/s, after 2.5s untouched | Zeroed every tick while Going Dark |
| **Armor** | `DefenseDef.armor_hp`, summed | **No** — only `repair()` and Going Dark | Ablative only today |
| **Hull** | `HullDef.hull_hp` **only** | No | Components never add hull |
| **Evasion** | `Pilot.evasion()`, player only | — | Shrinks the **hit profile** for every weapon test |
| **`_dmg_reduction`** | Bulwark only | — | The only multiplier |

`repair()` fills **hull first**, then armor. **Never shields.**

**Going Dark** (`ship.gd:1159`): `shield = 0` every tick (no absorption at all),
`repair(14/s)`, drag `0.15`, energy regen ×4, reboot lockout 2.6s on exit.

> **DEAD: `DefenseDef.kind`** (SHIELD / ARMOR / COMPOSITE). Written by the generator,
> read by nothing. Whether a plate is a shield or armor is decided purely by which of
> `shield_hp` / `armor_hp` is non-zero.

---

## 3. Weapon stats — what each one actually does

| Stat | Default | Mechanic | Status |
|---|---|---|---|
| `damage` | 5.0 | × `dmg_mult` at spawn. Beams apply it **per `fire_interval` tick**. | BUILT |
| `fire_interval` | 0.3s | Cooldown between shots. | BUILT |
| `projectile_speed` | 900 | Muzzle speed, *before* shooter-velocity inheritance. Also the lead-solver's speed. | BUILT |
| `weapon_range` | 700 | **Only as a lifetime**: `life = range / speed`. Not a distance check. Also the beam's ray length and the AI's fire gate. | BUILT |
| `traverse` | 0 | `traverse_speed() = traverse if > 0 else 360/mark` deg/s. | BUILT |
| `magazine` / `ammo_price` | 0 | Ordnance: dry click at 0, restocked at dock per round. | BUILT |
| `hit_bonus` | 0 | Added to the bolt's grace radius. **Projectiles only.** | BUILT (gap) |
| `blast_radius` | 0 | > 0 enables the proximity fuze + splash + end-of-life detonation. | BUILT |
| `blast_falloff` | 0.45 | Damage retained at the rim. | BUILT |
| `homing` | 0 | > 0 = "this homes"; also the flat deg/**second** fallback rate. | BUILT |
| `seek_nearest` | false | true = HEAT (re-picks the nearest each frame); false = RADIO (locks the shooter's target at launch). | BUILT |
| `homing_by_band` | empty | Needs **exactly 5** entries; deg per **10 units travelled**, indexed by the target's size band. | BUILT |
| `mining_power` | 0 | Ore extracted per hit against rock. | BUILT |
| `beam` | false | Instant hitscan ray; no projectile. | BUILT |
| `beam_tail` | 0 | Pulse-laser visual only. A collapsing tail **cannot damage anything**. | BUILT (cosmetic) |

**Range is a lifetime, and bolts inherit the shooter's velocity.** So a weapon's reach in
its *own frame* is always exactly `weapon_range`, while its reach across the *world*
grows with your speed. Homing bolts also burn life while turning, so an evading target
effectively shortens a missile's reach.

---

## 4. Hit resolution

### Ballistic bolts — per physics frame, in order

1. A collapsing pulse tail returns immediately — **it can no longer hit anything**.
2. Homing steer (speed preserved, direction rotated).
3. Move; decrement life. At life 0: detonate if it has a blast, else expire.
4. **Proximity fuze** (blast weapons only): detonates within
   `blast × 0.7 + hit_profile_of(target)`. A point check at the current position — **no
   sweep**, but evasion counts.
5. **Swept segment test** against `prev → now`, so fast bolts cannot tunnel:
   ```
   radius = BuildShip.hit_profile_of(target) + grace     # = hit_radius × (1 − evasion)
   ```
   **Evasion is a deterministic profile shrink, not a dodge roll**, and all four weapon
   tests share the same helper. `grace` is 5.0 for player mounts, 0.0 for AI, plus the
   weapon's `hit_bonus`.
6. Asteroids use the same sweep with **no evasion and no grace**, and block everyone's fire.

### Blast falloff — exact

```
d = max(distance_to_target_centre − hit_profile_of(target), 0)   # surface distance
if d ≤ blast:  damage × lerp(1.0, blast_falloff, d / blast)
```

Linear from full at the hull surface to `blast_falloff` at the rim. Because the fuze
fires at 0.7 × radius, a fuzed hit lands around `lerp(1, falloff, 0.7)` — with falloff
0.45 that is ~62% of `damage`, with 0.7 it is ~79%. Splash hits **everything** in the
target group plus rocks, excluding the shooter.

### Beams

Ray along the barrel, max `weapon_range`, nearest valid target wins, damage once per
`fire_interval`. **Beams cannot miss once you are in the ray** — but the ray tests against
the evasion-shrunk profile, so an evasive target is a narrower ray to be in. No
`hit_bonus` (that stays projectile-only) and no blast.

### Aim assist — player only

A `nose_locked` mount whose shot is within `ASSIST_CONE_DEG 14°` of the firing solution
bends by up to `ASSIST_SNAP_DEG 7°` toward it. **AI never gets this.**

### Turrets and arcs

- Player mounts with `arc_deg ≤ 60` are **nose-locked**: steering is aiming.
- Wider mounts self-track: they slew toward the intercept point at `traverse_speed`,
  clamped to `arc_deg / 2` either side of their facing.
- `intercept_point` leads by `lead_factor` (**0.6** for all AI and Guardians) but cancels
  the shooter's own velocity **exactly** — physics, not skill.
- **A mount fires along its current rotation whether or not it has finished slewing.**
  There is no "out of arc, hold fire" check, so traverse lag causes real misses.

> **Coverage:** evasion now applies to all four weapon tests — bolt sweep, proximity
> fuze, beam ray and blast surface distance — via `hit_profile_of`. It deliberately does
> NOT apply to collisions (physical), Cinderweb's bite (designed as unavoidable terror),
> or abilities. `hit_bonus` still never reaches beams.

---

## 5. The multiplier stack

### Outgoing damage, in order

1. **Authored `damage`**, already mutated by any affixes baked in at drop time
   (`keen` +18%, `rapid` −12% interval, `longbore` +22% range, `swift` +30% speed,
   `tracking` ×1.6 traverse, `deeprack` ×1.5 magazine).
2. **`WeaponMount.damage_mult`**:
   - Player → `Pilot.damage_mult()` = `1 + level × combat_tier`
   - Guardian → `max(MILITARY_DMG 3.0, Progression.damage_mult(level))`, where
     `damage_mult(L) = 1 + (L−1) × 0.32` — so L35 ≈ **11.9×**
   - **Pirates → 1.0. AI damage does not scale with level at all.**
3. **Blast falloff**, if any.
4. **Target's `(1 − _dmg_reduction)`**.
5. Shield → armor → hull.

Abilities bypass mounts and apply `Pilot.damage_mult()` directly.

### Defensive pools, at `apply_build`

1. `ShipStats.aggregate` sums authored values.
2. **Level rescale** (only if `spawn_level != hull.level`):
   `toughness_between(from, to) = toughness_mult(to) / toughness_mult(from)`, where
   `toughness_mult(L) = 1 + (L−1) × 0.28`. Applied to hull, armor **and** shield.
3. **Guardian military ×3** on hull and armor. **Shields are not tripled.**
4. **Player Pilot dials** — `hull_mult`, `armor_mult`, `shield_hp_mult` (all
   `1 + level × combat_tier`), `shield_regen_mult`, `cargo_mult`.

### Handling (everyone)

`accel = thrust / mass`; `_accel = accel × 66`; `_max_speed = accel × 44`;
`_turn_speed = clamp(220 / mass, 0.3, 4.5)` — the 0.3 floor is what makes capitals
ponderous.

---

## 6. Detection

| Rule | Value | Where |
|---|---|---|
| `AGGRO_RANGE` | 950 — the **ceiling** on acquisition | ai_ship.gd:50 |
| `acquire_range()` | `min(AGGRO_RANGE, sensor_reach(0))` — **a hunter sees only as far as its sensors**; 0 sensors = never acquires | ai_ship.gd:426 |
| `LEASH_RANGE` | 1700 — **retention only**. Acquire close, leash far. | ai_ship.gd:54 |
| Silent | `runs_silent()` × **0.4** reach. Base is always `false`; only the player's **Going Dark** returns true. | build_ship.gd:313 |
| `sensor_reach(floor)` | **0.0 with no sensor fitted**; the floor applies only to a ship that has eyes. `sensor_range` aggregates as **max**, not a sum. | build_ship.gd:325 |
| Sanctuary | `SANCTUARY_R` **2600** around the station; nothing engages inside unless `sanctuary_suppressed` | ai_ship.gd:66 |
| `classify()` | Names a contact's ROLE. Needs `role_id_range > 0` **and** ≥ distance. Augur array = 1800. Chips never contribute. | ship.gd:2001 |
| Hidden | Cloak / decoy / blackout set `is_hidden()`, which drops the contact entirely | ship.gd:1111 |

**Attacker queue:** only the closest `MAX_ATTACKERS 2` press the attack; the rest hold at
`STANDOFF_RANGE 680`. Hulls over `HEAVY_MASS 100` ignore the queue.

**Specialists:** `SPECIALIST_CHANCE 0.13`, only above `SPECIALIST_MIN_MASS 40`.

| Role | Cooldown | Effect |
|---|---|---|
| Mender | 9s | Heals 55 to the worst-wounded ally within 700 (only below 85% hull) |
| Warden | 16s | 0.45 reduction for 5s, self + allies within 520 |
| Binder | 14s | TangleField on prey within 850, 2.6s |

---

## 7. Energy

- **Pool** = sum of `ReactorDef.energy_capacity`. **Recharge** = sum of `energy_recharge`.
  Legacy reactors that publish neither fall back to a LOAD-derived formula.
- `energy += regen × energy_regen_mult × delta`. Refit and docking top off free.
- **Only module abilities cost energy.** Firing weapons, shields, thrust, boost and
  turning are all free — there is no capacitor or weapon-heat system.
- Typical costs: cloak 22, bulwark 20, repair field 25, killshot 18, tangle 12, warp 10,
  lance 8, blight 6. **Survey Scan is free by design.**
- **At zero:** the ability is refused with a loud red note, and **nothing is deducted**.
  Cost is charged only after every other check passes, so a mis-aimed press is free.
  There is no other penalty — the ship flies, shoots and shields normally.

---

## 8. Dead stats — do not balance around these

Nothing reads any of these at runtime:

| Thing | Note |
|---|---|
| `DefenseDef.kind` | Shield/armor decided by which HP field is non-zero |
| `HullDef.trait_id` / `trait_description` | Every hull has one; no mechanical hookup exists |
| `HullDef.grade`, `category` | Display only (`level` **is** live) |
| `ComponentDef.hazard` | Zero readers |
| `ShipStats.dps` | Computed, only ever printed |
| `Progression.toughness_mult` (absolute) | Only the *ratio* form is used |
| `Progression.damage_between` | No caller outside tests |
| `CouplingDef.bonus_*` | Aggregation is wired; every shipped coupling is 0 |

**Partly dead / wrong:**

- **Gunnery's advertised "wider firing arcs" does not exist.** `traverse_mult` feeds slew
  rate only; `arc_deg` comes solely from the hardpoint and nothing ever widens it.
- **The `surging` affix says "+12% capacity" but raises `power_output` (LOAD)** — stale
  since the reactor split.
- **`ShipStats.validate()`'s power rule is advisory in flight.** Overdraw is refused at
  the refit screen but there is no runtime brownout — which is why NPC builds could ship
  illegal until `test_hulls` started checking them.
- **`beam_tail`** is rendering only.

---

## 9. THE SYSTEM WE WANT

Everything above is what the code does today. This section is the **target** — the
system we are building toward, so that anything not matching it is a known gap rather
than an accident. Sections 1–8 describe reality; **this one wins when they disagree**.

### 9.1 Principles

Five rules, all established in design conversation, in rough order of how often they
decide an argument.

1. **A component PROVIDES something — that is why it is worth its mass and draw.**
   If a component does nothing, why carry it? The corollary is the rule worth enforcing:
   **never grant what a ship has not equipped.** Every free floor, default or fallback is
   a component nobody needs to buy. (This is what the `maxf(600, sensor_range)` floors
   were: sensing handed out free, which made the Tin-Ear set worthless.)

2. **The layers are different MATERIALS, not one HP bar.** Shields regenerate and stop
   everything. Armor ablates *and* mitigates, and can be answered by the right weapon.
   Hull is the thing you are protecting. Rules are **layer-local** — armor's mitigation
   never applies to shields or hull.

3. **Information is a capability you buy.** Detection, role identification, telemetry —
   all gear, all gated, and silence is the honest answer when you cannot tell. Never
   imply a target is ordinary just because you cannot read it.

4. **Physical size and combat size are different questions.** How big a ship is to bump
   into is not how big it is to shoot. Evasion changes the second, never the first.

5. **Authored, not derived.** A stat should state what it does rather than have it
   inferred from something else. `mark` says how BIG a gun is; it must not silently also
   decide what the gun can hit.

### 9.2 The three radii

| radius | answers | changes with | status |
|---|---|---|---|
| **Physical** (`hit_radius`) | collision, bumping, planetoid surfaces, AI spacing | hull only | **BUILT** |
| **Hit profile** (`hit_profile_of`) | every weapon test — bolts, beams, fuzes, splash | **evasion** | **BUILT** |
| **Interaction** (`interaction_radius`) | pickups and salvage reach | **hull size + components** | **BUILT** |

Interaction reach was a flat `SALVAGE_RADIUS = 95.0` on the player — it did not scale with
hull and **no component could influence it**, so a cargo scoop was unbuildable. It is now
`BuildShip.interaction_radius()`: the **hull** provides the baseline (a bigger hull has a
bigger door — `max(95, hit_radius x 2.4)`) and gear raises it from there, aggregated as a
MAX because two scoops do not reach twice as far. The **Grapple Scoop** (Salvage, 260) is
the first module that exists *because* the stat does.

Still flat and not yet on this seam: **docking and scan reach.** Those are separate
constants today and would be the natural next users of the same property.

**Kept as plain distance math, not Area2D** — decided deliberately. Projectiles are not
physics bodies, and a 2200-speed bolt covers ~37 units per frame against a ~14-unit
target, so the **swept** segment test is more *correct* than an overlap check, not merely
cheaper. Blast falloff needs a real distance anyway. Area2D remains reasonable for the
*beneficial* radius later, if enter/exit semantics are wanted — but the property matters
more than the mechanism.

> **The known weakness of the math approach:** every new hit test must remember to call
> `hit_profile_of`. That is exactly how evasion came to work in one place and be forgotten
> in four. A collider is structurally correct by default; math is correct if you are
> disciplined. **Any new weapon hit test goes through the shared helper.**

### 9.3 The layered defence

The target, per `docs/armor_and_penetration.md` (spec complete, not built):

| layer | mitigates? | ablates? | answered by |
|---|---|---|---|
| Shield | no | yes (pool) | anything; it is the clean outer answer |
| **Armor** | **YES — layer-local DR** | yes (pool) | **Heat / Penetration / HESH** |
| Hull | no | it *is* the ship | getting through the above |

So an armored ship is not globally tougher — it is tougher **for exactly as long as its
armor lasts**, which makes stripping armor a real objective and gives shields and armor
genuinely different characters.

**This resurrects a currently-dead stat.** `DefenseDef.kind` is read by nothing today, and
`ShipStats` collapses every plate into one `armor_hp` number. The spec's rule — *you get
the LOWEST DR of all fitted plates, because Murphy's Law says that is where the shot
lands* — needs **per-plate** data. So implementing armor means `kind` becomes live and
`ShipStats` must keep the individual plates, not just their sum.

### 9.4 Weapons declare their answers

A weapon should say what it is good against rather than have it inferred:

- **`traverse`** — authored deg/s. **BUILT.** `mark` no longer decides tracking, which is
  what made the Palisade flak battery (Mk4, 420°/s, short reach) possible.
- **`heat` / `penetration` / `hesh_bonus`** — **QUEUED.** All default to 0, so every
  existing weapon behaves exactly as it does now and the system is opt-in per gun.
- The payoff is that this needs **no new weapons** — it fills numbers in on the arsenal
  already shipped and turns a flat list into a set of answers.

### 9.5 Perception is bought

**BUILT:** `sensor_reach` (0 with no sensor — blind means blind), `role_id_range` on a
blue L10+ array, AI acquisition capped by its own sensors, retention deliberately
separate.

**QUEUED:** the **computer as a data tier** — modules produce data, the computer decides
how much reaches you. That gives the long-unused `"computer"` tag a job and gives every
future telemetry feature one gate instead of each inventing its own. Armor heat readouts,
ordnance counts, enemy energy state, module cooldowns — all the same question, asked once.

### 9.6 What does not match yet

Ordered by how much the mismatch costs.

| Gap | Why it matters |
|---|---|
| **Armor is pure HP** | A point of armor equals a point of hull; no weapon can specialise. Spec is complete — this is the biggest single upgrade available. |
| **AI damage does not scale with level** | Only `GuardianShip` applies `Progression.damage_mult`. A level-25 Recluse is as tough as designed but hits like a level-1 pirate. **Decide before levelling more content.** |
| **Every hull has a `trait_id` and none of them do anything** | Nine authored traits, zero hookups. Either wire them or stop authoring them. |
| **Gunnery advertises "wider firing arcs"** | Not implemented. Either widen `_half_arc` or fix the text. |
| **`ShipStats.dps` and `DefenseDef.kind` are dead** | `kind` comes alive with armor; `dps` is display-only and should probably say so. |
| **`surging` affix text says capacity, code raises LOAD** | Stale since the reactor split. |
| **Overdraw has no runtime consequence** | `validate()` refuses it at the refit screen, but nothing enforces it in flight. |

### 9.7 Open decisions

Genuine forks — not to be guessed at.

1. **Should AI damage scale with level?** Today only Guardians do. If pirates should too,
   the region bands on the Long Lane start meaning something on offence as well as
   defence; if not, level is a toughness-only axis for enemies and should be documented
   as such.
2. **What do hull traits do?** Every hull carries one as flavour. Options: wire them as
   real modifiers, demote them to pure description, or make them the seam for a future
   perk system.
3. **Should anything besides abilities cost energy?** Right now guns, shields, thrust and
   boost are all free, so a reactor's *recharge* only matters to ability users. Making
   sustained fire draw power would give Capacity a second job — and would be a large
   change to how combat feels.
4. **Does overdraw do anything in flight?** A brownout rule would make the LOAD budget a
   live constraint rather than a fitting-screen one.
5. **Should docking and scan reach join the interaction seam?** Salvage now runs on
   `interaction_radius()`; docking and scanning are still separate constants. Folding them
   in would make one module improve all three — which may be too much for one component.

### 9.8 WEAPONS — the target design

Designed with the user 2026-07-26. **None of this is built.** Sections 1–8 describe the
weapons we have; this is the weapon system we are building toward.

#### Damage

**Level and QUALITY determine base damage** — a table or a curve, whichever proves easier
to tune. Not a multiplier stacked on the pipeline: they produce the starting number.

This is simply how gear is expected to behave. Nobody picks up a higher-level weapon
expecting it to underperform the one in their bag, and an Experimental that hits like
Salvage is a letdown, not a balance decision.

Defences will scale on the same axes. That is a later section — we are documenting
weapons here — but it is a **hard dependency**: offense scaling on level and quality while
defence scales on neither collapses time-to-kill. Neither half ships alone.

#### `damage_cycle` — instant vs recurring

| Value | Meaning |
|---|---|
| `nil` | **Instant.** Damage lands once, on hit. The common case by far. |
| `{duration, period}` | **Recurring.** Damage every `period` seconds for `duration` seconds. |

Recurring weapons are **much rarer**, with **lower base damage and lower scaling** — the
trade is that the total arrives over time instead of now. In fiction it is what sets a
ship's interior alight, or an acid in the damage profile.

**Stacking rules:**

- Same DoT from the **same source** → **refreshes**.
- Same DoT from a **different source** → a **separate effect**, even if it is the same
  ability.
- **One source, one stack** of a given DoT — and this applies per *line*, not just per
  ability, so two ranks of the same line do not double up.
- **Maximum 10 debuffs** on a target.

`blight.gd` already implements a working DoT and should be the basis rather than a second
implementation.

#### `damage_type`

Four to start. **Shields and hull may each carry resistances**, making them more or less
effective against each.

| Type | Role |
|---|---|
| **Impact** | the baseline — kinetic, no rider |
| **Heat** | **applies Heat stacks**, the armor-stripping mechanic in `docs/armor_and_penetration.md` |
| **Antimatter** | **the anti-HULL answer** — 125% hull, **75% shields *and* armor** |
| **Radiation** | **the anti-SHIELD answer** — 125% shields, extended regen cut, builds **Contamination** |

**Heat is deliberately one concept, not two.** Taking Heat damage is what builds Heat on
the target, so the damage type and the armor mechanic are the same system seen from two
ends rather than a name collision.

##### WEAPONS ATTRIT. ABILITIES CONTROL. (user, 2026-07-26)

**A weapon effect may NEVER debilitate.** Wearing a target down is a weapon's job; taking
away what a target can *do* — stun, root, blind, disable, silence — belongs to ABILITIES,
and specifically to the control professions. A weapon that debilitates tramples the thing
those commissions exist to be, and hands out for the price of ammunition what a controller
spends a whole identity on.

**Where a weapon effect and a control ability share a name, they exist at two
intensities.** The weapon version is the mild, attrition-flavoured one; the profession
ability is the real thing. Same fiction, two tiers, and the controller keeps sole ownership
of removing agency.

**Weapon effects should ENHANCE control, not replace it.** A contaminated target is
*easier to control* — tangle sticks better, stuns land more reliably, control lasts a touch
longer. That makes a Radiation gunner the **setup** for a controller rather than a
substitute for one: two players' choices combining into something neither had alone, which
is exactly what the coop north star is for.

> **THIS CORRECTS AN EARLIER LINE IN THIS DOCUMENT.** EMP was written as "the hard blind
> that drops below the visual floor". That is a debilitation and it violates this rule.
> **EMP-the-weapon-effect is a minor sensor/energy degrade that stays ABOVE the visual
> floor.** EMP-the-ability — whoever ends up owning it — is the one that genuinely blinds.

**TYPES AND EFFECTS ARE SEPARATE AXES.** A *type* is what resistances answer; an *effect*
is a rider a weapon inflicts. **EMP is an EFFECT, not a type** — any weapon may carry it
regardless of what damage it deals. Heat happens to be both, because Heat damage is
precisely what builds Heat stacks; that is a deliberate overlap, not the pattern.

Effects known so far: **Heat stacks** (strips armor DR), **EMP** (the hard blind — see
Range), **Contamination** (Radiation, below), and **DoT** via `damage_cycle`. The
10-debuff cap governs effects, not types.

##### Contamination — Radiation's second half

Radiation builds **Contamination** on a target **hit while unshielded**. Contamination
degrades *everything* by a single scaled percentage: turn rate, acceleration, turret
traverse, sensor reach, shield regen, energy recharge.

**Why "everything slightly" rather than "one system at random":** a per-system debuff needs
a separate implementation each, is invisible when it hits something the pilot was not
using, and in a group reads as frustration rather than tactics. One stat degrading
everything is a single implementation, always felt, and scales smoothly with exposure.

**THE MAXIMUM DEGRADE IS VERY MINOR** (user) — think a handful of percent at full
Contamination, not a crippling stack. This is deliberate and it is what keeps the mechanic
honest: it degrades *everything at once*, so even a small number is felt across turning,
tracking, seeing and recharging simultaneously. Push it higher and it stops being attrition
and becomes a soft disable — which is a CONTROL ABILITY's job, not a weapon's. A ship soaking Radiation
should feel like it is *wearing down*, never like it is being switched off.

**It is CUMULATIVE and SLOW to decay** — which is what separates it from Heat. Heat is a
ramp you lose the moment you break off; Contamination lingers, so you fly *away* from a
Radiation fight still degraded. That lingering is the memorable part.

**This is what stops Radiation falling off a cliff.** Because the pipeline is strictly
shields to armor to hull, a shield preference would otherwise mean "strong for five
seconds, then 75% for the rest of the fight". Contamination makes it a TRANSITION instead:
shields up it breaks them and holds them down, shields down it grinds. Radiation is the
**attrition** type.

> **THE DEATH-SPIRAL TRAP, and why it is already closed.** Contamination degrades sensors;
> weapon range is capped by sensor reach; so radiation could in principle disarm a target
> and leave it unable to answer. The range rule already prevents it —
> `min(weapon_range, max(VISUAL_RANGE, sensor_reach))` — because **the visual floor holds
> even at zero sensors.** Radiation shortens your reach; it can never take your guns. That
> also sets the rule for every weapon rider: **no weapon effect may push a target below the
> floor.** Contamination shortens reach and never removes it. Only a CONTROL ABILITY blinds
> outright — see "weapons attrit, abilities control".

##### One layer, one owner

Each defensive layer has exactly **one** answer, so nothing overlaps:

| Answer | Beats | Mechanism |
|---|---|---|
| **Impact** | nothing | the baseline |
| **Heat** | makes armor easier *for everyone* | strips armor DR (armor spec) |
| **HESH** *(weapon attribute)* | **armor** | +% damage to plate |
| **Antimatter** | **hull** | 125% hull, 75% shields and armor |
| **Radiation** | **shields** | 125% shields, extended regen cut, Contamination |

**Antimatter is the FINISHER**, not a generalist. An earlier draft had it at 125% against
armor *and* hull with 75% against shields — but shields are the smallest pool, they
regenerate, and plenty of ships (every V-Shrike build, `pirate_raider`) carry none at all.
Its penalty would have barely existed while its bonus applied to everything that matters,
making it the default pick. It also duplicated HESH, which already owns anti-armor. Paying
75% against *both* outer layers gives it a real weakness and pairs it with Penetration.

Keep resistances **modest — around ±25%, not ×0/×2.** Strong resistances make players
carry one weapon per type and swap between fights, which is tedious rather than tactical.

**Resistances must be readable or they are invisible complexity.** This is the natural
first customer for the *computer as a data tier* idea (§9.5) — reading a target's
resistance profile should be a capability you buy.

##### Type icons (user, 2026-07-26)

Damage type shows as an **icon on the weapon tooltip**:

| Type | Icon | Colour |
|---|---|---|
| **Impact** | bullet | **steel / pale grey** — see note |
| **Heat** | flame | orange |
| **Antimatter** | vortex | dark blue |
| **Radiation** | radio wave | purple |

**These are SHAPE-distinct, not merely colour-distinct**, which satisfies the project's
standing colourblind rule (`grades.gd`: colours always pair with a second channel). Dark
blue and purple sit close on the wheel, but a spiral against concentric arcs reads
regardless of how they are perceived. Keep that property if the set ever grows.

**Impact is NOT pure black.** Every panel in the game is a dark `UiTheme` surface, so a
black icon is nearly invisible on it. Steel/pale grey, or black with a light outline.

**Show the icon AND the name** in the tooltip body. An icon alone is unlearnable the first
time it is seen, and the tooltip is exactly where the player is doing that learning.

**Drop-in art**, matching the existing convention (`assets/icons/components/`,
`assets/icons/materials/`): `assets/icons/damage/<type>.png`, resolved by name with a
procedural fallback, so art lands with no code change.

#### Range

```
effective_range = min(weapon_range, max(VISUAL_RANGE, sensor_reach))
```

Range **scales**, and is **limited by sensor reach** — but with a visual floor (~350–400)
so you can always shoot what is close enough to see out the window. Without that floor,
every combat ship is forced onto the best sensor and "a hauler can have crappy sensors"
stops being true for anyone who fights.

**Some sensors should extend weapon range** — a fire-control array is a weapons upgrade,
not just a map upgrade.

**AN ABILITY-GRADE BLIND STILL KILLS YOUR DAMAGE.** The visual floor covers *having a
cheap sensor*; it must not protect you from a controller who has genuinely blinded you. A
**control ability** drops effective range below the floor — being blinded is supposed to be
devastating.

**WEAPON effects never do this.** Per "weapons attrit, abilities control", no damage type
or weapon rider may push a target below the floor. Radiation's Contamination shortens your
reach; only an ability can take your guns.

#### Rate of fire

**Already exists as `fire_interval`** (seconds between shots); RoF is its reciprocal. No
new stat — but the UI should *show* RoF, which reads far better than an interval.

#### Traverse, magazine, mining

- **Traverse** — no change. Authored per weapon (§9.4).
- **Magazine** — roughly **twice as generous**, and scaling substantially with Mark.
  Mechanics unchanged. Note `ammo_price` likely wants raising to keep the economy sink
  intact, since bigger magazines mean fewer restock trips.
- **Mining power** — **scales with the mining skill.** This wires `Pilot.mining_yield_mult()`,
  which exists today and is called by nothing. `salvage_luck()` is the identical one-line
  fix beside it.

#### Delivery classes

Four ways a weapon can reach its target. Today these are **overlapping booleans**
(`beam`, `homing`, `beam_tail`) with undefined combinations — `beam + homing` is
meaningless and nothing forbids it. **Make it an explicit `delivery` enum.**

| Class | Aiming | Damage ceiling | Status |
|---|---|---|---|
| **Assisted projectile** | Gunnery skill and tracking computers assist | mid | assist + `traverse_mult` exist |
| **Tracking projectile** | tracking lives in the weapon, no skill needed | **lower** — the price of not aiming | `homing` exists |
| **Hitscan** | instant hit, flash or beam as pure visual | **highest** — hardest to aim | `beam` exists |
| **Fire-control** | hit or miss on **Gunnery alone**, no physical tracking | on par with assisted | **new** |

#### Fire-control is an ACCESSIBILITY PATH — that is its purpose

**The reason this class exists (user, 2026-07-26):** so that players with special needs,
or who cannot make playing games a career and develop the reflexes to match, can still
play — and specifically **play socially with friends**. It is not a weapon flavour. Treat
every decision below as an accessibility requirement, not a balance knob.

What follows from that:

- **It looks like a normal weapon.** Fire-control still shows its projectile or beam. The
  ship must not visually announce that this player is using a different system.
- **A miss is shown by the SHOT GOING WIDE**, not by a "MISS" label. The information lands
  either way; a clinical popup marks the player out and a bolt silently passing through a
  hull reads as a bug. Show the round pass wide, or the beam splash off the plating.
- **HIGH hit chance, LOW spread** — around 85–95% with Gunnery, not a swingy roll. This
  matters far more in a group than solo: if your damage is a coin-flip while your friends'
  is steady, you are *the unreliable one*, which is precisely the social experience the
  option exists to prevent. It should feel like a steady weapon that occasionally misses.
- **NEVER called "die-roll" in player-facing text.** In fiction it is **fire-control**:
  the ship's computer aims and you designate. That fits the established targeting-computer
  fiction, and someone choosing it should read a legitimate tech path rather than an easy
  mode.
- **A rung at every level and grade, available to anyone.** If accessible play requires
  one commission, or only exists on a Mk3 gun, it is not accessibility — it is a build.
- **Slightly less damage than the skill classes — and the gap must live in the CEILING,
  not the baseline.** The user's framing: an FCS player should *never feel punished*, while
  a high-skill player feels *slightly rewarded*. Those are the same numbers with opposite
  feelings. If the gap is baked into the baseline, FCS reads as a permanent tax on people
  who need it; if it is what practice unlocks on top, FCS feels complete and the skilled
  player feels earned. **Build it as a ceiling.**
- **It leans heavily on Gunnery**, which is the skill that replaces the reflexes — so the
  progression path is real and investable rather than a flat handout.

Note this does **not** conflict with "evasion is a deterministic profile shrink, not an
RNG miss" — that rule governs *evasion*, which continues to work exactly that way for the
three physical classes. Fire-control resolves on its own axis.

**The wider audit.** The game already has an unusually low-reflex foundation: the mouse
never aims weapons, nose-locked mounts make steering the aiming, targets are selected by
RMB/TAB rather than tracked by hand, and creep-docking is always safe. The remaining
twitch-dependent surfaces are **dodging incoming fire**, the **landing minigame's**
velocity and angle checks, and **Hyperslide**. Fire-control is the biggest piece of the
accessibility goal but not the whole of it — those three deserve the same pass.

#### Open questions

1. **Does `Pilot.damage_mult()` still multiply weapon damage** once base damage carries
   level and quality itself? That is the one remaining double-dip: the pilot's level would
   scale a number that already grew with the item's level. Cleanest is probably that gear
   power comes from gear and the pilot's level scales the *pilot* — but it is a real fork.
2. **How much does Contamination degrade, and how slowly does it decay?** The shape is
   settled (cumulative, lingering, everything by one scaled percentage); the numbers are
   not. It needs a cap, and it needs a readout — an invisible degrade is an invisible
   mechanic, which makes it another customer for the computer-as-data-tier idea.
3. **What happens at the 10-debuff cap** — is a new debuff refused, or does the oldest
   fall off?
4. **Do defences scale on level+quality too, and on what curve?** Named here because
   weapons cannot ship without it.

### 9.9 Reconciliation rule

When this section and sections 1–8 disagree, **this section is the intent and the code is
the bug.** Fix the code or change this section deliberately — never let them drift
silently. That is the failure mode that produced the backwards traverse rationale, the
free sensor floors, and an evasion stat that worked against exactly one weapon type.

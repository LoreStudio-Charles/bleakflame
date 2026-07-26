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
| **Evasion** | `Pilot.evasion()`, player only | — | See the coverage gap below |
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
4. **Proximity fuze** (blast weapons only): detonates within `blast × 0.7 + target radius`.
   A point check at the current position — **no sweep, and evasion is ignored**.
5. **Swept segment test** against `prev → now`, so fast bolts cannot tunnel:
   ```
   radius = target.hit_radius × (1 − evasion) + grace
   ```
   **Evasion is a deterministic profile shrink, not a dodge roll.** `grace` is 5.0 for
   player mounts, 0.0 for AI, plus the weapon's `hit_bonus`.
6. Asteroids use the same sweep with **no evasion and no grace**, and block everyone's fire.

### Blast falloff — exact

```
d = max(distance_to_target_centre − target.hit_radius, 0)      # surface distance
if d ≤ blast:  damage × lerp(1.0, blast_falloff, d / blast)
```

Linear from full at the hull surface to `blast_falloff` at the rim. Because the fuze
fires at 0.7 × radius, a fuzed hit lands around `lerp(1, falloff, 0.7)` — with falloff
0.45 that is ~62% of `damage`, with 0.7 it is ~79%. Splash hits **everything** in the
target group plus rocks, excluding the shooter.

### Beams

Ray along the barrel, max `weapon_range`, nearest valid target wins, damage once per
`fire_interval`. **Beams cannot miss once you are in the ray** — no evasion, no
`hit_bonus`, no blast.

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

> **Coverage gaps worth knowing:** `evasion` is read in exactly **one place** — the bolt
> sweep. Beams, splash, the proximity fuze, collisions and every ability ignore it
> entirely. `hit_bonus` likewise never reaches beams.

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

## 9. Queued changes that will alter this page

- **`docs/armor_and_penetration.md`** — armor gains damage reduction (layer-local), plus
  Heat / Penetration / HESH weapon attributes. Spec complete, not built.
- **`docs/progression_table.md`** — the level→stat table. `toughness_mult` is defined but
  only used as a ratio; the absolute curve is unapplied.

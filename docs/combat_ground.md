# Ground Combat — Reference

**Derived from the code 2026-07-26, not from memory.** Every number was read out of
source. Status tags:

- **BUILT** — wired; something reads it at runtime.
- **DESIGN** — `docs/ground_combat.md` promises it; the code does not do it.
- **DEAD** — exists in code but *nothing reads it*. Do not balance around these.

For space combat see `docs/combat_space.md`. **Keep the two apart.** The headline
difference is deliberate:

> **BOTH ARMORS MITIGATE. The ablating pool on each side is a different layer.**
> Revised 2026-07-26: ship armor lost its hit-point pool and became DR-only, exactly like
> character armor, so the old headline ("ship armor ABLATES, character armor MITIGATES")
> is no longer true. Armor is a percentage in both systems. What ablates is the **shield**
> in space and the **barrier** on the ground — and in both cases it is *energy*, which
> plating does not protect.
>
> The real difference is now narrower and more interesting: **a ship can opt into
> ABLATIVE PLATE** (+10% DR that exhausts as it works, and costs the most to repair —
> `docs/armor_and_penetration.md` §2). There is no character equivalent, and if one is
> ever wanted it should be argued for on its own merits rather than inherited.

---

## 1. The damage pipeline

`GroundCharacter.take_damage(raw, attacker)` — `scenes/ground/ground_character.gd:98`.
The only path into a character's health. In exact order:

```
1.  dead?                          → return 0
2.  attacker given AND no current target AND hostile
                                   → combat_target = attacker      (target only)
3.  _since_hit = 0                 (resets the barrier clock)
4.  BARRIER soaks first:  soak = min(barrier, raw);  after = raw − soak
5.  after ≤ 0                      → return 0        (still reset the clock, still aimed)
6.  mit = clamp(worn + kneel + brace, 0, 0.85)       ← ADDITIVE
7.  taken = max(1.0, after × (1 − mit))              ← a hit ALWAYS costs ≥ 1
8.  health −= taken
9.  health ≤ 0                     → die()
```

**Barrier before mitigation, and mitigation never touches the barrier** — "a barrier is
energy; plating doesn't help it."

**The floor of 1** means no amount of armor makes you immune to chip damage.

**Retaliation aims but does not fire.** Being hit acquires the attacker as a target only
if you had none — it never re-aims a fight in progress and never sets `auto_attack`.

### Mitigation sources — additive, and there are two different caps

| Source | Value | Cap |
|---|---|---|
| Worn gear | sum of `mitigation` across **all** slots | `MITIGATION_CAP` **0.6**, applied in `GroundStats.derive` |
| Kneeling (`[SPACE]`) | `COVER_MITIGATION` **0.25** | — |
| Brace technique | 0.3 for 6s | — |
| **Runtime total** | | hard-clamped **0.85** in `take_damage` |

0.6 worn + 0.25 kneel = exactly 0.85, so a fully-armored kneeling character is at the
ceiling before Brace is even considered.

> **DESIGN vs CODE:** `docs/ground_combat.md` says cover stacks *multiplicatively* with
> plating. The code adds it, and a test pins the additive behaviour. The doc is wrong,
> and the header comment in `ground_character.gd` repeats the same error.

### Barrier — the ablating pool

- Regenerates **out of combat only**: `BARRIER_REGEN_DELAY` **4.0s**,
  `BARRIER_REGEN_RATE` **8.0/s**.
- **The clock keys on being HIT, not on being in combat.** A ranged character killing a
  scrit at 240u regenerates barrier mid-fight.

### Health

**Health never regenerates.** There is no health regen anywhere — only the `Field Patch`
technique and the full heal on respawn.

---

## 2. `GroundStats.derive()` — the stat block

`scripts/ground/ground_stats.gd:19`. Input is the worn gear; output is what the walker uses.

| Const | Value |
|---|---|
| `BASE_HEALTH` | 100.0 |
| `MITIGATION_CAP` | 0.6 |
| `BASE_ENERGY` | 60.0 |
| `BASE_RECHARGE` | 1.4 |
| `UNARMED` | damage 4.0, range 36, cooldown 0.8, melee |

| Output | Formula |
|---|---|
| `max_health` | `(100 + Σ health_bonus) × Pilot.hull_mult()` |
| `mitigation` | `clamp(Σ mitigation, 0, 0.6)` |
| `barrier` | `Σ barrier` — **no cap, no multiplier** |
| `max_energy` | `60 + Σ energy` — **no multiplier** |
| `energy_recharge` | `1.4 + Σ energy_recharge` — **no multiplier** |
| `attack` | Main weapon's damage × `Pilot.damage_mult()`, plus its range/cooldown/melee; else `UNARMED` |

**The loop sums across every slot indiscriminately** — a Grenade or Offhand piece
contributes mitigation and barrier exactly like a chest plate.

**Only two Pilot multipliers reach the ground:** `hull_mult()` on health and
`damage_mult()` on weapon damage. Both are `1 + level × combat_tier`.

**Two asymmetries worth knowing:**

- **Fists are not scaled.** `UNARMED` damage 4.0 is returned raw, so an unarmed
  high-level pilot hits exactly as hard as a level-1 one.
- **`Pilot.energy_regen_mult()` never reaches the ground.** It is a real profession stat
  and is ship-only, so a Trader's +35% energy regen does nothing on foot.

**Gear changes never heal.** Re-deriving preserves the *health fraction* and only clamps
barrier and energy downward — swapping a vest mid-fight is not a free top-up.

**Enemies do not use `derive` at all.** The scrit's block is hardcoded.

---

## 3. Equipment — nine slots

`Head · Chest · Feet · Pants · Hands · Waist · Main · Offhand · Grenade`

| Field | Contributes | Status |
|---|---|---|
| `mitigation` | any slot | BUILT |
| `barrier` | any slot | BUILT (only the Surveyor's Belt, 15) |
| `damage` / `attack_range` / `cooldown` / `melee` | **`Main` only** | BUILT |
| `health_bonus`, `energy`, `energy_recharge` | any slot | **BUILT but no item sets them** |
| `two_handed` | Main | BUILT |
| `art_key` / `grip_x` / `grip_y` | weapon art discovery | BUILT |

> **Offhand weapon stats are unreachable.** `derive` reads the weapon block from `Main`
> only, so an Offhand weapon's damage, range and cooldown do nothing. Its *mitigation and
> barrier* do count — the Scrap Buckler's 0.06 is real.

**Two-handed** uses a marker string (`OFFHAND_LOCK`) written into the Offhand key, not an
item. Equipping a two-hander shoves any Offhand item **out to you** rather than
overwriting it; equipping into a locked Offhand is refused; fitting a one-hander clears
the lock.

### The shipped catalogue

| Item | Slot | Numbers |
|---|---|---|
| Scrap Pistol | Main | 9 dmg, 240 range, 0.6s, ranged |
| Dune Rifle | Main | 16 dmg, 380 range, **1.0s**, ranged, **two-handed** |
| Scrap Shiv | Main | 7 dmg, 42 range, 0.45s, **melee** |
| Scrapweave Vest | Chest | 0.08 mitigation |
| Scrap Buckler | Offhand | 0.06 mitigation |
| Surveyor's Belt | Waist | 15 barrier |
| Canvas Pants / Dune Boots / Rag Hood / Work Gloves | — | 0.03 / 0.02 / 0.02 / 0.02 |

**Starter kit** (granted once, on first landfall): pistol, vest, pants, boots
— **0.13 mitigation, 0 barrier, 100 health, 60 energy at 1.4/s.**

**Ground affixes** roll on scrit drops: `keen` +18% damage, `quickdraw` −12% cooldown,
`farshot` +20% range, `hardened` ×1.25 mitigation, `warding` +12 barrier.

> **`mark` and `grade` do not scale any ground stat.** Mark affects price only.

---

## 4. Techniques

Five bus slots (`BUS_SLOTS 5`), separate from the ship's ability gems — different array,
different save key.

| id | Name | Source | Energy | Cooldown | Effect |
|---|---|---|---|---|---|
| `field_patch` | Field Patch | universal | 25 | 14s | heal 34 |
| `sand_kick` | Kick Sand | universal | 12 | 9s | stun 3s, range 90 |
| `second_wind` | Second Wind | universal | 18 | 22s | haste 5s |
| `brace` | Brace | **guardian** | 30 | 26s | +0.3 mitigation, 6s |

**That is the entire shipped set.** One profession technique exists; the other five
identities are unimplemented.

**Refusal order** — every check runs *before* any spend, so a refused technique costs
nothing: empty slot → unknown → dead → meditating → stunned → on cooldown → (no target /
out of range) → (already at full health) → not enough energy.

**Effects, all on `GroundCharacter`** so an NPC could use the identical call:

- `mend(n)` — heal, capped at max.
- `apply_stun(s)` — refreshes rather than stacks; clears auto-attack, roots, and blocks
  attacking.
- `apply_haste(s)` — `HASTE_MULT` **1.55** on move speed (175 → 271).
- `apply_brace(s, amount)` — read only inside `take_damage`.

**Meditate `[K]`** — `MEDITATE_REGEN` **9.0/s** replaces normal recharge (a 6.4×
speed-up), roots you, kneels you, and blocks all technique use.

**Energy regen always runs**, in and out of combat.

> **DESIGN vs CODE:** the doc says re-preparing techniques in the field requires
> Meditate. It does not — the dossier can re-prepare any time, and meditating merely
> blocks *using* them.

---

## 5. Attacking

`_tick_combat` runs every physics frame, **before** the dead check, so timers and regen
keep ticking.

1. Decay stun / haste / brace; regen barrier and energy; tick the attack cooldown.
2. **Target housekeeping** — a freed or dead target is cleared. This deliberately sits
   *above* the auto-attack guard, and a test pins that ordering.
3. Bail if dead, meditating, stunned, weapons cold, or no attack spec.
4. **Range check** — out of range simply holds fire. *The controller decides whether to
   close; the player is never auto-moved.* With a shiv you walk in yourself.
5. Face the target; ranged characters enter the aiming pose.
6. Off cooldown → fire.

**Resolution is target-locked: no projectile, no aiming, no accuracy roll, and no
line-of-sight check.** In range plus off cooldown means the hit lands. The muzzle flash
and tracer are pure effect.

`combat_target` is a **property setter** that subscribes to the target's `died` signal
(one-shot) and unsubscribes the previous one — event-driven, because in Godot 4 a freed
reference compares equal to null and cannot be distinguished from a cleared one.

**A kill stands you down**: `_on_target_died` clears `auto_attack`, so your next click
selects rather than opens fire.

### Controls

| Input | Action |
|---|---|
| LMB | **select only** |
| RMB | engage — target **and** weapons free |
| `Q` | toggle auto-attack (grabs the nearest hostile if none) |
| `TAB` | cycle hostiles |
| `SPACE` | kneel (cover) |
| `K` | meditate |

Click radius 46px; `TAB` only considers hostiles within 900.

### Death

`GroundDeath.apply` drops **all ship-hold commodities**; equipment is kept. Respawn is a
2.2s fade then a teleport, at full health.

> **DESIGN vs CODE:** the doc describes a personal BAG that drops and a lootable satchel.
> Neither exists — the goods are simply gone. XP loss and a corpse entity are marked TODO
> in the code.

---

## 6. The Scrit

Hardcoded, no Pilot multipliers, no `derive`.

| Stat | Value |
|---|---|
| Health | 34 |
| Mitigation | 0.05 |
| Barrier | 0 |
| Speed | 150 (player 175) |
| Attack | 7 damage, 40 reach, 1.1s, melee |

| AI const | Value |
|---|---|
| `NOTICE_RANGE` | 420 |
| `LEASH_RANGE` | 950 |
| `FLEE_HEALTH` | 0.3 |
| `PACK_RANGE` | 260 |
| `TOWN_SANCTUARY_R` | 1150 |

Behaviour, in order: dormant (ambushers lie in wait) → flee below 30% health for 2s →
skulk near home if no prey → **hesitate unless a packmate is within 260** → rush.

**Town sanctuary:** a scrit will not close on prey within 1150 of the town centre; it
paces at the edge of the light instead.

**`cornered`** disables *both* the flee and the pack hesitation — used for the cave pack,
which has nowhere to run.

**Drops:** 3–9 credits always, plus a **22%** chance of one item from
{shiv, rag hood, work gloves}, rolled through the affix system. Corpses are lootable with
`[E]` within 70u. **+6 XP**, paid by the town, not the actor.

---

## 7. Dead stats and design gaps

**DEAD — nothing reads these:**

| Thing | Note |
|---|---|
| `health_bonus`, `energy`, `energy_recharge` on gear | Summed by `derive`, but **no item sets any of them** — every character has exactly 60 energy at 1.4/s |
| `Slot.GRENADE` | Slot exists in the enum, the name list and the dossier. **No grenade item, and `[R]` is never polled on the ground.** |
| Offhand weapon stats | Only `Main` is read for the attack block |
| `is_braced()` / `is_hasted()` | No readers (`is_stunned()` **is** read) |
| `Techniques.tooltip_body()` | Only called from a test |
| `Keys.BOOST` (`[SHIFT]` sprint) | Never polled — **there is no sprint on foot** |
| `mark` / `grade` | No ground stat scales off either |

**Latent bug:** `_brace_mit` is never reset when the brace expires, and `apply_brace`
takes `maxf` of the old value — so once a strong brace has been used, later weaker braces
would inherit the stronger number. Harmless today because Brace is the only source and is
always 0.3.

**DESIGN promises the code does not keep** (`docs/ground_combat.md`):

1. **`SuitDef` does not exist.** The doc makes the suit a frame carrying the slot set and
   a trait, like a hull. The code has a fixed nine-slot paperdoll and no suit item.
2. Cover is **additive**, not multiplicative (see §1).
3. The mitigation cap is **two numbers** (0.6 worn, 0.85 runtime), not the doc's "~60%".
4. "Melee closes to reach" is implemented **for the scrit only**.
5. `[SHIFT]` sprint — not implemented.
6. `[R]` grenade — slot only; no consumable, no key, no restock.
7. Five of six profession technique identities are unimplemented.
8. Meditate does not gate technique preparation.
9. Death drops the **ship's** hold, not a personal bag; no satchel entity.
10. Kill XP is a hardcoded inline `6`, not a `KILL_XP`-style table.

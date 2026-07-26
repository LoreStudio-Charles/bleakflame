# Progression & Levels — Reference

**Derived from the code 2026-07-26, not from memory.** Companion to
`docs/combat_space.md` and `docs/combat_ground.md`. For the per-profession build-out plan
see `docs/profession_buildout.md`.

Status tags: **BUILT** (read at runtime) · **DEAD** (exists, nothing reads it) ·
**PLANNED** (docs only).

---

## 1. Levels

```
xp_for_level(lv) = 50 × (lv − 1) ^ 1.6      # cumulative, L1 free
```

| Level | 2 | 3 | 5 | 10 | 20 | 30 | 40 | **60** |
|---|---|---|---|---|---|---|---|---|
| XP | 50 | 151 | 459 | 1,635 | 5,558 | 10,935 | 17,542 | **34,031** |

- **Cap `MAX_LEVEL` 60.**
- **Level is never stored.** It is derived from `Wallet.xp` every time it is asked for;
  only the XP is saved. Skill points recompute the same way.
- **No respec exists anywhere.**

### Skill points

`skill_points_total() = level / 4` (integer division). **First point at level 4**, then
every 4 levels — **15 points at level 60**.

### XP sources — all BUILT

| Source | Amount |
|---|---|
| Ship kills | `KILL_XP` — wasp 8 · raider 10 · brawler 14 · vulture 40, × `kill_xp_mult()` |
| Scrit kills (ground) | flat **6**, and it **ignores `kill_xp_mult()`** |
| Quests | 20–100 per beat |
| Tutorial licence | 50 |

---

## 2. What a level actually changes today

This is the complete list. Everything is `1 + level × combat_tier` unless stated.

| Effect | Site | Arena |
|---|---|---|
| Ship hull max | `hull_mult` | SPACE |
| Ship armor max | `armor_mult` | SPACE |
| Ship shield max | `shield_hp_mult` | SPACE |
| **All** weapon damage | `damage_mult` → every mount | SPACE |
| Killshot / Blight damage | `damage_mult` | SPACE |
| **Character max health** | `hull_mult` | **GROUND** |
| **Character weapon damage** | `damage_mult` | **GROUND** |
| Trade buy/sell (Trader only) | `1 ∓ level × 0.005` | DOCK |
| Skill points | `level / 4` | both |
| Guardian standing seed (once) | `clamp(xp / 40, 0, 10)` | one-time |

**Nothing else.** Level does **not** gate techniques, tree nodes, wares, offices,
contracts, quests, ability unlocks, or enemy scaling.

### The growth curve in practice

`combat_tier` is 0.01–0.02, so at **level 60** a pilot has:

| Commission | Tier | Combat growth at 60 |
|---|---|---|
| Guardian, Privateer | 0.02 | **+120%** |
| Miner, Scout | 0.015 | **+90%** |
| Trader, Science | 0.01 | **+60%** |
| *No commission* | 0.01 | **+60%** |

A full career roughly **doubles** you. That is a deliberate shallow curve — gear and
hulls are meant to carry the rest.

---

## 3. Every `Pilot.*_mult()`

| Function | Formula | Arena | Status |
|---|---|---|---|
| `hull_mult` | `1 + level×tier` | **SPACE + GROUND** | BUILT |
| `damage_mult` | `1 + level×tier` | **SPACE + GROUND** | BUILT |
| `armor_mult` | `1 + level×tier` | SPACE | BUILT |
| `shield_hp_mult` | `1 + level×tier` | SPACE | BUILT |
| `cargo_mult` | `1 + rank(hull_discipline)×0.08` | SPACE | BUILT |
| `shield_regen_mult` | `1 + rank(shield_tuning)×0.10` | SPACE | BUILT |
| `evasion` | `min(0.6, rank(evasion)×0.05)` | SPACE | BUILT |
| `energy_regen_mult` | commission rate | SPACE only | BUILT |
| `turn_mult` | `(1.03 courier) + rank(piloting)×0.05` | SPACE | BUILT |
| `traverse_mult` | `(1.05 gunner) + rank(gunnery)×0.08` | SPACE | BUILT |
| `ore_sense_range` | `1600` if Miner | SPACE | BUILT |
| `scan_mult` | `0.9` if prospector background | SPACE | BUILT |
| `repair_mult` | `0.9` if dockhand | DOCK | BUILT |
| `sell_mult` | `1.1` if scrapper | DOCK | BUILT |
| `kill_xp_mult` | `1.15` if militia | SPACE only | BUILT |
| `trade_buy/sell_mult` | `1 ∓ perk("trade")` | DOCK | BUILT |
| `salvage_luck` | `rank(salvage)×0.08` | — | **DEAD** |
| `mining_yield_mult` | `1 + rank(prospecting)×0.10 + perk` | — | **DEAD** |
| `scan_value_mult` | `1 + perk("scan_value")` | — | **DEAD** |
| `insight_mult` | `1 + perk("insight")` | — | **DEAD** |

All combat multipliers are applied in `Ship.apply_build` — **player only**. AI never runs
that block.

---

## 4. The seven skills

`BASE_CAP` 2; a commission raises its favoured caps to 4 or 5. Raising a cap never
invalidates ranks already bought.

| Skill | per rank | Caps | Advertised | Reality |
|---|---|---|---|---|
| **Gunnery** | 0.08 | 5 grd/prv | "Wider firing arcs **and** faster traverse" | **HALF** — only traverse. Arcs come solely from the hardpoint and are never widened. |
| **Piloting** | 0.05 | 5 grd/sct, 4 trd/sci | Sharper turn rate | BUILT |
| **Evasion** | 0.05 | 5 prv/sct, 4 grd/trd | Smaller hit profile | BUILT. Note the `0.6` clamp **can never bind** — 5 ranks is 0.25. |
| **Hull Discipline** | 0.08 | 5 min/trd | More cargo | BUILT |
| **Shield Tuning** | 0.10 | 4 grd/sci | Faster shield recharge | BUILT |
| **Prospecting** | 0.10 | 5 min/sci, 4 sct | Richer mining and scan yield | **DEAD — nothing reads it** |
| **Salvage** | 0.08 | 5 prv, 4 min | Better wreck drops | **DEAD — nothing reads it** |

**Two of seven skills do literally nothing, and a third delivers half its description.**
**No skill affects the ground at all** — every one of them stops at the airlock.

---

## 5. Standing

Range ±1000. **INVITE_AT 10 · FRIENDLY_AT 100 · ALLIED_AT 500 · HOSTILE_AT −100 ·
KOS_AT −500.** One faction per profession.

| Action | Change |
|---|---|
| Kill a pirate | guardian **+1**, privateer **−1** |
| Chart a secret POI | scout **+3** |
| Turn in a contract | **+2** to the *giver's* guild |
| Sell ore | miner **+1 per unit** |
| Turn in Scan Data | science **+ max(1, n/2)** |
| Fence stolen goods | privateer **+2 per unit** |
| First hit on a hauler | guardian **−3** |
| Save a hauler (**your** guns) | guardian **+8**, trader **+6** |
| Kill a hauler | trader **−40**, guardian **−50**, privateer **+8** |
| Krayt's death beat | privateer **+20** |
| Break the Shoal truce | privateer set to exactly **−100** |

**Mending:** 250 credits buys +20, only while negative, capped at 0, once per faction per
game day.

**What standing gates:** the commission door and accept button (INVITE_AT 10); station
docking denied at KOS with the Guardians; the Shoal's pad and fence
(`shoal_invited` or privateer ≥ 100); "wanted" status.

> **`FRIENDLY_AT` is read by only two Shoal predicates, and `ALLIED_AT` gates nothing at
> all.** There are no price changes, no unlocked content, no reputation rewards. The top
> 900 points of the scale are currently decorative.

---

## 6. Ground vs space — the asymmetry

**SPACE has fourteen progression hooks.** Hull, armor, shield, all weapon damage, two
ability damages, shield regen, cargo, turn rate, turret slew, evasion, energy regen, ore
sense, scan time, repair bill, kill XP.

**GROUND HAS EXACTLY TWO:**

```
max_health   = (100 + Σ gear health_bonus) × Pilot.hull_mult()
attack.damage = weapon.damage × Pilot.damage_mult()
```

That is the entire effect of level and profession on foot. Everything else — mitigation,
barrier, energy, recharge, reach, cooldown — comes from **gear alone** and never scales.

### What is missing on the ground

| Gap | Consequence |
|---|---|
| **No skill applies** | 15 skill points buy nothing you can feel on foot |
| **No armor or shield growth** | Only health scales; mitigation and barrier are gear-only |
| **No `energy_regen_mult`** | A Trader's +35% regen does nothing on foot |
| **Techniques gate on profession only** | Never on level or standing — the "office syllabus" gates are unbuilt |
| **Four techniques exist** | Three universal + one Guardian. **Five of six commissions have zero ground techniques.** |
| **Ground XP is flat 6** | Ignores `kill_xp_mult`; no `KILL_XP`-style table |
| **Unarmed damage is unscaled** | Fists hit for 4.0 at level 60 exactly as at level 1 |
| **No death cost** | XP loss / de-level / corpse are explicit TODO seams |

**This asymmetry is the single biggest structural gap in progression.** A level-60 pilot
on foot is a level-1 pilot with more health and a better gun.

---

## 7. The gap list

### Dead skills and perks

1. **Prospecting** — `mining_yield_mult()` called by nothing.
2. **Salvage** — `salvage_luck()` called by nothing.
3. **Gunnery's "wider arcs"** — never implemented.
4. **Scout's `scan_value` perk** — unread; Scan Data sells at base rate.
5. **Science's `insight` perk** — unread; Insight grants ignore it.
6. **Miner's `mining` perk** — only reachable through the dead prospecting mult. The
   Miner's *only* live perk is the hardcoded `ore_sense` radar range, which isn't even in
   the profession list.

> **Of four non-combat perks, only the Trader's works.**

### Trees do nothing

`Professions.branches()` is **pure display**. No node has a cost, a prerequisite, an
unlock state, a level gate or a standing gate. Abilities are acquired *exclusively*
through wares → chip → fit → gem. The docs promise "trait lines, points spent per level";
**no trait points exist in code**.

**11 nodes are designed but `built: false`** — see `docs/profession_buildout.md`.

### Seams defined but unapplied

- `Progression.toughness_mult()` — absolute form never applied; only the ratio is used.
- `Progression.damage_between()` — called only by tests.
- `Progression.damage_mult(level)` — applied in **exactly one place**, GuardianShip. So
  **pirate damage does not scale with level at all.**
- Component `level` / `grade` — nothing scales off either.
- `Professions.LIST` fields `verb` and `abilities` — dead strings.
- `Nemesis` — a complete grudge ledger with **no hook into progression**: no XP, no
  standing, no reward.

### Doc ↔ code disagreements

- `progression_professions.md` lists the Privateer leader as Krayt; code says **Vyper**.
- The same doc lists the Scout leader as "The Counter" and the Trader as "Odessa"; code
  says **Sella** and **Imari**.
- `ground_combat.md` says ground stats derive from "suit + gear + **skills** + profession
  tier × level". **Skills contribute nothing on the ground.**
- `professions.md` advertises Prospecting and Salvage effects that do not exist.
- Blackout "stays in wares until the trees exist" — it does, but `wares()` filters it, so
  it is currently unpurchasable.

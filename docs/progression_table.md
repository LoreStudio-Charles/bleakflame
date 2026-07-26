# Progression Table — level and grade → combat numbers

**Built 2026-07-26.** First-pass curves for `docs/combat_space.md` §9.8 (weapons) and §9.9
(defences). **These are numbers to tune, not numbers to trust** — but they are internally
consistent and anchored to values already shipped, so authoring against them will not
invalidate the existing game.

**THE TABLES THEMSELVES ARE CSV**, one file per quality, under `docs/tables/`:

    progression_flotsam.csv   progression_salvage.csv   progression_standard.csv
    progression_advanced.csv  progression_experimental.csv
    progression_bespoke.csv   progression_exotic.csv

60 rows (one per level) x 37 columns each. **Generated, not hand-maintained** —
`python tools/gen_progression_tables.py` rebuilds all seven from the constants at the top
of that script. Tune one constant, re-run, and every file moves together. Hand-edited
tables drift the moment anyone rebalances, and a table that disagrees with its neighbours
is worse than no table at all.

Columns, in order: `level`, `level_factor`, `hull_*` (5 size bands), then Mk I–V blocks of
`shield_hp`, `shield_regen`, `armor_hp`, `armor_dr`, `dps`, `dot_dps`.

This file is the *reasoning*; the CSVs are the arithmetic. Every number below was read back
out of the generated files rather than computed by hand, so the two cannot disagree.

Supersedes the previous PLANNED stub. The old placeholder formulas in `scripts/progression.gd`
(`damage_mult`, `toughness_mult`) are what this replaces.

---

## 1. The two axes

Everything scales on **LEVEL** and **GRADE**, and both apply to every scaling stat.

### Level factor — COMPOUNDING, cap 60, soft lock 30

```
level_factor(L) = 1.08 ^ (L - 1)          MAX_LEVEL = 60,  LEVEL_LOCK = 30
```

| L | 1 | 5 | 10 | 20 | 30 *(lock)* | 45 | 60 |
|---|---|---|---|---|---|---|---|
| ×  | 1.00 | 1.36 | 2.00 | 4.32 | **9.32** | 29.56 | **93.76** |

**The cap is 60.** `LEVEL_LOCK` is how far content is balanced *today* and is meant to
**rise** — a soft cap that moves, not a design ceiling. The tables generate all 60, so
raising the lock never requires re-deriving anything; a `reachable_now` column marks which
rows are live.

**A level 60 is ~94× a level 1, deliberately.** The usual objection is that a spread that
large wrecks grouping. **The grouping bands below are the answer**, and because grouping is
gated by band rather than by power, the power curve is free to be dramatic.

**"When a player levels they should feel it and rejoice"** (user, 2026-07-26), and that
requires **compounding** rather than linear growth.

Linear growth makes each level a *smaller share of what you already have*. On the previous
60-level linear curve a level was +5.0% at the start and **+1.3% at level 60** —
imperceptible by construction, no matter how the numbers were tuned. Compounding is always
**+8%**, so 29 → 30 feels exactly as good as 1 → 2.

| A level at… | old (linear) | now (1.08ⁿ) |
|---|---|---|
| L2 | +5.0% | **+8.0%** |
| L10 | +3.6% | **+8.0%** |
| L20 | +2.6% | **+8.0%** |
| L30 | +2.1% | **+8.0%** |
| L60 | **+1.3%** | **+8.0%** |

The old curve *decayed* — a level at 60 was worth a quarter of a level at 2, which made
"feel it and rejoice" impossible however the numbers were tuned. Compounding does not
decay: **level 59 → 60 lands exactly like 1 → 2.**

### GROUPING BANDS — what makes the ×94 spread safe

```
lower = max(1, min(level − 5, level ÷ 2))
upper = min(60, max(level × 2, 5))
```

| Level | May group with |
|---|---|
| 1 | **1 – 5** |
| 5 | **1 – 10** |
| 10 | **5 – 20** |
| 20 | 10 – 40 |
| 30 | **15 – 60** |
| 45 | 22 – 60 |
| 60 | 30 – 60 |

**The band widens as you level.** Below level 11 the flat −5 window is the more permissive
floor; above it, half-level takes over. The top is always double.

By level 30 the band reaches the cap, so **everyone 30+ groups with everyone 30+** — the
late game is one community rather than a ladder.

**This is the piece that lets levels be enormous.** A ×94 spread would normally mean a
low-level friend cannot meaningfully play with a high-level one. Instead the game simply
does not pair them, and every pair it *does* allow sits inside roughly a 4× power window.
Grouping is gated by **band**, not by power.

It also reframes "play with your friends": rather than flattening progression so any two
players can group, a player keeps **a character reserved for that group**. That needs a
proper character-select system — `Pilot` is a single static today, one pilot per save — but
it costs progression nothing.

### XP — a level should cost real effort

```
xp_for_level(L) = 500 × (L - 1) ^ 1.6     # cumulative; L1 free
```

**10× the shipped base of 50** (user: *"you shouldn't walk outside, walk back in and level
up"*). The exponent stays at the shipped 1.6 — with the base already ten times higher,
steepening the curve too would put the late game out of reach.

| L | 2 | 10 | 20 | 30 *(lock)* | 60 |
|---|---|---|---|---|---|
| cumulative | 500 | 16,817 | 55,587 | **109,346** | 340,669 |
| that level alone | 500 | 2,889 | 4,607 | 5,970 | 9,191 |

**The first level now costs 500 XP** — around 35 kills, or 2.5 quests at 200. Previously
the tutorial licence paid for it outright.

### XP SOURCES — every profession should level by its own verb

XP is currently *~entirely combat*, which is a large part of why Miner, Scout, Trader and
Science feel thin: their signature verb does not advance them. **Each profession should
have an XP path through what it actually does.**

| Source | Status | Notes |
|---|---|---|
| **Ship kills** | BUILT | 8/10/14/40 — wants ~**×3** now that costs are ×10 and other sources exist |
| **Quests** | BUILT | 20–100 → **200**. About 2.5 per early level, which reads right |
| **Ground kills** | BUILT | flat 6/scrit, currently ignoring `kill_xp_mult` — fold into the same system |
| **Mining** | NEW | naturally bounded: ore is finite per rock, rocks are placed, travel costs time |
| **Trading** | NEW | **very minor** — see below |
| **Tutorial** | BUILT | 50 — no longer buys a level; raise with the curve |

**Trading XP staying minor is load-bearing, not caution.** If it is competitive with
combat, everyone trades, because trading is safe. It should make a Trader's own playstyle
*viable*, never optimal.

**Target: comparable XP per hour across paths**, with combat slightly ahead because it
carries risk. Otherwise one path quietly becomes correct and the rest become flavour.

### What this does to level GAPS — the best part

| Behind by | old | now |
|---|---|---|
| 5 levels | ×1.13 | **×1.47** |
| 10 levels | ×1.29 | **×2.16** |
| 17 levels | ×1.63 | **×3.70** |

(A gap wider than the band cannot be *grouped* at all — only *fought*, which is where the
Long Lane's region levels do their work.)

This is what makes the Long Lane's region bands mean something. A level-25 Recluse against
a level-8 pilot stops being a label and becomes genuinely terrifying.

### Grade factor

| Grade | Flotsam | Salvage | Standard | Advanced | Experimental | Bespoke | Exotic |
|---|---|---|---|---|---|---|---|
| ×  | 0.80 | 0.90 | **1.00** | 1.15 | 1.32 | 1.52 | **1.75** |

~15% a tier. **Standard is the anchor at 1.00** — every base number below is a Standard
number, so the existing arsenal needs no re-basing.

**Combined range: ×16.3 at the lock, ×164 at level 60** (L1 Flotsam → Exotic).

### Level and grade must BOTH matter (user, 2026-07-26)

Three constraints, and the numbers satisfy all three:

| Claim | Check | Result |
|---|---|---|
| A high level in trash is still dangerous to a low level | L30 Flotsam vs L10 Standard | **×2.1 advantage** ✓ |
| …but has no chance against a well-geared high level | L30 Flotsam vs L30 Exotic | **×2.2 against** ✓ |
| A low level in great gear flies through levelling | L10 Exotic ≈ a L20 in Standard | ✓ |

**The knob is the RATIO of the two spreads.** Levels span ×93.8, grades ×2.19 — so a full
grade ladder is worth roughly **10 levels**. If gear should feel more decisive than that,
widen the grade spread rather than touching levels; 0.6 → 2.5 would make it worth about
20. Multiply by the size-band spread
below and the real power range is far wider.

---

## 2. Hull — value only

Base hull HP by size band, at **L1, Standard**:

| Band | LIGHT | MEDIUM | HEAVY | SUPER_HEAVY | SUPER_HEAVY_PLUS |
|---|---|---|---|---|---|
| Base | **120** | **260** | **560** | **1200** | **2600** |

Roughly doubling per band — the same doubling as the art-canvas budget, so silhouette size
and toughness tell the same story.

```
hull = band_base × level_factor(L) × grade_factor(G)
```

**Anchored against what ships today:**

| Hull | L | Grade | Table says | Currently |
|---|---|---|---|---|
| Rooster | 1 | Flotsam | 96 | 110 |
| Vulture | 5 | Salvage | 281 | 320 |
| Dowager | 4 | Flotsam | 234 | 230 |
| Bellwether | 15 | Standard | 952 | 900 |
| Supercruiser | 35 | Standard | **3240** | 1800 |

Close enough to leave alone everywhere except the **Supercruiser, which is badly
under-tuned for its band** — it currently reads as barely tougher than a HEAVY freighter.
That is a real finding, not a rounding error.

---

## 3. Shields — value and regen

Base by mark, at **L1, Standard**:

| Mark | I | II | III | IV | V |
|---|---|---|---|---|---|
| Shield HP | **60** | 110 | 190 | 320 | 520 |
| Regen /s | **4.0** | 5.4 | 7.2 | 9.6 | 12.8 |

(×1.7 a mark, anchored on the Veil Shield's 60/4.0.)

```
shield_hp = mark_base × level_factor × grade_factor
regen     = regen_base × level_factor^0.5 × grade_factor^0.5     ← SUB-LINEAR, on purpose
```

**The square roots are the trap guard.** At L60 Exotic a Mk1 shield pool goes 60 → 415
(6.9×) while its regen goes 4.0 → 10.5 (2.6×). A bigger shield that refills at a similar
rate is straightforwardly better; one that also refills proportionally faster would make
armor and hull irrelevant, because `SHIELD_REGEN_DELAY` is a fixed 2.5s that does not scale.

---

## 4. Armor — value and DR

Base by mark, at **L1, Standard**:

| Mark | I | II | III | IV | V |
|---|---|---|---|---|---|
| Armor HP | **80** | 145 | 250 | 420 | 680 |

(Anchored on Bulwark Plating's 80.) Value scales exactly like a pool:

```
armor_hp = mark_base × level_factor × grade_factor
```

### DR — the curve

DR does **not** multiply out. Both axes feed one rating, and the rating goes through a
flattening curve to a hard cap:

```
rating = L + grade_tier × 10 + mark × 5          # grade_tier: Flotsam 0 … Exotic 6
dr     = DR_CAP × rating / (rating + K)

DR_CAP = 0.40      K = 40
```

| Situation | rating | DR |
|---|---|---|
| L1 Flotsam Mk1 | 6 | **5.2%** |
| L1 Standard Mk1 | 26 | 15.8% |
| L10 Standard Mk2 | 40 | 20.0% |
| L25 Advanced Mk3 | 70 | 25.5% |
| L45 Experimental Mk4 | 105 | 29.0% |
| L60 Exotic Mk5 | 145 | **31.4%** |

**~5% → ~31%, hard-capped at 40%** — and verified: the highest DR appearing anywhere in
all seven generated tables is **31.4%**. Both axes contribute, early rating is worth far more
than late, and no combination of level and grade can ever break the cap.

**Marine affinity: raise `DR_CAP`, never the rating.** At `DR_CAP = 0.55` a Marine's L60
Exotic Mk5 reads **43%** — a real ceiling nobody else reaches, on the same curve. Adding to
the *rating* instead would climb the flat end and feel like nothing.

---

## 5. Weapons — damage

Base **DPS** by mark, at **L1, Standard**:

| Mark | I | II | III | IV | V |
|---|---|---|---|---|---|
| DPS | **20** | 34 | 58 | 98 | 166 |

(×1.7 a mark, anchored on the VK-2's 5 damage / 0.25s = 20 dps.)

```
dps = mark_base × level_factor × grade_factor
damage_per_shot = dps × fire_interval
```

**Time-to-kill sanity check** — the reason to trust the shape:

| Matchup | dps | target hull | TTK |
|---|---|---|---|
| L1 Standard Mk1 → L1 Flotsam LIGHT | 20 | 96 | ~4.8s |
| L60 Exotic Mk5 → L60 Exotic SUPER_HEAVY_PLUS | 1148 | 17972 | ~16s |

Early fights stay brisk, capital fights stay long, and **offense and defence scale at the
same rate** — so a level-25 Recluse is terrifying to a level-8 pilot because of the *gap*,
not because absolute numbers ran away.

### Recurring damage (`damage_cycle`)

DoT weapons trade immediacy for total, and are rarer:

```
dot_dps = dps × 0.60 × level_factor^0.8 × grade_factor^0.8
```

Lower base **and** lower scaling, per §9.8.

---

## 6. Damage types

| Type | vs Shields | vs Armor | vs Hull | Rider |
|---|---|---|---|---|
| **Impact** | 100% | 100% | 100% | — |
| **Heat** | 100% | 100% | 100% | builds **Heat stacks** (strips armor DR) |
| **Antimatter** | **75%** | **75%** | **125%** | — |
| **Radiation** | **125%** | 75% | 75% | extended regen cut + **Contamination** |

±25%, one owner per layer, no overlap with HESH. Gear may modify these further.

### Contamination

| | |
|---|---|
| Build | **0.025%** per hit, unshielded targets only |
| Cap | **5%** — *tunable to 10%* |
| Decay | **0.01% / 3s** (~15 min to clear a 3% dose) |
| Clears at dock | yes |

---

## 7. What this replaces, and what it costs

`scripts/progression.gd` currently holds two placeholder formulas:

- `damage_mult(L) = 1 + (L-1) × 0.32` — **far steeper than this table** (L35 = 11.9× vs
  2.70×). Applied only in `GuardianShip`, which is why a level-35 capital instagibs
  level-1 pirates today.
- `toughness_mult(L) = 1 + (L-1) × 0.28` — also steeper, and used only as a *ratio* via
  `toughness_between`.

Adopting this table means **retuning both**, and the Guardian's `MILITARY_DMG 3.0` floor
alongside them. Do it with a playtest — the son is on the tutorial line, which is exactly
where a level-1 curve change is felt first.

### THE CODE CHANGES THIS REQUIRES

None of this is wired yet. Adopting the table means:

| Where | From | To |
|---|---|---|
| `Pilot.MAX_LEVEL` | 60 | **60 — unchanged.** Add a separate soft `LEVEL_LOCK = 30` |
| `Pilot.POINTS_PER_LEVELS` | 4 | 4 — unchanged; 15 points at 60, 7 at the lock |
| `Pilot.xp_for_level` | `50 × (L-1)^1.6` | `500 × (L-1)^1.6` |
| *(new)* grouping band | — | `max(1, min(L-5, L/2))` … `min(60, max(L×2, 5))` |
| `tutorial.gd REWARD_XP` | 50 | raise with the curve — it no longer buys a level |
| `flight_test.KILL_XP` | 8/10/14/40 | **~×3** — see XP sources |
| Quest rewards | 20–100 | **200** |
| `Progression.damage_mult` / `toughness_mult` | `1 + (L-1)×0.32` / `×0.28` | the single compounding `1.08^(L-1)` |

**Existing pilots keep their XP** — level is derived, never stored, so a save simply
re-reads at the new cap. A level-40 pilot becomes a level-30 pilot with XP to spare.

### The Navy sits above the LOCK, not above the cap

The region levels are **rim 1–5, the Long Lane 6–15, the Navy 35–40**. With the cap at 60
there is no conflict: the Navy simply sits **above the current soft lock of 30**, which is
exactly the right relationship. The fleet is out of reach *for now*, and raising the lock
later walks players toward it rather than past it.

The Supercruiser's authored level 35 needs no change — unreachable content is what a paced
reveal wants.

### The tutorial no longer buys a level

`tutorial.gd REWARD_XP = 50`, and level 2 now costs **500** — a tenth of a level, where
before it paid exactly one. That was 50 against a cost of 50: a coincidence of two
unrelated numbers rather than a decision anyone made.

**An early first level is good onboarding** — it teaches that the system exists and feels
like a reward — so `REWARD_XP` should rise with the curve rather than be left behind. The
difference is that it would now be a *deliberate* gift, sized against a level worth +8%
permanently.

**Open before implementation:**

1. **Does `Pilot.damage_mult()` survive?** With base damage carrying level and grade
   itself, a pilot-level multiplier on top is a second helping of the same axis. Cleanest is
   that gear power comes from gear and pilot level scales the *pilot* — but it is a real
   fork (`combat_space.md` §9.8).
2. **Does grade scale NPC gear too?** It would make the Long Lane's STANDARD-vs-SALVAGE
   distinction mechanical, which is desirable — and it silently buffs every lane enemy, so
   it wants doing deliberately.
3. **The Supercruiser is under-tuned for its band** (1800 against a table value of 3240).
   Fix it, or accept that SUPER_HEAVY bases should be lower than the doubling suggests.

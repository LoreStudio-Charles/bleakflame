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

### Level factor

```
level_factor(L) = 1 + (L - 1) × 0.05
```

| L | 1 | 5 | 10 | 20 | 35 | 50 | 60 |
|---|---|---|---|---|---|---|---|
| ×  | 1.00 | 1.20 | 1.45 | 1.95 | 2.70 | 3.45 | **3.95** |

A full career is **~4×**. Deliberately shallow — hulls and grades carry the rest, which is
what keeps a beloved small ship viable deep into a run.

### Grade factor

| Grade | Flotsam | Salvage | Standard | Advanced | Experimental | Bespoke | Exotic |
|---|---|---|---|---|---|---|---|
| ×  | 0.80 | 0.90 | **1.00** | 1.15 | 1.32 | 1.52 | **1.75** |

~15% a tier. **Standard is the anchor at 1.00** — every base number below is a Standard
number, so the existing arsenal needs no re-basing.

**Combined range: 6.9×** (L1 Flotsam → L60 Exotic). Multiply by the size-band spread below
and the real power range is far wider.

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

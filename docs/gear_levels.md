# Gear levels — the 1–10 band

**Specced and BUILT with the user 2026-07-26.** Companion to `docs/progression_table.md`
(the curve) and `docs/combat_space.md` §9.8–9.9 (what scales).

---

## 1. The rule

**Level is DERIVED from grade and mark, never hand-typed:**

```
level = GRADE_FLOOR[grade] + (mark - 1)
```

Quality decides when a thing reaches the shelf; size spreads it within its tier. The rule
lives once, in `generate_sample_data.gd._level_for`, so a new component is levelled
correctly the moment it is authored and re-tuning a floor is a one-line change instead of a
sweep somebody half-finishes.

| Grade | Colour | Floor | Status |
|---|---|---|---|
| Flotsam | grey | **1** | decided |
| Salvage | white | **1** | decided |
| Standard | **green** | **3** | **user, 2026-07-26** |
| Advanced | **blue** | **5** | **user, 2026-07-26** |
| Experimental | purple | **15** | **user, 2026-07-26** — *"not yet, unless it already exists"* |
| Bespoke | gold | 22 | provisional |
| Exotic | red | 30 | provisional |

**This gates the SHOP, not the item.** Salvage still drops what it drops — *"the shop sells
CLEAN factory gear; salvage is where treasure comes from."* A level-2 pilot who loots a green
plate keeps it. The rule controls what a quartermaster will *sell*, which is the pacing lever.

**One deliberate exception:** the Augur Sensor Array is authored at **10**, because role
identification gates on `level >= 10`. The derived value would be 6, silently un-gating a
capability the player is meant to buy. `_save` only fills in a level that was never set
(`<= 1`), which is what preserves exceptions like this.

---

## 2. What was authored

Seven new components. The gap that mattered most was the **shield**: the cheapest one in the
game was the *green* Veil Shield, so gating green at 3 would have left a new pilot with **no
shield at any price** — and the shield is the layer that teaches you to disengage and come
back.

| New item | Grade | Mk | Level | Why |
|---|---|---|---|---|
| **Sputter Screen** | white | 1 | **1** | the missing starter shield; 28 hp / 2.0 regen |
| **Hacksaw Scattergun** | white | 2 | **2** | first upgrade — trades over half the Junker's reach for real close-in damage, so it is a *choice*, not a bigger number |
| **Braceplate Armor** | white | 2 | **2** | between Patchplate (40) and green Bulwark (80) |
| **Kickstart Thruster** | white | 2 | **2** | between Drifter (500) and green Vectorjet (800) |
| **Halberd Repeater** | blue | 1 | **5** | see below |
| **Mirrorfield Projector** | blue | 1 | **5** | 95 hp / 6.0 regen |
| **Quickstep Drive** | blue | 1 | **5** | 980 thrust |

**Why three new blues:** every Advanced item on disk was **mark 2**, which the rule puts at
level 6 — so "blue at 5" was true of nothing at all. The three mark-1 blues are the rung that
makes the promise real.

All seven are in `SHOP_STOCK`, along with the **Tin-Ear**, which was never stocked despite
now being what the starter flies.

### The starter had to move down

The Rooster flew VK-2s, a Vectorjet, a Hearth Fusion and a Veil Shield — **all green**, i.e.
level 3 gear a level 1 pilot cannot buy. That inverted the ladder: the first affordable thing
on the shelf was a *downgrade* from what you already owned, so there was no first upgrade to
feel good about. It now flies white and grey throughout — a complete ship, every layer
present, all of them poor.

> Its sensor goes through `_make`'s `sensor` parameter, **not a slot index**. The Sensor
> Mount is appended by the generator, so its index differs per hull; naming index 5 by hand
> put a sensor in the cargo socket and `test_hulls` caught it on the first run.

---

## 3. The ladder as shipped

| Level | What arrives |
|---|---|
| **1** | Junker Slugthrower, Drifter Ion, Scrap-Cell Pile, **Sputter Screen**, Patchplate, Tin-Ear, Strapdown Pod, Grapple Scoop, Survey Routine, Scrap + Salvaged Couplings |
| **2** | **Hacksaw Scattergun, Braceplate Armor, Kickstart Thruster** |
| **3** | *green opens* — VK-2, Ferro Cutter, Bombard Pod, Skeet PD, Vectorjet, Hearth Fusion, Veil Shield, Bulwark Plating, Wayfarer, False-Bottom, Broadband Coupling |
| **4** | Drover Defense Turret |
| **5** | *blue opens* — **Halberd Repeater, Mirrorfield Projector, Quickstep Drive**, Lattice Coupling, and all 13 ability chips |
| **6** | Twinlance, Heat-Seeker, Radio-Guided Rack, Afterjet Sprint, Bastion Heavy Battery (green mk4) |
| **7** | Galean Naval Autocannon, Keelstone Fusion Plant |
| **8** | Aegis Lance Battery, Palisade Flak Battery |
| **10** | Augur Sensor Array *(authored exception)* |
| **15–18** | *purple* — Manifold Coupling 15, Aegis Composite 16, Overcharged Cell 16, Sentinel Radar 18 |
| **22** | Bespoke Coupling |

**Chips all land at 5.** They are Advanced mark 1, and 5 is a defensible place for abilities
to start — but it does mean the whole ability system unlocks in one step rather than laddering.
Worth revisiting when professions get their evaluation pass.

> ### THE GAP: levels 9 and 11–14 are empty
> Blue tops out at mark 4 (level 8), and purple now starts at 15. Nothing occupies 9, or 11
> through 14, except the Augur at 10. **1–8 is dense and very testable; the run-up to purple
> is bare.** Three ways to close it, all yours to pick: stretch Advanced to mark 5+, drop the
> purple floor to ~10, or author a mid-tier that does not exist yet. This is exactly where the
> Long Lane's own gear would live (that region is specced at levels 6–15).

---

## 4. Built vs not

**Built:**
- The derived level rule + all 52 components levelled.
- The seven new items, stocked.
- The starter re-fit.
- **Armory level-range filter** — min/max SpinBoxes, inclusive, ends shove rather than cross,
  and an emptied shelf names the band that emptied it.
- **Chips filter** — a chip is identified by *what it grants* (`Abilities.id_for_tag`), not by
  slot type or folder, because a chip and a cargo pod are both SystemDefs. The System shelf
  now excludes chips so the two are not the same list twice.

**Not built:**
- **Nothing enforces the gate.** Levels are labels the Armory *filter* reads; the shop does
  not yet refuse to sell above your level. A pilot can still set the range to 1–60 and buy a
  Palisade Flak Battery at level 1. That is the next step if the gate is meant to bite.
- Level scaling of component *stats* — still the open question from `CLAUDE.md` (*"which stats
  scale, and how loot rolls a level"*). These levels gate availability only, and deliberately
  do not pre-commit that decision.
- A dual-thumb range slider. Godot ships none (`HSlider` is single-value), so it is a bespoke
  widget; two SpinBoxes match the existing button-bar idiom and are more precise anyway.
  Deferred until there is nothing more valuable to build.

> **TWO SOURCES, ON PURPOSE.** `generate_sample_data.gd` authors weapons, engines, reactors,
> defense and systems — levels for those must be set **in the generator**, never in the
> `.tres`, or a regen silently discards them. **Chips and couplings are hand-authored** (the
> generator only mentions them in a comment), so their `level` is written directly into the
> file, which is safe precisely because no regen touches those folders. Always follow a regen
> with `test_hulls.gd`.

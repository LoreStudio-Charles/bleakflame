# Energy — design spec

User-designed 2026-07-21/22. **BUILT 2026-07-22** — steps 0–6 all shipped;
boot clean, full suite green, `tools/test_abilities.gd` guards it.

WHAT LANDED: `BuildShip.energy/energy_max/energy_regen/energy_regen_mult`
(derived in `apply_build`, ticked in `tick_common`) · `Pilot.energy_regen_mult()`
+ `Professions.energy_regen()` · `ship._spend()` gating all 14 costed abilities ·
`ship.energy_cost()` for the HUD · Going Dark ×4 · full refill on docking ·
the REACTOR PILL on the effigy · gem-bar "can't afford" state · costs written
into every module `.tres`.

NOT built, deliberately: weapon energy (deferred to v2), and AI ships are
unmetered (`energy_regen_mult` stays 1.0 and nothing spends).

## The pitch (user's words)

> A mana that regens slow, faster when Going Dark, recharges at stations and
> landings fastest. Module abilities will all draw energy. Maybe some weapons
> will draw energy — never weapons that fire ordnance or ammunition. Powerful
> energy weapons may draw very small amounts, or have their own energy source
> that drains and charges faster than ship energy used by the modules.

## FIRST: the naming collision (SETTLED 2026-07-22 — user approved)

The game **already has a thing called power**: `ReactorDef.power_output` against
each component's `power_draw`, enforced at fit time as a hard constraint
(`ship_stats.gd` — "power overdrawn: 9 draw vs 40 output"). That is a *static
budget*, checked once when you bolt the ship together.

Energy is a *spendable pool* that drains and refills in flight. Two different
concepts, and right now they would both read as "power" in the Armory.

**APPROVED.** Internals stay as they are (`power_output` / `power_draw` vs
`energy` / `energy_max` — no collision in code); the player-facing labels change:

| Concept | Today's label | **New label** |
|---|---|---|
| Static fit budget | "power draw 9" | **LOAD** 9 |
| Reactor's budget | "power output 70" | **CAPACITY** 70 |
| Spendable pool | — | **ENERGY** |

A module then reads "LOAD 9 · ENERGY 8 per use", which is unambiguous.

**BUILT 2026-07-22** (step 0 of the build sketch — copy-only, no data edits,
full suite green). Sites changed:
- `reactor_def.stat_summary()` — "power output 70" → "capacity 70"
- `ship_stats.validate()` — "power overdrawn: …" → "LOAD exceeds CAPACITY: …"
- `dock_screen.gd` ×4 — Landing Bay overview, Engineering stat strip, component
  detail header ("draw" → "load"), and the fit footer
- `flight_hud.gd` — the cockpit dash line ("power 9/70" → "load 9/70")
- `affixes.gd` ×3 — Surging ("+12% capacity"), Efficient ("−25% load"),
  Power-Hungry ("+40% load"). The *prefix* "Power-Hungry" stays: it is flavour,
  not a stat name, and it still reads correctly against LOAD.

`mining_power` is untouched — different concept, no collision.

## Where capacity and regen come from — no new fields

The elegant version uses what reactors already publish:

- **Energy max = `power_output` × `ENERGY_PER_OUTPUT`** (proposed 2.0).
  Scrap-Cell Pile 40 → 80 · Hearth Fusion 70 → 140 · Overcharged Cell 120 → 240.
  Reactors currently only *gate* fitting; this gives them a second reason to
  exist and makes upgrading one feel like something.

- **Regen = `REGEN_BASE` + `power_margin` × `REGEN_PER_MARGIN`**
  (**2.0/s** flat, plus **0.12**/s per point of unused LOAD).

  ⚠ **The flat BASE was added at build time (2026-07-22) after measuring real
  ships, and it matters.** The margin-only design assumed a typical ~25 margin.
  The actual starter Rooster runs **56 LOAD against 70 CAPACITY = 14 spare**,
  and fitting any profession module (9–12 draw each) takes that to **~0**. Pure
  margin regen would have pinned nearly every fitted ship to the 0.8 floor:
  a 20-cost Bulwark would need **25s** to afford against an **18s** cooldown, so
  every ability would have been ENERGY-gated instead of cooldown-gated — which
  reads to a player as "my abilities are broken".
  Margin is now a **bonus for flying lean**, not the entire supply.
  Guarded by `test_abilities._check_energy_math`, which asserts that a
  ZERO-margin ship still banks the dearest ability's cost within its cooldown.

  This is the good one. A ship crammed to the last watt regenerates almost
  nothing; a lean fit recharges fast. The tradeoff is emergent, legible, and
  needs **zero new data** — it also retroactively makes every existing reactor
  and module meaningful. A pilot who wants to spam abilities must leave headroom,
  which is a real fitting decision rather than a stat tax.

  Guardrail: floor the regen (`REGEN_FLOOR`, **0.8**/s) so a maxed-out fit is
  slow, never *dead*.

  *Why 0.12 and not 0.35:* a typical fit runs ~25 margin. At 0.35 that is
  8.75/s — a full 140 pool in 16 seconds, which makes energy decorative. At
  0.12 it is 3/s, ~47s to fill. "Regens slow" means slow.

## Rates

| State | Regen | Note |
|---|---|---|
| Flying | `(2.0 + margin × 0.12) × profession` /s | the baseline |
| **Going Dark** | **× 4.0** | everything is offline — the "meditate" seam already written into the Going Dark design |
| Docked / landed | **instant to full** | on `ship.dock()`, alongside repairs and the save checkpoint |

Docking already advances the calendar day and bills repairs, so a full charge
belongs there — and it reinforces "come home" as the loop's punctuation.

### Profession regen multiplier (user, 2026-07-22)

Science and Trader regenerate **faster than the combat professions**, to offset
their weaker hull/armor/shield/damage growth. It is the support tier's
compensation: they can't take a hit, so they get to keep acting.

| Tier | Professions | Multiplier | On a stock Rooster (14 margin) |
|---|---|---|---|
| Combat | Guardian, Privateer | **1.00×** | 3.68/s |
| Field | Miner, Scout | **1.15×** | 4.23/s |
| Support | **Science, Trader** | **1.35×** | 4.97/s |
| *(uncommissioned)* | — | 1.00× | 3.68/s |

Mirrors the combat tier exactly, inverted — the ladder that costs you hull pays
you back in uptime. Implement as an explicit `energy_regen` field on each
`Professions.LIST` entry (not derived from `combat_tier`), so the two can
diverge later without surgery.

**Note this is a SECOND dial for the support professions**, on top of their
existing per-level perk (Trader buy/sell, Science Insight). That is a
deliberate exception to the one-dial rule — worth being conscious of, since
the rule exists to keep professions legible. The justification: the perk is an
*economic* dial and this is a *combat-survivability* dial, and the support tier
had nothing in the second category.

## COSTS — the full pass (2026-07-22)

Modules pay on activation, from `<tag>_energy` in their `.tres` `extra`.

**Principle: cost tracks IMPACT, not cooldown.** A long cooldown already limits
an ability; charging by cooldown would make the biggest effects effectively
free. Sustained drain (cost ÷ cooldown) is the number that matters — it says
whether you can hold a rotation forever or must pick your moment.

Reference: a Hearth Fusion fit regenerates ~3.0/s combat, ~4.05/s support.

| Ability | Profession | Cost | CD | Drain /s | Impact it buys |
|---|---|---|---|---|---|
| **Survey Scan** | *(any scanner)* | **0** | — | 0 | **FREE — see below** |
| Micro-Warp | Scout | 10 | 10s | 1.00 | 900-unit blink |
| Conductive Lance | Guardian | 10 | 6s | 1.67 | 120 damage |
| Withering Timbers | Privateer | 8 | 20s | 0.40 | 150 damage over 30s |
| Tangle Shot | Miner | 12 | 12s | 1.00 | 3.5s snare, one target |
| Overload Pulse | Science | 16 | 18s | 0.89 | 3s shields-down window |
| Decoy Flare | **Trader** | 14 | 16s | 0.88 | break all locks + decoy |
| Blackout | Trader | 14 | 16s | 0.88 | 3s untargetable |
| JINX Protocol | Privateer | 20 | 22s | 0.91 | 6s team evasion buff |
| Killshot | Scout | 18 | 14s | 1.29 | 200 guaranteed damage at range |
| Crystalline Array | Miner | 18 | 16s | 1.13 | 7s placed anti-ordnance screen |
| Bulwark Projector | Guardian | 20 | 18s | 1.11 | 5s team damage reduction |
| Tender Drone | Trader | 22 | 36s | 0.61 | 140 healing, one ally |
| Umbral Cloak | Privateer *(sys 2)* | 22 | 14s | 1.57 | 6s untargetable |
| Repair Field | Science | 25 | 20s | 1.25 | 80 healing to the whole team |

**Survey Scan is FREE** (user, 2026-07-22). It is the first ability a pilot ever
uses, it is pre-slotted so the bar works out of the box, and it is the verb of
mining, exploration and three professions' standing. Metering discovery would
tax curiosity — the one thing the game most wants to reward. Zero, not "cheap".

**Reading the drain column:** every single ability sits between 0.4 and 1.7/s
against a ~3/s regen, so **any one rotation is sustainable indefinitely** —
which is the point. Energy does not gate using your ability; it gates using
*all of them at once*. Stack two and you are running a deficit; stack three and
you are on a clock. That is the intended texture, and it keeps the floor of the
game (guns, and one signature) always available.

**Two costs are deliberately under-priced by impact:** the Lance (120 damage for
10) and Timbers (150 over time for 8). The user's briefs specified "minor energy
cost" for both, and honoring the design intent beats honoring the formula. If
Guardian/Privateer damage proves too cheap in play, these two are the first
knobs to turn.

**Rejection must be visible** (project rule): not enough energy = a flash
("NOT ENOUGH ENERGY — 6/8") plus the gem drawing dim/red in the bar, exactly
like the existing "module not fitted" ✕ state.

## Weapons — DEFERRED TO v2 (user, 2026-07-22)

Ship the module pool first, watch it play, then decide whether weapons draw at
all. Guns are the floor of the game and the riskiest thing to touch before a
playtest. The rules below stand as the design when it lands.

- **Never** ordnance or ammunition weapons. Magazines are already the economy
  sink for those (`ammo_price` per round at dock); charging them twice would be
  double taxation.
- **Energy weapons draw small amounts** — small enough that normal shooting
  doesn't compete with abilities. Guns are the floor of the game; they must
  never go quiet because you used a gem.
- **Powerful energy weapons carry their OWN capacitor** — a separate pool per
  weapon that drains and refills faster than ship energy. Keeps a beam cannon's
  uptime a function of *that gun*, not of your ability loadout.
  Implementation: a `WeaponDef.capacitor` / `capacitor_regen` pair; when
  `capacitor > 0` the weapon spends its own pool and ignores ship energy.

## Build sketch

0. Relabel LOAD / CAPACITY / ENERGY (copy-only, ship it first — it is
   independent of the rest and makes every later screen readable).
1. `BuildShip.energy` / `energy_max` / `energy_regen`, derived in `apply_build`
   from `stats.power_output` and `stats.power_margin`; tick in `_physics_process`.
   Player-only profession multiplier via `Pilot.energy_regen_mult()`, matching
   the existing `Pilot.*_mult()` seam pattern — AI never runs it.
2. `ship.gd` — a `_spend(cost) -> bool` gate at the top of every `_engage_*`,
   returning false with a visible flash. Going Dark multiplies regen;
   `dock()` fills. Add `energy_cost(aid)` next to `gem_state(aid)` so the HUD
   can dim an unaffordable gem without knowing each ability's internals.
3. HUD — **the REACTOR PILL on the effigy** (user, 2026-07-22). Not another
   dashboard gauge: a pill drawn on the ship effigy *where the reactor sits*, so
   the reading is diegetic — you look at the reactor to see the reactor.
   **White-hot blue = full → black = empty** (user, 2026-07-22). Blue is the
   near-universal mana convention, so it reads as "the pool" before anyone is
   taught what it is, and a glowing electric blue suits a reactor better than
   amber. It also dodges the amber-means-money collision entirely, and sits
   naturally beside `UiTheme.ACCENT` cyan (= information/systems) — energy is a
   systems readout, not a currency.

   *Colorblind safety:* a blue→black ramp is a **luminance** change, not a hue
   pair, so it survives all three dichromacies and full monochromacy. Value is
   the safe channel.

   *But apply the house rule anyway* ("colors always pair with pips"): encode
   the level **redundantly** as a FILL HEIGHT as well as a value shift, inside a
   permanently-visible bezel. Two reasons beyond colorblindness:
   - on the `#0E1018` cockpit ground, "empty = black" makes the pill vanish —
     an empty reactor and a *missing* pill would look identical. The bezel keeps
     its extent readable at zero.
   - a small pill's absolute value is hard to judge at a glance; a fill line
     gives an exact read without a legend.

   *Animation — animate the EVENT, not the state.* A constant crackle is
   unreadable at pill size and costs frames for nothing. Put the motion on the
   **transitions** instead, where it carries information:
   - **spend** → a sharp white flash, then a fast dim to the new level. The
     discharge is felt, and the size of the drop is legible in the flash.
   - **full** → a single brief bloom the instant it tops off, then still. The
     pilot learns "I'm topped up" from the corner of their eye.
   - **critically low** → a slow pulse (not a fast strobe), the only ambient
     motion, so movement on the pill always means *trouble*.

   Event-driven motion also stays honest at 8–12px, where a shock effect would
   just read as noise.
4. Gem bar — dim/red a gem that is unaffordable right now, reusing the ✕ path.
5. Write the twelve costs above into each `.tres` `extra` (nine are new;
   Lance 8→10 and Timbers 6→8 get revised; Killshot already carries 18).
6. AI: leave enemy ships unmetered at first (they already have their own
   cooldown pacing); revisit if it reads unfair.

## Risk

A playtest is close. Gating abilities behind a resource **changes feel more than
any change this session** — a pilot who could always press [1] now sometimes
can't. Recommend shipping v1 deliberately generous (high capacity, forgiving
regen) and tightening after watching someone play, rather than tuning for
scarcity first. The Going Dark ×4 also becomes a real tactical option the moment
this exists, which is a nice side effect worth watching for.

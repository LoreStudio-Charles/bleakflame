# Profession Build-Out Guide

**Written 2026-07-26 from the code.** The working document for turning six commissions
from "one signature ability each" into full identities. Companion to
`docs/progression_reference.md` (what progression does today) and `docs/professions.md`
(the flavour and voice of each commission — unchanged, still the source of truth for who
these people *are*).

---

## Where every commission actually stands

| | tier | energy | favoured caps | perk | built abilities | ground techniques |
|---|---|---|---|---|---|---|
| **Guardian** | 0.02 | 1.00 | gunnery 5 · piloting 5 · shield 4 · evasion 4 | — | Bulwark, Lance | **Brace** |
| **Privateer** *(hidden)* | 0.02 | 1.00 | gunnery 5 · evasion 5 · salvage 5 | — | Blight, Cloak, JINX | none |
| **Miner** | 0.015 | 1.15 | prospecting 5 · hull 5 · salvage 4 | mining **(dead)** | Tangle, Crystal | none |
| **Scout** | 0.015 | 1.15 | piloting 5 · evasion 5 · prospecting 4 | scan_value **(dead)** | Warp, Killshot | none |
| **Trader** | 0.01 | 1.35 | hull 5 · piloting 4 · evasion 4 | trade ✅ | Repair Drone, Decoy *(Blackout withheld)* | none |
| **Science** | 0.01 | 1.35 | prospecting 5 · shield 4 · piloting 4 | insight **(dead)** | Repair Field, Overload | none |

Guardian is the **only** commission with four favoured skills. Privateer is the only one
with three 5-caps. Those are the two identity-defining spreads and they are already good.

---

## The four structural gaps

Fixing these matters more than adding abilities, because each one is currently a promise
the game makes and does not keep.

### 1. Trees are display-only

`branches()` is read by exactly one line of UI. **No node has a cost, prerequisite,
unlock state, level gate or standing gate.** Every ability comes from the wares → chip →
fit → gem pipeline instead.

So a "tree" today is a picture of a shop. Either:

- **(a) Make the tree real** — nodes cost something (skill points? a new currency?), gate
  on level and/or standing, and *grant* the chip or the ability directly; or
- **(b) Drop the tree metaphor** and present the commission as a curated shelf, which is
  honestly what it is.

This is the biggest open design question in progression, and everything below depends on
which way it goes.

### 2. Half the skills and three of four perks are dead

Prospecting, Salvage, Gunnery's arc half, and the Scout / Science / Miner perks. **Every
one belongs to a non-combat commission.** The effect is that Miner, Scout and Science
have a *thinner mechanical identity than the game claims they do* — their signature
non-combat verb is unimplemented while their combat tier is the lowest.

Wiring these four is cheap and immediately makes three commissions feel distinct:

| Dead thing | Where it should attach |
|---|---|
| `mining_yield_mult` | `MineableAsteroid.hit()` ore yield |
| `salvage_luck` | `Affixes.roll_for_drop` odds / drop count |
| `scan_value_mult` | Scan Data sale price and lab turn-in |
| `insight_mult` | `Research` Insight grants |
| Gunnery arcs | `WeaponMount._half_arc` |

### 3. The ground has almost no progression

Two hooks total (health, weapon damage) and **five of six commissions have no ground
technique at all.** A Miner on foot is identical to a Scientist on foot.

`docs/ground_combat.md` names an intended identity for each — Privateer drains and
terror, Miner tangle, Scout blink, Science mend-field, Trader blackout. **One technique
per commission** would do more for felt identity than any number of ship abilities,
because the ground is where you *see* your character.

### 4. Standing's top 900 points gate nothing

INVITE_AT 10 opens the door. FRIENDLY_AT 100 is read by two Shoal predicates. ALLIED_AT
500 gates **nothing**. There is no reason to grind reputation past the invitation.

Obvious hooks: prices, ware tiers, higher-value contracts, the office syllabus (which the
technique code already anticipates in a comment), and — if trees go real — node gates.

---

## The eleven unbuilt tree nodes

All are `built: false`, and because `SHOW_UNBUILT` is false they are **invisible** — the
office shows one node per branch and is headed "COMMISSION ABILITIES" rather than
"ABILITY TREE" precisely because of this.

| Commission | Branch | Node | Tier |
|---|---|---|---|
| Guardian | Bulwark | Point-defense | 2 |
| Guardian | Bulwark | Taunt Beacon | 3 |
| Guardian | Lance | Hyperslide+ | 2 |
| Privateer | Blight | Ambush Burst | 2 |
| Miner | Tangle | Blast Mining | 2 |
| Scout | Warp | Deep Sensor Sweep | 2 |
| Scout | Killshot | Disruptor Ping | 2 |
| Trader | Tender | *(second heal)* | 2 — **undesigned** |
| Trader | Decoy | Bribe Jettison | 2 |
| Science | Repair Field | Weak-point Analyzer | 2 |
| Science | Overload | Stasis Tractor | 2 |

Plus **Blackout**: built, but on the `WITHHELD` list, so its node is hidden *and* its chip
is filtered off Trader's shelf. One switch, both ends — deliberately.

---

## Per-commission notes

### Guardian — the paladin

The most complete commission: four favoured skills, both signature abilities built, and
the only ground technique in the game. Its T2/T3 nodes are the clearest to design because
the identity is settled — shields, damage reflection, weapon disable, **self-only**
healing (allied healing would erase Science and Trader).

*Next:* Point-defense is a natural fit with the existing turret traverse rules.

### Privateer — the shadow knight, and a secret

Fully built, three abilities, the only triple-5 caps — and **hidden**, absent from every
advertised surface. Its wares sell at the Shoal, not the dock.

**Its terror must stay mundane** — reputation, not the supernatural. Cinderweb keeps sole
ownership of dread. Terror rides comms and scales off Privateer standing, which is
currently the *only* designed use of standing above the invite threshold and is unbuilt.

*Next:* the plunder loop. `trader_ship.gd` wires the consequences of robbing a hauler, and
the fence *spends* stolen goods, but **nothing in flight actually acquires them.**

### Miner — the most under-served

Two built abilities, but its perk is dead, its favoured Prospecting skill is dead, and its
one live perk (`ore_sense` radar) is hardcoded and not even listed as a perk.

*Next:* wire `mining_yield_mult`. It is a one-line attachment and it makes the whole
commission mean something immediately.

### Scout — identity intact, payoff missing

Warp and Killshot are both built and both feel like a Scout. But `scan_value` is dead, so
the exploration half pays exactly what everyone else gets.

*Next:* `scan_value_mult` on Scan Data pricing, and Deep Sensor Sweep — which now has an
obvious mechanical home in `role_id_range` and the Augur array.

### Trader — the only working perk

Trade buy/sell genuinely scales with level, which makes the Trader the one commission
whose non-combat identity is real. Repair Drone and Decoy are built; Blackout is built but
withheld; the second Tender node is **explicitly undesigned**.

*Next:* design that second heal, and decide whether Blackout comes back.

### Science Officer — the researcher who doesn't research faster

Repair Field and Overload are built. `insight` is dead, so a Science Officer earns Insight
at exactly the base rate — the commission's entire premise.

*Next:* `insight_mult` on Research grants. Like the Miner, a one-line fix with a large
identity payoff.

---

## Suggested order

1. **Wire the five dead effects** (mining yield, salvage luck, scan value, insight,
   gunnery arcs). Cheap, and it makes three commissions real.
2. **Give each commission one ground technique.** Biggest felt-identity gain per unit of
   work; the effects all already exist on `GroundCharacter`.
3. **Decide the tree question** — real progression, or an honest shelf. Everything else
   waits on this.
4. **Give standing something to do above 10.**
5. **Then** build the eleven T2/T3 nodes, which is content rather than structure.

---

## Banked, not in the list

**Bounty Hunter** (7th) and **Marine** (8th, heavy-armour warrior at Orivel) are designed
in `docs/professions.md` but absent from `Professions.LIST`. The Marine's note is explicit
that it must not be "Guardian with bigger numbers" — worth re-reading before either is
started, and neither should begin before the tutorial line through Epharon and the Gate is
verified.

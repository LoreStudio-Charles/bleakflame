# Profession Build-Out Guide

**Written 2026-07-26 from the code.** Companion to `docs/progression_reference.md` (what
progression does today) and `docs/professions.md` (the flavour and voice of each
commission — unchanged, still the source of truth for who these people *are*).

> **A FULL PROFESSION EVALUATION PASS COMES FIRST (user, 2026-07-26).** The professions
> "aren't very well planned" as they stand, so **this document is INPUT to that pass, not a
> build order to execute.** It is an honest inventory of what exists, what is dead, and
> where the structural holes are — exactly the material an evaluation needs — but nothing
> here should be built until the pass decides what the six commissions actually are.
>
> The design decided since (Trader as a Druid, Science owning rad cleansing) are likewise
> *inputs*: good answers to specific questions, not a substitute for looking at all six
> together.

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

**Blackout STAYS withheld** pending the evaluation pass (user, 2026-07-26). It is already
in exactly the state that wants — no code change needed. Two observations go into the pass
with it: it is a **debuff sitting at T3 of the Tender HEALING branch**, which the Druid
split makes plainly wrong, and it is the only *built* ability the game is deliberately
hiding, which makes it the cleanest test of whatever the pass decides a tree node is.

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

### Trader — the only working perk, and the DRUID (user, 2026-07-26)

Trade buy/sell genuinely scales with level, which makes the Trader the one commission
whose non-combat identity is real. Repair Drone and Decoy are built; Blackout is built but
withheld; the second Tender node is **explicitly undesigned**.

**THE IDENTITY: a Druid.** The Trader progresses into a choice between two support modes —
**DoT and debuffs**, or **heal-over-time and buffs**. Not two commissions; two ways to play
one.

This maps onto the tree that already exists. **Tender (Healing)** becomes the HoT-and-buff
line, and its `built: false`, explicitly *undesigned* T2 node now has an obvious answer:
**the heal-over-time**. The debuff line becomes the other branch.

**The bus is already the opt-in mechanism.** Five slots; wire DoT chips or HoT chips. No
sub-commission, no lock, no new machinery — and a Trader re-specs by re-wiring at dock,
which fits the established "wire, not memorize" idiom exactly.

Two supporting facts already in the data: the Trader carries the **highest `energy_regen`
(1.35)**, which is exactly what a sustained-casting support wants, and the **lowest
`combat_tier` (0.01)**, which is what a support should have.

*Next:* design the heal-over-time on Tender T2, and **move Blackout off the Tender branch**
— it is a debuff sitting on the healing line, which the Druid split makes plainly wrong.

### Radiation cleansing — Science first, then Trader (user, 2026-07-26)

Contamination (`docs/combat_space.md`) decays over ~15–25 minutes and clears at dock, so a
**field cleanse** is a real ability with a real job.

**Science Officer gets it first.** It fits the researcher fiction, and Science currently has
the thinnest identity of the six — its `insight` perk is dead and its two built abilities
are generic. "The commission that scrubs rads" is a genuine job.

**Trader second**, arriving through the buff/heal half of the Druid split above.

Note the defensive value is **not** the 5% stat recovery — it is that a clean ship is
**harder to lock down**, since contamination is what makes control land harder. Cleansing is
a counter to controllers, not a stat-restore.

### Science Officer — the researcher who doesn't research faster

Repair Field and Overload are built. `insight` is dead, so a Science Officer earns Insight
at exactly the base rate — the commission's entire premise.

*Next:* `insight_mult` on Research grants. Like the Miner, a one-line fix with a large
identity payoff.

#### The direction (user, 2026-07-26) — SEED ONLY, not planned yet

**A weird mix of heals and control** — a cleric mashed up with a necromancer, or an
enchanter. Some healing, and some genuinely strange stuff mixed in. Science is **not** the
game's healer; a **MEDICAL OFFICER** commission may arrive later to be that. Science gets
*some* traditionally clerical tools, including **rez** — flavoured as a **Temporal
Anomaly** that brings a ship back from before it was destroyed.

The user has explicitly not planned this yet. Recorded so it is not lost, with the
questions that will bite if they are answered late:

1. **Does a rez erase a Nemesis grudge?** `Nemesis` records a defeat when a *named* hunter
   kills you, and the whole vengeance arc hangs off that. If a rez wipes the record, hunters
   like Recluse lose their teeth whenever a Science Officer is present. **Recommend the
   grudge STANDS** — you were killed and somebody brought you back, which is a better story
   than un-killing.
2. **Self-rez or others-only?** A self-rez in solo play is simply a free life and drains
   the stakes out of every encounter, Cinderweb included. **Others-only** keeps solo death
   meaningful *and* becomes a strong reason to fly together — which is what the coop north
   star wants. Ties to [[coop-campaign-northstar]].
3. **"Temporal" makes time manipulation CANON.** The Saga's Wardens are already
   *space*-folders — the WayGate is their road — so folding time is a short step but a real
   one, and it constrains the Saga afterwards (if time can be rewound, why not rewind the
   Convergence?). Either accept it deliberately or keep the fiction mundane: a **pattern
   buffer** or **phase echo** restoring a recorded state reads identically in play and
   makes no claim about time.
4. **Science and Trader would overlap.** The Trader is becoming a Druid (HoT + buffs, or
   DoT + debuffs). If Science is cleric + necro + enchanter, both commissions heal and both
   debuff. **Split them by CADENCE, not by verb:** Trader is *sustained* — over-time,
   maintenance, gradual; Science is *burst and utility* — rez, dispel, cleanse, situational
   oddities. That also leaves clean room for a Medical Officer as the dedicated,
   throughput healer later.
5. **Medical Officer would be the NINTH commission** (after Bounty Hunter and Marine, both
   banked). Each addition dilutes the others unless it owns a verb nobody else has — worth
   tracking as the list grows rather than discovering at nine.

---

## Suggested order

**Subject to the evaluation pass above.** Step 1 is safe regardless — wiring a dead stat is
correct under any profession design, because those effects are already advertised to the
player. Everything after it depends on what the pass decides.

1. **Wire the five dead effects** (mining yield, salvage luck, scan value, insight,
   gunnery arcs). Cheap, and it makes three commissions real. Note `insight` belongs to
   Science, which is also the first owner of rad cleansing — the two together finally give
   that commission a shape.
2. **Give each commission one ground technique.** Biggest felt-identity gain per unit of
   work; the effects all already exist on `GroundCharacter`.
3. **Decide the tree question** — real progression, or an honest shelf. Everything else
   waits on this.
4. **Give standing something to do above 10.**
5. **Then** build the eleven T2/T3 nodes, which is content rather than structure.

---

## Banked, not in the list

**Bounty Hunter** (7th), **Marine** (8th, heavy-armour warrior at Orivel) and now a
possible **Medical Officer** (9th, the dedicated healer — see Science above) are designed or
seeded but absent from `Professions.LIST`. The Marine's note is explicit
that it must not be "Guardian with bigger numbers" — worth re-reading before either is
started, and neither should begin before the tutorial line through Epharon and the Gate is
verified.

# Economy, Interdiction & Contraband

**Designed in conversation 2026-07-26. NOT BUILT.** The trading half of progression, the
risk that gates it, and the criminal layer that grows out of both.

Companion to `docs/progression_table.md` (which owns the XP curve and sources) and
`docs/profession_buildout.md` (which owns commission identity).

---

## 1. Trading gives XP — and why that needs a guard

Every profession should level by its own verb (see `progression_table.md`), so **trading
earns XP** — deliberately **very minor**. If trading XP were competitive with combat,
everyone would trade, because trading is *safe*. It should make a Trader's playstyle
viable, never optimal.

But XP-for-profit has an exploit surface that combat does not: **a buy-low/sell-high loop
between two docks can be run forever at no risk.** Two things close it, and they do
different jobs.

### Guard 1 — risk, which gates the VALUABLE routes

Pirates, interdiction, seizure and destruction sit on the road. This does not stop a safe
grind on its own — the station↔colony run is Guardian-patrolled and near the sanctuary —
but it does not need to, **because profit and danger correlate geographically.** The safe
loop is thin by construction; the fat routes cross the Gap. That is the same logic the
Long Lane already runs on.

### Guard 2 — price decay, which is the real answer

**Prices drift toward the average as the player settles supply and demand, recovering
slowly over time.** Per **commodity, per venue** — sell enough circuits to the colony and
the colony stops wanting circuits, regardless of where they came from.

This is the elegant guard: since XP tracks profit, **farming a route is the thing that
stops paying.** No cap, no cooldown, no arbitrary counter — the economy simply responds to
you.

It has a side effect worth having: it pushes players to **find new routes**, which feeds
discovery and the Scout. Exploration stops being flavour and becomes what keeps trade
income alive.

Three things to get right:

- **A floor, and reliable recovery.** Prices converge toward average, never invert.
  Otherwise a heavy trader can brick their own local economy with nothing to do but wait.
  Converge-and-recover, not punish.
- **`Research.day` is the natural clock** — it advances one game day per docking, so
  recovery cannot be idled past and needs no real-world timer.
- **Per save, not global.** Irrelevant today; matters the moment alt characters exist for
  playing with different groups.

---

## 2. Interdiction — the same encounter, three meanings

Nothing currently stops and boards you. Adding it gives the hauler a **failure state that
is not death**: you do not explode, you lose the cargo. That is a far better pressure for a
freight pilot than an explosion, and it is unlike anything else in the game.

**Who stops you determines what it means**, and the factions already differ enough to make
this free characterisation:

| Who | What it is | What they want |
|---|---|---|
| **Guardians** | law | to *check* — which is what makes contraband a real risk rather than a flavour word |
| **The Navy** | law, at the capital end | the same, with far more teeth |
| **Pirates** | robbery wearing the same shape | your cargo |
| **V-Shrike** | **they do not stop you** | already canon: *no prisoners, no survivors, only ash* |

That last row is the point. Three factions, one encounter, three completely different
meanings — and the V-Shrike's refusal to interdict says more about them than a paragraph
would.

It lands directly on **standing and wanted**, since who may lawfully stop you is a legal
question. A KOS pilot gets stopped; a trusted one waved through.

---

## 3. Contraband and black markets

Smuggling is less a new pillar than **connective tissue between four things already
half-built**:

- The Shoal's **fence** (`speak_easy.gd`) already buys stolen goods for Privateer standing
- The Dowager's **False-Bottom Hold** already exists — *"room the manifest never
  mentions"* — currently just +40 cargo with no fiction attached
- **Standing and wanted** already decide who shoots at you
- The **Privateer** is already the grey-work commission

Black markets want at least: **the Shoal** (obvious), **Ember Row's back room** (already
implied by the bar), and a **capital undercity** if Telon is built.

**Smuggling should be a SYSTEM anyone can touch, with a specialist who is best at it** —
exactly how mining works today. Anyone can shoot a rock; the Miner gets ore-sense and
yield. Anyone can run contraband; the Smuggler gets concealment, better black-market
prices, and a way to talk out of an inspection. The mechanic then ships without waiting on
a commission decision.

---

## 4. Smuggler and Bounty Hunter — earned on FANTASY

**The design principle, and it is a good one (user, 2026-07-26):**

> Some professions earn their place on **fantasy** rather than on role need. Han Solo means
> people want to play him. Boba Fett means people want to play bounty hunters. Some tropes
> are universal.

**With the discipline that makes it work:** *"there isn't a space wizard with laser swords
in the setting."* Tropes get taken only where the Reach can hold them. A setting with
fences, contraband, standing and a criminal harbour holds a smuggler easily; it does not
hold a mystic, and adding one would cost the setting more than it gained.

**The refinement worth keeping in mind:** fantasy earns the *slot*, but it does not supply
the *verb* — and it raises the stakes. The failure is not "a class nobody wanted"; it is
"the class everyone wanted, and it played like a Trader with a different hat". That
disappoints *more* than absence, because the fantasy set the expectation.

### The fantasy tells you the mechanics

Han Solo is not a cargo optimiser. He is: a fast ship that should not be that fast, hidden
compartments, talking his way out of an inspection, and **owing dangerous people money.**
Three quarters of that already exists here.

**The debt half is the genuinely distinct part.** No other profession carries an
*obligation that pursues them*. Everything else in the game pushes outward — standing,
contracts, exploration. A smuggler holding a marker somebody will eventually call in is a
different kind of pressure, and it is narrative rather than statistical.

### The Bounty Hunter's machinery already exists

`scripts/nemesis.gd` tracks named hunters and grudges — **that is a bounty system**, simply
pointed at the player instead of wielded by one. A Bounty Hunter runs it the other
direction. In coop, it points at people.

### Privateer overlap — force versus logistics

The Privateer *takes* things; the Smuggler *moves* them. One is violence, one is a supply
chain. That keeps them distinct, and makes them **a natural pair in coop**: the Privateer
generates contraband, the Smuggler distributes it, and neither does the other's half.

### Roster pressure

Six commissions today, plus Bounty Hunter and Marine banked, plus Medical Officer seeded.
Smuggler would be tenth. Each addition dilutes the others unless it owns a verb nobody else
has — worth tracking as the list grows rather than noticing at ten.

---

## 5. Open

1. **Does the Smuggler become a commission, or stay a system with a specialist?** Shipping
   the system first answers this on evidence.
2. **Does stock actually deplete, or is price decay the whole model?** Decay alone is
   simpler and probably sufficient.
3. **What makes an interdiction survivable?** Speed, concealment, a social check, standing,
   or a bribe — the smuggler's toolkit lives here.
4. **What is contraband?** Nothing is currently illegal. The category has to exist before
   any of this does.

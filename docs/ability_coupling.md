# The Universal Coupling — ability components

Design settled with user 2026-07-22. **Not built yet.**

## The problem it solves

Profession ability modules currently occupy System slots, and hulls are
deliberately tight — the starter Rooster has exactly two, holding sensors and a
cargo pod. Fitting an ability meant giving up cargo or sensors, so the whole
profession layer competed with basic ship function and mostly lost.

## The answer

ONE dedicated container. Abilities stop being modules and become
**COMPONENTS (chips)** that live inside it.

- **The Universal Coupling** is a slot every hull has, like the reactor — never
  traded away, never competing with cargo or sensors.
- It is presented **like a WoW bag slot**: its own element in Engineering,
  separate from the paperdoll. Click it open, drag chips in.
- A chip inside the Coupling puts its ability in the **BOOK**. Memorising to a
  [1]-[5] gem is completely unchanged — the Coupling is what you KNOW, the gems
  are what you have to hand.

Rejected on the way here: per-module-type hosting (defense chips in shields,
mobility chips in engines). Elegant, but three rule-systems — host types,
per-type capacity, composition constraints — to solve one problem. A single
container is one sentence.

## Capacity is grade, and only grade

| Grade | Colour | Chips |
|---|---|---|
| Flotsam | grey | 1 |
| Salvage | white | 2 |
| Standard | green | 4 |
| Advanced | blue | 8 |
| Experimental | purple | 16 |
| Bespoke / Exotic | gold / red | 64 |

Doubling, so each upgrade is a felt jump rather than an increment. Gold-plus at
64 is "you have won this axis", which is fine for endgame.

GENEROUS ON PURPOSE. The book is not meant to be the constraint — the FIVE gem
slots are, plus Going Dark being the only way to re-flash them away from a dock.
Holding many abilities only buys versatility; using them still costs energy and
a gem slot.

## Decisions

- **Chips move freely.** No destructive install. Consuming a chip on install
  would be an economic sink, but it fights the point: if rearranging costs you
  the chip, players pick one safe layout and never experiment. If the economy
  needs a sink later, the softer version is an EXTRACTION FEE — free to install,
  credits to pull one back out. Taxes churn, doesn't punish planning.
- **Starter Rooster ships with a SALVAGE (white, 2) Coupling** — enough for
  Survey Scan plus a first profession ability, which is the loop the tutor
  already teaches. Flotsam couplings exist as loot-tier junk.
- **The Coupling itself draws NO LOAD** (user). It is a rack, not a system —
  charging for the container would tax simply having a book. A CHIP may declare
  its own `power_draw` if what it does warrants one, so cost attaches to the
  capability rather than to the shelf it sits on.
- **No host matching.** One container, one rule.

## Build order

1. `SlotType.COUPLING` + one hardpoint on every hull (and the generator).
2. `CouplingDef` — capacity from grade via the table above.
3. `AbilityChipDef` — carries the ability `tag` and `profession_lock`. Chips are
   ordinary components otherwise: bought, carried in the hold, stashed.
4. **Storage: `ShipBuild.chips`** — a flat `Array[String]` of chip paths. There
   is exactly ONE Coupling, so a flat list beats a per-slot dictionary.
   Serialises into the existing save shape as one more key.
   ⚠ Sockets must NOT live on the component: `load()` returns the same Resource
   for a given .tres, so two ships fitting the same Coupling would share chips.
5. `Abilities.known_for_build` reads `build.chips` instead of module tags.
6. Engineering: the bag-slot element + its open panel; drag from hold/stash.
7. Migrate the twelve profession modules into chips; quartermasters sell chips.

## Open questions

- **Does Survey Scan become a chip?** If yes, the scanner module stops GRANTING
  scan and becomes a BOOSTER (its `scan_range`/`scan_time` extras still apply).
  That is a cleaner rule — *modules improve, chips grant* — but it rewrites the
  `buy_scanner` tutor lesson, which currently teaches "fit a scanner to get the
  ability".
- Do chips have mass? Probably near zero; they are cards, not hardware.
- What happens to chips when a Coupling is sold or downgraded below its fill
  level? Stash the overflow, and say so visibly.

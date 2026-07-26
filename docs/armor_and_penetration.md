# Armor as Mitigation — and the weapons that answer it

**Designed with the user 2026-07-26. QUEUED, NOT BUILT.** Nothing here is implemented;
this is the spec to build from when it comes up the queue.

---

## The problem

Right now **armor is only extra HP**. `BuildShip.take_damage` is a flat cascade —
shields absorb, then armor, then hull — so a point of armor and a point of hull are
worth exactly the same, and "armored" is just "bigger". Nothing about a weapon cares
what layer it is chewing through, so there is no such thing as a good anti-armor gun.

## The rule

**Armor also MITIGATES: it reduces the damage absorbed by the armor itself.**

The mitigation is strictly layer-local, and that boundary is the whole design:

| layer | armor DR applies? |
|---|---|
| shields | **no** |
| armor | **YES** — only while the weapon is striking the armor itself |
| hull | **no** |

So a heavily-armored ship is not globally tougher. It is tougher *for exactly as long as
its armor lasts*, and stripping the armor is a real objective rather than a formality.
This also gives shields and armor genuinely different characters: shields are a
regenerating pool, armor is an ablating wall that fights back.

## Weapon attributes that answer armor

Three ways for a weapon to be good against armor, each a different verb.

### Heat (`#`)

Weapons with Heat apply **stacks of Heat** on hit.

- Each stack reduces the target's **armor DR by 10%**, capped at **80%**.
- Armor carries a **heat dissipation rate** — usually **3**, meaning 3 seconds.

Heat is the *sustained fire* answer: it rewards staying on target, and it decays if you
break off. A slow heavy weapon will not heat anything; a fast-cycling one melts a wall
open for whatever is shooting beside it. Good on a support gun.

### Penetration (`#`)

**The first `#` damage penetrates the armor; the rest lands on the armor.**

Penetration is the *flat* answer, and it is strongest against thin or heavily-mitigating
armor — a weapon with penetration 20 pays no attention to the first 20 points of wall
regardless of how good that wall is. It scales badly against big pools, which keeps it
from being universally correct.

### HESH (`##%`)

**Does `##%` more damage to armor.** Usually **30%**.

The blunt answer: no cleverness, just a shell shaped to hurt plate. Weak against
shields and hull, so carrying one is a real loadout commitment rather than a free
upgrade.

---

## Open questions — resolve BEFORE building

The design is clear on intent; these are the places where two readings both make sense,
and guessing would bake in the wrong one.

1. **Heat dissipation, 3 = 3 seconds of what?** One stack decaying every 3 seconds, or
   all Heat clearing after 3 seconds without a hit? The first makes sustained fire a
   ramp you can lose gradually; the second makes it a cliff.
2. **Where does penetrating damage GO?** Straight to hull, or into armor but ignoring
   its DR? "Penetrates the armor" reads as the former — it should hurt the ship, not the
   wall — but that makes penetration lethal against a still-armored target, which is a
   big claim worth making on purpose.
3. **Is DR a percentage on `DefenseDef`,** and does it **stack** when two armor plates
   are fitted? Additive percentages hit 100% fast; multiplicative never quite reaches it.
4. **Does HESH apply before or after DR?** `(dmg × 1.3) × (1 − DR)` and
   `dmg × (1.3 − DR)` are very different weapons.
5. **Heat stacks: capped at 8** (8 × 10% = the stated 80% cap), or uncapped stacks with
   the *effect* capped? Matters for how fast a second gun re-melts a cooling wall.
6. **Does the player SEE heat?** An invisible ramp is an invisible mechanic. Probably a
   pip or a rising tint on the target's armor bar — the same argument that moved
   specialist role onto the targeting readout.

## Where it attaches

- `BuildShip.take_damage` — the cascade at the centre of it; today it is 10 lines with
  no notion of which layer a hit is landing on.
- `DefenseDef` — gains `damage_reduction` and `heat_dissipation`. Only `Kind.ARMOR` and
  `Kind.COMPOSITE` use them.
- `WeaponDef` — gains `heat`, `penetration`, `hesh_bonus`, all defaulting to 0 so every
  existing weapon behaves exactly as it does now.
- Heat is per-SHIP state with a decay timer, so it needs a tick — `BuildShip` already has
  `tick_common`.

## Why it is worth doing

It makes the existing arsenal mean something it currently does not. The Ferro Cutter is
a sustained beam (Heat). The Bombard's fat warhead is blunt (HESH). The Aegis Lance is a
precision instrument (Penetration). None of that needs new weapons — it needs the three
numbers above filled in on the ones already shipped, which is the same trick the turret
traverse pass pulled: a stat that turns a flat list into a set of answers.

It also gives the Long Lane's freighters a reason to exist as targets. A Bellwether with
a real armor belt is not a fat HP bar; it is a wall the V-Shrike need the right gun for.

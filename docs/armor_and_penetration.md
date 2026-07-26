# Armor as Mitigation — and the weapons that answer it

**Designed with the user 2026-07-26. SPEC COMPLETE; NOT BUILT.** Every open question is
answered — this is buildable as written, bar two small ordering points flagged in "The
resolution order". Nothing here is implemented yet.

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

## Resolved rules (user, 2026-07-26)

### 1 — Heat dissipation is SECONDS PER POINT

`heat_dissipation` is how long one point of Heat takes to shed, so **lower is better
armor**. At HD 1 the plate drops a point every second; at the usual HD 3 it drops one
every three. Take 3 stacks against HD 1 armor and your reduction improves by 1 every
second, all of it gone in 3.

It is a RAMP, not a cliff — break off and the wall cools gradually, so the pressure is
to stay on target rather than to land one perfect burst.

### 2 — Penetration goes to the HULL

The first `penetration` damage **hits the hull directly**. DR then reduces what is left,
and the reduced remainder is absorbed by armor.

So penetration hurts the ship through an intact wall. That is a strong claim, made on
purpose: it is the answer to armor you cannot out-damage, and it scales badly against
big pools, which stops it being universally correct.

### 3 — DR does NOT stack: you get the LOWEST

With several plates fitted you get the **lowest DR of all of them** — because by Murphy's
Law that is where the shot lands.

Elegant, and it does real work: mixing one cheap plate into a good suit actively hurts
you, so armor is a matched set rather than a pile. It also removes any stacking-toward-
immunity question.

### 4 — HESH is a separate, armor-only damage packet

- The `hesh_bonus` % is computed off base damage and applied **first**.
- That bonus can **only ever damage armor**.
- Against **shields** it does nothing — and it is *lost*, not deferred: even if the
  shield breaks on that hit, the HESH portion does not carry through.
- Against **hull** it is lost.
- HESH damage **exceeding the armor pool is wasted** and does not spill into hull.
- **DR reduces the HESH bonus and the base damage by the same percentage.**
- Once the anti-armor portion resolves, the rest of the hit behaves normally.

### 5 — Heat: 8 stacks, 80% hard cap

Stacks cap at **8**, and **80% is the hard ceiling** on DR reduction regardless.

The per-stack magnitude is a WEAPON stat, not a constant — the usual 10% × 8 reaches the
cap exactly, but a weak emitter applying 4% a stack tops out far short of it and simply
cannot strip good armor. That is the intended texture: heat weapons have a *reach*, and
only good ones reach the ceiling.

*(Tuning note, not a blocker: 8 stacks × 4% is 32%, where the sketch said 40%. Whether a
weak weapon's ceiling is stack-count × magnitude, or its own authored ceiling, is a knob
to settle when the numbers go in.)*

### 6 — Reporting is a GEAR TIER, not a given

Whether the player can *see* Heat depends on the armor:

| armor | what it tells you |
|---|---|
| crappy | **nothing.** It does not report. |
| good | carries sensors your computer can read and display |
| great | adds a **hazard flash** and an **audible ping** |

And the computer gets swagger of its own: **the computer may limit what data your systems
and modules can surface at all.** A great suit wired to a cheap computer still cannot
tell you much.

This is the same principle as sensor-gated role identification — information is a
capability you buy, not a free HUD element — and it deserves its own spec, because it
generalises past armor to every module that produces data. See below.

---

## Adjacent system: the COMPUTER as a data tier

Falls out of answer 6 and is worth building as its own thing.

Modules *produce* data; the **computer decides how much of it reaches you**. That gives
the long-unused `"computer"` tag a job, makes a cheap computer a real bottleneck on an
expensive suit, and gives every future telemetry feature one consistent gate instead of
each inventing its own.

It also sits naturally beside what already exists: `role_id_range` on sensors already
gates *contact* identification the same way. Armor heat, ordnance counts, enemy energy
state, module cooldowns — all the same question, asked once.

**Not specced yet.** Worth its own doc before any of it is built.

## The resolution order

Written out because every rule above is about *when* something applies, and prose hides
ordering bugs that pseudocode cannot.

```
on hit(base, weapon, target):

    # HESH is computed up front, off BASE, and is a SEPARATE armor-only packet.
    hesh = base * weapon.hesh_bonus

    # --- SHIELD LAYER ---------------------------------------------------
    # Shields know nothing about armor. No DR, no penetration, no HESH.
    absorbed = min(target.shield, base)
    target.shield -= absorbed
    base         -= absorbed
    if absorbed > 0:
        hesh = 0        # HESH struck a shield: LOST, even if the shield broke

    # --- ARMOR LAYER ----------------------------------------------------
    # DR is the LOWEST of the fitted plates, softened by current Heat stacks.
    dr = lowest_dr(target.armor_plates)
    dr *= (1 - min(0.80, target.heat_stacks * weapon.heat_per_stack))

    # Penetration bypasses the wall entirely and lands on the ship.
    pen   = min(weapon.penetration, base)
    base -= pen
    target.hull -= pen

    # Everything else is mitigated, then eaten by the plate.
    to_armor      = base * (1 - dr)
    hesh_to_armor = hesh * (1 - dr)          # same DR, same hit

    armor_taken  = min(target.armor, to_armor + hesh_to_armor)
    target.armor -= armor_taken

    # BASE overflow carries to hull; HESH overflow is WASTED.
    overflow    = max(0, to_armor - target.armor_before)
    target.hull -= overflow

    target.heat_stacks = min(8, target.heat_stacks + weapon.heat)
```

**One thing the spec does not state, flagged rather than guessed:** whether
**penetration also bypasses SHIELDS**. The order above says no — shields absorb first,
and penetration is an armor-layer interaction — which keeps shields as the clean outer
answer and stops penetration being a universal solvent. If penetration should punch
through a live shield too, that is a one-line move and a very different weapon.

Second, smaller: whether **HESH overflow is wasted against the armor POOL or against
what the plate can absorb this tick**. The order above uses the pool.

## Where it attaches

- `BuildShip.take_damage` — the cascade at the centre of it; today it is 10 lines with
  no notion of which layer a hit is landing on.
- `DefenseDef` — gains `damage_reduction`, `heat_dissipation` (SECONDS PER POINT, so
  lower is better) and a `reporting` tier (none / readout / hazard-flash+ping). Only
  `Kind.ARMOR` and `Kind.COMPOSITE` use them.
- `WeaponDef` — gains `heat` (stacks applied per hit), `heat_per_stack` (the % of DR each
  stack strips — a WEAPON stat, so weak emitters cannot reach the 80% ceiling),
  `penetration` and `hesh_bonus`. All default to 0, so every existing weapon behaves
  exactly as it does today and the system is opt-in per gun.
- Heat is per-SHIP state with a decay timer, so it needs a tick — `BuildShip` already has
  `tick_common`. Decay is one point per `heat_dissipation` seconds.
- `lowest_dr()` needs the FITTED PLATES, not the summed pool: `ShipStats` aggregates
  armor into one number today and would have to keep the per-plate DRs to find the
  minimum.

## Why it is worth doing

It makes the existing arsenal mean something it currently does not. The Ferro Cutter is
a sustained beam (Heat). The Bombard's fat warhead is blunt (HESH). The Aegis Lance is a
precision instrument (Penetration). None of that needs new weapons — it needs the three
numbers above filled in on the ones already shipped, which is the same trick the turret
traverse pass pulled: a stat that turns a flat list into a set of answers.

It also gives the Long Lane's freighters a reason to exist as targets. A Bellwether with
a real armor belt is not a fat HP bar; it is a wall the V-Shrike need the right gun for.
